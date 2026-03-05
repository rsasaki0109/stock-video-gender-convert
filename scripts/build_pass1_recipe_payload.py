#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

NEGATIVE_HINTS = (
    "deformed face",
    "bad anatomy",
    "extra fingers",
    "blurry",
    "plastic skin",
    "warped mouth",
    "asymmetrical eyes",
    "lowres",
    "artifacts",
)

RECIPES = {
    "baseline_pose": {
        "width": 832,
        "height": 1472,
        "steps": 24,
        "cfg": 4.5,
        "denoise": 0.48,
        "controlnet_weight": 0.82,
        "ipadapter_weight": 0.68,
        "positive_extra": [],
        "negative_extra": [],
    },
    "pose_lock_soft": {
        "width": 768,
        "height": 1365,
        "steps": 24,
        "cfg": 4.3,
        "denoise": 0.42,
        "controlnet_weight": 0.90,
        "ipadapter_weight": 0.58,
        "positive_extra": [
            "same person",
            "same identity",
        ],
        "negative_extra": [
            "identity drift",
        ],
    },
    "female_balanced": {
        "width": 768,
        "height": 1365,
        "steps": 28,
        "cfg": 4.8,
        "denoise": 0.52,
        "controlnet_weight": 0.82,
        "ipadapter_weight": 0.78,
        "positive_extra": [
            "feminine face",
            "soft makeup",
            "delicate eyes",
        ],
        "negative_extra": [
            "male appearance",
            "beard",
            "stubble",
        ],
    },
    "female_strong": {
        "width": 768,
        "height": 1365,
        "steps": 32,
        "cfg": 5.2,
        "denoise": 0.56,
        "controlnet_weight": 0.78,
        "ipadapter_weight": 0.92,
        "positive_extra": [
            "clearly female face",
            "soft feminine profile",
            "natural lipstick",
            "feminine hairstyle",
        ],
        "negative_extra": [
            "male appearance",
            "beard",
            "masculine jawline",
            "heavy brow",
        ],
    },
    "identity_strong": {
        "width": 832,
        "height": 1472,
        "steps": 30,
        "cfg": 4.7,
        "denoise": 0.50,
        "controlnet_weight": 0.86,
        "ipadapter_weight": 1.00,
        "positive_extra": [
            "same person",
            "same identity",
            "feminine face",
        ],
        "negative_extra": [
            "identity drift",
            "male appearance",
        ],
    },
    "probe_lowres": {
        "width": 576,
        "height": 1024,
        "steps": 24,
        "cfg": 4.8,
        "denoise": 0.54,
        "controlnet_weight": 0.84,
        "ipadapter_weight": 0.82,
        "positive_extra": [
            "feminine face",
            "woman",
        ],
        "negative_extra": [
            "male appearance",
            "beard",
        ],
    },
}


def parse_args():
    parser = argparse.ArgumentParser(
        description="Build a canonical Pass1 recipe payload for ComfyUI."
    )
    parser.add_argument("--input", required=True, help="Canonical payload json")
    parser.add_argument("--output", required=True, help="Output payload json")
    parser.add_argument(
        "--recipe",
        default="baseline_pose",
        choices=sorted(RECIPES.keys()),
        help="Named recipe preset",
    )
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--frame-load-cap", type=int)
    parser.add_argument("--skip-first-frames", type=int)
    parser.add_argument("--select-every-nth", type=int)
    parser.add_argument("--force-rate", type=float)
    parser.add_argument("--frame-rate", type=float)
    parser.add_argument("--filename-prefix")
    parser.add_argument("--source-video")
    parser.add_argument("--ref-image")
    parser.add_argument("--target-width", type=int)
    parser.add_argument("--target-height", type=int)
    parser.add_argument("--steps", type=int)
    parser.add_argument("--cfg", type=float)
    parser.add_argument("--denoise", type=float)
    parser.add_argument("--controlnet-weight", type=float)
    parser.add_argument("--ipadapter-weight", type=float)
    parser.add_argument("--lora-name")
    parser.add_argument("--lora-strength-model", type=float, default=0.0)
    parser.add_argument("--lora-strength-clip", type=float, default=0.0)
    parser.add_argument("--positive-extra", action="append", default=[])
    parser.add_argument("--negative-extra", action="append", default=[])
    return parser.parse_args()


def ensure_payload_prompt(payload):
    prompt = payload.get("prompt")
    if isinstance(prompt, dict):
        return prompt
    raise ValueError("Unsupported payload format: expected top-level prompt object")


def append_if_missing(base: str, fragment: str) -> str:
    fragment = fragment.strip()
    if not fragment:
        return base
    if not base:
        return fragment
    if fragment.lower() in base.lower():
        return base
    return f"{base}, {fragment}"


def is_negative_prompt(text: str) -> bool:
    lowered = text.lower()
    return any(marker in lowered for marker in NEGATIVE_HINTS)


def maybe_set(inputs, key, value):
    if value is not None:
        inputs[key] = value


def choose(override, fallback):
    return fallback if override is None else override


def inject_lora(prompt, lora_name: str, strength_model: float, strength_clip: float):
    if not lora_name:
        prompt.pop("16", None)
        return

    prompt["16"] = {
        "class_type": "LoraLoader",
        "inputs": {
            "model": ["6", 0],
            "clip": ["6", 1],
            "lora_name": lora_name,
            "strength_model": float(strength_model),
            "strength_clip": float(strength_clip),
        },
    }

    for node in prompt.values():
        if not isinstance(node, dict):
            continue
        inputs = node.get("inputs")
        if not isinstance(inputs, dict):
            continue
        cls = node.get("class_type")

        if cls == "CLIPTextEncode" and inputs.get("clip") == ["6", 1]:
            inputs["clip"] = ["16", 1]

        if cls == "IPAdapterUnifiedLoader" and inputs.get("model") == ["6", 0]:
            inputs["model"] = ["16", 0]


def main():
    args = parse_args()
    recipe = dict(RECIPES[args.recipe])
    input_path = Path(args.input)
    output_path = Path(args.output)

    with input_path.open("r", encoding="utf-8") as f:
        payload = json.load(f)

    prompt = ensure_payload_prompt(payload)
    recipe["width"] = choose(args.target_width, recipe["width"])
    recipe["height"] = choose(args.target_height, recipe["height"])
    recipe["steps"] = choose(args.steps, recipe["steps"])
    recipe["cfg"] = choose(args.cfg, recipe["cfg"])
    recipe["denoise"] = choose(args.denoise, recipe["denoise"])
    recipe["controlnet_weight"] = (
        args.controlnet_weight
        if args.controlnet_weight is not None
        else recipe["controlnet_weight"]
    )
    recipe["ipadapter_weight"] = (
        args.ipadapter_weight
        if args.ipadapter_weight is not None
        else recipe["ipadapter_weight"]
    )
    recipe["positive_extra"] = recipe["positive_extra"] + args.positive_extra
    recipe["negative_extra"] = recipe["negative_extra"] + args.negative_extra
    inject_lora(
        prompt,
        args.lora_name or "",
        args.lora_strength_model,
        args.lora_strength_clip,
    )

    for node in prompt.values():
        if not isinstance(node, dict):
            continue
        inputs = node.get("inputs")
        if not isinstance(inputs, dict):
            continue
        cls = node.get("class_type")

        if cls == "VHS_LoadVideoPath":
            maybe_set(inputs, "video", args.source_video)
            maybe_set(inputs, "frame_load_cap", args.frame_load_cap)
            maybe_set(inputs, "skip_first_frames", args.skip_first_frames)
            maybe_set(inputs, "select_every_nth", args.select_every_nth)
            maybe_set(inputs, "force_rate", args.force_rate)

        if cls == "ResizeAndPadImage":
            inputs["target_width"] = recipe["width"]
            inputs["target_height"] = recipe["height"]

        if cls == "ACN_AdvancedControlNetApply_v2":
            inputs["strength"] = float(recipe["controlnet_weight"])

        if cls == "IPAdapter":
            inputs["weight"] = float(recipe["ipadapter_weight"])

        if cls == "KSampler":
            inputs["seed"] = int(args.seed)
            inputs["steps"] = int(recipe["steps"])
            inputs["cfg"] = float(recipe["cfg"])
            inputs["denoise"] = float(recipe["denoise"])

        if cls == "VHS_VideoCombine":
            maybe_set(inputs, "frame_rate", args.frame_rate)
            maybe_set(inputs, "filename_prefix", args.filename_prefix)
            inputs.pop("meta_batch", None)

        if cls == "LoadImage":
            maybe_set(inputs, "image", args.ref_image)

        if cls == "CLIPTextEncode":
            text = inputs.get("text")
            if not isinstance(text, str):
                continue
            fragments = (
                recipe["negative_extra"]
                if is_negative_prompt(text)
                else recipe["positive_extra"]
            )
            for fragment in fragments:
                text = append_if_missing(text, fragment)
            inputs["text"] = text

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
