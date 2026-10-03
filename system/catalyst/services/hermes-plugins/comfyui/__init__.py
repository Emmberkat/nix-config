"""image_gen backend: Z-Image Turbo text-to-image on a local ComfyUI."""

import base64
import json
import os
import random
import time
import urllib.parse
import urllib.request

from agent.image_gen_provider import (
    DEFAULT_ASPECT_RATIO,
    ImageGenProvider,
    error_response,
    resolve_aspect_ratio,
    save_b64_image,
    success_response,
)

URL = os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188")
MODEL = "z-image-turbo-int8"
SIZES = {"square": (1024, 1024), "landscape": (1344, 768), "portrait": (768, 1344)}
TIMEOUT = 600  # a cold model load takes ~2 min


def workflow(prompt, width, height, seed):
    return {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "z_image_turbo_int8_convrot.safetensors", "weight_dtype": "default"}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b_fp8_mixed.safetensors", "type": "lumina2", "device": "default"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "model": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["unet", 0], "shift": 3}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": prompt}},
        "neg": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["pos", 0]}},
        "latent": {"class_type": "EmptySD3LatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
        "sample": {"class_type": "KSampler", "inputs": {
            "model": ["model", 0], "positive": ["pos", 0], "negative": ["neg", 0], "latent_image": ["latent", 0],
            "seed": seed, "steps": 8, "cfg": 1, "sampler_name": "res_multistep", "scheduler": "simple", "denoise": 1}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sample", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "hermes"}},
    }


def api(path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(URL + path, data, {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read()


class ComfyUIProvider(ImageGenProvider):
    name = "comfyui"

    def generate(self, prompt, aspect_ratio=DEFAULT_ASPECT_RATIO, **kwargs):
        aspect = resolve_aspect_ratio(aspect_ratio)
        meta = {"model": MODEL, "prompt": prompt, "aspect_ratio": aspect, "provider": self.name}
        try:
            wf = workflow(prompt, *SIZES[aspect], random.randint(0, 2**50))
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
        return success_response(image=str(path), **meta)


def register(ctx):
    ctx.register_image_gen_provider(ComfyUIProvider())
