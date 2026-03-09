#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAYLOAD_PATH="${1:-$ROOT_DIR/pass1_canonical_payload.json}"
SOURCE_VIDEO="${PASS1_FINAL_SOURCE_VIDEO:-/workspace/ai_coding_ws/ComfyUI/input/source.mp4}"
REF_IMAGE="${PASS1_FINAL_REF_IMAGE:-$ROOT_DIR/output/reference/pass1_best_ref.jpg}"
RUN_SCRIPT="$ROOT_DIR/scripts/run_pass1_smooth_prod.sh"

run_clip() {
  local skip="$1"
  local basename="$2"
  local prefix="$3"

  env \
    PASS1_FINAL_SOURCE_VIDEO="$SOURCE_VIDEO" \
    PASS1_FINAL_REF_IMAGE="$REF_IMAGE" \
    PASS1_FINAL_SKIP_FIRST_FRAMES="$skip" \
    PASS1_FINAL_BASENAME="$basename" \
    PASS1_FINAL_COMFY_FILENAME_PREFIX="$prefix" \
    bash "$RUN_SCRIPT" "$PAYLOAD_PATH"
}

run_clip 0 source_seg00_12fps_smooth pass1_source_seg00_12fps_smooth
run_clip 39 source_seg39_12fps_smooth pass1_source_seg39_12fps_smooth
run_clip 79 source_seg79_12fps_smooth pass1_source_seg79_12fps_smooth
