#!/usr/bin/env bash
set -euo pipefail

CANONICAL_PAYLOAD="${1:?Usage: $0 <canonical_payload_json>}"
COMFY_URL="${COMFY_URL:-http://127.0.0.1:8188}"
SCRIPT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEARCH_DIR="${PASS1_SEARCH_DIR:-/tmp/pass1_recipe_search}"
FRAME_CAP="${PASS1_SEARCH_FRAME_CAP:-8}"
FORCE_RATE="${PASS1_SEARCH_FORCE_RATE:-24}"
FRAME_RATE="${PASS1_SEARCH_FRAME_RATE:-24}"
TARGET_WIDTH="${PASS1_SEARCH_TARGET_WIDTH:-576}"
TARGET_HEIGHT="${PASS1_SEARCH_TARGET_HEIGHT:-1024}"
BASE_SEED="${PASS1_SEARCH_BASE_SEED:-1337}"
RECIPES_CSV="${PASS1_SEARCH_RECIPES:-probe_lowres,female_balanced,female_strong,identity_strong}"
CHECK_ARGS="${PASS1_SEARCH_CHECK_ARGS:---check-gender --min-gender-frames 4 --gender-female-min-ratio 0.25 --gender-female-confidence-threshold 0.25 --include-frame-debug --max-frame-debug-entries 32}"
LORA_NAME="${PASS1_SEARCH_LORA_NAME:-}"
LORA_STRENGTH_MODEL="${PASS1_SEARCH_LORA_STRENGTH_MODEL:-}"
LORA_STRENGTH_CLIP="${PASS1_SEARCH_LORA_STRENGTH_CLIP:-}"
OVERRIDE_STEPS="${PASS1_SEARCH_STEPS:-}"
OVERRIDE_CFG="${PASS1_SEARCH_CFG:-}"
OVERRIDE_DENOISE="${PASS1_SEARCH_DENOISE:-}"
OVERRIDE_CONTROLNET_WEIGHT="${PASS1_SEARCH_CONTROLNET_WEIGHT:-}"
OVERRIDE_IPADAPTER_WEIGHT="${PASS1_SEARCH_IPADAPTER_WEIGHT:-}"
POSITIVE_EXTRA_CSV="${PASS1_SEARCH_POSITIVE_EXTRA_CSV:-}"
NEGATIVE_EXTRA_CSV="${PASS1_SEARCH_NEGATIVE_EXTRA_CSV:-}"
SOURCE_VIDEO="${PASS1_SEARCH_SOURCE_VIDEO:-}"
REF_IMAGE="${PASS1_SEARCH_REF_IMAGE:-}"
FILENAME_PREFIX_BASE="${PASS1_SEARCH_FILENAME_PREFIX:-}"

if [[ ! -f "$CANONICAL_PAYLOAD" ]]; then
  echo "[pass1-search] canonical payload not found: $CANONICAL_PAYLOAD"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[pass1-search] jq is required"
  exit 1
fi

mkdir -p "$SEARCH_DIR"
summary_file="${SEARCH_DIR}/summary.tsv"
: > "$summary_file"

wait_prompt() {
  local prompt_id=$1
  local start_ts
  local status
  start_ts="$(date +%s)"
  while true; do
    status="$(curl -s "${COMFY_URL}/api/history/${prompt_id}" | jq -r '.["'"${prompt_id}"'"].status.status_str // empty')"
    echo "[pass1-search] prompt_id=${prompt_id} status=${status:-running}"
    if [[ "$status" == "success" || "$status" == "error" ]]; then
      break
    fi
    if (( "$(date +%s)" - start_ts > 1800 )); then
      echo "[pass1-search] timeout prompt_id=${prompt_id}"
      return 2
    fi
    sleep 4
  done
  [[ "$status" == "success" ]]
}

IFS=',' read -r -a RECIPES <<< "$RECIPES_CSV"

for idx in "${!RECIPES[@]}"; do
  recipe="${RECIPES[$idx]}"
  seed=$(( BASE_SEED + idx ))
  payload_path="${SEARCH_DIR}/${recipe}_payload.json"
  report_path="${SEARCH_DIR}/${recipe}_report.json"
  strip_path="${SEARCH_DIR}/${recipe}_faces.jpg"
  build_args=(
    --input "$CANONICAL_PAYLOAD"
    --output "$payload_path"
    --recipe "$recipe"
    --seed "$seed"
    --frame-load-cap "$FRAME_CAP"
    --force-rate "$FORCE_RATE"
    --frame-rate "$FRAME_RATE"
  )

  if [[ -n "$FILENAME_PREFIX_BASE" ]]; then
    build_args+=(--filename-prefix "${FILENAME_PREFIX_BASE}_${recipe}")
  else
    build_args+=(--filename-prefix "pass1_${recipe}")
  fi

  if [[ -n "$TARGET_WIDTH" ]]; then
    build_args+=(--target-width "$TARGET_WIDTH")
  fi

  if [[ -n "$TARGET_HEIGHT" ]]; then
    build_args+=(--target-height "$TARGET_HEIGHT")
  fi

  if [[ -n "$LORA_NAME" ]]; then
    build_args+=(--lora-name "$LORA_NAME")
  fi

  if [[ -n "$SOURCE_VIDEO" ]]; then
    build_args+=(--source-video "$SOURCE_VIDEO")
  fi

  if [[ -n "$REF_IMAGE" ]]; then
    build_args+=(--ref-image "$REF_IMAGE")
  fi

  if [[ -n "$LORA_STRENGTH_MODEL" ]]; then
    build_args+=(--lora-strength-model "$LORA_STRENGTH_MODEL")
  fi

  if [[ -n "$LORA_STRENGTH_CLIP" ]]; then
    build_args+=(--lora-strength-clip "$LORA_STRENGTH_CLIP")
  fi

  if [[ -n "$OVERRIDE_STEPS" ]]; then
    build_args+=(--steps "$OVERRIDE_STEPS")
  fi

  if [[ -n "$OVERRIDE_CFG" ]]; then
    build_args+=(--cfg "$OVERRIDE_CFG")
  fi

  if [[ -n "$OVERRIDE_DENOISE" ]]; then
    build_args+=(--denoise "$OVERRIDE_DENOISE")
  fi

  if [[ -n "$OVERRIDE_CONTROLNET_WEIGHT" ]]; then
    build_args+=(--controlnet-weight "$OVERRIDE_CONTROLNET_WEIGHT")
  fi

  if [[ -n "$OVERRIDE_IPADAPTER_WEIGHT" ]]; then
    build_args+=(--ipadapter-weight "$OVERRIDE_IPADAPTER_WEIGHT")
  fi

  if [[ -n "$POSITIVE_EXTRA_CSV" ]]; then
    IFS=',' read -r -a positive_extra_parts <<< "$POSITIVE_EXTRA_CSV"
    for fragment in "${positive_extra_parts[@]}"; do
      [[ -n "$fragment" ]] || continue
      build_args+=(--positive-extra "$fragment")
    done
  fi

  if [[ -n "$NEGATIVE_EXTRA_CSV" ]]; then
    IFS=',' read -r -a negative_extra_parts <<< "$NEGATIVE_EXTRA_CSV"
    for fragment in "${negative_extra_parts[@]}"; do
      [[ -n "$fragment" ]] || continue
      build_args+=(--negative-extra "$fragment")
    done
  fi

  python3 "${SCRIPT_ROOT}/scripts/build_pass1_recipe_payload.py" "${build_args[@]}"

  response="$(curl -s -H 'Content-Type: application/json' -X POST --data "@${payload_path}" "${COMFY_URL}/api/prompt")"
  prompt_id="$(echo "$response" | jq -r '.prompt_id // empty')"

  if [[ -z "$prompt_id" || "$prompt_id" == "null" ]]; then
    echo "[pass1-search] submit failed for recipe=${recipe}"
    echo "$response"
    continue
  fi

  if ! wait_prompt "$prompt_id"; then
    echo "[pass1-search] generation failed recipe=${recipe} prompt_id=${prompt_id}"
    continue
  fi

  read -r -a check_args_array <<< "$CHECK_ARGS"
  python3 "${SCRIPT_ROOT}/scripts/check_pass1_output.py" \
    --prompt-id "$prompt_id" \
    --api "$COMFY_URL" \
    --output-json "$report_path" \
    --face-strip-path "$strip_path" \
    "${check_args_array[@]}"

  status="$(jq -r '.status // "ERROR"' "$report_path")"
  female_ratio="$(jq -r '.metrics.gender_female_ratio // 0' "$report_path")"
  female_prob="$(jq -r '.metrics.gender_female_prob_mean // 0' "$report_path")"
  continuity="$(jq -r '.metrics.face_similarity_mean // 0' "$report_path")"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$recipe" "$prompt_id" "$status" "$female_ratio" "$female_prob" "$continuity" "$strip_path" \
    >> "$summary_file"

  echo "[pass1-search] recipe=${recipe} status=${status} female_ratio=${female_ratio} female_prob=${female_prob} strip=${strip_path}"
done

echo "[pass1-search] summary:"
sort -t $'\t' -k5,5gr "$summary_file" | sed 's/\t/ | /g'
