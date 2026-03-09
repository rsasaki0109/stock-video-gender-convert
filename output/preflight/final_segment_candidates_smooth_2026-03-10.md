# Smooth Segment Candidates (2026-03-10)

## Recommended Baseline

- Replace the old `64` frame / `8 fps` final baseline with `96` frames / `12 fps`.
- Keep final source resolution at `704x1248` first, then fall back to `640x1136` only if runtime or VRAM becomes unstable.
- After generation, export a delivery file with `scripts/interpolate_video_24fps.sh` to reach a smoother `24 fps` container.

## Why This Baseline

- The old `8 fps` outputs are long enough (`8.0s`) but visibly choppy.
- A full `24 fps` native run would require `192` generated frames for the same `8.0s`, which is likely too expensive for this workflow.
- `12 fps` is the practical middle ground:
  - `96` generated frames instead of `64`
  - still `8.0s` long
  - noticeably cleaner motion before interpolation
  - enough temporal density for `24 fps` optical-flow interpolation

## Source Reality

- `source.mp4` duration: `14.5667s`
- original source stream: `30 fps`, `437` frames
- resampled at `12 fps`, the usable stream is about `175` frames long
- with a `96` frame cap, `skip_first_frames` must stay at or below about `79`

## Candidate Segments

- `clip_a_smooth`
  - source: `source.mp4`
  - skip_first_frames: `0`
  - expected output: `96` frames at `12 fps` (`8.0s`)
- `clip_b_smooth`
  - source: `source.mp4`
  - skip_first_frames: `39`
  - expected output: `96` frames at `12 fps` (`8.0s`)
- `clip_c_smooth`
  - source: `source.mp4`
  - skip_first_frames: `79`
  - expected output: `96` frames at `12 fps` (`8.0s`)

## Command Pattern

```bash
PASS1_FINAL_SOURCE_VIDEO=/workspace/ai_coding_ws/ComfyUI/input/source.mp4 \
PASS1_FINAL_REF_IMAGE=/workspace/ai_coding_ws/stock-video-gender-convert/output/reference/pass1_best_ref.jpg \
PASS1_FINAL_SKIP_FIRST_FRAMES=39 \
PASS1_FINAL_BASENAME=source_seg39_12fps_smooth \
PASS1_FINAL_COMFY_FILENAME_PREFIX=pass1_source_seg39_12fps_smooth \
bash /workspace/ai_coding_ws/stock-video-gender-convert/scripts/run_pass1_smooth_prod.sh \
  /workspace/ai_coding_ws/stock-video-gender-convert/pass1_canonical_payload.json
```

Then interpolate the generated publish-ready export:

```bash
bash /workspace/ai_coding_ws/stock-video-gender-convert/scripts/interpolate_video_24fps.sh \
  /workspace/ai_coding_ws/stock-video-gender-convert/output/video/source_seg39_12fps_smooth_publish_ready.mp4
```
