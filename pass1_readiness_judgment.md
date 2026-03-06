# Pass 1 実行判定レポート（2026-03-05）

## 判定
- 結論: **未完了（素材準備完了、Pass 1 実行待ち）**
- 理由: `ip-adapter-plus-face_sdxl_vit-h.safetensors` / `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` の揃いを確認。Pass1 の1回目レンダリングがまだ未実施。

## チェック結果
- OpenPose前処理ノード: 追加済み（`comfyui_controlnet_aux`）
- ComfyUI起動確認: 起動ログでカスタムノード読み込み成功
- 入力素材: 取得済み
  - `ComfyUI/input/source.mp4`（5秒, 1920x1080, 30fps）
  - `ComfyUI/input/ref_face.jpg`（500x750 JPEG）
- 重要アセットの状態:
  - `models/checkpoints`: `sdxl-base.safetensors` 配置済み
  - `models/controlnet`: `controlnet-openpose-sdxl.safetensors` 配置済み
  - `models/ipadapter`: `ip-adapter-plus-face_sdxl_vit-h.safetensors` 配置済み
  - `models/clip_vision`: `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` 配置済み
  - `ComfyUI/input`: `source.mp4`, `ref_face.jpg` は上記で確認済み

## 即時実行すべき最短アクション
1. モデルを投入
   - `sdxl-base.safetensors` → `ComfyUI/models/checkpoints/`
   - `controlnet-openpose-sdxl.safetensors` → `ComfyUI/models/controlnet/`
   - `ip-adapter-plus-face_sdxl_vit-h.safetensors` → `ComfyUI/models/ipadapter/`
   - `CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` → `ComfyUI/models/clip_vision/`
2. 入力素材を投入（済）
   - `ComfyUI/input/source.mp4`
   - `ComfyUI/input/ref_face.jpg`
3. [pass1_first_clip_runbook.md](/media/sasaki/aiueo/ai_coding_ws/stock-video-gender-convert/pass1_first_clip_runbook.md) の手順で1回目レンダリング

補助コマンド:
- `bash scripts/check_pass1_readiness.sh`

## 目標到達基準（PASS条件）
- 1本目を `832x1472`, `steps=24` で完走
- 生成失敗なし
- 出力動画が保存される
- 主要評価項目（mouth/eyes/handsの崩れ）で重大な欠陥なし
