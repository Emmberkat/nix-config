"""ComfyUI image generation backend for Hermes' ``image_generate`` tool.

Runs an API-format ComfyUI workflow against a ComfyUI server (default
``http://127.0.0.1:8188``) and returns the first saved image.

Workflows are plain API-format JSON (ComfyUI "Export (API)"). The plugin does
not depend on node ids: it walks the graph and

* writes the prompt into the text encoder feeding every sampler's ``positive``
  input (a ``text`` or ``prompt`` string input; walks upstream through
  conditioning nodes if needed),
* writes width/height into every latent node that has them (a linked
  width/height, e.g. from a ResolutionSelector, is replaced by the literal),
* randomises every ``seed`` / ``noise_seed``,
* points every ``filename_prefix`` at ``hermes/<model>``.

Configuration (config.yaml, all optional)::

    image_gen:
      provider: comfyui
      comfyui:
        url: http://127.0.0.1:8188       # or env COMFYUI_URL
        model: z-image-turbo-int8        # or env COMFYUI_IMAGE_MODEL
        timeout: 600                     # seconds, includes cold model loads
        sizes: {square: [1024, 1024], landscape: [1344, 768], portrait: [768, 1344]}
        workflows:                       # extra API-format workflows by id
          my-flux: /path/to/flux_api.json
"""

from __future__ import annotations

import base64
import copy
import json
import logging
import os
import random
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from agent.image_gen_provider import (
    DEFAULT_ASPECT_RATIO,
    ImageGenProvider,
    error_response,
    resolve_aspect_ratio,
    save_b64_image,
    success_response,
)

logger = logging.getLogger(__name__)

PROVIDER = "comfyui"
DEFAULT_URL = "http://127.0.0.1:8188"
DEFAULT_TIMEOUT = 600.0
POLL_SECONDS = 1.0

WORKFLOW_DIR = Path(__file__).resolve().parent / "workflows"

# Bundled workflows (workflows/<id>.json). Order = picker order; first is the default.
BUNDLED: Dict[str, Dict[str, Any]] = {
    "z-image-turbo-int8": {
        "display": "Z-Image Turbo (int8)",
        "speed": "~15s warm, ~1-2 min cold",
        "strengths": "Fast photoreal 8-step model; fits a 12 GB card alongside other GPU users",
    },
    "z-image-turbo-bf16": {
        "display": "Z-Image Turbo (bf16)",
        "speed": "~15s warm, ~3 min cold",
        "strengths": "Full-precision Z-Image; offloads part of the model on a 12 GB card",
    },
    "qwen-image-2.1": {
        "display": "Qwen-Image 2.1 (int8)",
        "speed": "minutes (25 steps, offloads on 12 GB)",
        "strengths": "Strong prompt adherence and in-image text rendering",
    },
}

# ~1 MP, multiples of 64.
DEFAULT_SIZES: Dict[str, Tuple[int, int]] = {
    "square": (1024, 1024),
    "landscape": (1344, 768),
    "portrait": (768, 1344),
}

SAMPLER_INPUTS = ("positive",)
PROMPT_KEYS = ("text", "prompt")
SEED_KEYS = ("seed", "noise_seed")


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

def _config() -> Dict[str, Any]:
    """``image_gen.comfyui`` from config.yaml ({} on any failure)."""
    try:
        from hermes_cli.config import load_config

        cfg = load_config()
        section = (cfg.get("image_gen") or {}).get(PROVIDER) if isinstance(cfg, dict) else None
        return section if isinstance(section, dict) else {}
    except Exception as exc:  # noqa: BLE001 - config is best-effort
        logger.debug("comfyui: could not load config: %s", exc)
        return {}


def _base_url(cfg: Dict[str, Any]) -> str:
    url = os.environ.get("COMFYUI_URL") or cfg.get("url") or DEFAULT_URL
    return str(url).rstrip("/")


def _timeout(cfg: Dict[str, Any]) -> float:
    try:
        return float(cfg.get("timeout", DEFAULT_TIMEOUT))
    except (TypeError, ValueError):
        return DEFAULT_TIMEOUT


def _sizes(cfg: Dict[str, Any]) -> Dict[str, Tuple[int, int]]:
    sizes = dict(DEFAULT_SIZES)
    custom = cfg.get("sizes")
    if isinstance(custom, dict):
        for aspect, wh in custom.items():
            if isinstance(wh, (list, tuple)) and len(wh) == 2:
                try:
                    sizes[str(aspect)] = (int(wh[0]), int(wh[1]))
                except (TypeError, ValueError):
                    pass
    return sizes


def _catalog(cfg: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
    """Model id -> metadata incl. ``path``; bundled first, then configured extras."""
    catalog: Dict[str, Dict[str, Any]] = {}
    for model_id, meta in BUNDLED.items():
        path = WORKFLOW_DIR / f"{model_id}.json"
        if path.is_file():
            catalog[model_id] = {**meta, "path": path}
    extra = cfg.get("workflows")
    if isinstance(extra, dict):
        for model_id, path in extra.items():
            if isinstance(path, str) and path.strip():
                catalog[str(model_id)] = {
                    "display": str(model_id),
                    "strengths": "Custom workflow",
                    "path": Path(os.path.expanduser(path.strip())),
                }
    return catalog


def _resolve_model(catalog: Dict[str, Dict[str, Any]], cfg: Dict[str, Any],
                   explicit: Optional[str]) -> Optional[str]:
    """explicit (``image_gen.model``) -> env -> ``image_gen.comfyui.model`` -> first.
    Unknown ids fall through: the top-level ``image_gen.model`` may belong to another provider."""
    for candidate in (explicit, os.environ.get("COMFYUI_IMAGE_MODEL"), cfg.get("model")):
        if isinstance(candidate, str) and candidate.strip() in catalog:
            return candidate.strip()
    return next(iter(catalog), None)


# ---------------------------------------------------------------------------
# Workflow patching
# ---------------------------------------------------------------------------

def _is_link(value: Any) -> bool:
    return (isinstance(value, list) and len(value) == 2
            and isinstance(value[0], str) and isinstance(value[1], int))


def _find_prompt_node(wf: Dict[str, Any], start: str) -> Optional[Tuple[str, str]]:
    """Breadth-first upstream from ``start`` to the nearest node with a string prompt input."""
    seen, queue = set(), [start]
    while queue:
        node_id = queue.pop(0)
        if node_id in seen or node_id not in wf:
            continue
        seen.add(node_id)
        inputs = wf[node_id].get("inputs", {})
        for key in PROMPT_KEYS:
            if isinstance(inputs.get(key), str):
                return node_id, key
        queue.extend(v[0] for v in inputs.values() if _is_link(v))
    return None


def patch_workflow(wf: Dict[str, Any], *, prompt: str, width: int, height: int,
                   seed: int, prefix: str) -> Dict[str, Any]:
    """Return a patched deep copy. Raises ValueError if no prompt input can be found."""
    wf = copy.deepcopy(wf)
    prompt_targets = set()
    for node in wf.values():
        inputs = node.get("inputs", {})
        for key in SAMPLER_INPUTS:
            if _is_link(inputs.get(key)):
                found = _find_prompt_node(wf, inputs[key][0])
                if found:
                    prompt_targets.add(found)
    if not prompt_targets:
        raise ValueError("workflow has no sampler 'positive' input leading to a text/prompt field")
    for node_id, key in prompt_targets:
        wf[node_id]["inputs"][key] = prompt

    for node in wf.values():
        inputs = node.get("inputs", {})
        if "width" in inputs and "height" in inputs and str(node.get("class_type", "")).startswith("Empty"):
            inputs["width"], inputs["height"] = width, height
        for key in SEED_KEYS:
            if key in inputs and not _is_link(inputs[key]):
                inputs[key] = seed
        if isinstance(inputs.get("filename_prefix"), str):
            inputs["filename_prefix"] = prefix
    return wf


# ---------------------------------------------------------------------------
# ComfyUI HTTP
# ---------------------------------------------------------------------------

class ComfyError(Exception):
    def __init__(self, message: str, error_type: str = "provider_error"):
        super().__init__(message)
        self.error_type = error_type


def _request(url: str, *, data: Optional[bytes] = None, timeout: float = 30.0) -> bytes:
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"} if data else {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        raise ComfyError(f"ComfyUI HTTP {exc.code} for {url}: {_describe_http_error(body)}",
                         "api_error") from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise ComfyError(f"Cannot reach ComfyUI at {url}: {exc}", "connection_error") from exc


def _describe_http_error(body: str) -> str:
    """Condense ComfyUI's /prompt validation error JSON into one line."""
    try:
        data = json.loads(body)
    except ValueError:
        return body[:500]
    parts = []
    err = data.get("error")
    if isinstance(err, dict):
        parts.append(err.get("message") or err.get("type") or "")
    for node_id, node_err in (data.get("node_errors") or {}).items():
        for e in node_err.get("errors", []):
            parts.append(f"node {node_id} ({node_err.get('class_type')}): {e.get('message')} {e.get('details', '')}".strip())
    return "; ".join(p for p in parts if p)[:1000] or body[:500]


def _execution_error(entry: Dict[str, Any]) -> str:
    for msg in (entry.get("status") or {}).get("messages", []):
        if isinstance(msg, list) and len(msg) == 2 and msg[0] == "execution_error":
            d = msg[1]
            return f"{d.get('node_type')} (node {d.get('node_id')}): {d.get('exception_message', '').strip()}"
    return "execution failed (no error message in history)"


def run_workflow(base: str, wf: Dict[str, Any], timeout: float) -> Tuple[str, List[Dict[str, Any]]]:
    """Submit ``wf``, wait for it, return ``(prompt_id, images)`` from its outputs."""
    payload = json.dumps({"prompt": wf, "client_id": f"hermes-{uuid.uuid4()}"}).encode()
    resp = json.loads(_request(f"{base}/prompt", data=payload))
    prompt_id = resp.get("prompt_id")
    if not prompt_id:
        raise ComfyError(f"ComfyUI rejected the workflow: {_describe_http_error(json.dumps(resp))}", "api_error")

    deadline = time.monotonic() + timeout
    while True:
        history = json.loads(_request(f"{base}/history/{urllib.parse.quote(prompt_id)}"))
        entry = history.get(prompt_id)
        if entry:
            status = entry.get("status") or {}
            if status.get("status_str") == "error":
                raise ComfyError(f"ComfyUI execution error: {_execution_error(entry)}", "execution_error")
            if status.get("completed") or status.get("status_str") == "success":
                images = [img for out in (entry.get("outputs") or {}).values()
                          for img in (out.get("images") or []) if img.get("type") == "output"]
                if not images:
                    raise ComfyError("ComfyUI finished but produced no saved images", "empty_response")
                return prompt_id, images
        if time.monotonic() > deadline:
            raise ComfyError(
                f"Timed out after {timeout:.0f}s waiting for ComfyUI job {prompt_id} "
                f"(it may still finish; raise image_gen.comfyui.timeout for cold model loads)", "timeout")
        time.sleep(POLL_SECONDS)


def fetch_image(base: str, image: Dict[str, Any]) -> bytes:
    query = urllib.parse.urlencode({
        "filename": image.get("filename", ""), "subfolder": image.get("subfolder", ""),
        "type": image.get("type", "output")})
    return _request(f"{base}/view?{query}", timeout=60.0)


# ---------------------------------------------------------------------------
# Provider
# ---------------------------------------------------------------------------

class ComfyUIImageGenProvider(ImageGenProvider):
    """Local ComfyUI backend driven by API-format workflow templates."""

    @property
    def name(self) -> str:
        return PROVIDER

    @property
    def display_name(self) -> str:
        return "ComfyUI (local)"

    def is_available(self) -> bool:
        # Cheap on purpose (called when building tool schemas): no network probe.
        # An unreachable server surfaces as a clear connection_error at generate time.
        return bool(_catalog(_config()))

    def list_models(self) -> List[Dict[str, Any]]:
        return [{"id": mid, "display": m.get("display", mid), "speed": m.get("speed", ""),
                 "strengths": m.get("strengths", ""), "price": "free (local GPU)"}
                for mid, m in _catalog(_config()).items()]

    def default_model(self) -> Optional[str]:
        cfg = _config()
        return _resolve_model(_catalog(cfg), cfg, None)

    def get_setup_schema(self) -> Dict[str, Any]:
        return {"name": "ComfyUI (local)", "badge": "local",
                "tag": "Runs API-format workflows on your own ComfyUI server", "env_vars": []}

    def capabilities(self) -> Dict[str, Any]:
        return {"modalities": ["text"], "max_reference_images": 0}

    def generate(self, prompt: str, aspect_ratio: str = DEFAULT_ASPECT_RATIO, *,
                 image_url: Optional[str] = None, reference_image_urls: Optional[List[str]] = None,
                 **kwargs: Any) -> Dict[str, Any]:
        prompt = (prompt or "").strip()
        aspect = resolve_aspect_ratio(aspect_ratio)
        cfg = _config()
        catalog = _catalog(cfg)
        model_id = _resolve_model(catalog, cfg, kwargs.get("model")) or ""

        def fail(error: str, error_type: str) -> Dict[str, Any]:
            return error_response(error=error, error_type=error_type, provider=PROVIDER,
                                  model=model_id, prompt=prompt, aspect_ratio=aspect)

        if image_url or reference_image_urls:
            return fail("The ComfyUI backend is text-to-image only; image_url and "
                        "reference_image_urls are not supported.", "modality_unsupported")
        if not prompt:
            return fail("Prompt is required and must be a non-empty string", "invalid_input")
        if not model_id:
            return fail("No ComfyUI workflow available (bundled workflows missing and none "
                        "configured under image_gen.comfyui.workflows).", "no_model_available")

        try:
            template = json.loads(Path(catalog[model_id]["path"]).read_text())
        except (OSError, ValueError) as exc:
            return fail(f"Cannot load workflow for '{model_id}': {exc}", "invalid_workflow")

        width, height = _sizes(cfg).get(aspect, DEFAULT_SIZES["square"])
        seed = random.randint(0, 2**50)
        try:
            wf = patch_workflow(template, prompt=prompt, width=width, height=height,
                                seed=seed, prefix=f"hermes/{model_id}")
        except ValueError as exc:
            return fail(f"Workflow '{model_id}' is not usable: {exc}", "invalid_workflow")

        base = _base_url(cfg)
        started = time.monotonic()
        try:
            prompt_id, images = run_workflow(base, wf, _timeout(cfg))
            first = images[0]
            data = fetch_image(base, first)
        except ComfyError as exc:
            logger.warning("comfyui generation failed: %s", exc)
            return fail(str(exc), exc.error_type)

        ext = Path(first.get("filename", "")).suffix.lstrip(".").lower() or "png"
        path = save_b64_image(base64.b64encode(data).decode("ascii"),
                              prefix=f"comfyui_{model_id}", extension=ext)
        return success_response(
            image=str(path), model=model_id, prompt=prompt, aspect_ratio=aspect, provider=PROVIDER,
            extra={"seed": seed, "width": width, "height": height, "comfyui_prompt_id": prompt_id,
                   "comfyui_file": f"{first.get('subfolder', '')}/{first.get('filename', '')}".lstrip("/"),
                   "generation_seconds": round(time.monotonic() - started, 1)})


def register(ctx) -> None:
    """Plugin entry point."""
    ctx.register_image_gen_provider(ComfyUIImageGenProvider())
