# stock-video-gender-convert

Internal workflow repo for converting stock-footage people videos with AI gender restyling and packaging them as short-form vertical clips.

## Current status

- As of `2026-03-10`, three publish-ready outputs exist:
  - `output/video/source_male_8fps_prod_v1_publish_ready.mp4`
  - `output/video/source_seg26_8fps_prod_v2_publish_ready.mp4`
  - `output/video/source_seg53_8fps_prod_v3_publish_ready.mp4`
- Subtitle burn-in, audio bed, timing notes, review artifacts, and upload metadata are already generated.
- The remaining blocker is source-license provenance for the original local clip.

## Result previews

### Clip 1

Preview GIF: `output/review/source_male_8fps_prod_v1_preview.gif`

Full video: `output/video/source_male_8fps_prod_v1_publish_ready.mp4`

Review board: `output/review/source_male_8fps_prod_v1_review_board.jpg`

![Clip 1 preview](output/review/source_male_8fps_prod_v1_preview.gif)

### Clip 2

Preview GIF: `output/review/source_seg26_8fps_prod_v2_preview.gif`

Full video: `output/video/source_seg26_8fps_prod_v2_publish_ready.mp4`

Review board: `output/review/source_seg26_8fps_prod_v2_review_board.jpg`

![Clip 2 preview](output/review/source_seg26_8fps_prod_v2_preview.gif)

### Clip 3

Preview GIF: `output/review/source_seg53_8fps_prod_v3_preview.gif`

Full video: `output/video/source_seg53_8fps_prod_v3_publish_ready.mp4`

Review board: `output/review/source_seg53_8fps_prod_v3_review_board.jpg`

![Clip 3 preview](output/review/source_seg53_8fps_prod_v3_preview.gif)

## Japanese early-20s probe

- Initial seed probe:
  - `output/video/source_jp_early20s_fastprobe.mp4`
  - used to bootstrap a tighter face reference from a successful transformed frame
- Improved bootstrap reference:
  - `output/reference/jp_early20s_bootstrap_ref.png`
- Beauty-leaning bootstrap probe:
  - `output/video/source_jp_early20s_bootstrap_probe.mp4`
- Beauty-leaning bootstrap review board:
  - `output/review/source_jp_early20s_bootstrap_probe_review_board.jpg`
- Latest cute-leaning variant:
  - `output/video/source_jp_cute_probe.mp4`
  - `output/review/source_jp_cute_probe_preview.gif`
  - `output/review/source_jp_cute_probe_review_board.jpg`
- Both are cheap internal probes (`16` frames at `576x1024`) for a Japanese / early-20s visual direction.
- Auto metrics:
  - bootstrap probe: `female_ratio=1.000`, `female_prob_mean=0.897`
  - cute probe: `female_ratio=0.875`, `female_prob_mean=0.768`
  - `face_similarity_mean=0.987`
- Current result: `pending_gpt_review`
  - the cute probe is the current preferred style direction
  - it passes the main auto-gate thresholds with no listed QC issues
  - the earlier bootstrap probe remains useful as a stronger femininity baseline

![Japanese early-20s cute probe preview](output/review/source_jp_cute_probe_preview.gif)

## Source provenance note

- The local source files are:
  - `/media/sasaki/aiueo/ai_coding_ws/ComfyUI/input/source.mp4`
  - `/media/sasaki/aiueo/ai_coding_ws/ComfyUI/input/source_male.mp4`
- These two files are byte-identical copies of the same source clip.
- The strongest current source candidate is the Pixabay asset below:
  - `https://pixabay.com/videos/man-young-beard-bald-person-light-62553/`
  - creator: `Engin_Akyurt`
- This match is based on subject similarity, `3840x2160` resolution match, and timing proximity to the embedded local MP4 `creation_time`.
- This is still an inference, not proven provenance. No saved download URL, receipt, or browser download record has been recovered yet.

Because this repository is private, this note is kept here as an internal tracking record. Do not treat the three outputs as externally publishable until provenance is confirmed.

## Main docs

- `PLAN.md`
- `output/edit_status.md`
- `output/license/probable_source_candidate.md`
- `output/license/manual_verification_blocker.md`
