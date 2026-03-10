#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERP_SCRIPT="$ROOT_DIR/scripts/interpolate_video_24fps.sh"

bash "$INTERP_SCRIPT" \
  "$ROOT_DIR/output/video/source_male_8fps_prod_v1_publish_ready.mp4" \
  "$ROOT_DIR/output/video/source_male_8fps_prod_v1_publish_ready_interp24.mp4"

bash "$INTERP_SCRIPT" \
  "$ROOT_DIR/output/video/source_seg26_8fps_prod_v2_publish_ready.mp4" \
  "$ROOT_DIR/output/video/source_seg26_8fps_prod_v2_publish_ready_interp24.mp4"

bash "$INTERP_SCRIPT" \
  "$ROOT_DIR/output/video/source_seg53_8fps_prod_v3_publish_ready.mp4" \
  "$ROOT_DIR/output/video/source_seg53_8fps_prod_v3_publish_ready_interp24.mp4"
