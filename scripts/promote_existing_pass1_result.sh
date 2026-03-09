#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GENERATED_VIDEO="${1:?Usage: $0 <generated_video> <final_basename> <source_video> [ref_image]}"
FINAL_BASENAME="${2:?Usage: $0 <generated_video> <final_basename> <source_video> [ref_image]}"
SOURCE_VIDEO="${3:?Usage: $0 <generated_video> <final_basename> <source_video> [ref_image]}"
REF_IMAGE="${4:-}"

VIDEO_DIR="$ROOT_DIR/output/video"
REPORT_DIR="$ROOT_DIR/output/report"
FACES_DIR="$ROOT_DIR/output/faces"
REVIEW_DIR="$ROOT_DIR/output/review"

FINAL_VIDEO_PATH="$VIDEO_DIR/${FINAL_BASENAME}.mp4"
FINAL_REPORT_PATH="$REPORT_DIR/${FINAL_BASENAME}_report.json"
FINAL_SUMMARY_PATH="$REPORT_DIR/${FINAL_BASENAME}_summary.json"
FINAL_FACES_PATH="$FACES_DIR/${FINAL_BASENAME}_faces.jpg"
FINAL_REVIEW_BOARD_PATH="$REVIEW_DIR/${FINAL_BASENAME}_review_board.jpg"
FINAL_REVIEW_JSON_PATH="$REVIEW_DIR/${FINAL_BASENAME}_review.json"

mkdir -p "$VIDEO_DIR" "$REPORT_DIR" "$FACES_DIR" "$REVIEW_DIR"
cp "$GENERATED_VIDEO" "$FINAL_VIDEO_PATH"

python3 "$ROOT_DIR/scripts/check_pass1_output.py" \
  --video "$FINAL_VIDEO_PATH" \
  --output-json "$FINAL_REPORT_PATH" \
  --face-strip-path "$FINAL_FACES_PATH" \
  --check-gender \
  --min-gender-frames 4 \
  --gender-female-min-ratio 0.70 \
  --gender-female-confidence-threshold 0.55

python3 "$ROOT_DIR/scripts/build_pass1_summary.py" \
  --report-json "$FINAL_REPORT_PATH" \
  --output-json "$FINAL_SUMMARY_PATH" \
  --video "$FINAL_VIDEO_PATH" \
  --source-video "$SOURCE_VIDEO" \
  $( [[ -n "$REF_IMAGE" ]] && printf '%q %q' --ref-image "$REF_IMAGE" )

python3 "$ROOT_DIR/scripts/build_pass1_review_board.py" \
  --video "$FINAL_VIDEO_PATH" \
  --report-json "$FINAL_REPORT_PATH" \
  --output-image "$FINAL_REVIEW_BOARD_PATH" \
  --output-json "$FINAL_REVIEW_JSON_PATH" \
  --source-video "$SOURCE_VIDEO" \
  $( [[ -n "$REF_IMAGE" ]] && printf '%q %q' --ref-image "$REF_IMAGE" ) \
  $( [[ -f "$FINAL_FACES_PATH" ]] && printf '%q %q' --faces-image "$FINAL_FACES_PATH" )

echo "[promote-pass1] video=$FINAL_VIDEO_PATH"
echo "[promote-pass1] report=$FINAL_REPORT_PATH"
echo "[promote-pass1] summary=$FINAL_SUMMARY_PATH"
echo "[promote-pass1] review_board=$FINAL_REVIEW_BOARD_PATH"
echo "[promote-pass1] review_json=$FINAL_REVIEW_JSON_PATH"
