#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAYLOAD_PATH="${1:-$ROOT_DIR/pass1_canonical_payload.json}"

# Smoother base motion with moderate extra cost:
# 96 frames at 12 fps still yields an 8 second clip, and interpolates cleanly to 24 fps.
export PASS1_FINAL_FRAME_CAP="${PASS1_FINAL_FRAME_CAP:-96}"
export PASS1_FINAL_FORCE_RATE="${PASS1_FINAL_FORCE_RATE:-12}"
export PASS1_FINAL_FRAME_RATE="${PASS1_FINAL_FRAME_RATE:-12}"
export PASS1_FINAL_RESOLUTION_LADDER="${PASS1_FINAL_RESOLUTION_LADDER:-704x1248,640x1136}"
export PASS1_FINAL_STEPS="${PASS1_FINAL_STEPS:-30}"
export PASS1_FINAL_CFG="${PASS1_FINAL_CFG:-8.0}"
export PASS1_FINAL_DENOISE="${PASS1_FINAL_DENOISE:-0.60}"

bash "$ROOT_DIR/scripts/run_pass1_best.sh" "$PAYLOAD_PATH"
