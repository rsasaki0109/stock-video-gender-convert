#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/workspace/ai_coding_ws/ComfyUI"
INPUT_DIR="$ROOT_DIR/input"
MODELS_DIR="$ROOT_DIR/models"

required_inputs=(
  "$INPUT_DIR/source.mp4"
  "$INPUT_DIR/ref_face.jpg"
)

required_models=(
  "$MODELS_DIR/checkpoints/sdxl-base.safetensors"
  "$MODELS_DIR/controlnet/controlnet-openpose-sdxl.safetensors"
  "$MODELS_DIR/ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors"
  "$MODELS_DIR/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
)

missing=0

echo "[pass1-judge] checking inputs"
for f in "${required_inputs[@]}"; do
  if [[ -s "$f" ]]; then
    echo "  OK input: $f"
  else
    echo "  MISSING input: $f"
    ((missing+=1))
  fi
done

echo "[pass1-judge] checking models"
for f in "${required_models[@]}"; do
  if [[ -s "$f" ]]; then
    echo "  OK model: $f"
  else
    echo "  MISSING model: $f"
    ((missing+=1))
  fi
done

echo "[pass1-judge] required dirs"
for d in "$MODELS_DIR/checkpoints" "$MODELS_DIR/controlnet" "$MODELS_DIR/ipadapter" "$MODELS_DIR/clip_vision" "$INPUT_DIR"; do
  if [[ -d "$d" ]]; then
    echo "  DIR OK: $d"
  else
    echo "  DIR NG:  $d"
    ((missing+=1))
  fi
done

echo "[pass1-judge] custom node check"
if [[ -d "$ROOT_DIR/custom_nodes/comfyui_controlnet_aux" ]]; then
  echo "  OK: comfyui_controlnet_aux installed"
else
  echo "  NG: comfyui_controlnet_aux missing"
  ((missing+=1))
fi

if (( missing == 0 )); then
  echo "RESULT: PASS (ready for Pass1 run)"
  exit 0
else
  echo "RESULT: BLOCKED ($missing missing items)"
  exit 1
fi
