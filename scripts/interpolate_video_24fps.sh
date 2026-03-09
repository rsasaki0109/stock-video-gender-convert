#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 INPUT_VIDEO [OUTPUT_VIDEO]" >&2
  exit 1
fi

INPUT_VIDEO="$1"
OUTPUT_VIDEO="${2:-${INPUT_VIDEO%.*}_interp24.mp4}"
TARGET_FPS="${TARGET_FPS:-24}"
PAD_DURATION="${PAD_DURATION:-0.25}"
CRF="${CRF:-18}"
PRESET="${PRESET:-medium}"

ffmpeg -y \
  -i "$INPUT_VIDEO" \
  -vf "minterpolate=fps=${TARGET_FPS}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,tpad=stop_mode=clone:stop_duration=${PAD_DURATION}" \
  -c:v libx264 \
  -preset "$PRESET" \
  -crf "$CRF" \
  -c:a copy \
  -shortest \
  -movflags +faststart \
  "$OUTPUT_VIDEO"
