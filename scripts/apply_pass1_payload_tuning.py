#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

FEMALE_LEVEL_PRESETS = [
    {
        "label": "base",
        "ipadapter_weight": 0.68,
        "ksampler": {
            "steps": 24,
            "cfg": 4.5,
            "denoise": 0.48,
        },
        "positive_additions": [],
        "negative_additions": [
            "male appearance",
            "beard",
            "masculine face",
        ],
    },
    {
        "label": "strong-female",
        "ipadapter_weight": 0.78,
        "ksampler": {
            "steps": 28,
            "cfg": 4.8,
            "denoise": 0.50,
        },
        "positive_additions": [
            "feminine face",
            "feminine jawline",
            "soft makeup",
            "delicate eyes",
        ],
        "negative_additions": [
            "male appearance",
            "beard",
            "masculine face",
            "stubble",
            "broad jaw",
        ],
    },
    {
        "label": "extra-female",
        "ipadapter_weight": 0.88,
        "ksampler": {
            "steps": 30,
            "cfg": 5.0,
            "denoise": 0.52,
        },
        "positive_additions": [
            "clearly female face",
            "soft feminine skin",
            "elegant feminine features",
            "subtle feminine makeup",
            "smooth feminine jawline",
        ],
        "negative_additions": [
            "male appearance",
            "male features",
            "beard",
            "stubble",
            "moustache",
            "broad jaw",
        ],
    },
    {
        "label": "max-female",
        "ipadapter_weight": 0.95,
        "ksampler": {
            "steps": 32,
            "cfg": 5.3,
            "denoise": 0.55,
        },
        "positive_additions": [
            "clearly female, photorealistic woman",
            "feminine, soft features",
            "natural feminine skin texture",
            "refined lips and eyes",
            "longer hair",
        ],
        "negative_additions": [
            "male appearance",
            "beard",
            "stubble",
            "masculine jawline",
            "broad nose",
            "heavy brow",
        ],
    },
    {
        "label": "extreme-female-1",
        "ipadapter_weight": 1.15,
        "ksampler": {
            "steps": 36,
            "cfg": 5.8,
            "denoise": 0.58,
        },
        "positive_additions": [
            "clearly female person, female character",
            "feminine face shape, soft facial features",
            "delicate jawline, smooth skin, natural lipstick",
            "long flowing hair",
        ],
        "negative_additions": [
            "male appearance",
            "beard",
            "stubble",
            "masculine jawline",
            "heavy brow",
            "broad nose",
            "wide shoulders",
        ],
    },
    {
        "label": "extreme-female-2",
        "ipadapter_weight": 1.35,
        "ksampler": {
            "steps": 40,
            "cfg": 6.2,
            "denoise": 0.62,
        },
        "positive_additions": [
            "unmistakably female face",
            "soft feminine profile",
            "woman with feminine hairstyle",
            "natural makeup, subtle lipstick",
            "elegant feminine expression",
        ],
        "negative_additions": [
            "male appearance",
            "male face",
            "masculine body",
            "broad jaw",
            "beard",
            "moustache",
            "stubble",
        ],
    },
]

NEGATIVE_HINTS = [
    "deformed face",
    "bad anatomy",
    "extra fingers",
    "blurry",
    "plastic skin",
    "warped mouth",
    "asymmetrical eyes",
    "lowres",
    "artifacts",
]


def parse_args():
    parser = argparse.ArgumentParser(
        description="Apply seed and female conversion tuning to a ComfyUI payload."
    )
    parser.add_argument("--input", required=True, help="Input ComfyUI prompt payload file")
    parser.add_argument("--output", required=True, help="Output ComfyUI prompt payload file")
    parser.add_argument("--seed", type=int, required=True, help="KSampler seed")
    parser.add_argument(
        "--female-level",
        type=int,
        default=0,
        help="Female strength tuning level (0..3)",
    )
    return parser.parse_args()


def append_if_missing(base: str, fragment: str) -> str:
    if not fragment:
        return base
    if not base:
        return fragment
    base_l = base.lower()
    if fragment.lower() in base_l:
        return base
    return f"{base}, {fragment}"


def is_negative_prompt(text: str) -> bool:
    t = text.lower()
    return any(marker in t for marker in NEGATIVE_HINTS)


def ensure_payload_prompt(data):
    prompt = data.get("prompt")
    if isinstance(prompt, dict):
        return prompt, ("dict", data, None)

    if (
        isinstance(prompt, list)
        and len(prompt) >= 3
        and isinstance(prompt[2], dict)
    ):
        return prompt[2], ("list", data, 2)

    raise ValueError("Unsupported ComfyUI prompt format")


def apply_seed_and_tuning(payload_data, seed: int, level: int):
    level = max(0, min(level, len(FEMALE_LEVEL_PRESETS) - 1))
    preset = FEMALE_LEVEL_PRESETS[level]
    prompt_obj, prompt_ref = ensure_payload_prompt(payload_data)

    for node_id, node in prompt_obj.items():
        if not isinstance(node, dict):
            continue
        cls = node.get("class_type")
        inputs = node.get("inputs")
        if not isinstance(inputs, dict):
            continue

        if cls in {"KSampler", "KSamplerAdvanced"}:
            for key, value in preset["ksampler"].items():
                inputs[key] = value

        if cls == "IPAdapter":
            inputs["weight"] = float(preset["ipadapter_weight"])

        if cls == "CLIPTextEncode":
            text = inputs.get("text")
            if not isinstance(text, str):
                continue
            if is_negative_prompt(text):
                for fragment in preset["negative_additions"]:
                    text = append_if_missing(text, fragment)
            else:
                for fragment in preset["positive_additions"]:
                    text = append_if_missing(text, fragment)
            inputs["text"] = text

        if cls == "KSampler":
            inputs["seed"] = int(seed)
        if cls == "KSamplerAdvanced":
            inputs["common_ksampler"] = (
                str(inputs.get("common_ksampler", "karras")).strip() or "karras"
            )
            inputs["seed"] = int(seed)


def main():
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)
    if not input_path.exists():
        raise SystemExit(f"input file not found: {input_path}")

    with input_path.open("r", encoding="utf-8") as f:
        payload_data = json.load(f)

    apply_seed_and_tuning(payload_data, args.seed, args.female_level)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(payload_data, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
