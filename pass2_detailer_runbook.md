# Pass 2 Detailer Runbook

目的: Pass 1 の出力で `mouth / eyes / hands / face drift` が残ったときだけ、局所補修を再現可能な手順にする。

## 使う条件
- Pass 1 の `status` は `PASS`
- `issues` は空でも、見た目で以下の欠点が残る
  - 口元の崩れ
  - 目の非対称
  - 手の破綻が目立つ
  - 顔が一瞬だけ別人に寄る

## 使わない条件
- Pass 1 の QC が落ちている
- 顔スイッチや性別判定失敗のような大きな問題がある
- 生成全体の雰囲気が悪く、局所補修では救えない

## 入力
- Pass 1 の承認候補動画
- Pass 1 の report / summary / review board
- 現在の baseline reference image

## Pass 2 基本設定
- detail scope: face-first
- optional secondary scope: hands only if final cutで目立つ
- denoise: `0.20 - 0.35`
- keep source pose lock
- export with `VHS_VideoCombine`

推奨開始値:
- `denoise`: `0.28`
- `controlnet weight`: Pass 1 と同値
- `ipadapter weight`: Pass 1 と同値か `+0.03`
- `cfg`: Pass 1 より `-0.2` から開始

## 調整ルール
- 顔が別人化する:
  - `denoise` を下げる
  - `ipadapter weight` を少し上げる
- 口元が崩れる:
  - detail scope を face のみに絞る
  - `denoise` を `0.28 -> 0.24`
- 表情が固い:
  - `cfg` を少し下げる
- 姿勢が崩れる:
  - `controlnet weight` を少し上げる
- 手だけ悪い:
  - face を再生成せず、hands のみ別パスに分ける

## 実行チェック
1. 補修前の問題点を 1 行で書く
2. Pass 2 後に同じ箇所だけ見直す
3. 悪化したら採用しない
4. 採用時は report / review board を上書きせず、新しい basename を使う

## 合格条件
- 補修対象の欠点が軽減されている
- 顔の連続性が悪化していない
- 性別表現の安定性が落ちていない
- 最終 review で Pass 可能な見た目を維持している

## 出力物
- Pass 2 適用後動画
- 適用メモ
- 必要なら新しい review board
