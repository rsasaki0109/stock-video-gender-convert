#!/usr/bin/env bash
set -euo pipefail

PAYLOAD_PATH="${1:?Usage: $0 <payload_json>}"
COMFY_URL="${COMFY_URL:-http://127.0.0.1:8188}"
POLL_SEC="${PASS1_ONCE_POLL_SEC:-4}"
TIMEOUT_SEC="${PASS1_ONCE_TIMEOUT_SEC:-1800}"

if [[ ! -f "$PAYLOAD_PATH" ]]; then
  echo "[pass1-once] payload not found: $PAYLOAD_PATH" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[pass1-once] jq is required" >&2
  exit 1
fi

response="$(curl -s -H 'Content-Type: application/json' -X POST --data "@${PAYLOAD_PATH}" "${COMFY_URL}/api/prompt")"
prompt_id="$(echo "$response" | jq -r '.prompt_id // empty')"

if [[ -z "$prompt_id" || "$prompt_id" == "null" ]]; then
  echo "[pass1-once] failed to submit prompt" >&2
  echo "$response" >&2
  exit 1
fi

echo "[pass1-once] prompt_id=${prompt_id}"

start_ts="$(date +%s)"
while true; do
  status="$(curl -s "${COMFY_URL}/api/history/${prompt_id}" | jq -r '.["'"${prompt_id}"'"].status.status_str // empty')"
  echo "[pass1-once] status=${status:-running}"
  if [[ "$status" == "success" || "$status" == "error" ]]; then
    break
  fi

  now="$(date +%s)"
  if (( now - start_ts >= TIMEOUT_SEC )); then
    echo "[pass1-once] timeout after ${TIMEOUT_SEC}s" >&2
    exit 2
  fi
  sleep "$POLL_SEC"
done

if [[ "$status" == "error" ]]; then
  echo "[pass1-once] generation failed for prompt_id=${prompt_id}" >&2
  exit 1
fi

echo "[pass1-once] done prompt_id=${prompt_id}"
