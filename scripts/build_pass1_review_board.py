#!/usr/bin/env python3
import argparse
import json
import math
from pathlib import Path

import cv2
import numpy as np


def load_image(path: str | None):
    if not path:
        return None
    p = Path(path)
    if not p.is_file():
        return None
    image = cv2.imread(str(p))
    return image


def sample_video_frames(video_path: str, samples: int):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"failed to open video: {video_path}")

    frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    if frame_count <= 0:
        cap.release()
        raise RuntimeError(f"video has no frames: {video_path}")

    samples = max(1, min(samples, frame_count))
    indices = sorted({round(i * (frame_count - 1) / max(samples - 1, 1)) for i in range(samples)})
    frames = []
    for idx in indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ok, frame = cap.read()
        if not ok or frame is None:
            continue
        frames.append((idx, frame))
    cap.release()
    if not frames:
        raise RuntimeError(f"failed to sample frames: {video_path}")
    return frames


def fit_tile(image, width, height):
    if image is None:
        tile = np.full((height, width, 3), 24, dtype=np.uint8)
        cv2.putText(tile, "N/A", (18, height // 2), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (210, 210, 210), 2, cv2.LINE_AA)
        return tile

    h, w = image.shape[:2]
    scale = min(width / w, height / h)
    resized = cv2.resize(image, (max(1, int(w * scale)), max(1, int(h * scale))), interpolation=cv2.INTER_AREA)
    canvas = np.full((height, width, 3), 24, dtype=np.uint8)
    y0 = (height - resized.shape[0]) // 2
    x0 = (width - resized.shape[1]) // 2
    canvas[y0:y0 + resized.shape[0], x0:x0 + resized.shape[1]] = resized
    return canvas


def draw_tile(canvas, x, y, image, title, subtitle, width, height):
    tile = fit_tile(image, width, height)
    canvas[y:y + height, x:x + width] = tile
    cv2.rectangle(canvas, (x, y), (x + width, y + height), (90, 90, 90), 2)
    cv2.putText(canvas, title, (x + 10, y + 24), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2, cv2.LINE_AA)
    if subtitle:
        cv2.putText(canvas, subtitle, (x + 10, y + height - 14), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (220, 220, 220), 1, cv2.LINE_AA)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--video", required=True)
    parser.add_argument("--report-json", required=True)
    parser.add_argument("--output-image", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--source-video")
    parser.add_argument("--ref-image")
    parser.add_argument("--faces-image")
    parser.add_argument("--samples", type=int, default=9)
    args = parser.parse_args()

    with open(args.report_json, "r", encoding="utf-8") as f:
        report = json.load(f)

    output_frames = sample_video_frames(args.video, args.samples)
    source_frames = sample_video_frames(args.source_video, 1) if args.source_video else []
    source_frame = source_frames[0][1] if source_frames else None
    ref_image = load_image(args.ref_image)
    faces_image = load_image(args.faces_image)

    header_h = 110
    tile_w = 320
    tile_h = 220
    margin = 24
    cols = 3
    meta_rows = 1
    frame_rows = math.ceil(len(output_frames) / cols)
    canvas_w = margin + cols * tile_w + (cols - 1) * margin + margin
    canvas_h = header_h + margin + meta_rows * tile_h + (meta_rows - 1) * margin + margin + frame_rows * tile_h + (frame_rows - 1) * margin + margin
    canvas = np.full((canvas_h, canvas_w, 3), 18, dtype=np.uint8)

    metrics = report.get("metrics", {})
    cv2.putText(canvas, "GPT review board: transformation quality", (margin, 36), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (255, 255, 255), 2, cv2.LINE_AA)
    cv2.putText(canvas, "Do not infer gender identity. Review whether the requested feminine presentation is visually achieved and stable.", (margin, 72), cv2.FONT_HERSHEY_SIMPLEX, 0.62, (220, 220, 220), 1, cv2.LINE_AA)
    summary_text = (
        f"auto_female_ratio={metrics.get('gender_female_ratio', 0):.3f}  "
        f"auto_female_prob={metrics.get('gender_female_prob_mean', 0):.3f}  "
        f"face_similarity={metrics.get('face_similarity_mean', 0):.3f}"
    )
    cv2.putText(canvas, summary_text, (margin, 98), cv2.FONT_HERSHEY_SIMPLEX, 0.62, (180, 220, 255), 1, cv2.LINE_AA)

    meta_y = header_h
    draw_tile(canvas, margin, meta_y, source_frame, "Source first frame", "", tile_w, tile_h)
    draw_tile(canvas, margin + tile_w + margin, meta_y, ref_image, "Reference image", "", tile_w, tile_h)
    draw_tile(canvas, margin + 2 * (tile_w + margin), meta_y, faces_image, "Detected faces strip", "", tile_w, tile_h)

    frame_y0 = header_h + margin + tile_h + margin
    for i, (frame_idx, frame) in enumerate(output_frames):
        row = i // cols
        col = i % cols
        x = margin + col * (tile_w + margin)
        y = frame_y0 + row * (tile_h + margin)
        draw_tile(canvas, x, y, frame, f"Output frame {frame_idx}", "Check transformation clarity and stability", tile_w, tile_h)

    output_image = Path(args.output_image)
    output_image.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(output_image), canvas)

    review = {
        "status": "PENDING_GPT_REVIEW",
        "review_mode": "gpt_review",
        "purpose": "Review whether the output clearly achieves the requested feminine presentation without identity drift.",
        "note": "This review is about visual transformation quality. Do not use it to infer or label a person's gender identity.",
        "artifacts": {
            "review_board": str(output_image),
            "video": args.video,
            "source_video": args.source_video,
            "ref_image": args.ref_image,
            "faces_image": args.faces_image,
            "report_json": args.report_json,
        },
        "auto_metrics": {
            "gender_female_ratio": metrics.get("gender_female_ratio"),
            "gender_female_prob_mean": metrics.get("gender_female_prob_mean"),
            "face_similarity_mean": metrics.get("face_similarity_mean"),
            "face_switch_ratio": metrics.get("face_switch_ratio"),
        },
        "gpt_review_checklist": [
            "Across sampled frames, the subject looks clearly transformed toward the requested feminine presentation, not just slightly softened.",
            "There is no obvious beard, stubble, heavy brow, or strongly masculine jaw reversion in the sampled frames.",
            "The face remains visually consistent from frame to frame.",
            "No sampled frame looks like a different person or a broken face blend.",
        ],
        "gpt_review_output_contract": {
            "allowed_values": ["PASS", "FAIL"],
            "required_fields": ["verdict", "confidence", "reasons"],
        },
    }

    output_json = Path(args.output_json)
    output_json.parent.mkdir(parents=True, exist_ok=True)
    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(review, f, ensure_ascii=False, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
