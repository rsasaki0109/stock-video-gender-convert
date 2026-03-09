# Target Resolution Decision

Date: 2026-03-09

## Tested target
- resolution: `832x1472`
- steps: `24`
- cfg: `4.5`
- denoise: `0.48`
- controlnet weight: `0.82`
- ipadapter weight: `0.68`
- sampler: `dpmpp_2m_sde`
- scheduler: `karras`
- source: `ComfyUI/input/source.mp4`
- reference: `output/reference/pass1_best_ref.jpg`

## Result
- Status: `FAILED_ON_CURRENT_MACHINE`
- Failure mode: `torch.OutOfMemoryError`
- Observed during: strict QC generation attempt on prompt `de0887e5-a102-4de1-be89-df5d32955d05`

## Evidence
- Requested extra allocation at failure: about `1.46 GiB`
- Free CUDA memory at failure: about `82.62 MiB`
- Device class: `RTX 4070 Ti SUPER 16GB`

## Decision
- `832x1472 / steps 24` is not the current production default.
- The production-safe default remains the already approved fallback path centered on `704x1248`.

## Next action
- Keep `pass1_production_payload.json` as the default production payload.
- Only retry `832x1472` after a workflow change that materially lowers memory pressure.
