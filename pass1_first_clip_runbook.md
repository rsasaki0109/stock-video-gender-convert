# Pass 1 初回テスト実行手順（16GB向け）

目的: `832x1472` / `steps 24` で 1本目の試験クリップを出力する。

## 事前準備（これだけは必須）
  - `ComfyUI` が起動できる状態
  - 次のモデルが置かれていること
  - SDXL チェックポイント: `ComfyUI/models/checkpoints/*.safetensors`
  - OpenPose ControlNet(SDXL): `ComfyUI/models/controlnet/*.safetensors`
  - IPAdapter Face: `ComfyUI/models/ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors`
  - CLIP Vision: `ComfyUI/models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors`
- 入力素材
  - `ComfyUI/input/source.mp4`
  - `ComfyUI/input/ref_face.jpg`
  - 可能なら `OpenPose Pose`（`OpenposePreprocessor`）が入っているか確認（未導入なら OpenPose 取得で失敗）

## 実行手順
- CLIP Vision がまだ未配置なら、最短で補完:
  - `bash /media/sasaki/aiueo/ai_coding_ws/stock-video-gender-convert/scripts/fetch_pass1_models.sh`
- ComfyUI を起動
  - `cd /media/sasaki/aiueo/ai_coding_ws/ComfyUI`
  - `source .venv/bin/activate`
  - `python main.py --listen 127.0.0.1 --port 8188`
- ブラウザで `http://127.0.0.1:8188` を開く
- `comfyui_gender_swap_pass1_blueprint.json` のノード順に従い、ワークフローを構築
  - 重要: `VHS_LoadVideoPath` の入力は `source.mp4`
  - OpenPose前処理は最初に `OpenPose Pose`（`OpenposePreprocessor`）を接続
  - `VHS_VideoCombine` の `fps` は元動画に合わせる
- 推奨値
  - 解像度: `832` x `1472`
  - `steps`: `24`
  - `sampler`: `dpmpp_2m_sde`
  - `scheduler`: `karras`
  - `cfg`: `4.5`
  - `denoise`: `0.48`
  - `controlnet weight`: `0.82`
  - `ipadapter weight`: `0.68`

## 1回目の記録項目
- 生成フレーム数 / 時間
- メモリピーク（想定16GB）
- 顔の崩れ: `mouth / eyes / hands` の3項目
- pose drift の有無（胴体・脚の破綻）

## ワンクリック実行
- すぐ実行する場合（判定をスキップしてComfyUI起動のみ）:
  - `PASS1_SKIP_READINESS=1 PASS1_COMFYUI_ARGS='--user-directory /tmp/comfyui-user-test' bash /media/sasaki/aiueo/ai_coding_ws/stock-video-gender-convert/scripts/run_pass1_pipeline.sh`

## 開始前チェック
- `bash /media/sasaki/aiueo/ai_coding_ws/stock-video-gender-convert/scripts/check_pass1_readiness.sh`
- ここが `RESULT: PASS` でない場合は、`pass1_readiness_judgment.md` の不足項目を埋める

## 失敗時の最短対処
- OOM: 解像度を `768x1365` に落とす
- 顔崩れ: `denoise` を `0.45` → `0.42` に下げる
- 姿勢崩れ: `controlnet weight` を `0.82` → `0.87`
- 反応が遅い: `steps` を `24` → `20`

## Pass 1 生成後チェック（推奨）
- `bash scripts/run_pass1_with_quality_gate.sh <payload_json>`
- 取得した `status` が `PASS` かつ `issues` が空であることを次工程の合格条件にする
- `issues` に `gender_female_ratio` / `gender_female_prob_mean` が含まれていないことを確認する（女性判定失敗）
- 失敗時は `issues` の内容で再設定する
- 自動再試行:
  - `PASS1_QC_MAX_ATTEMPTS=5 PASS1_QC_BASE_SEED=1337 PASS1_QC_SEED_STEP=97 bash scripts/run_pass1_with_quality_gate.sh <payload_json>`
  - 再試行時は `multi_face_ratio` / `no_face_ratio` / `face_switch_ratio` を判定して、検出パラメータを自動調整
  - 旧動画を退避したい場合は `COMFY_OUTPUT_DIR=/media/sasaki/aiueo/ai_coding_ws/ComfyUI/output` を設定

## 成功時の次アクション
- 出力動画を `clips/` へ保管し、[PLAN.md](/media/sasaki/aiueo/ai_coding_ws/stock-video-gender-convert/PLAN.md) の
  `Run first clip at 832x1472, steps 24` を完了に更新
- その後、Quality tuning（Pass 2）へ進む
