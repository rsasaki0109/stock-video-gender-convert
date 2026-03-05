# ComfyUI Gender Convert Runbook (Stock Footage Only)

## Goal
Convert stock-footage people videos with a stable male/female look using ComfyUI.

## Environment
- OS: Windows
- GPU: NVIDIA (12GB VRAM recommended, 8GB possible with lite settings)
- ComfyUI: latest
- Input clip: 8-15s, 24-30fps, vertical preferred

## Required custom nodes
- `ComfyUI-VideoHelperSuite` (video load/export)
- `ComfyUI-Advanced-ControlNet` (pose lock)
- `ComfyUI_IPAdapter_plus` (face consistency)
- `ComfyUI-Impact-Pack` (optional face repair)

## Required models
- SDXL photoreal checkpoint
- OpenPose ControlNet model for SDXL
- `ip-adapter-plus-face_sdxl_vit-h.safetensors`
- CLIP Vision `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` (name must match IPAdapter Unified Loader preset)

## Input files
- Source video: `input/source.mp4`
- Face reference image: `input/ref_face.jpg`

## Pass 1: Base conversion
Connect nodes in this order:

1. `VHS_LoadVideo`
2. `ResizeAndPadImage` (start with `832x1472`, black padding)
3. `OpenPose Pose` (`OpenposePreprocessor`)
4. `ACN_ControlNetLoaderAdvanced` (`cnet: controlnet-openpose-sdxl.safetensors`)
5. `ACN_AdvancedControlNetApply_v2` (`positive/negative`: openpose conditioning)
6. `Load Checkpoint (SDXL)`
7. `CLIP Text Encode (positive)`
8. `CLIP Text Encode (negative)`
9. `IPAdapter Unified Loader` (`model`: checkpoint, `preset`: PLUS FACE (portraits))
10. `LoadImage` (`ref_face.jpg`)
11. `IPAdapter` (`image`: ref_face.jpg)
12. `VAE Encode`
13. `KSampler (img2img)`
14. `VAE Decode`
15. `VHS_VideoCombine`

Recommended values (12GB VRAM):
- `steps`: 18-24
- `sampler`: `dpmpp_2m_sde`
- `scheduler`: `karras`
- `cfg`: 4.0-5.5
- `denoise`: 0.42-0.55
- `controlnet weight`: 0.70-0.90
- `ipadapter weight`: 0.55-0.75
- `fps`: same as source

## Pass 1品質ゲート（生成後）
- 生成完了後は必ず以下を確認する:
  1. 顔トラッキングの抜けがないか
  2. フレーム間の顔位置ジャンプが大きくないか
  3. フェイス領域のノイズ/ぼやけが極端でないか
  4. メイン人物が女性判定される比率（`gender_female_ratio`) が閾値以上か

- 自動チェック（推奨）:
  - `bash scripts/run_pass1_with_quality_gate.sh <payload_json>`
  - 監視〜実行後、`/tmp/pass1_quality_<prompt_id>.json` に結果を保存
- 失敗条件: `status: FAIL` または `issues` に項目がある場合
  - 性別チェックが入る場合、`issues` に `gender_female_ratio` または `gender_female_prob_mean` があると `FAIL` 扱い
  - 旧動画は `COMFY_OUTPUT_DIR` を指定して退避先を制御（未指定時は `ComfyUI/output/old`）
- 再試行まで含めた実行:
  - `PASS1_QC_MAX_ATTEMPTS=5 PASS1_QC_BASE_SEED=1337 PASS1_QC_SEED_STEP=97 bash scripts/run_pass1_with_quality_gate.sh <payload_json>`
  - 2回目以降は同一ワークフローの `seed` を変えて再生成し、`PASS` を目指す
  - 再試行時、`multi_face_ratio`/`no_face_ratio`/`face_switch_ratio` の失敗内容を見て、顔検出の設定を自動で強化/緩和します
  - フェイス連続性を強める場合:
    - `PASS1_QC_CHECK_ARGS='--detect-scale-factor 1.08 --detect-min-neighbors 6 --max-overlap-iou 0.42 --max-face-switch-ratio 0.10' PASS1_QC_MAX_ATTEMPTS=5 PASS1_QC_BASE_SEED=1337 bash scripts/run_pass1_with_quality_gate.sh <payload_json>`

## Pass 2: Artifact fix (only if needed)
Use when mouth, eyes, or hands break.

1. Reload Pass 1 output
2. Apply `FaceDetailer` (or similar detailer) on face area only
3. Keep `denoise` lower (`0.20-0.35`)
4. Export again with `VHS_VideoCombine`

Quick tuning:
- Face drifting to another person: lower `denoise`
- Skeleton/pose collapse: raise `controlnet weight`
- Expression looks stiff: lower `cfg` slightly

## 8GB VRAM lite profile
- Resolution: `576x1024` or `540x960`
- `steps`: 12-16
- `batch/frame`: 1
- Use tiled VAE if available
- Optional: pre-convert source to `12-24fps`

## 16GB VRAM profile (recommended for your setup)
- Resolution: start at `832x1472` (vertical), fallback to `768x1365` if unstable
- `steps`: 22-30
- `cfg`: 4.0-5.0
- `denoise`: 0.40-0.52
- `controlnet weight`: 0.75-0.90
- `ipadapter weight`: 0.58-0.78
- `batch/frame`: 1 (use 2 only if VRAM usage stays stable)
- Keep source fps at `24-30`

Stable first preset for 16GB:
- `832x1472`, `steps 24`, `cfg 4.5`, `denoise 0.48`
- `controlnet 0.82`, `ipadapter 0.68`, `sampler dpmpp_2m_sde`, `scheduler karras`

## Prompt templates
Male to Female:
`photorealistic young woman, natural skin texture, soft makeup, detailed eyes, realistic lighting, same pose, same framing, cinematic`

Female to Male:
`photorealistic young man, natural skin texture, subtle beard shadow, detailed eyes, realistic lighting, same pose, same framing, cinematic`

Negative:
`deformed face, bad anatomy, extra fingers, blurry, plastic skin, warped mouth, asymmetrical eyes, lowres, artifacts`

## TikTok pre-upload checklist
- Confirm footage license allows modification and publication
- Add AI-generated content label in TikTok
- Avoid claims that imply a real private person identity

## Fast production loop (per clip)
1. Pick footage (5 min)
2. Run Pass 1 (10-25 min)
3. Optional Pass 2 (5-15 min)
4. Captions/SFX edit (10 min)
5. Upload (3 min)
