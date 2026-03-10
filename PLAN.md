# Project Plan

## Objective
Build a repeatable workflow to convert stock-footage people videos with AI gender conversion and publish short videos safely.

## Scope
- Use only stock footage whose license explicitly allows modification and publication.
- Run generation with ComfyUI on a 16GB VRAM machine.
- Keep pose and identity stable with OpenPose + IPAdapter face conditioning.
- Ship short-form outputs with AI-content labeling and without misleading identity claims.

## Current State (2026-03-09)

### What is already proven
- [x] ComfyUI environment and required custom nodes are installed.
- [x] Required models and source inputs are in place for Pass 1 readiness.
- [x] Baseline Pass 1 output exists and has approved review artifacts.
- [x] Reproducibility has been demonstrated on at least one additional source clip.
- [x] A production payload has been saved at `pass1_production_payload.json`.
- [x] The `832x1472 / steps 24` target was tested on 2026-03-09 and retired on the current 16GB machine because of OOM.
- [x] Pass 2 standardization files now exist: `pass2_detailer_runbook.md`, `pass2_detailer_preset.json`.
- [x] Three full-length `8.0s` clips now exist and are marked `approved_gpt_review`:
  - `output/video/source_male_8fps_prod_v1.mp4`
  - `output/video/source_seg26_8fps_prod_v2.mp4`
  - `output/video/source_seg53_8fps_prod_v3.mp4`

### Evidence already in the repo
- Approved baseline summary: `output/report/pass1_best_summary.json`
- Approved reproducibility summary: `output/report/source_male_female_best_summary.json`
- Approved alternate variant summary: `output/report/pass1_gptfix_final_summary.json`
- Working baseline reference image: `output/reference/pass1_best_ref.jpg`
- Review boards and review JSONs: `output/review/`
- Canonical payload and blueprint: `pass1_canonical_payload.json`, `comfyui_gender_swap_pass1_blueprint.json`
- Production payload: `pass1_production_payload.json`
- 832 decision log: `output/decisions/target_832_resolution_decision.md`

### What is not done yet
- [x] Three full-length generation-approved clips are now generated and packaged in `output/video/`.
- [ ] Most previously approved clips are short evaluation renders (`64` frames at `24 fps`, about `2.67s`), not the intended `8-15s` final assets.
- [x] Subtitle/SFX finishing has now been completed for the final three clips.
- [ ] Per-clip license verification and upload checklist have not been closed.

### Important clarification
- The approved production-safe default is now `704x1248`, based on successful reviewed outputs.
- The original `832x1472` target is not blocked by uncertainty anymore; it is currently retired on this machine due to OOM.
- Only one local stock clip currently satisfies the `8-15s` source-length requirement; the three final clips therefore need to be different segments of that same licensed source unless additional footage is added.
- This means the project is past "environment setup", "proof of viability", and "baseline locking", but not yet at "production complete".

## Final Done Definition
The project is only complete when all of the following are true:

- [x] A stable default Pass 1 recipe is documented and saved as reusable JSON/payload settings.
- [x] The target configuration `832x1472`, `steps 24` is either:
  - [ ] proven stable and adopted as default, or
  - [x] explicitly retired with evidence and replaced by a justified fallback default.
- [ ] A Pass 2 recovery path exists for mouth/eyes/hands failures.
- [ ] Three publish-ready clips have been generated from allowed stock footage.
- [ ] Each final clip has:
  - [ ] QC report
  - [ ] summary JSON
  - [ ] review board
  - [ ] human/GPT review decision
  - [x] subtitles and SFX
  - [ ] timing record
  - [ ] source-license verification note
  - [ ] platform upload checklist marked complete
- [x] AI-generated content labeling steps are documented for publishing.
- [ ] No final clip makes misleading identity claims about a real private person.

## Operating Rules
- Only use stock clips that can legally be modified and republished.
- Keep all working outputs under `output/` and avoid ad-hoc final exports scattered elsewhere.
- Treat `output/reference/pass1_best_ref.jpg` as the current working female baseline unless a better reviewed reference supersedes it.
- Do not trust a generation result based only on visual impression; require QC artifacts plus review.
- Use GPU for real runs. `scripts/run_pass1_pipeline.sh` defaults to CPU unless `PASS1_CPU=0` is set.
- If the target spec fails repeatedly, record the reason in this file and move to the fallback ladder instead of stalling.

## Milestones
1. Lock the default baseline recipe
2. Standardize recovery tuning and Pass 2
3. Produce three approved clips
4. Finish captions, SFX, and timing records
5. Complete publishing and compliance checklist

## Execution Order
Work in this exact order unless a blocking issue forces a rollback:

1. Reconfirm readiness and launch ComfyUI on GPU
2. Lock the best default Pass 1 recipe
3. Prove or retire the `832x1472` target preset
4. Standardize Pass 2 remediation
5. Select three source clips and preflight them
6. Generate the three clips with QC and review
7. Finish edit pass with captions and SFX
8. Complete license and upload checklist
9. Mark the project done only after all artifacts are saved

## Phase 1: Lock The Default Baseline Recipe

### Goal
Establish the production starting point so later runs are reproducible.

### Entry Criteria
- `scripts/check_pass1_readiness.sh` returns `RESULT: PASS`
- ComfyUI models and input files exist
- `output/reference/pass1_best_ref.jpg` is available

### Tasks
- [ ] Run readiness check:
  - `bash scripts/check_pass1_readiness.sh`
- [ ] Launch ComfyUI on GPU:
  - `PASS1_CPU=0 PASS1_COMFYUI_ARGS='--user-directory /tmp/comfyui-user-test' bash scripts/run_pass1_pipeline.sh`
- [ ] Use the current working baseline reference:
  - `output/reference/pass1_best_ref.jpg`
- [ ] Confirm the canonical payload still matches the intended default recipe:
  - `pass1_canonical_payload.json`
- [ ] Record the currently accepted baseline metrics in this file for comparison:
  - `female_ratio >= 0.70`
  - `female_prob_mean >= 0.55`
  - `face_similarity_mean >= 0.95`
  - `face_switch_ratio == 0.0`

### Exit Criteria
- [ ] There is one clearly named baseline recipe to start every new clip from.
- [ ] The baseline has both automatic QC success and review approval.
- [ ] The baseline reference image is no longer ambiguous.

## Phase 2: Prove Or Retire The Target Spec `832x1472 / steps 24`

### Goal
Close the biggest open question in the original project plan.

### Why this phase exists
The original plan says the first clip must run at `832x1472`, `steps 24`. The current approved artifacts show success at `704x1248`, which means the target spec is still open.

### Primary Attempt
- [ ] Run one clip at:
  - resolution: `832x1472`
  - `steps`: `24`
  - `cfg`: `4.5`
  - `denoise`: `0.48`
  - `controlnet weight`: `0.82`
  - `ipadapter weight`: `0.68`
  - `sampler`: `dpmpp_2m_sde`
  - `scheduler`: `karras`

### Recommended path
- [ ] First do the manual or UI-driven attempt described in `pass1_first_clip_runbook.md`
- [ ] Then run automatic QC if a payload is ready:
  - `COMFY_OUTPUT_DIR=/media/sasaki/aiueo/ai_coding_ws/ComfyUI/output PASS1_QC_MAX_ATTEMPTS=5 PASS1_QC_BASE_SEED=1337 PASS1_QC_SEED_STEP=97 bash scripts/run_pass1_with_quality_gate.sh pass1_canonical_payload.json`

### Failure handling ladder
- [ ] If OOM or instability occurs at `832x1472`, try `768x1365`
- [ ] If still unstable, try `704x1248`
- [ ] If `mouth/eyes/hands` degrade, lower `denoise`
- [ ] If pose drifts, raise `controlnet weight`
- [ ] If identity weakens, raise `ipadapter weight` slightly and retry

### Decision rule
- [ ] Adopt `832x1472` as the production default only if it passes QC and review without recurring major defects.
- [ ] If `832x1472` repeatedly fails and `704x1248` remains the stable winner, document that fallback as the official default and explicitly mark the original target as retired.

### Exit Criteria
- [ ] The project has a documented default resolution.
- [ ] The status of `832x1472` is no longer ambiguous.
- [ ] `PLAN.md` states the chosen production default and why.

## Phase 3: Standardize Quality Tuning And Pass 2

### Goal
Make remediation repeatable instead of ad-hoc.

### Trigger conditions for Pass 2
- [ ] Mouth breaks or warps
- [ ] Eyes lose symmetry or detail
- [ ] Hands become distracting in the final cut
- [ ] Face briefly reverts or drifts between frames

### Pass 2 defaults
- [ ] Reload the Pass 1 output
- [ ] Apply face-local detailer only
- [ ] Keep Pass 2 `denoise` in the `0.20-0.35` range
- [ ] Re-export with `VHS_VideoCombine`

### Tuning rules to standardize
- [ ] Face drifting toward another person:
  - lower `denoise`
- [ ] Skeleton or pose collapse:
  - raise `controlnet weight`
- [ ] Expression too stiff:
  - lower `cfg` slightly
- [ ] Face identity weak:
  - raise `ipadapter weight` modestly

### Deliverables
- [ ] One written Pass 2 checklist in this repo
- [ ] One saved preset JSON or payload variant for Pass 2
- [ ] One short note defining when Pass 2 should be skipped

### Exit Criteria
- [ ] Another person could repeat Pass 2 without guessing.
- [ ] The project has a named recovery path for common artifact classes.

## Phase 4: Select And Preflight Three Final Candidate Clips

### Goal
Choose sources that are likely to finish successfully and legally.

### Source selection criteria
- [ ] Stock footage only
- [ ] License allows modification and publication
- [ ] Clip length between `8-15s`
- [ ] Main subject remains visible enough for face tracking
- [ ] Framing is suitable for vertical output or easy crop
- [ ] No severe occlusion for most of the clip

### Preflight process
- [ ] Gather at least 5 candidate clips
- [ ] Reject any clip with unclear licensing
- [ ] Run preflight checks before generation
- [ ] Keep only the best 3 plus 1 backup

### Preflight commands
- [ ] Batch path:
  - `bash scripts/run_pass1_best_batch.sh pass1_canonical_payload.json <video1> <video2> <video3> ...`
- [ ] Preflight reports will be saved under:
  - `output/preflight/`

### Exit Criteria
- [ ] Three primary clips are selected
- [ ] One backup clip is selected
- [ ] Every selected clip has a written license note

## Phase 5: Generate Three Approved Clips

### Goal
Produce three final-generation assets that clear QC and review.

### For each selected clip
- [ ] Run Pass 1 with the locked baseline recipe
- [ ] Run automatic QC
- [ ] Generate review board artifacts
- [ ] Review the result
- [ ] If needed, run Pass 2 and re-review
- [ ] Save final approved output under `output/video/`
- [ ] Save matching report artifacts under `output/report/` and `output/review/`

### Preferred execution path
- [ ] Use the reviewed baseline reference image:
  - `PASS1_FINAL_REF_IMAGE=output/reference/pass1_best_ref.jpg`
- [ ] Run best-search generation per clip:
  - `PASS1_FINAL_REF_IMAGE=output/reference/pass1_best_ref.jpg bash scripts/run_pass1_best.sh pass1_canonical_payload.json`
- [ ] For multiple clips:
  - `PASS1_BATCH_REF_IMAGE=output/reference/pass1_best_ref.jpg bash scripts/run_pass1_best_batch.sh pass1_canonical_payload.json <video1> <video2> <video3>`

### Per-clip acceptance criteria
- [ ] `status` is `PASS`
- [ ] `issues` is empty
- [ ] `final_decision` is `approved_gpt_review` or equivalent approved state
- [ ] No major `mouth / eyes / hands` defects remain in the final edit
- [ ] No obvious face switch or identity collapse

### Exit Criteria
- [ ] There are three approved output videos.
- [ ] Each approved output has full report and review artifacts.

## Phase 6: Subtitle, SFX, And Edit Packaging

### Goal
Turn the technically successful outputs into publish-ready short videos.

### For each approved clip
- [x] Trim head/tail if needed
- [x] Add subtitle track or burned-in captions
- [x] Add SFX or light audio sweetening
- [x] Confirm subtitle timing does not hide facial details
- [x] Export the publish-ready version

### Packaging requirements
- [x] Keep the original generated output untouched
- [x] Save the publish-ready edit with clear naming
- [x] Record edit decisions in a short note

### Timing record
- [ ] Measure:
  - source selection time
  - generation time
  - QC/review time
  - Pass 2 time, if used
  - subtitle/SFX edit time
  - total clip completion time

### Exit Criteria
- [x] Three publish-ready edited clips exist
- [x] Completion time per clip is recorded

## Phase 7: Publishing And Compliance

### Goal
Finish the work safely and with a repeatable release checklist.

### Per-clip checklist
- [ ] Source license re-checked
- [x] AI-generated content label prepared for TikTok
- [x] Caption/description avoids misleading identity claims
- [x] Final file chosen for upload
- [x] Upload metadata prepared

### Compliance notes
- [ ] Do not imply the subject is a real identified private person
- [ ] Do not imply the transformation reveals a person's "true" identity
- [ ] Keep a local note of the stock source URL and license terms

### Exit Criteria
- [ ] Every final clip has a completed upload checklist
- [ ] Publishing can proceed without unresolved compliance questions

## Artifact Checklist

### Required baseline artifacts
- [ ] `pass1_canonical_payload.json`
- [ ] `comfyui_gender_swap_pass1_blueprint.json`
- [ ] `output/reference/pass1_best_ref.jpg`

### Required per-clip artifacts
- [ ] final video in `output/video/`
- [ ] QC report in `output/report/`
- [ ] summary JSON in `output/report/`
- [ ] review board image in `output/review/`
- [ ] review JSON in `output/review/`
- [ ] timing record
- [ ] license note

## Risk Register

### Technical risks
- [ ] `832x1472` may remain unstable on the current machine for some clips
- [ ] Identity can regress if the wrong reference image is reused
- [ ] QC can pass while visual taste is still borderline, so review remains necessary

### Operational risks
- [ ] Ambiguous stock-footage licenses can block publishing late in the process
- [ ] Subtitle placement can hide face details and reduce perceived quality
- [ ] Batch generation can waste time if preflight is skipped

### Mitigations
- [ ] Use the fallback resolution ladder instead of repeatedly forcing a failing preset
- [ ] Keep `output/reference/pass1_best_ref.jpg` as the reviewed default until replaced
- [ ] Run preflight before spending generation time
- [ ] Require written license notes before clips enter the final-three set

## Immediate Next Actions
These are the next actions to move the project again right now:

1. [ ] Produce full-length (`8-15s`) outputs instead of `64`-frame evaluation clips
2. [ ] Add subtitle and SFX finishing for the three kept clips
3. [ ] Record final per-clip completion time including edit time
4. [ ] Store source license proof for each clip
5. [ ] Complete TikTok upload checklist for each kept clip

## Completion Record
Update this section as milestones close:

- [x] Baseline recipe locked
- [x] `832x1472` decision closed
- [x] Pass 2 standardized
- [x] Three approved technical clips generated in the repo (`pass1_best`, `pass1_gptfix_final`, `source_male_female_best`)
- [ ] Three edited clips packaged
- [ ] License and upload checklist completed
- [ ] Project complete
