# stock-video-gender-convert

Internal workflow repo for converting stock-footage people videos with AI gender restyling and packaging them as short-form vertical clips.

## Current status

- As of `2026-03-10`, three publish-ready outputs exist:
  - `output/video/source_male_8fps_prod_v1_publish_ready.mp4`
  - `output/video/source_seg26_8fps_prod_v2_publish_ready.mp4`
  - `output/video/source_seg53_8fps_prod_v3_publish_ready.mp4`
- Subtitle burn-in, audio bed, timing notes, review artifacts, and upload metadata are already generated.
- The remaining blocker is source-license provenance for the original local clip.

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
