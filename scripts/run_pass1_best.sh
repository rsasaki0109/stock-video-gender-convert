#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAYLOAD_PATH="${1:-$ROOT_DIR/pass1_canonical_payload.json}"
SEARCH_SCRIPT="$ROOT_DIR/scripts/run_pass1_recipe_search.sh"
OUTPUT_DIR="${PASS1_FINAL_OUTPUT_DIR:-$ROOT_DIR/output}"
ARCHIVE_DIR="$OUTPUT_DIR/old"
VIDEO_DIR="${PASS1_FINAL_VIDEO_DIR:-$OUTPUT_DIR/video}"
REPORT_DIR="${PASS1_FINAL_REPORT_DIR:-$OUTPUT_DIR/report}"
FACES_DIR="${PASS1_FINAL_FACES_DIR:-$OUTPUT_DIR/faces}"
REVIEW_DIR="${PASS1_FINAL_REVIEW_DIR:-$OUTPUT_DIR/review}"
COMFY_OUTPUT_DIR="${PASS1_COMFY_OUTPUT_DIR:-/workspace/ai_coding_ws/ComfyUI/output}"
TMP_ROOT="${PASS1_FINAL_TMP_DIR:-/tmp/pass1_best}"
TMP_REPORT="/tmp/pass1_recipe_search/female_balanced_report.json"
TMP_FACES="/tmp/pass1_recipe_search/female_balanced_faces.jpg"
START_MARKER="$(mktemp /tmp/pass1_best_start.XXXXXX)"
SOURCE_VIDEO="${PASS1_FINAL_SOURCE_VIDEO:-}"
DEFAULT_REF_IMAGE="$ROOT_DIR/output/reference/pass1_best_ref.jpg"
if [[ -n "${PASS1_FINAL_REF_IMAGE:-}" ]]; then
  REF_IMAGE="$PASS1_FINAL_REF_IMAGE"
elif [[ -f "$DEFAULT_REF_IMAGE" ]]; then
  REF_IMAGE="$DEFAULT_REF_IMAGE"
else
  REF_IMAGE=""
fi

FRAME_CAP="${PASS1_FINAL_FRAME_CAP:-64}"
FORCE_RATE="${PASS1_FINAL_FORCE_RATE:-24}"
FRAME_RATE="${PASS1_FINAL_FRAME_RATE:-$FORCE_RATE}"
SKIP_FIRST_FRAMES="${PASS1_FINAL_SKIP_FIRST_FRAMES:-}"
SELECT_EVERY_NTH="${PASS1_FINAL_SELECT_EVERY_NTH:-1}"
LORA_NAME="${PASS1_FINAL_LORA_NAME:-LORA_FACE_CUTE.safetensors}"
LORA_STRENGTH_MODEL="${PASS1_FINAL_LORA_STRENGTH_MODEL:-1.25}"
LORA_STRENGTH_CLIP="${PASS1_FINAL_LORA_STRENGTH_CLIP:-1.05}"
STEPS="${PASS1_FINAL_STEPS:-34}"
CFG="${PASS1_FINAL_CFG:-8.5}"
DENOISE="${PASS1_FINAL_DENOISE:-0.62}"
CONTROLNET_WEIGHT="${PASS1_FINAL_CONTROLNET_WEIGHT:-0.70}"
IPADAPTER_WEIGHT="${PASS1_FINAL_IPADAPTER_WEIGHT:-0.20}"
POSITIVE_EXTRA="${PASS1_FINAL_POSITIVE_EXTRA_CSV:-beautiful young woman,close-up portrait,angelic features,soft glowing skin,natural pink lips,delicate cheekbones,soft lighting,soft makeup,feminine face,oval face,pretty eyes}"
NEGATIVE_EXTRA="${PASS1_FINAL_NEGATIVE_EXTRA_CSV:-male appearance,beard,masculine jawline,heavy brow,stubble,square jaw,thick neck}"
RESOLUTION_LADDER="${PASS1_FINAL_RESOLUTION_LADDER:-832x1472,768x1365,704x1248}"

SELECTED_VIDEO=""
SELECTED_REPORT=""
SELECTED_FACES=""
SELECTED_SUMMARY=""
SELECTED_WIDTH=""
SELECTED_HEIGHT=""

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alnum:]' '_' \
    | sed 's/^_//; s/_$//'
}

if [[ -n "$SOURCE_VIDEO" ]]; then
  SOURCE_STEM="$(basename "$SOURCE_VIDEO")"
  SOURCE_STEM="${SOURCE_STEM%.*}"
  SOURCE_SLUG="$(slugify "$SOURCE_STEM")"
else
  SOURCE_SLUG=""
fi

if [[ -n "${PASS1_FINAL_BASENAME:-}" ]]; then
  FINAL_BASENAME="$PASS1_FINAL_BASENAME"
elif [[ -n "$SOURCE_SLUG" ]]; then
  FINAL_BASENAME="${SOURCE_SLUG}_female_best"
else
  FINAL_BASENAME="pass1_best"
fi

if [[ -n "${PASS1_FINAL_COMFY_FILENAME_PREFIX:-}" ]]; then
  COMFY_FILENAME_PREFIX="$PASS1_FINAL_COMFY_FILENAME_PREFIX"
elif [[ -n "$SOURCE_SLUG" ]]; then
  COMFY_FILENAME_PREFIX="pass1_${SOURCE_SLUG}"
else
  COMFY_FILENAME_PREFIX="pass1_best"
fi

archive_existing() {
  mkdir -p "$OUTPUT_DIR" "$ARCHIVE_DIR" "$VIDEO_DIR" "$REPORT_DIR" "$FACES_DIR" "$REVIEW_DIR" "$TMP_ROOT"
  shopt -s nullglob
  local path
  for path in \
    "$VIDEO_DIR/${FINAL_BASENAME}.mp4" \
    "$REPORT_DIR/${FINAL_BASENAME}_report.json" \
    "$REPORT_DIR/${FINAL_BASENAME}_summary.json" \
    "$FACES_DIR/${FINAL_BASENAME}_faces.jpg" \
    "$REVIEW_DIR/${FINAL_BASENAME}_review_board.jpg" \
    "$REVIEW_DIR/${FINAL_BASENAME}_review.json"; do
    if [[ -e "$path" ]]; then
      mv "$path" "$ARCHIVE_DIR/"
    fi
  done
  shopt -u nullglob
}

archive_comfy_outputs() {
  local comfy_archive_dir="$COMFY_OUTPUT_DIR/archive/${COMFY_FILENAME_PREFIX}_$(date +%Y%m%d_%H%M%S)"
  shopt -s nullglob
  local files=( "$COMFY_OUTPUT_DIR"/"${COMFY_FILENAME_PREFIX}"_* )
  if (( ${#files[@]} == 0 )); then
    shopt -u nullglob
    return 0
  fi
  mkdir -p "$comfy_archive_dir"
  mv "${files[@]}" "$comfy_archive_dir"/
  shopt -u nullglob
}

find_new_video() {
  find "$COMFY_OUTPUT_DIR" -maxdepth 1 -type f -name "${COMFY_FILENAME_PREFIX}_female_balanced_*.mp4" -newer "$START_MARKER" -printf '%T@ %p\n' \
    | sort -n \
    | tail -n 1 \
    | cut -d' ' -f2-
}

find_report_video() {
  local report_path="$1"
  python3 - "$report_path" <<'PY'
import json
import sys
import urllib.request

report_path = sys.argv[1]
with open(report_path, "r", encoding="utf-8") as f:
    report = json.load(f)

prompt_id = report.get("prompt_id")
api = report.get("api", "http://127.0.0.1:8188").rstrip("/")
if not prompt_id:
    raise SystemExit(0)

with urllib.request.urlopen(f"{api}/history/{prompt_id}", timeout=10) as r:
    history = json.load(r).get(prompt_id, {})

outputs = history.get("outputs", {})
for node_output in outputs.values():
    for gif in node_output.get("gifs", []):
        fullpath = gif.get("fullpath")
        if fullpath:
            print(fullpath)
            raise SystemExit(0)
        filename = gif.get("filename")
        if filename:
            print(filename)
            raise SystemExit(0)
PY
}

build_summary() {
  local report_path="$1"
  local summary_path="$2"
  local width="$3"
  local height="$4"
  python3 - "$report_path" "$summary_path" "$width" "$height" "$SOURCE_VIDEO" "$REF_IMAGE" <<'PY'
import json
import sys

report_path, summary_path, width, height, source_video, ref_image = sys.argv[1:7]
with open(report_path, "r", encoding="utf-8") as f:
    report = json.load(f)

metrics = report.get("metrics", {})
female_ratio = metrics.get("gender_female_ratio", 0.0) or 0.0
female_prob_mean = metrics.get("gender_female_prob_mean", 0.0) or 0.0
face_similarity_mean = metrics.get("face_similarity_mean", 0.0) or 0.0
face_switch_ratio = metrics.get("face_switch_ratio", 1.0)

ok = (
    female_ratio >= 0.70
    and female_prob_mean >= 0.55
    and face_similarity_mean >= 0.95
    and face_switch_ratio <= 0.0
)

summary = {
    "prompt_id": report.get("prompt_id"),
    "status": report.get("status"),
    "selected_width": int(width),
    "selected_height": int(height),
    "source_video": source_video or None,
    "ref_image": ref_image or None,
    "auto_gate_passed": ok,
    "gpt_review_required": True,
    "final_decision": "pending_gpt_review" if ok else "rejected_auto_gate",
    "female_ratio": metrics.get("gender_female_ratio"),
    "female_prob_mean": metrics.get("gender_female_prob_mean"),
    "face_similarity_mean": metrics.get("face_similarity_mean"),
    "face_switch_ratio": metrics.get("face_switch_ratio"),
    "issues": report.get("issues", []),
    "thresholds": {
        "female_ratio_min": 0.70,
        "female_prob_mean_min": 0.55,
        "face_switch_ratio_max": 0.0,
        "face_similarity_mean_min": 0.95,
    },
}

with open(summary_path, "w", encoding="utf-8") as f:
    json.dump(summary, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(json.dumps(summary, ensure_ascii=False))
if not ok:
    raise SystemExit(1)
PY
}

run_candidate() {
  local width="$1"
  local height="$2"
  local label="${width}x${height}"
  local log_path="$TMP_ROOT/${label}.log"
  local report_path="$TMP_ROOT/${label}_report.json"
  local faces_path="$TMP_ROOT/${label}_faces.jpg"
  local summary_path="$TMP_ROOT/${label}_summary.json"
  local latest_video=""

  rm -f "$TMP_REPORT" "$TMP_FACES" "$log_path" "$report_path" "$faces_path" "$summary_path"

  echo "[pass1-best] trying ${label}"
  if ! env \
      PASS1_SEARCH_RECIPES=female_balanced \
      PASS1_SEARCH_FRAME_CAP="$FRAME_CAP" \
      PASS1_SEARCH_FORCE_RATE="$FORCE_RATE" \
      PASS1_SEARCH_FRAME_RATE="$FRAME_RATE" \
      PASS1_SEARCH_SKIP_FIRST_FRAMES="$SKIP_FIRST_FRAMES" \
      PASS1_SEARCH_SELECT_EVERY_NTH="$SELECT_EVERY_NTH" \
      PASS1_SEARCH_TARGET_WIDTH="$width" \
      PASS1_SEARCH_TARGET_HEIGHT="$height" \
      PASS1_SEARCH_FILENAME_PREFIX="$COMFY_FILENAME_PREFIX" \
      PASS1_SEARCH_LORA_NAME="$LORA_NAME" \
      PASS1_SEARCH_LORA_STRENGTH_MODEL="$LORA_STRENGTH_MODEL" \
      PASS1_SEARCH_LORA_STRENGTH_CLIP="$LORA_STRENGTH_CLIP" \
      PASS1_SEARCH_STEPS="$STEPS" \
      PASS1_SEARCH_CFG="$CFG" \
      PASS1_SEARCH_DENOISE="$DENOISE" \
      PASS1_SEARCH_CONTROLNET_WEIGHT="$CONTROLNET_WEIGHT" \
      PASS1_SEARCH_IPADAPTER_WEIGHT="$IPADAPTER_WEIGHT" \
      PASS1_SEARCH_POSITIVE_EXTRA_CSV="$POSITIVE_EXTRA" \
      PASS1_SEARCH_NEGATIVE_EXTRA_CSV="$NEGATIVE_EXTRA" \
      PASS1_SEARCH_SOURCE_VIDEO="$SOURCE_VIDEO" \
      PASS1_SEARCH_REF_IMAGE="$REF_IMAGE" \
      bash "$SEARCH_SCRIPT" "$PAYLOAD_PATH" >"$log_path" 2>&1; then
    echo "[pass1-best] launcher failed for ${label}" >&2
    tail -n 20 "$log_path" >&2 || true
    return 1
  fi

  if rg -q "generation failed" "$log_path"; then
    echo "[pass1-best] generation failed for ${label}" >&2
    tail -n 20 "$log_path" >&2 || true
    return 1
  fi

  if [[ ! -f "$TMP_REPORT" ]]; then
    echo "[pass1-best] missing report for ${label}" >&2
    return 1
  fi

  cp "$TMP_REPORT" "$report_path"
  if [[ -f "$TMP_FACES" ]]; then
    cp "$TMP_FACES" "$faces_path"
  fi

  latest_video="$(find_new_video)"
  if [[ -z "$latest_video" ]]; then
    latest_video="$(find_report_video "$report_path" || true)"
  fi
  if [[ -z "$latest_video" ]]; then
    echo "[pass1-best] could not resolve video for ${label}" >&2
    return 1
  fi
  if [[ ! -f "$latest_video" ]]; then
    if [[ -f "$COMFY_OUTPUT_DIR/$latest_video" ]]; then
      latest_video="$COMFY_OUTPUT_DIR/$latest_video"
    else
      echo "[pass1-best] resolved video missing for ${label}: $latest_video" >&2
      return 1
    fi
  fi

  if ! build_summary "$report_path" "$summary_path" "$width" "$height"; then
    echo "[pass1-best] quality gate failed for ${label}" >&2
    return 1
  fi

  SELECTED_VIDEO="$latest_video"
  SELECTED_REPORT="$report_path"
  SELECTED_FACES="$faces_path"
  SELECTED_SUMMARY="$summary_path"
  SELECTED_WIDTH="$width"
  SELECTED_HEIGHT="$height"
  return 0
}

archive_existing

if [[ -n "${PASS1_FINAL_TARGET_WIDTH:-}" && -n "${PASS1_FINAL_TARGET_HEIGHT:-}" ]]; then
  RESOLUTION_LADDER="${PASS1_FINAL_TARGET_WIDTH}x${PASS1_FINAL_TARGET_HEIGHT}"
fi

IFS=',' read -r -a RESOLUTIONS <<<"$RESOLUTION_LADDER"
for resolution in "${RESOLUTIONS[@]}"; do
  width="${resolution%x*}"
  height="${resolution#*x}"
  if run_candidate "$width" "$height"; then
    break
  fi
done

if [[ -z "$SELECTED_VIDEO" ]]; then
  echo "[pass1-best] no resolution in ladder succeeded" >&2
  exit 1
fi

FINAL_VIDEO_PATH="$VIDEO_DIR/${FINAL_BASENAME}.mp4"
FINAL_REPORT_PATH="$REPORT_DIR/${FINAL_BASENAME}_report.json"
FINAL_SUMMARY_PATH="$REPORT_DIR/${FINAL_BASENAME}_summary.json"
FINAL_FACES_PATH="$FACES_DIR/${FINAL_BASENAME}_faces.jpg"
FINAL_REVIEW_BOARD_PATH="$REVIEW_DIR/${FINAL_BASENAME}_review_board.jpg"
FINAL_REVIEW_JSON_PATH="$REVIEW_DIR/${FINAL_BASENAME}_review.json"

cp "$SELECTED_VIDEO" "$FINAL_VIDEO_PATH"
cp "$SELECTED_REPORT" "$FINAL_REPORT_PATH"
cp "$SELECTED_SUMMARY" "$FINAL_SUMMARY_PATH"
if [[ -f "$SELECTED_FACES" ]]; then
  cp "$SELECTED_FACES" "$FINAL_FACES_PATH"
fi

python3 "$ROOT_DIR/scripts/build_pass1_review_board.py" \
  --video "$FINAL_VIDEO_PATH" \
  --report-json "$FINAL_REPORT_PATH" \
  --output-image "$FINAL_REVIEW_BOARD_PATH" \
  --output-json "$FINAL_REVIEW_JSON_PATH" \
  $( [[ -n "$SOURCE_VIDEO" ]] && printf '%q %q' --source-video "$SOURCE_VIDEO" ) \
  $( [[ -n "$REF_IMAGE" ]] && printf '%q %q' --ref-image "$REF_IMAGE" ) \
  $( [[ -f "$FINAL_FACES_PATH" ]] && printf '%q %q' --faces-image "$FINAL_FACES_PATH" )

archive_comfy_outputs

echo "[pass1-best] selected_resolution=${SELECTED_WIDTH}x${SELECTED_HEIGHT}"
echo "[pass1-best] video=$FINAL_VIDEO_PATH"
echo "[pass1-best] report=$FINAL_REPORT_PATH"
echo "[pass1-best] summary=$FINAL_SUMMARY_PATH"
echo "[pass1-best] review_board=$FINAL_REVIEW_BOARD_PATH"
echo "[pass1-best] review_json=$FINAL_REVIEW_JSON_PATH"
