#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

import cv2


def resolve_cascade_path(filename: str) -> str:
    candidates = []
    if hasattr(cv2, "data") and hasattr(cv2.data, "haarcascades"):
        candidates.append(Path(cv2.data.haarcascades) / filename)
    candidates.extend(
        [
            Path("/usr/share/opencv4/haarcascades") / filename,
            Path("/usr/share/opencv/haarcascades") / filename,
            Path("/usr/local/share/opencv4/haarcascades") / filename,
            Path("/usr/local/share/opencv/haarcascades") / filename,
        ]
    )
    for path in candidates:
        if path.is_file():
            return str(path)
    raise SystemExit(f"failed to locate {filename}")


def sample_indices(frame_count: int, sample_count: int) -> list[int]:
    if frame_count <= 0:
        return []
    sample_count = max(1, min(sample_count, frame_count))
    if sample_count == 1:
        return [0]
    return sorted({round(i * (frame_count - 1) / (sample_count - 1)) for i in range(sample_count)})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--video", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--sample-count", type=int, default=12)
    parser.add_argument("--min-detected-ratio", type=float, default=0.60)
    parser.add_argument("--min-mean-face-area-ratio", type=float, default=0.015)
    parser.add_argument("--min-max-face-area-ratio", type=float, default=0.025)
    parser.add_argument("--min-eye-detected-ratio", type=float, default=0.35)
    parser.add_argument("--min-mean-face-sharpness", type=float, default=15.0)
    args = parser.parse_args()

    face_cascade = cv2.CascadeClassifier(resolve_cascade_path("haarcascade_frontalface_default.xml"))
    eye_cascade = cv2.CascadeClassifier(resolve_cascade_path("haarcascade_eye.xml"))
    if face_cascade.empty() or eye_cascade.empty():
        raise SystemExit("failed to load haar cascade")

    cap = cv2.VideoCapture(args.video)
    if not cap.isOpened():
        raise SystemExit(f"failed to open video: {args.video}")

    frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    indices = sample_indices(frame_count, args.sample_count)
    face_area_ratios = []
    eye_detected_count = 0
    face_sharpness_values = []
    frame_debug = []

    for idx in indices:
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ok, frame = cap.read()
        if not ok or frame is None:
            frame_debug.append({"frame_idx": idx, "detected": False, "reason": "read_failed"})
            continue

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(32, 32))
        frame_area = frame.shape[0] * frame.shape[1]

        if len(faces) == 0:
            frame_debug.append({"frame_idx": idx, "detected": False, "reason": "no_face"})
            continue

        x, y, w, h = max(faces, key=lambda rect: rect[2] * rect[3])
        area_ratio = (w * h) / frame_area
        face_gray = gray[y:y + h, x:x + w]
        upper_face = face_gray[: max(1, int(h * 0.6)), :]
        eyes = eye_cascade.detectMultiScale(upper_face, scaleFactor=1.1, minNeighbors=4, minSize=(12, 12))
        sharpness = cv2.Laplacian(face_gray, cv2.CV_64F).var()
        face_area_ratios.append(area_ratio)
        face_sharpness_values.append(sharpness)
        if len(eyes) >= 1:
            eye_detected_count += 1
        frame_debug.append(
            {
                "frame_idx": idx,
                "detected": True,
                "bbox": [int(x), int(y), int(w), int(h)],
                "face_area_ratio": area_ratio,
                "eye_detected": len(eyes) >= 1,
                "face_sharpness": sharpness,
            }
        )

    cap.release()

    sampled = len(indices)
    detected = len(face_area_ratios)
    detected_ratio = detected / sampled if sampled else 0.0
    mean_face_area_ratio = sum(face_area_ratios) / detected if detected else 0.0
    max_face_area_ratio = max(face_area_ratios) if detected else 0.0
    eye_detected_ratio = eye_detected_count / detected if detected else 0.0
    mean_face_sharpness = sum(face_sharpness_values) / detected if detected else 0.0

    issues = []
    if detected_ratio < args.min_detected_ratio:
        issues.append(f"detected_ratio too low: {detected_ratio:.3f}")
    if mean_face_area_ratio < args.min_mean_face_area_ratio:
        issues.append(f"mean_face_area_ratio too low: {mean_face_area_ratio:.4f}")
    if max_face_area_ratio < args.min_max_face_area_ratio:
        issues.append(f"max_face_area_ratio too low: {max_face_area_ratio:.4f}")
    if eye_detected_ratio < args.min_eye_detected_ratio:
        issues.append(f"eye_detected_ratio too low: {eye_detected_ratio:.3f}")
    if mean_face_sharpness < args.min_mean_face_sharpness:
        issues.append(f"mean_face_sharpness too low: {mean_face_sharpness:.2f}")

    status = "PASS" if not issues else "FAIL"
    result = {
        "status": status,
        "video": args.video,
        "metrics": {
            "sampled_frames": sampled,
            "detected_frames": detected,
            "detected_ratio": detected_ratio,
            "mean_face_area_ratio": mean_face_area_ratio,
            "max_face_area_ratio": max_face_area_ratio,
            "eye_detected_ratio": eye_detected_ratio,
            "mean_face_sharpness": mean_face_sharpness,
        },
        "thresholds": {
            "min_detected_ratio": args.min_detected_ratio,
            "min_mean_face_area_ratio": args.min_mean_face_area_ratio,
            "min_max_face_area_ratio": args.min_max_face_area_ratio,
            "min_eye_detected_ratio": args.min_eye_detected_ratio,
            "min_mean_face_sharpness": args.min_mean_face_sharpness,
        },
        "issues": issues,
        "frame_debug": frame_debug,
    }

    output_path = Path(args.output_json)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(json.dumps(result, ensure_ascii=False))
    if status != "PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
