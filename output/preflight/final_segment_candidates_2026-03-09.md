# Final Segment Candidates (2026-03-09)

## Source Reality

- `source.mp4` and `source_male.mp4` are byte-identical local copies of the same `14.57s` stock clip.
- `source_female_backup.mp4` is only `5.7s`, so it does not satisfy the `8-15s` target length for final clips.
- In `VHS_LoadVideoPath`, `skip_first_frames` behaves against the resampled `force_rate=8 fps` stream, not the original `30 fps` timeline.
- Practical implication: to preserve a `64`-frame / `8.0s` output, `skip_first_frames` must stay at or below `53` for this source.

## Selected Final Candidates

- `clip_a`
  - source: `source.mp4`
  - skip_first_frames: `0`
  - expected output: `64` frames at `8 fps` (`8.0s`)
  - status: approved as `source_male_8fps_prod_v1`
- `clip_b`
  - source: `source.mp4`
  - skip_first_frames: `26`
  - expected output: `64` frames at `8 fps` (`8.0s`)
  - status: approved as `source_seg26_8fps_prod_v2`
- `clip_c`
  - source: `source.mp4`
  - skip_first_frames: `53`
  - expected output: `64` frames at `8 fps` (`8.0s`)
  - status: approved as `source_seg53_8fps_prod_v3`

## Backup

- `backup_short`
  - source: `source.mp4`
  - skip_first_frames: `80`
  - observed output: `37` frames at `8 fps` (`4.625s`)
  - status: technical probe only, rejected for final-length requirement
