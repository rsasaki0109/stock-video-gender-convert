#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BASENAME="${1:?Usage: $0 <basename> <input_video> <timing_json> [tone_hz] [source_video]}"
INPUT_VIDEO="${2:?Usage: $0 <basename> <input_video> <timing_json> [tone_hz] [source_video]}"
TIMING_JSON="${3:?Usage: $0 <basename> <input_video> <timing_json> [tone_hz] [source_video]}"
TONE_HZ="${4:-220}"
SOURCE_VIDEO="${5:-}"

PUBLISH_DIR="$ROOT_DIR/output/publish"
VIDEO_DIR="$ROOT_DIR/output/video"

ASS_PATH="$PUBLISH_DIR/${BASENAME}_captions.ass"
EDIT_NOTE_PATH="$PUBLISH_DIR/${BASENAME}_edit_note.md"
UPLOAD_NOTE_PATH="$PUBLISH_DIR/${BASENAME}_upload_metadata.md"
OUTPUT_VIDEO="$VIDEO_DIR/${BASENAME}_publish_ready.mp4"

mkdir -p "$PUBLISH_DIR" "$VIDEO_DIR"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "[publish-ready] ffmpeg is required" >&2
  exit 1
fi

if ! command -v ffprobe >/dev/null 2>&1; then
  echo "[publish-ready] ffprobe is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[publish-ready] jq is required" >&2
  exit 1
fi

if [[ ! -f "$INPUT_VIDEO" ]]; then
  echo "[publish-ready] input video not found: $INPUT_VIDEO" >&2
  exit 1
fi

if [[ ! -f "$TIMING_JSON" ]]; then
  echo "[publish-ready] timing json not found: $TIMING_JSON" >&2
  exit 1
fi

duration="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$INPUT_VIDEO")"
if [[ -z "$duration" ]]; then
  echo "[publish-ready] failed to detect duration" >&2
  exit 1
fi

segment_1_end="$(awk -v d="$duration" 'BEGIN { printf "%.2f", d / 3.0 }')"
segment_2_end="$(awk -v d="$duration" 'BEGIN { printf "%.2f", (d * 2.0) / 3.0 }')"
fade_out_start="$(awk -v d="$duration" 'BEGIN { s = d - 0.70; if (s < 0) s = 0; printf "%.2f", s }')"

secs_to_ass() {
  awk -v s="$1" 'BEGIN {
    if (s < 0) s = 0;
    h = int(s / 3600);
    m = int((s - h * 3600) / 60);
    sec = s - h * 3600 - m * 60;
    printf "%d:%02d:%05.2f", h, m, sec;
  }'
}

start_0="$(secs_to_ass 0)"
end_1="$(secs_to_ass "$segment_1_end")"
end_2="$(secs_to_ass "$segment_2_end")"
end_3="$(secs_to_ass "$duration")"

cat > "$ASS_PATH" <<EOF
[Script Info]
ScriptType: v4.00+
PlayResX: 704
PlayResY: 1248
WrapStyle: 2
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: TopLabel,Ubuntu Sans,23,&H00FFFFFF,&H000000FF,&H50000000,&H78000000,-1,0,0,0,100,100,0,0,3,1.5,0,8,48,48,54,1
Style: BottomCard,Ubuntu Sans,31,&H00FFFFFF,&H000000FF,&H5A000000,&H8C000000,-1,0,0,0,100,100,0,0,3,1.5,0,2,58,58,92,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,$start_0,$end_3,TopLabel,,0,0,0,,AI-GENERATED RESTYLE
Dialogue: 0,$start_0,$end_1,BottomCard,,0,0,0,,AI-generated restyle demo
Dialogue: 0,$end_1,$end_2,BottomCard,,0,0,0,,Licensed stock footage + AI edit
Dialogue: 0,$end_2,$end_3,BottomCard,,0,0,0,,Visual transformation only
EOF

edit_started_at_ms="$(date +%s%3N)"

ffmpeg -y \
  -i "$INPUT_VIDEO" \
  -f lavfi -t "$duration" -i "sine=frequency=${TONE_HZ}:sample_rate=48000" \
  -f lavfi -t "$duration" -i "anoisesrc=color=pink:sample_rate=48000" \
  -filter_complex "[0:v]subtitles=${ASS_PATH}:fontsdir=/usr/share/fonts/truetype/ubuntu,format=yuv420p[v];[1:a]volume=0.013,lowpass=f=900,afade=t=in:st=0:d=0.45,afade=t=out:st=${fade_out_start}:d=0.70[tone];[2:a]volume=0.0025,highpass=f=140,lowpass=f=2400,afade=t=in:st=0:d=0.45,afade=t=out:st=${fade_out_start}:d=0.70[noise];[tone][noise]amix=inputs=2:normalize=0,pan=stereo|c0=c0|c1=c0,alimiter=limit=0.35[a]" \
  -map "[v]" \
  -map "[a]" \
  -c:v libx264 \
  -preset medium \
  -crf 18 \
  -c:a aac \
  -b:a 128k \
  -shortest \
  -movflags +faststart \
  "$OUTPUT_VIDEO"

edit_finished_at_ms="$(date +%s%3N)"
edit_seconds="$(awk -v s="$edit_started_at_ms" -v e="$edit_finished_at_ms" 'BEGIN { printf "%.3f", (e - s) / 1000.0 }')"

cat > "$EDIT_NOTE_PATH" <<EOF
# Edit Note: ${BASENAME}

- Source generated clip: \`${INPUT_VIDEO}\`
- Publish-ready export: \`${OUTPUT_VIDEO}\`
- Source stock clip: \`${SOURCE_VIDEO:-unknown}\`
- Burned captions:
  - \`AI-generated restyle demo\`
  - \`Licensed stock footage + AI edit\`
  - \`Visual transformation only\`
- Audio finish:
  - synthetic ambient bed built with \`ffmpeg\`
  - sine tone base: \`${TONE_HZ}Hz\`
  - low-level pink-noise layer
- Safety:
  - captions avoid claims about a real person's identity
  - export still requires platform-side AI-generated content label on upload
- Edit timing:
  - started_at_ms: \`${edit_started_at_ms}\`
  - finished_at_ms: \`${edit_finished_at_ms}\`
  - edit_seconds: \`${edit_seconds}\`
EOF

cat > "$UPLOAD_NOTE_PATH" <<EOF
# Upload Metadata: ${BASENAME}

- Final upload file: ${OUTPUT_VIDEO}
- TikTok AI-generated content label: ON
- Suggested caption:
  - AI-generated restyle demo using licensed stock footage. Visual effect only.
- Caption safety review:
  - does not identify the subject
  - does not claim a private person's "true" identity
  - explicitly frames the result as an AI-generated effect
EOF

tmp_json="$(mktemp)"
jq \
  --arg export "$OUTPUT_VIDEO" \
  --arg edit_note "$EDIT_NOTE_PATH" \
  --arg upload_note "$UPLOAD_NOTE_PATH" \
  --argjson edit_started "$edit_started_at_ms" \
  --argjson edit_finished "$edit_finished_at_ms" \
  --arg edit_seconds "$edit_seconds" \
  '
  .edit_started_at_ms = $edit_started
  | .edit_finished_at_ms = $edit_finished
  | .edit_seconds = ($edit_seconds | tonumber)
  | .publish_ready_video = $export
  | .edit_note = $edit_note
  | .upload_metadata_note = $upload_note
  | .total_clip_completion_seconds = ((($edit_finished) - (.generation_started_at_ms // $edit_started)) / 1000)
  | .notes = (((.notes // [])
      | map(select(
          . != "Subtitle and SFX edit time has not been recorded yet."
          and . != "Publish-ready export created with burned captions and synthetic ambience."
          and . != "TikTok AI-generated content label is prepared in the upload metadata note."
        ))) + [
      "Publish-ready export created with burned captions and synthetic ambience.",
      ("Subtitle/SFX edit time recorded: " + $edit_seconds + "s."),
      "TikTok AI-generated content label is prepared in the upload metadata note."
    ])
  ' "$TIMING_JSON" > "$tmp_json"
mv "$tmp_json" "$TIMING_JSON"

echo "[publish-ready] output=$OUTPUT_VIDEO"
echo "[publish-ready] captions=$ASS_PATH"
echo "[publish-ready] edit_note=$EDIT_NOTE_PATH"
echo "[publish-ready] upload_note=$UPLOAD_NOTE_PATH"
