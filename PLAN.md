# Project Plan

## Objective
Build a repeatable workflow to convert stock-footage people videos with AI gender conversion and publish short videos safely.

## Scope
- Use only footage with licenses that allow modification and publication.
- Generate output with ComfyUI on a 16GB VRAM machine.
- Keep identity consistency with pose + face conditioning.
- Publish with required AI-content labeling.

## Milestones
1. Environment setup
2. Workflow baseline
3. Quality tuning
4. Production loop
5. Publishing checklist

## Tasks
1. Environment setup
- [ ] Install ComfyUI on 16GB PC
- [ ] Install required custom nodes
- [ ] Place required SDXL/ControlNet/IPAdapter models
- [ ] Verify GPU with `nvidia-smi`

2. Workflow baseline
- [ ] Import runbook settings from `comfyui_gender_swap_runbook.md`
- [ ] Configure Pass 1 pipeline (pose lock + IPAdapter)
- [ ] Run first clip at `832x1472`, `steps 24`

3. Quality tuning
- [ ] Fix artifacts with Pass 2 detailer
- [ ] Tune `denoise/controlnet/ipadapter` for face stability
- [ ] Save a stable preset JSON

4. Production loop
- [ ] Produce 3 test clips (8-15s each)
- [ ] Add subtitles and SFX
- [ ] Measure completion time per clip

5. Publishing checklist
- [ ] Re-check license terms per source clip
- [ ] Add AI-generated label on TikTok
- [ ] Avoid misleading identity claims

## Done Definition
- 3 clips produced with stable faces and no major mouth/hand artifacts.
- One reusable ComfyUI preset exported.
- Upload checklist completed for each clip.

