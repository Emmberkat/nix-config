"""image_gen backend: Flux.2 Klein 4B on a local ComfyUI, for text-to-image and edits."""

import base64
import json
import os
import random
import time
import urllib.parse
import urllib.request
import uuid

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
MODEL = "flux-2-klein-4b-fp8"
SIZES = {"square": (1024, 1024), "landscape": (1344, 768), "portrait": (768, 1344)}
MAX_REFS = 2
TIMEOUT = 600  # a cold model load takes ~2 min


def workflow(prompt, size, images, seed):
    """Text-to-image; each uploaded image adds a reference latent, which turns it into an edit."""
    wf = {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "flux-2-klein-4b-fp8.safetensors", "weight_dtype": "default"}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b.safetensors", "type": "flux2"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2-vae.safetensors"}},
        "pos0": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": prompt}},
        "neg0": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": ""}},
        "noise": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
        "sampler": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "euler"}},
        "sample": {"class_type": "SamplerCustomAdvanced", "inputs": {
            "noise": ["noise", 0], "guider": ["guider", 0], "sampler": ["sampler", 0], "sigmas": ["sigmas", 0], "latent_image": ["latent", 0]}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sample", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "hermes"}},
    }
    pos, neg = ["pos0", 0], ["neg0", 0]
    for i, name in enumerate(images, 1):
        wf[f"load{i}"] = {"class_type": "LoadImage", "inputs": {"image": name}}
        wf[f"image{i}"] = {"class_type": "ImageScaleToTotalPixels", "inputs": {
            "image": [f"load{i}", 0], "upscale_method": "lanczos", "megapixels": 1, "resolution_steps": 16}}
        wf[f"ref{i}"] = {"class_type": "VAEEncode", "inputs": {"pixels": [f"image{i}", 0], "vae": ["vae", 0]}}
        wf[f"pos{i}"] = {"class_type": "ReferenceLatent", "inputs": {"conditioning": pos, "latent": [f"ref{i}", 0]}}
        wf[f"neg{i}"] = {"class_type": "ReferenceLatent", "inputs": {"conditioning": neg, "latent": [f"ref{i}", 0]}}
        pos, neg = [f"pos{i}", 0], [f"neg{i}", 0]
    if images:  # an edit keeps the source image's shape
        wf["size"] = {"class_type": "GetImageSize", "inputs": {"image": ["image1", 0]}}
        width, height = ["size", 0], ["size", 1]
    else:
        width, height = size
    wf["guider"] = {"class_type": "CFGGuider", "inputs": {"model": ["unet", 0], "positive": pos, "negative": neg, "cfg": 1}}
    wf["sigmas"] = {"class_type": "Flux2Scheduler", "inputs": {"steps": 4, "width": width, "height": height}}
    wf["latent"] = {"class_type": "EmptyFlux2LatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}}
    return wf


def api(path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(URL + path, data, {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


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
            wf = workflow(prompt, SIZES[aspect], images, random.randint(0, 2**50))
            prompt_id = json.loads(api("/prompt", {"prompt": wf}))["prompt_id"]
            deadline = time.monotonic() + TIMEOUT
            while not (entry := json.loads(api(f"/history/{prompt_id}")).get(prompt_id)):
                if time.monotonic() > deadline:
                    raise TimeoutError(f"no result after {TIMEOUT}s")
                time.sleep(1)
            if entry["status"]["status_str"] != "success":
                raise RuntimeError(json.dumps(entry["status"]["messages"])[-1000:])
            image = api("/view?" + urllib.parse.urlencode(entry["outputs"]["save"]["images"][0]))
        except Exception as exc:  # noqa: BLE001 - surface any failure to the agent
            return error_response(error=f"ComfyUI: {exc}", **meta)
        path = save_b64_image(base64.b64encode(image).decode(), prefix="comfyui")
        return success_response(image=str(path), modality="image" if sources else "text", **meta)


def register(ctx):
    ctx.register_image_gen_provider(ComfyUIProvider())
