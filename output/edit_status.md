# Edit Status

Current repo state:

- `pass1_best`, `pass1_gptfix_final`, and `source_male_female_best` are generation-complete and review-approved.
- `source_male_8fps_prod_v1` is the first full-length `8.0s` production-style clip and is marked `approved_gpt_review`.
- `source_seg26_8fps_prod_v2` is the second full-length `8.0s` production-style clip and is marked `approved_gpt_review`.
- `source_seg53_8fps_prod_v3` is the third full-length `8.0s` production-style clip and is marked `approved_gpt_review`.
- Publish-ready exports now exist for all three clips with burned captions and AAC audio beds.
- Local editing automation now exists in `scripts/build_publish_ready_clip.sh` and `scripts/build_publish_ready_batch.sh`.

Remaining blocker:

- The only long-form source currently available is one stock clip duplicated as `source.mp4` and `source_male.mp4`.
- Manual stock-license verification is still missing for the final three upload candidates.

Until that is resolved, the three clips are publish-ready in a technical sense but not yet cleared for upload.
