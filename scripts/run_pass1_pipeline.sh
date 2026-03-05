#!/usr/bin/env bash
set -euo pipefail

COMFY_DIR="/workspace/ai_coding_ws/ComfyUI"
WORKDIR="/workspace/ai_coding_ws/stock-video-gender-convert"
SKIP_READINESS=${PASS1_SKIP_READINESS:-0}
PASS1_CPU=${PASS1_CPU:-1}
PASS1_COMFYUI_ARGS=${PASS1_COMFYUI_ARGS:-}

required_models=(
  "$COMFY_DIR/models/checkpoints/sdxl-base.safetensors"
  "$COMFY_DIR/models/controlnet/controlnet-openpose-sdxl.safetensors"
  "$COMFY_DIR/models/ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors"
  "$COMFY_DIR/models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"
)

required_inputs=(
  "$COMFY_DIR/input/source.mp4"
  "$COMFY_DIR/input/ref_face.jpg"
)

if [[ "$SKIP_READINESS" != "1" ]]; then
  missing=0
  for f in "${required_models[@]}" "${required_inputs[@]}"; do
    if [[ -s "$f" ]]; then
      echo "[PASS1] OK: $f"
    else
      echo "[PASS1] MISSING: $f"
      missing=1
    fi
  done

  if [[ $missing -ne 0 ]]; then
    echo "[PASS1] モデルまたは入力素材が不足しています。先に揃えてください。"
    exit 1
  fi
else
  echo "[PASS1] PASS1_SKIP_READINESS=1 のため、モデル/素材チェックをスキップします。"
fi

cd "$COMFY_DIR"
source .venv/bin/activate

if [[ -d "$COMFY_DIR/custom_nodes/comfyui_controlnet_aux" ]]; then
  echo "[PASS1] controlnet_aux OK"
fi

if [[ "$PASS1_CPU" == "1" ]]; then
  PASS1_COMFYUI_ARGS="--cpu ${PASS1_COMFYUI_ARGS}"
fi

setsid nohup python main.py --listen 127.0.0.1 --port 8188 ${PASS1_COMFYUI_ARGS} > /tmp/comfyui_pass1.log 2>&1 < /dev/null &
COMFY_PID=$!
sleep 4

if ps -p "$COMFY_PID" > /dev/null 2>&1; then
  echo "[PASS1] ComfyUI started: http://127.0.0.1:8188"
  echo "[PASS1] UI上でワークフローファイルを読み込み、以下を設定してください"
  echo "        - runbook: $WORKDIR/comfyui_gender_swap_runbook.md"
  echo "        - pass1 blueprint: $WORKDIR/comfyui_gender_swap_pass1_blueprint.json"
  echo "[PASS1] ログ: /tmp/comfyui_pass1.log"
else
  echo "[PASS1] ComfyUI failed to start. /tmp/comfyui_pass1.log を確認してください。"
  exit 1
fi
