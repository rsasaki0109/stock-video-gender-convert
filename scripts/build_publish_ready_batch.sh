#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIP_SCRIPT="$ROOT_DIR/scripts/build_publish_ready_clip.sh"

bash "$CLIP_SCRIPT" \
  source_male_8fps_prod_v1 \
  "$ROOT_DIR/output/video/source_male_8fps_prod_v1.mp4" \
  "$ROOT_DIR/output/timing/source_male_8fps_prod_v1_timing.json" \
  196 \
  "/workspace/ai_coding_ws/ComfyUI/input/source_male.mp4"

bash "$CLIP_SCRIPT" \
  source_seg26_8fps_prod_v2 \
  "$ROOT_DIR/output/video/source_seg26_8fps_prod_v2.mp4" \
  "$ROOT_DIR/output/timing/source_seg26_8fps_prod_v2_timing.json" \
  220 \
  "/workspace/ai_coding_ws/ComfyUI/input/source.mp4"

bash "$CLIP_SCRIPT" \
  source_seg53_8fps_prod_v3 \
  "$ROOT_DIR/output/video/source_seg53_8fps_prod_v3.mp4" \
  "$ROOT_DIR/output/timing/source_seg53_8fps_prod_v3_timing.json" \
  247 \
  "/workspace/ai_coding_ws/ComfyUI/input/source.mp4"
