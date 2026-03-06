#!/usr/bin/env bash
set -euo pipefail

COMFY_DIR="/media/sasaki/aiueo/ai_coding_ws/ComfyUI"
MODEL_DIRS=(
  "$COMFY_DIR/models/checkpoints"
  "$COMFY_DIR/models/controlnet"
  "$COMFY_DIR/models/ipadapter"
  "$COMFY_DIR/models/clip_vision"
)

for d in "${MODEL_DIRS[@]}"; do
  mkdir -p "$d"
done

FORCE_DOWNLOAD=${PASS1_FORCE_DOWNLOAD:-0}

download_if_missing() {
  local url="$1"
  local dest="$2"
  local label="$3"

  if [[ -s "$dest" && "$FORCE_DOWNLOAD" != "1" ]]; then
    echo "[PASS1] SKIP: already exists -> $dest"
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    echo "[PASS1] GET: $label"
    curl -L --fail --retry 3 --retry-delay 2 -o "$dest" "$url"
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    echo "[PASS1] GET: $label"
    wget -O "$dest" "$url"
    return 0
  fi

  echo "[PASS1] ERROR: curl/wget が見つかりません。$label を手動で置いてください。"
  return 1
}

download_if_missing \
  "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" \
  "$COMFY_DIR/models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors" \
  "CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"

cat <<'EOF'
[PASS1] clip_vision model download complete.
[PASS1] 既存のチェックポイント/ControlNet/IPAdapter資産を別途取得する場合は同名で配置してください。
  - checkpoints/sdxl-base.safetensors
  - controlnet/controlnet-openpose-sdxl.safetensors
  - ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors
EOF

