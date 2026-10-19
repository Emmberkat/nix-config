"""image_gen backend: Qwen-Image 2.1 on a local ComfyUI, for text-to-image and edits."""

import base64
import io
import json
import os
import random
import time
import urllib.parse
import urllib.request
import uuid

from PIL import Image

from agent.file_safety import raise_if_read_blocked
from agent.image_gen_provider import (
    DEFAULT_ASPECT_RATIO,
    ImageGenProvider,
    error_response,
    normalize_reference_images,
    resolve_aspect_ratio,
    save_b64_image,
    success_response,
)
from tools.url_safety import create_ssrf_safe_client, is_safe_url

URL = os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188")
MODEL = "qwen_image_2.1_int8_convrot"
CLIP = "qwen3vl_8b_int8_convrot"  # 2.1 needs the 4096-dim Qwen3-VL 8B, not the 3584-dim 2.5-VL 7B
VAE = "qwen_image_2.1_vae_bf16"
LIGHTNING_LORA = "Qwen-Image-2512-Lightning-4steps-V1.0-bf16.safetensors"
SIZES = {"square": (1024, 1024), "landscape": (1344, 768), "portrait": (768, 1344)}
GEN_RESOLUTION = 1344  # square canvas for generation; cropped to the requested aspect after decode
MAX_REFS = 2
TIMEOUT = 600  # a cold model load takes ~4 min


def workflow(prompt, images, seed, lightning):
    """Text-to-image; each uploaded image becomes a reference, which turns it into an edit."""
    wf = {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": MODEL + ".safetensors", "weight_dtype": "default"}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": CLIP + ".safetensors", "type": "qwen_image"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": VAE + ".safetensors"}},
    }
    if lightning:
        wf["lora"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["unet", 0], "lora_name": LIGHTNING_LORA, "strength_model": 1.0}}
        model, steps, cfg = ["lora", 0], 4, 1.0
    else:
        model, steps, cfg = ["unet", 0], 50, 4.0
    wf["aura"] = {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": model, "shift": 3.1, "sampling": "flow"}}
    enc = {"clip": ["clip", 0], "prompt": prompt, "negative_prompt": "", "vae": ["vae", 0]}
    if images:
        # an edit: the node resizes references to ~1024 px preserving aspect; the output matches
        enc["resolution"] = 1024
        enc["images"] = {f"image_{i}": [f"load{i}", 0] for i in range(1, len(images) + 1)}
        for i, name in enumerate(images, 1):
            wf[f"load{i}"] = {"class_type": "LoadImage", "inputs": {"image": name}}
    else:
        enc["resolution"] = GEN_RESOLUTION
    wf["enc"] = {"class_type": "TextEncodeQwenImage21", "inputs": enc}
    wf["ks"] = {"class_type": "KSampler", "inputs": {
        "model": ["aura", 0], "seed": seed, "steps": steps, "cfg": cfg,
        "sampler_name": "euler", "scheduler": "simple",
        "positive": ["enc", 0], "negative": ["enc", 1], "latent_image": ["enc", 2], "denoise": 1.0}}
    wf["dec"] = {"class_type": "VAEDecode", "inputs": {"samples": ["ks", 0], "vae": ["vae", 0]}}
    wf["save"] = {"class_type": "SaveImage", "inputs": {"images": ["dec", 0], "filename_prefix": "hermes"}}
    return wf


def api(path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(URL + path, data, {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


_lightning = None


def has_lightning():
    """The 4-step LoRA makes generation ~10x faster; fall back to 50 steps without it."""
    global _lightning
    if _lightning is None:
        try:
            names = json.loads(api("/api/object_info/LoraLoader"))["LoraLoader"]["input"]["required"]["lora_name"][0]
            _lightning = LIGHTNING_LORA in names
        except Exception:  # noqa: BLE001 - missing LoRA just means the slow path
            _lightning = False
    return _lightning


def fit_aspect(data, width, height):
    """Center-crop a square render to the requested aspect, then resize to the target size."""
    img = Image.open(io.BytesIO(data))
    w, h = img.size
    target = width / height
    if w / h > target:
        new_w = int(h * target)
        left = (w - new_w) // 2
        img = img.crop((left, 0, left + new_w, h))
    else:
        new_h = int(w / target)
        top = (h - new_h) // 2
        img = img.crop((0, top, w, top + new_h))
    if img.size != (width, height):
        img = img.resize((width, height), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def read_source(ref):
    """Bytes of an http(s) URL, data: URI or local path."""
    if ref.lower().startswith(("http://", "https://")):
        if not is_safe_url(ref):
            raise ValueError(f"URL failed the SSRF safety check: {ref}")
        with create_ssrf_safe_client(timeout=60, follow_redirects=True) as client:
            resp = client.get(ref)
        resp.raise_for_status()
        return resp.content
    if ref.lower().startswith("data:"):
        return base64.b64decode(ref.partition(",")[2])
    raise_if_read_blocked(ref)
    with open(ref, "rb") as fh:
        return fh.read()


def upload(data):
    """Store an image in ComfyUI's input dir; returns the name LoadImage takes."""
    boundary = uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="hermes-{boundary}.png"\r\n\r\n'
            ).encode() + data + f"\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(URL + "/upload/image", body, {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read())["name"]


class ComfyUIProvider(ImageGenProvider):
    name = "comfyui"

    def capabilities(self):
        return {"modalities": ["text", "image"], "max_reference_images": MAX_REFS}

    def generate(self, prompt, aspect_ratio=DEFAULT_ASPECT_RATIO, *, image_url=None, reference_image_urls=None, **kwargs):
        aspect = resolve_aspect_ratio(aspect_ratio)
        sources = [image_url.strip()] if isinstance(image_url, str) and image_url.strip() else []
        sources = (sources + (normalize_reference_images(reference_image_urls) or []))[: MAX_REFS + 1]
        meta = {"model": MODEL, "prompt": prompt, "aspect_ratio": aspect, "provider": self.name}
        try:
            images = [upload(read_source(s)) for s in sources]
            wf = workflow(prompt, images, random.randint(0, 2**50), has_lightning())
            prompt_id = json.loads(api("/prompt", {"prompt": wf}))["prompt_id"]
            deadline = time.monotonic() + TIMEOUT
            while not (entry := json.loads(api(f"/history/{prompt_id}")).get(prompt_id)):
                if time.monotonic() > deadline:
                    raise TimeoutError(f"no result after {TIMEOUT}s")
                time.sleep(1)
            if entry["status"]["status_str"] != "success":
                raise RuntimeError(json.dumps(entry["status"]["messages"])[-1000:])
            image = api("/view?" + urllib.parse.urlencode(entry["outputs"]["save"]["images"][0]))
            if not images:  # generation renders a square canvas; crop to the requested aspect
                image = fit_aspect(image, *SIZES[aspect])
        except Exception as exc:  # noqa: BLE001 - surface any failure to the agent
            return error_response(error=f"ComfyUI: {exc}", **meta)
        path = save_b64_image(base64.b64encode(image).decode(), prefix="comfyui")
        return success_response(image=str(path), modality="image" if sources else "text", **meta)


def register(ctx):
    ctx.register_image_gen_provider(ComfyUIProvider())
