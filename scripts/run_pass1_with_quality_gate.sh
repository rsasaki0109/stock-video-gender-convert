#!/usr/bin/env bash
set -euo pipefail

PAYLOAD_PATH="${1:?Usage: $0 <pass1_payload_json>}"
COMFY_URL="${COMFY_URL:-http://127.0.0.1:8188}"
POLL_SEC="${PASS1_QC_POLL_SEC:-4}"
TIMEOUT_SEC="${PASS1_QC_TIMEOUT_SEC:-1800}"
MAX_ATTEMPTS="${PASS1_QC_MAX_ATTEMPTS:-4}"
BASE_SEED="${PASS1_QC_BASE_SEED:-1337}"
SEED_STEP="${PASS1_QC_SEED_STEP:-97}"
FEMALE_LEVEL="${PASS1_QC_FEMALE_LEVEL:-0}"
MAX_FEMALE_LEVEL="${PASS1_QC_MAX_FEMALE_LEVEL:-3}"
FAIL_ON_ISSUE="${PASS1_QC_FAIL_ON_ISSUE:-1}"
SCRIPT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMFY_OUTPUT_DIR="${COMFY_OUTPUT_DIR:-${SCRIPT_ROOT}/ComfyUI/output}"
SCRIPT_START_TS="$(date +%s)"
BASE_CHECK_ARGS="${PASS1_QC_CHECK_ARGS:---check-gender --min-gender-frames 4 --gender-female-min-ratio 0.70 --gender-female-confidence-threshold 0.55}"

if [[ ! -f "$PAYLOAD_PATH" ]]; then
  echo "[pass1-qc] payload not found: $PAYLOAD_PATH"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[pass1-qc] jq is required"
  exit 1
fi

archive_old_outputs() {
  local output_dir=$1
  local old_dir="$output_dir/old"
  local moved=0

  if [[ ! -d "$output_dir" ]]; then
    return
  fi

  mkdir -p "$old_dir"
  shopt -s nullglob
  for f in "$output_dir"/*.mp4 "$output_dir"/*.mov "$output_dir"/*.avi "$output_dir"/*.mkv "$output_dir"/*.webm; do
    [[ -f "$f" ]] || continue
    # Keep files generated during this run out of the move path.
    local ts
    ts="$(stat -c %Y "$f" 2>/dev/null || echo "$SCRIPT_START_TS")"
    if (( ts < SCRIPT_START_TS )); then
      mv -f "$f" "$old_dir/"
      moved=$(( moved + 1 ))
    fi
  done
  shopt -u nullglob

  if (( moved > 0 )); then
    echo "[pass1-qc] moved ${moved} old outputs to $old_dir"
  fi
}

apply_payload_tuning() {
  local input_payload=$1
  local output_payload=$2
  local seed=$3
  local level=$4
  python3 "${SCRIPT_ROOT}/scripts/apply_pass1_payload_tuning.py" \
    --input "$input_payload" \
    --output "$output_payload" \
    --seed "$seed" \
    --female-level "$level"
}

has_issue() {
  local report_file=$1
  local issue_key=$2
  jq -e --arg key "$issue_key" '(.issues // []) | any(.[]?; contains($key))' "$report_file" >/dev/null 2>&1
}

wait_prompt() {
  local prompt_id=$1
  local status
  local start_ts
  start_ts="$(date +%s)"
  while true; do
    status="$(curl -s "${COMFY_URL}/api/history/${prompt_id}" | jq -r '.["'"${prompt_id}"'"].status.status_str // empty')"
    echo "[pass1-qc] status=${status:-running}"
    if [[ "$status" == "success" || "$status" == "error" ]]; then
      break
    fi
    local now
    now="$(date +%s)"
    if (( now - start_ts >= TIMEOUT_SEC )); then
      echo "[pass1-qc] timeout after ${TIMEOUT_SEC}s"
      return 2
    fi
    sleep "$POLL_SEC"
  done
  if [[ "$status" == "error" ]]; then
    return 1
  fi
  return 0
}

check_quality() {
  local prompt_id=$1
  local report_file=$2
  local -a extra_args=()
  local -a issue_args=()
  local last_report=${3:-}

  # shell-safe split for simple CLI args (quoted values are not supported)
  read -r -a extra_args <<< "$BASE_CHECK_ARGS"

  if [[ -n "$last_report" ]] && [[ -f "$last_report" ]]; then
    if has_issue "$last_report" "multi_face_ratio"; then
      issue_args+=(--detect-scale-factor 1.12)
      issue_args+=(--detect-min-neighbors 8)
      issue_args+=(--max-overlap-iou 0.60)
      issue_args+=(--max-multi-face-ratio 0.30)
    fi
    if has_issue "$last_report" "face_switch_ratio"; then
      issue_args+=(--max-face-switch-ratio 0.10)
      issue_args+=(--max-face-jump-ratio 0.12)
      issue_args+=(--min-continuity-similarity 0.40)
    fi
    if has_issue "$last_report" "no_face_ratio"; then
      issue_args+=(--detect-scale-factor 1.04)
      issue_args+=(--detect-min-neighbors 5)
      issue_args+=(--max-no-face-ratio 0.30)
    fi
    if has_issue "$last_report" "gender_female_ratio"; then
      # keep the female threshold strict to avoid false-pass; only retry with harder prompts.
      :
    fi
  fi

  # Keep older entries before newer entries so latest policy wins.
  extra_args=("${extra_args[@]}" "${issue_args[@]}")

  python3 scripts/check_pass1_output.py \
    --prompt-id "$prompt_id" \
    --api "$COMFY_URL" \
    --output-json "$report_file" \
    "${extra_args[@]}"
  return $?
}

attempt=1
last_report_file=""
current_female_level="$FEMALE_LEVEL"
tmp_payload="/tmp/pass1_payload_work_${BASHPID}.json"
trap 'rm -f "$tmp_payload"' EXIT

while (( attempt <= MAX_ATTEMPTS )); do
  archive_old_outputs "$COMFY_OUTPUT_DIR"

  seed=$(( BASE_SEED + (attempt - 1) * SEED_STEP ))
  if [[ -n "$last_report_file" ]] && [[ -f "$last_report_file" ]]; then
    if has_issue "$last_report_file" "gender_female_ratio"; then
      if (( current_female_level < MAX_FEMALE_LEVEL )); then
        current_female_level=$(( current_female_level + 1 ))
      fi
    fi
  fi

  echo "[pass1-qc] attempt ${attempt}/${MAX_ATTEMPTS} seed=${seed} female_level=${current_female_level}"

  apply_payload_tuning "$PAYLOAD_PATH" "$tmp_payload" "$seed" "$current_female_level"
  echo "[pass1-qc] submit"
  response="$(curl -s -H 'Content-Type: application/json' -X POST --data "@${tmp_payload}" "${COMFY_URL}/api/prompt")"
  prompt_id="$(echo "$response" | jq -r '.prompt_id // empty')"

  if [[ -z "$prompt_id" || "$prompt_id" == "null" ]]; then
    echo "[pass1-qc] failed to submit prompt"
    echo "$response"
    exit 1
  fi
  echo "[pass1-qc] prompt_id=${prompt_id}"

  if ! wait_prompt "$prompt_id"; then
    echo "[pass1-qc] generation timeout or failed"
    if [[ "$attempt" -ge "$MAX_ATTEMPTS" ]]; then
      exit 1
    fi
    attempt=$((attempt + 1))
    continue
  fi

  report_file="/tmp/pass1_quality_${prompt_id}.json"
  if ! check_quality "$prompt_id" "$report_file" "$last_report_file"; then
    status="FAIL"
  else
    status="$(jq -r '.status // "ERROR"' "$report_file")"
  fi

  echo "[pass1-qc] quality status=${status} (${report_file})"
  if [[ "$status" == "PASS" ]]; then
    if [[ "$FAIL_ON_ISSUE" == "1" ]]; then
      echo "[pass1-qc] PASS"
    fi
    echo "[pass1-qc] done: ${prompt_id}"
    exit 0
  fi

  if [[ "$attempt" -ge "$MAX_ATTEMPTS" ]]; then
    echo "[pass1-qc] all attempts failed"
    if [[ -f "$report_file" ]]; then
      echo "[pass1-qc] issues:"
      jq -r 'if (.issues|length) > 0 then .issues[] else "" end' "$report_file" 2>/dev/null || true
    fi
    if [[ "$FAIL_ON_ISSUE" == "1" ]]; then
      exit 1
    else
      exit 0
    fi
  fi

  echo "[pass1-qc] FAIL"
  echo "[pass1-qc] issues:"
  jq -r 'if (.issues|length) > 0 then .issues[] else "" end' "$report_file" 2>/dev/null || true

  last_report_file="$report_file"
  attempt=$((attempt + 1))
done

exit 0
