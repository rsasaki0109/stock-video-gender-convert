#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BEST_SCRIPT="$ROOT_DIR/scripts/run_pass1_best.sh"

PAYLOAD_PATH="${1:-$ROOT_DIR/pass1_canonical_payload.json}"
REF_IMAGE="${2:-${PASS1_FINAL_REF_IMAGE:-}}"
SOURCE_VIDEO="${3:-${PASS1_FINAL_SOURCE_VIDEO:-/media/sasaki/aiueo/ai_coding_ws/ComfyUI/input/source.mp4}}"

if [[ -z "$REF_IMAGE" ]]; then
  echo "Usage: $0 [payload_json] <ref_image> [source_video]" >&2
  echo "Example: $0 $ROOT_DIR/pass1_canonical_payload.json $ROOT_DIR/output/reference/jp_ref_01.jpg" >&2
  exit 1
fi

env \
  PASS1_FINAL_SOURCE_VIDEO="$SOURCE_VIDEO" \
  PASS1_FINAL_REF_IMAGE="$REF_IMAGE" \
  PASS1_FINAL_BASENAME="${PASS1_FINAL_BASENAME:-source_jp_early20s_probe}" \
  PASS1_FINAL_COMFY_FILENAME_PREFIX="${PASS1_FINAL_COMFY_FILENAME_PREFIX:-pass1_source_jp_early20s_probe}" \
  PASS1_FINAL_IPADAPTER_WEIGHT="${PASS1_FINAL_IPADAPTER_WEIGHT:-0.24}" \
  PASS1_FINAL_POSITIVE_EXTRA_CSV="${PASS1_FINAL_POSITIVE_EXTRA_CSV:-young adult Japanese woman,early 20s adult,natural beauty,clear skin,soft youthful face,gentle eyes,subtle makeup,soft blush,light lip tint,refined jawline,elegant portrait}" \
  PASS1_FINAL_NEGATIVE_EXTRA_CSV="${PASS1_FINAL_NEGATIVE_EXTRA_CSV:-child,minor,teenager,middle aged,elderly,harsh makeup,masculine jawline,heavy brow,beard,stubble}" \
  bash "$BEST_SCRIPT" "$PAYLOAD_PATH"
