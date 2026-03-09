# Project Plan

## Objective
Build a repeatable workflow to convert stock-footage people videos with AI gender restyling, keep identity and pose stable enough for short-form video, and package final clips safely for publication.

## Executive Summary (2026-03-10)

The project is no longer blocked on setup. It is now blocked on two narrower issues:

1. motion quality
2. source-license provenance

What is already true:

- ComfyUI, required nodes, and required models are installed and proven.
- A stable Pass 1 baseline exists on the current machine.
- Three publish-ready vertical clips already exist in the repo:
  - `output/video/source_male_8fps_prod_v1_publish_ready.mp4`
  - `output/video/source_seg26_8fps_prod_v2_publish_ready.mp4`
  - `output/video/source_seg53_8fps_prod_v3_publish_ready.mp4`
- Subtitle burn-in, basic audio bed, timing notes, review artifacts, and upload metadata already exist for those three clips.
- Japanese early-20s / cute-direction probe work has already been demonstrated in short low-cost probe runs and is documented in `README.md`.

What is not closed:

- The original stock source provenance is still not proven strongly enough for external publishing.
- The three existing final clips are technically usable but are still based on an `8 fps` generation baseline, so motion smoothness is the main remaining quality concern.
- A higher-motion local baseline has not yet been fully locked on the current 16GB-class GPU.

The project has therefore moved from "can this work at all?" to "what is the best realistic shipping path on this hardware?"

## Current Repository State

### Proven and committed outputs

- Environment readiness:
  - ComfyUI installed
  - custom nodes installed
  - required SDXL / ControlNet / IPAdapter assets in place
- Stable generation baseline:
  - canonical payload: `pass1_canonical_payload.json`
  - production payload: `pass1_production_payload.json`
  - reviewed reference image: `output/reference/pass1_best_ref.jpg`
- Three reviewed production-style clips:
  - `output/video/source_male_8fps_prod_v1.mp4`
  - `output/video/source_seg26_8fps_prod_v2.mp4`
  - `output/video/source_seg53_8fps_prod_v3.mp4`
- Three publish-ready exports:
  - `output/video/source_male_8fps_prod_v1_publish_ready.mp4`
  - `output/video/source_seg26_8fps_prod_v2_publish_ready.mp4`
  - `output/video/source_seg53_8fps_prod_v3_publish_ready.mp4`
- Review and report artifacts:
  - `output/report/`
  - `output/review/`
  - `output/publish/`
  - `output/timing/`
- Proven Japanese / cute-direction probes:
  - `output/video/source_jp_early20s_fastprobe.mp4`
  - `output/video/source_jp_early20s_bootstrap_probe.mp4`
  - `output/video/source_jp_cute_probe.mp4`

### Compliance and provenance status

- The strongest current source candidate is still a Pixabay asset, but the repo does not contain direct acquisition proof.
- Internal notes already exist:
  - `output/license/probable_source_candidate.md`
  - `output/license/manual_verification_blocker.md`
  - `output/license/source_license_note.md`
- Because of that, the current outputs are fine for internal/private workflow validation, but external publishing should still be treated as blocked until provenance is closed.

## Closed Technical Decisions

### 1. `832x1472 / steps 24` is retired on this machine

This was the largest unresolved question in the original plan. It is now closed.

- The target spec was tested and did not fit the current machine reliably.
- The official fallback default is now `704x1248`.
- The decision log already exists:
  - `output/decisions/target_832_resolution_decision.md`

### 2. The current stable production-safe baseline is still the older `8 fps` route

This is not the prettiest result, but it is the last fully proven route on local hardware.

- Known-good pattern:
  - `64 frames`
  - `8 fps`
  - `8.0s`
  - around `704x1248`
- This route produced the three approved clips already stored in the repo.

### 3. Motion smoothness is now the main technical quality problem

This is not a setup problem anymore. It is a resource and workflow-design problem.

- The current generator can make stable clips on this hardware.
- What it cannot do reliably is generate long-enough clips at meaningfully higher native fps without running out of VRAM.

## Hardware Reality On The Current Machine

The current GPU is a 16GB-class card, but the practical CUDA limit seen by ComfyUI is about `15.56 GiB`.

That is enough for:

- SDXL image-to-video-style conversion at modest frame counts
- ControlNet + IPAdapter conditioning
- stable `8 fps` / `64` frame generation

That is not enough for:

- comfortably moving to `96 frames / 12 fps / 8.0s` at the resolutions we actually want
- treating this pipeline like a true high-fps native video model

The main reason is the workflow shape:

- SDXL base model
- OpenPose / ControlNet conditioning
- IPAdapter face conditioning
- multi-frame latent processing

As soon as total frame count and resolution both climb, `KSampler` becomes the limiting step.

## Motion And Smoothness Investigation (2026-03-10)

### Why this investigation was needed

The user feedback was correct: the current clips are not smooth enough to feel like strong video outputs. The repo already had successful technical clips, but they were generated from an `8 fps` baseline and therefore still looked choppy.

The goal of this investigation was:

- keep total duration at `8.0s`
- increase temporal density
- stay on the local GPU if possible

### Configurations tested

#### Attempt A: `96 frames / 12 fps / 704x1248`

Intent:

- keep `8.0s`
- improve motion by increasing frame count from `64` to `96`
- preserve the previously proven production-like resolution

Result:

- failed with GPU OOM in `KSampler`

Observed error:

- requested: about `1.57 GiB`
- free at failure: about `88 MiB`
- device limit: `15.56 GiB`

Conclusion:

- this configuration is too heavy for the current local GPU

#### Attempt B: `96 frames / 12 fps / 640x1136`

Intent:

- reduce resolution while keeping the same temporal target

Result:

- failed with GPU OOM in `KSampler`

Observed error:

- requested: about `1.30 GiB`
- free at failure: about `104 MiB`

Conclusion:

- the bottleneck is not only resolution
- frame count itself is already too expensive in this workflow

#### Attempt C: `80 frames / 10 fps / 576x1024`

Intent:

- keep `8.0s`
- reduce total frames compared with `96/12`
- still beat the older `64/8` baseline on temporal density

Result:

- this run completed successfully

Observed metrics from the temporary report:

- `status = PASS`
- `gender_female_ratio = 0.625`
- `gender_female_prob_mean = 0.5155692022086333`
- `face_similarity_mean = 0.9797174045851293`
- `face_switch_ratio = 0.0`
- `issues = []`

Interpretation:

- continuity is strong enough
- face switching is controlled
- however the femininity score is still weaker than the previously accepted stronger baseline thresholds
- therefore this is a useful motion experiment, but not yet a locked production preset

### What this means in plain terms

On this machine, the practical frontier is no longer "can we generate anything?" It is:

- native `8 fps` works
- native `10 fps` may be realistic if resolution is reduced
- native `12 fps` is already too expensive at useful resolutions

That means the likely local strategy is:

1. generate at `8-10 fps`
2. keep duration at `8.0s`
3. interpolate the final result to `24 fps`

## Interpolation Findings

Interpolation scripts were added locally so we can test the more realistic shipping path:

- `scripts/interpolate_video_24fps.sh`
- `scripts/interpolate_publish_ready_batch.sh`

Three interpolated local exports were also generated for the existing publish-ready clips:

- `output/video/source_male_8fps_prod_v1_publish_ready_interp24.mp4`
- `output/video/source_seg26_8fps_prod_v2_publish_ready_interp24.mp4`
- `output/video/source_seg53_8fps_prod_v3_publish_ready_interp24.mp4`

These are useful as evaluation artifacts, but they should currently be treated as local experiments until we decide whether to commit them.

Important interpretation:

- interpolation helps perceived smoothness
- interpolation does not fix all generative instability
- interpolation is therefore a realistic delivery tactic, not a magic replacement for stronger native motion generation

## Current Recommended Decision

The most realistic local path is now:

- keep the existing `8 fps` pipeline as the last fully proven baseline
- continue local R&D around `10 fps`
- treat `12 fps` native generation as too expensive on this hardware for now
- use `24 fps` interpolation for delivery if the base clip is already visually acceptable

In short:

- native `24 fps` generation is not the local path
- native `12 fps` is probably too expensive
- native `10 fps` is the realistic ceiling worth tuning

## Aesthetic Direction Status

The repo now contains two distinct kinds of work:

1. production-safe baseline clips using the older reviewed reference image
2. newer Japanese early-20s / cute-direction probes

The cute-direction probes are encouraging for look development, but they are not yet full replacements for the stable production baseline.

What is already true:

- short probe runs can push the look toward a Japanese / cute / early-20s visual direction
- `source_jp_cute_probe` is the current preferred aesthetic probe

What is not yet true:

- that same direction has not yet been proven across full-length smooth-motion production settings

So the current recommendation is:

- treat the cute-direction probe as a styling lead
- do not yet treat it as the final full-length production baseline

## Updated Done Definition

The project should now be considered complete only when all of the following are true:

- [x] A reusable local baseline exists
- [x] The `832x1472` decision is closed
- [x] Three reviewed technical clips exist
- [x] Three publish-ready `8.0s` exports exist
- [ ] A clear motion strategy is locked:
  - [ ] either keep `8 fps` + interpolation as the official shipping route
  - [ ] or prove a stronger local `10 fps` baseline
  - [ ] or move high-motion generation to larger hardware
- [ ] The chosen motion route is documented with exact settings
- [ ] Source provenance is strong enough for external publishing
- [ ] Upload checklists can be honestly marked complete

## Remaining Workstreams

### Workstream A: Close the motion strategy

Goal:

- stop treating motion quality as an open-ended experiment

Decision options:

#### Option A: Ship on the proven local path

- keep `64/8` as the generation baseline
- interpolate to `24 fps` for delivery
- accept that the result is good enough for this project scope

Pros:

- fastest
- already near-complete
- least GPU risk

Cons:

- still visually weaker than a truly smoother native result

#### Option B: Lock a better local smooth baseline

- continue tuning around `80/10 / 576x1024`
- push femininity metrics back up without losing the motion win

Likely tuning levers:

- slightly stronger `IPAdapter` weight
- prompt cleanup toward the desired style
- possibly lower `denoise` a bit if identity weakens
- reuse the best bootstrap face reference

Pros:

- better local result without needing bigger hardware

Cons:

- still constrained by VRAM
- more iteration time

#### Option C: Move true smoother generation to larger hardware

- retest `96/12` or stronger settings on a larger GPU

Pros:

- cleaner route to better native motion

Cons:

- leaves the local workflow ceiling unchanged

### Workstream B: Close provenance

Goal:

- decide whether the current three clips can ever become externally publishable

Current reality:

- internal/private use: acceptable
- external publishing: still blocked

Required evidence:

- original source URL, or
- download record, or
- archived proof that the local MP4 is from a license-appropriate source

### Workstream C: Sync docs with the true operating model

Goal:

- stop pretending the old plan is still mostly about setup

Needed:

- keep `PLAN.md` aligned with the real blocker set
- keep `README.md` aligned with the motion and probe story
- keep any new smooth-generation helper scripts committed if they are intended to be part of the workflow

## Concrete Next Actions

These are the real next actions from the current state, in priority order:

1. Decide whether the project should ship on:
   - proven `8 fps` generation plus interpolation
   - or a newly tuned `10 fps` local baseline
2. If staying local and aiming for better motion:
   - rerun the `80/10 / 576x1024` route
   - tune femininity and style strength upward
   - only accept it if it clears both motion and quality review
3. If the current outputs are intended for any external platform:
   - close provenance first
4. If stronger smoothness is non-negotiable:
   - move the high-fps generation attempt to bigger hardware rather than wasting more time on impossible local settings

## Local Helper Scripts Added During This Investigation

These files are part of the current local solution direction:

- `scripts/run_pass1_best.sh`
  - now forwards force-rate / frame-rate / skip-first-frames / select-every-nth to the search layer
- `scripts/run_pass1_recipe_search.sh`
  - now accepts and forwards skip/select parameters
- `scripts/run_pass1_smooth_prod.sh`
  - local wrapper for smoother-than-8fps generation attempts
- `scripts/run_pass1_smooth_batch.sh`
  - local batch wrapper for smooth-segment experiments
- `scripts/interpolate_video_24fps.sh`
  - local interpolation helper
- `scripts/interpolate_publish_ready_batch.sh`
  - local batch interpolation helper
- `output/preflight/final_segment_candidates_smooth_2026-03-10.md`
  - local notes for smooth-segment planning

## Completion Record

- [x] Environment setup complete
- [x] Baseline generation proved
- [x] `832x1472` decision closed
- [x] Three technical production clips generated
- [x] Three publish-ready exports generated
- [x] Japanese cute-direction probe work demonstrated
- [ ] Motion strategy locked
- [ ] Source provenance closed
- [ ] External publishing cleared
