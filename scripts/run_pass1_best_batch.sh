#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BEST_SCRIPT="$ROOT_DIR/scripts/run_pass1_best.sh"
PREFLIGHT_SCRIPT="$ROOT_DIR/scripts/check_source_video_face_preflight.py"
PAYLOAD_PATH="${1:-$ROOT_DIR/pass1_canonical_payload.json}"
PREFLIGHT_DIR="${PASS1_BATCH_PREFLIGHT_DIR:-$ROOT_DIR/output/preflight}"

shift || true

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <canonical_payload_json> <video1> [video2 ...]" >&2
  exit 1
fi

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alnum:]' '_' \
    | sed 's/^_//; s/_$//'
}

REF_IMAGE="${PASS1_BATCH_REF_IMAGE:-${PASS1_FINAL_REF_IMAGE:-}}"
PREFLIGHT_SAMPLE_COUNT="${PASS1_BATCH_PREFLIGHT_SAMPLE_COUNT:-12}"
PREFLIGHT_MIN_DETECTED_RATIO="${PASS1_BATCH_PREFLIGHT_MIN_DETECTED_RATIO:-0.60}"
PREFLIGHT_MIN_MEAN_FACE_AREA_RATIO="${PASS1_BATCH_PREFLIGHT_MIN_MEAN_FACE_AREA_RATIO:-0.015}"
PREFLIGHT_MIN_MAX_FACE_AREA_RATIO="${PASS1_BATCH_PREFLIGHT_MIN_MAX_FACE_AREA_RATIO:-0.025}"
PREFLIGHT_MIN_EYE_DETECTED_RATIO="${PASS1_BATCH_PREFLIGHT_MIN_EYE_DETECTED_RATIO:-0.35}"
PREFLIGHT_MIN_MEAN_FACE_SHARPNESS="${PASS1_BATCH_PREFLIGHT_MIN_MEAN_FACE_SHARPNESS:-15.0}"
SKIP_EXISTING_APPROVED="${PASS1_BATCH_SKIP_EXISTING_APPROVED:-1}"

mkdir -p "$PREFLIGHT_DIR"

is_approved_output_present() {
  local slug="$1"
  local summary_path=""

  if [[ "$slug" == "source" && -f "$ROOT_DIR/output/report/pass1_best_summary.json" ]]; then
    summary_path="$ROOT_DIR/output/report/pass1_best_summary.json"
  elif [[ -f "$ROOT_DIR/output/report/${slug}_female_best_summary.json" ]]; then
    summary_path="$ROOT_DIR/output/report/${slug}_female_best_summary.json"
  fi

  if [[ -z "$summary_path" ]]; then
    return 1
  fi

  python3 - "$summary_path" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)

raise SystemExit(0 if data.get("final_decision") == "approved_gpt_review" else 1)
PY
}

for video in "$@"; do
  if [[ ! -f "$video" ]]; then
    echo "[pass1-batch] missing video: $video" >&2
    exit 1
  fi

  stem="$(basename "$video")"
  stem="${stem%.*}"
  slug="$(slugify "$stem")"

  echo "[pass1-batch] processing $video"
  if [[ "$SKIP_EXISTING_APPROVED" == "1" ]] && is_approved_output_present "$slug"; then
    echo "[pass1-batch] skipped existing approved output: $video"
    continue
  fi

  preflight_report="$PREFLIGHT_DIR/${slug}_preflight.json"
  if ! python3 "$PREFLIGHT_SCRIPT" \
      --video "$video" \
      --output-json "$preflight_report" \
      --sample-count "$PREFLIGHT_SAMPLE_COUNT" \
      --min-detected-ratio "$PREFLIGHT_MIN_DETECTED_RATIO" \
      --min-mean-face-area-ratio "$PREFLIGHT_MIN_MEAN_FACE_AREA_RATIO" \
      --min-max-face-area-ratio "$PREFLIGHT_MIN_MAX_FACE_AREA_RATIO" \
      --min-eye-detected-ratio "$PREFLIGHT_MIN_EYE_DETECTED_RATIO" \
      --min-mean-face-sharpness "$PREFLIGHT_MIN_MEAN_FACE_SHARPNESS"; then
    echo "[pass1-batch] skipped by preflight: $video"
    continue
  fi

  env \
    PASS1_FINAL_SOURCE_VIDEO="$video" \
    PASS1_FINAL_REF_IMAGE="$REF_IMAGE" \
    PASS1_FINAL_BASENAME="${slug}_female_best" \
    PASS1_FINAL_COMFY_FILENAME_PREFIX="pass1_${slug}" \
    bash "$BEST_SCRIPT" "$PAYLOAD_PATH"
done
