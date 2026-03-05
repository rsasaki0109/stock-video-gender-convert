#!/usr/bin/env python3
import argparse
import json
import math
import statistics
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Iterable

import cv2
import numpy as np

HAAR_CASCADE_PATHS = [
    "/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml",
    "/usr/share/opencv4/haarcascades/haarcascade_frontalface_alt.xml",
    "/usr/share/opencv4/haarcascades/haarcascade_frontalface_alt2.xml",
    "/usr/share/opencv4/haarcascades/haarcascade_frontalface_alt_tree.xml",
    "/usr/share/opencv/haarcascades/haarcascade_frontalface_default.xml",
    "/usr/share/opencv/haarcascades/haarcascade_frontalface_alt.xml",
    "/usr/share/opencv/haarcascades/haarcascade_frontalface_alt2.xml",
    "/usr/share/opencv/haarcascades/haarcascade_frontalface_alt_tree.xml",
]
SCRIPT_DIR = Path(__file__).resolve().parent
GENDER_MODEL_DIR = SCRIPT_DIR / "models" / "gender"
GENDER_DEFAULT_PROTOTXT = (
    GENDER_MODEL_DIR / "gender_net_deploy.prototxt"
)
GENDER_DEFAULT_CAFFEMODEL = (
    GENDER_MODEL_DIR / "gender_net.caffemodel"
)
GENDER_MODEL_URLS = {
    "prototxt": (
        "https://raw.githubusercontent.com/GilLevi/AgeGenderDeepLearning/"
        "master/gender_net_definitions/deploy.prototxt"
    ),
    "caffemodel": (
        "https://raw.githubusercontent.com/GilLevi/AgeGenderDeepLearning/"
        "master/models/gender_net.caffemodel"
    ),
}
GENDER_DEFAULT_MEAN = (78.4263377603, 87.7689143744, 114.895847746)


def resolve_haar_path():
    if hasattr(cv2, "data") and getattr(cv2, "data"):
        HAAR_CASCADE_PATHS.insert(0, cv2.data.haarcascades + "haarcascade_frontalface_default.xml")
    for path in HAAR_CASCADE_PATHS:
        if Path(path).exists():
            return path
    return HAAR_CASCADE_PATHS[0]

def parse_args():
    parser = argparse.ArgumentParser(
        description="Quality checker for ComfyUI Pass1 outputs (face continuity + optional history lookup)"
    )
    src = parser.add_mutually_exclusive_group(required=True)
    src.add_argument("--video", help="Path to generated mp4/avi/mov file")
    src.add_argument(
        "--prompt-id",
        help="ComfyUI prompt_id (video output is auto-resolved from /api/history/<prompt_id>)",
    )
    parser.add_argument("--api", default="http://127.0.0.1:8188", help="ComfyUI API base URL")
    parser.add_argument("--sample-step", type=int, default=2, help="Process every N-th frame")
    parser.add_argument(
        "--detect-scale-factor",
        type=float,
        default=1.08,
        help="OpenCV Haar scaleFactor parameter",
    )
    parser.add_argument(
        "--detect-min-neighbors",
        type=int,
        default=6,
        help="OpenCV Haar minNeighbors parameter",
    )
    parser.add_argument(
        "--max-overlap-iou",
        type=float,
        default=0.42,
        help="Merge duplicate detections whose IoU is higher than this",
    )
    parser.add_argument("--max-no-face-ratio", type=float, default=0.20)
    parser.add_argument("--max-multi-face-ratio", type=float, default=0.10)
    parser.add_argument("--max-face-drift-ratio", type=float, default=0.12)
    parser.add_argument("--min-face-area-ratio", type=float, default=0.003)
    parser.add_argument("--min-face-size-ratio", type=float, default=0.001)
    parser.add_argument("--min-detected-ratio", type=float, default=0.75)
    parser.add_argument("--min-mean-similarity", type=float, default=0.55)
    parser.add_argument("--min-mean-sharpness", type=float, default=35.0)
    parser.add_argument(
        "--min-continuity-similarity",
        type=float,
        default=0.45,
        help="Face-to-face similarity threshold for continuity checks",
    )
    parser.add_argument(
        "--max-face-switch-ratio",
        type=float,
        default=0.12,
        help="Fail if frame transitions with discontinuity exceed this ratio",
    )
    parser.add_argument(
        "--max-face-jump-ratio",
        type=float,
        default=0.16,
        help="Jump ratio threshold used to detect discontinuous face switches",
    )
    parser.add_argument(
        "--check-gender",
        dest="check_gender",
        action="store_true",
        default=True,
        help="Enable gender verification (female ratio check)",
    )
    parser.add_argument(
        "--no-check-gender",
        dest="check_gender",
        action="store_false",
        help="Disable gender verification",
    )
    parser.add_argument(
        "--gender-prototxt",
        default=str(GENDER_DEFAULT_PROTOTXT),
        help="Path to gender Caffe prototxt",
    )
    parser.add_argument(
        "--gender-caffemodel",
        default=str(GENDER_DEFAULT_CAFFEMODEL),
        help="Path to gender Caffe model",
    )
    parser.add_argument(
        "--gender-prototxt-url",
        default=GENDER_MODEL_URLS["prototxt"],
        help="Download URL for gender prototxt when file is missing",
    )
    parser.add_argument(
        "--gender-caffemodel-url",
        default=GENDER_MODEL_URLS["caffemodel"],
        help="Download URL for gender caffemodel when file is missing",
    )
    parser.add_argument(
        "--gender-mean-bgr",
        nargs=3,
        type=float,
        default=GENDER_DEFAULT_MEAN,
        help="Gender model mean values for BGR channels",
    )
    parser.add_argument(
        "--gender-female-min-ratio",
        type=float,
        default=0.70,
        help="Min ratio of sampled faces classified as female",
    )
    parser.add_argument(
        "--gender-female-confidence-threshold",
        type=float,
        default=0.55,
        help="Probability threshold for classifying female",
    )
    parser.add_argument(
        "--min-gender-frames",
        type=int,
        default=2,
        help="Minimum number of frames with valid gender inference",
    )
    parser.add_argument(
        "--face-strip-path",
        help="Write a horizontal strip of sampled face crops to this image path",
    )
    parser.add_argument(
        "--max-face-strip-faces",
        type=int,
        default=12,
        help="Maximum number of faces to include in the strip image",
    )
    parser.add_argument(
        "--include-frame-debug",
        action="store_true",
        help="Include per-frame debug information in the output report",
    )
    parser.add_argument(
        "--max-frame-debug-entries",
        type=int,
        default=32,
        help="Maximum number of per-frame debug entries to keep",
    )
    parser.add_argument("--output-json", help="Write report JSON to this path")
    parser.add_argument("--fail-on-issue", action="store_true", help="Exit non-zero when checks fail")
    return parser.parse_args()


def box_area(box: tuple[int, int, int, int]) -> int:
    return int(box[2] * box[3])


def box_iou(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> float:
    ax1, ay1, aw, ah = map(int, a)
    bx1, by1, bw, bh = map(int, b)
    ax2, ay2 = ax1 + aw, ay1 + ah
    bx2, by2 = bx1 + bw, by1 + bh

    x1 = max(ax1, bx1)
    y1 = max(ay1, by1)
    x2 = min(ax2, bx2)
    y2 = min(ay2, by2)

    iw = max(0, x2 - x1)
    ih = max(0, y2 - y1)
    if iw == 0 or ih == 0:
        return 0.0
    inter = iw * ih
    union = (aw * ah) + (bw * bh) - inter
    if union <= 0:
        return 0.0
    return inter / union


def merge_overlapping_boxes(
    boxes: list[tuple[int, int, int, int]], iou_threshold: float
) -> list[tuple[int, int, int, int]]:
    if not boxes:
        return []
    ordered = sorted(boxes, key=lambda b: box_area(b), reverse=True)
    kept: list[tuple[int, int, int, int]] = []
    for candidate in ordered:
        duplicate = False
        for selected in kept:
            if box_iou(candidate, selected) >= iou_threshold:
                duplicate = True
                break
        if not duplicate:
            kept.append(candidate)
    return kept


def select_stable_face(
    faces: list[tuple[int, int, int, int]],
    last_center: tuple[float, float] | None,
    frame_area: int,
) -> tuple[int, int, int, int]:
    if not faces:
        raise ValueError("No faces")
    faces_sorted = sorted(faces, key=box_area, reverse=True)
    if not last_center:
        return faces_sorted[0]

    last_x, last_y = last_center
    frame_area = max(1, frame_area)

    def score(face):
        x, y, w, h = face
        cx = x + w / 2.0
        cy = y + h / 2.0
        dist = math.hypot(cx - last_x, cy - last_y) / (math.sqrt(frame_area))
        size = (w * h) / frame_area
        return dist - (size * 0.05)

    return min(faces_sorted, key=score)


def read_history(api_base: str, prompt_id: str):
    url = f"{api_base.rstrip('/')}/api/history/{prompt_id}"
    with urllib.request.urlopen(url, timeout=20) as resp:
        raw = json.loads(resp.read().decode("utf-8"))
    entry = raw.get(prompt_id)
    if not entry:
        raise RuntimeError(f"No history entry for prompt_id={prompt_id}")
    return entry


def extract_video_from_history(entry: dict):
    outputs = entry.get("outputs") or {}
    def normalize_fullpath(path: str):
        p = Path(path)
        candidates = [p.name]
        if p.name.endswith("-audio.mp4"):
            candidates = [p.name.replace("-audio.mp4", ".mp4"), p.name]
        # remove duplicate names
        candidates = list(dict.fromkeys(candidates))
        # Check the original path and sibling `old` directory.
        for base in candidates:
            if not base:
                continue
            primary = p.with_name(base)
            if primary.exists():
                return str(primary)
            alt_dir = p.parent / "old"
            if (alt_dir / base).exists():
                return str(alt_dir / base)
        # If fullpath moved and no exact match exists, return the original path for caller.
        return str(p)

    for payload in outputs.values():
        if not isinstance(payload, dict):
            continue
        if "gifs" in payload:
            for item in payload["gifs"]:
                path = item.get("fullpath") if isinstance(item, dict) else None
                if path and str(path).lower().endswith((".mp4", ".mov", ".mkv", ".avi", ".webm")):
                    return normalize_fullpath(path)
        if "images" in payload:
            for item in payload["images"]:
                path = item.get("fullpath") if isinstance(item, dict) else None
                if path and str(path).lower().endswith((".mp4", ".mov", ".mkv", ".avi", ".webm")):
                    return normalize_fullpath(path)
        # fallback for some VHS node variants
        fullpath = payload.get("fullpath")
        if fullpath and str(fullpath).lower().endswith((".mp4", ".mov", ".mkv", ".avi", ".webm")):
            return normalize_fullpath(fullpath)
    # fallback if node outputs are not in expected shape
    return None


def download_file(url: str, dst: Path):
    dst.parent.mkdir(parents=True, exist_ok=True)
    tmp = dst.with_suffix(f"{dst.suffix}.part")
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            with open(tmp, "wb") as f:
                f.write(response.read())
    except urllib.error.URLError as e:
        if tmp.exists():
            tmp.unlink(missing_ok=True)
        raise RuntimeError(f"Failed to download {url}: {e}") from e

    if tmp.exists() and tmp.stat().st_size > 0:
        tmp.rename(dst)
    else:
        raise RuntimeError(f"Downloaded empty file: {url}")


def ensure_gender_model(args):
    proto_path = Path(args.gender_prototxt)
    model_path = Path(args.gender_caffemodel)
    if not proto_path.exists():
        print(f"[pass1-checker] gender prototxt missing, downloading: {proto_path}")
        download_file(args.gender_prototxt_url, proto_path)
    if not model_path.exists():
        print(f"[pass1-checker] gender caffemodel missing, downloading: {model_path}")
        download_file(args.gender_caffemodel_url, model_path)
    return proto_path, model_path


def make_gender_net(args):
    if not args.check_gender:
        return None
    proto_path, model_path = ensure_gender_model(args)
    try:
        net = cv2.dnn.readNetFromCaffe(str(proto_path), str(model_path))
    except Exception as e:
        raise RuntimeError(
            f"Failed to load gender model with cv2.dnn.readNetFromCaffe: {e}"
        ) from e
    return net


def predict_gender(face_bgr: np.ndarray, gender_net, mean_bgr: Iterable[float]) -> float | None:
    if gender_net is None or face_bgr is None or face_bgr.size == 0:
        return None
    try:
        resized = cv2.resize(face_bgr, (227, 227), interpolation=cv2.INTER_AREA)
    except Exception:
        return None
    try:
        blob = cv2.dnn.blobFromImage(
            resized,
            scalefactor=1.0,
            size=(227, 227),
            mean=mean_bgr,
            swapRB=False,
            crop=False,
        )
        gender_net.setInput(blob)
        probs = gender_net.forward()
    except Exception:
        return None

    probs = np.array(probs).reshape(-1)
    if probs.size < 2:
        return None
    male_prob = float(probs[0])
    female_prob = float(probs[1])
    if male_prob < 0.0 or female_prob < 0.0:
        return None
    # keep deterministic fallback when both are zero due to odd output formatting
    total = male_prob + female_prob
    if total <= 0.0:
        return None
    return female_prob / total


def ensure_video(video_path: str) -> Path:
    path = Path(video_path)
    if not path.exists():
        raise FileNotFoundError(path)
    if path.suffix.lower() not in {".mp4", ".mov", ".mkv", ".avi", ".webm"}:
        raise ValueError(f"Unsupported video extension: {path.suffix}")
    return path


def similarity_score(prev: np.ndarray, cur: np.ndarray) -> float:
    prev_small = cv2.resize(prev, (96, 96), interpolation=cv2.INTER_AREA)
    cur_small = cv2.resize(cur, (96, 96), interpolation=cv2.INTER_AREA)
    p = prev_small.astype(np.float32)
    c = cur_small.astype(np.float32)
    mse = np.mean((p - c) ** 2)
    return float(max(0.0, 1.0 - mse / (255.0 * 255.0)))


def write_face_strip(
    face_strip_entries: list[tuple[int, np.ndarray]],
    dst_path: Path,
    max_faces: int,
):
    valid_entries = [
        (frame_idx, crop)
        for frame_idx, crop in face_strip_entries
        if crop is not None and crop.size > 0
    ]
    if not valid_entries:
        return None

    max_faces = max(1, int(max_faces))
    if len(valid_entries) > max_faces:
        sample_indices = np.linspace(0, len(valid_entries) - 1, max_faces, dtype=int)
        valid_entries = [valid_entries[int(i)] for i in sample_indices]

    tiles = []
    label_height = 18
    target_height = 96
    for frame_idx, crop in valid_entries:
        scale = target_height / max(1, crop.shape[0])
        target_width = max(1, int(round(crop.shape[1] * scale)))
        tile = cv2.resize(crop, (target_width, target_height), interpolation=cv2.INTER_AREA)
        canvas = np.zeros((target_height + label_height, target_width, 3), dtype=np.uint8)
        canvas[label_height:, :, :] = tile
        cv2.putText(
            canvas,
            f"f{frame_idx}",
            (4, 13),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.4,
            (255, 255, 255),
            1,
            cv2.LINE_AA,
        )
        tiles.append(canvas)

    strip = np.concatenate(tiles, axis=1)
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(dst_path), strip)
    return str(dst_path)


def run_face_check(video_path: Path, args):
    gender_net = make_gender_net(args) if args.check_gender else None
    sample_step = args.sample_step
    min_face_size_ratio = args.min_face_size_ratio
    face_strip_capture_limit = (
        max(1, args.max_face_strip_faces) * 8 if args.face_strip_path else 0
    )
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise RuntimeError(f"Cannot open video: {video_path}")

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    frame_area = max(1, width * height)
    diag = math.hypot(width, height)
    fps = cap.get(cv2.CAP_PROP_FPS) or 0.0
    min_face_size = max(16, int(math.sqrt(frame_area * min_face_size_ratio)))
    cascade_paths = [p for p in HAAR_CASCADE_PATHS if Path(p).exists()]
    if hasattr(cv2, "data") and getattr(cv2, "data"):
        data_path = cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        if data_path not in cascade_paths:
            cascade_paths = [data_path] + cascade_paths

    if not cascade_paths:
        raise RuntimeError("No Haar cascades available for face detection.")

    face_detectors = []
    for path in cascade_paths:
        detector = cv2.CascadeClassifier(path)
        if not detector.empty():
            face_detectors.append(detector)

    if not face_detectors:
        raise RuntimeError("Failed to load Haar cascade for face detection.")

    frame_idx = 0
    sampled = 0
    seen = 0
    no_face = 0
    multi_face = 0
    too_small = 0
    drift_px = []
    drift_ratio = []
    face_area_ratio = []
    gender_female_prob = []
    gender_female_count = 0
    gender_frames = 0
    sharpness = []
    similarity = []
    frame_debug = []
    face_strip_entries = []
    last_center = None
    last_face_crop = None
    face_switch_count = 0

    while True:
        ok, frame = cap.read()
        if not ok:
            break
        if frame_idx % sample_step == 0:
            sampled += 1
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces_all = []
            for detector in face_detectors:
                faces = detector.detectMultiScale(
                    gray,
                    scaleFactor=args.detect_scale_factor,
                    minNeighbors=args.detect_min_neighbors,
                    minSize=(min_face_size, min_face_size),
                )
                if faces is not None and len(faces) > 0:
                    faces_all.extend(faces.tolist())

            faces = np.array(faces_all, dtype=int) if faces_all else np.array([], dtype=int).reshape(0, 4)
            if faces is None or len(faces) == 0:
                no_face += 1
                frame_idx += 1
                continue

            faces = [tuple(map(int, box)) for box in faces.tolist()]
            width_limit = width
            height_limit = height
            faces = [
                (x, y, w, h)
                for x, y, w, h in faces
                if w > 0
                and h > 0
                and x >= 0
                and y >= 0
                and x + w <= width_limit
                and y + h <= height_limit
            ]
            if not faces:
                no_face += 1
                frame_idx += 1
                continue

            faces = merge_overlapping_boxes(faces, args.max_overlap_iou)

            # Primary identity by size + nearest-to-last-frame preference
            faces = [
                box
                for box in faces
                if (box[2] * box[3]) >= max(
                    min_face_size * min_face_size,
                    int(frame_area * min_face_size_ratio * 0.8),
                )
            ]
            if not faces:
                too_small += 1
                frame_idx += 1
                continue

            x, y, w, h = map(int, select_stable_face(faces, last_center, frame_area))

            if len(faces) > 1:
                multi_face += 1
            area_ratio = (w * h) / frame_area

            cx = x + w / 2.0
            cy = y + h / 2.0
            seen += 1
            face_area_ratio.append(area_ratio)

            face_crop_gray = gray[y : y + h, x : x + w]
            face_crop_bgr = frame[y : y + h, x : x + w]
            current_sharpness = None
            current_similarity = None
            if face_crop_gray.size > 0:
                fv = cv2.Laplacian(face_crop_gray, cv2.CV_64F).var()
                current_sharpness = float(fv)
                sharpness.append(current_sharpness)

            if last_center is not None:
                dx = cx - last_center[0]
                dy = cy - last_center[1]
                d = math.hypot(dx, dy)
                drift_px.append(float(d))
                drift_ratio.append(float(d / max(diag, 1.0)))

            if last_face_crop is not None and face_crop_gray.size > 0:
                try:
                    current_similarity = similarity_score(last_face_crop, face_crop_gray)
                    similarity.append(current_similarity)
                    if (
                        current_similarity < args.min_continuity_similarity
                        and drift_ratio
                        and drift_ratio[-1] > args.max_face_jump_ratio
                    ):
                        face_switch_count += 1
                except Exception:
                    pass

            female_prob = None
            if gender_net is not None:
                female_prob = predict_gender(face_crop_bgr, gender_net, args.gender_mean_bgr)
                if female_prob is not None:
                    gender_frames += 1
                    gender_female_prob.append(female_prob)
                    if female_prob >= args.gender_female_confidence_threshold:
                        gender_female_count += 1

            if args.include_frame_debug and len(frame_debug) < args.max_frame_debug_entries:
                frame_debug.append(
                    {
                        "frame_idx": frame_idx,
                        "bbox": [int(x), int(y), int(w), int(h)],
                        "face_area_ratio": float(area_ratio),
                        "sharpness": current_sharpness,
                        "similarity_to_prev": current_similarity,
                        "female_prob": female_prob,
                    }
                )

            if (
                face_strip_capture_limit > 0
                and face_crop_bgr.size > 0
                and len(face_strip_entries) < face_strip_capture_limit
            ):
                face_strip_entries.append((frame_idx, face_crop_bgr.copy()))

            last_center = (cx, cy)
            if face_crop_gray.size > 0:
                last_face_crop = face_crop_gray
        frame_idx += 1

    cap.release()

    if sampled == 0:
        raise RuntimeError("No frames were sampled.")

    def mean_or_zero(values):
        return float(statistics.mean(values)) if values else 0.0

    def p95(values):
        if not values:
            return 0.0
        sorted_values = sorted(values)
        idx = int(len(sorted_values) * 0.95) - 1
        idx = max(0, min(len(sorted_values) - 1, idx))
        return float(sorted_values[idx])

    return {
        "video_path": str(video_path),
        "fps": float(fps),
        "frames": {
            "sampled": sampled,
            "faces_detected": seen,
            "no_face_frames": no_face,
            "multi_face_frames": multi_face,
            "faces_too_small": too_small,
            "face_switch_count": face_switch_count,
            "gender_evaluated_frames": gender_frames,
        },
        "metrics": {
            "detected_ratio": seen / sampled if sampled else 0.0,
            "no_face_ratio": no_face / sampled if sampled else 1.0,
            "multi_face_ratio": multi_face / sampled if sampled else 0.0,
            "drift_px_mean": mean_or_zero(drift_px),
            "drift_px_p95": p95(drift_px),
            "drift_ratio_mean": mean_or_zero(drift_ratio),
            "drift_ratio_p95": p95(drift_ratio),
            "face_area_ratio_mean": mean_or_zero(face_area_ratio),
            "face_area_ratio_std": float(statistics.pstdev(face_area_ratio)) if len(face_area_ratio) > 1 else 0.0,
            "face_similarity_mean": mean_or_zero(similarity),
            "face_sharpness_mean": mean_or_zero(sharpness),
            "face_switch_ratio": face_switch_count / sampled if sampled else 0.0,
            "gender_female_ratio": (
                gender_female_count / gender_frames if gender_frames else 0.0
            ),
            "gender_female_prob_mean": mean_or_zero(gender_female_prob),
        },
        "frame_debug": frame_debug,
        "face_strip_entries": face_strip_entries,
    }


def evaluate_result(metrics, args):
    thresholds = {
        "detected_ratio": (args.min_detected_ratio, 1.0),
        "no_face_ratio": (0.0, args.max_no_face_ratio),
        "multi_face_ratio": (0.0, args.max_multi_face_ratio),
        "drift_ratio_mean": (0.0, args.max_face_drift_ratio),
        "drift_ratio_p95": (0.0, args.max_face_drift_ratio * 1.5),
        "face_switch_ratio": (0.0, args.max_face_switch_ratio),
        "face_area_ratio_mean": (args.min_face_area_ratio, 1.0),
        "face_similarity_mean": (args.min_mean_similarity, 1.0),
        "face_sharpness_mean": (args.min_mean_sharpness, float("inf")),
    }
    if args.check_gender:
        thresholds["gender_female_ratio"] = (args.gender_female_min_ratio, 1.0)
        thresholds["gender_female_prob_mean"] = (
            args.gender_female_confidence_threshold,
            1.0,
        )
    checks = {}
    issues = []
    for key, (lower, upper) in thresholds.items():
        val = metrics["metrics"].get(key, None)
        if val is None:
            ok = False
        else:
            if val < lower or val > upper:
                ok = False
            else:
                ok = True
        checks[key] = {"value": val, "ok": bool(ok), "min": lower, "max": upper}
        if not ok:
            issues.append(f"{key} out of range: {val}")
    if args.check_gender:
        gender_frames = metrics["frames"].get("gender_evaluated_frames", 0)
        checks["gender_evaluated_frames"] = {
            "value": gender_frames,
            "ok": bool(gender_frames >= args.min_gender_frames),
            "min": args.min_gender_frames,
            "max": float("inf"),
        }
        if gender_frames < args.min_gender_frames:
            issues.append(f"gender_evaluated_frames out of range: {gender_frames}")

    status = "PASS" if not issues else "FAIL"
    return status, checks, issues


def main():
    args = parse_args()
    if args.prompt_id:
        history = read_history(args.api, args.prompt_id)
        video_candidate = extract_video_from_history(history)
        if not video_candidate:
            raise RuntimeError("No output video found in prompt history.")
        video_path = str(video_candidate)
    else:
        video_path = args.video

    video = ensure_video(video_path)
    metrics = run_face_check(video, args)
    status, checks, issues = evaluate_result(metrics, args)
    frame_debug = metrics.pop("frame_debug", [])
    face_strip_entries = metrics.pop("face_strip_entries", [])
    artifacts = {}
    if args.face_strip_path:
        face_strip_path = write_face_strip(
            face_strip_entries,
            Path(args.face_strip_path),
            args.max_face_strip_faces,
        )
        if face_strip_path:
            artifacts["face_strip_path"] = face_strip_path

    report = {
        "prompt_id": args.prompt_id,
        "status": status,
        "api": args.api,
        "args": vars(args),
        "metrics": metrics["metrics"],
        "frame_summary": metrics["frames"],
        "checks": checks,
        "issues": issues,
    }
    if args.include_frame_debug:
        report["frame_debug"] = frame_debug
    if artifacts:
        report["artifacts"] = artifacts

    print(json.dumps(report, ensure_ascii=False, indent=2))

    if args.output_json:
        out = Path(args.output_json)
        out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if args.fail_on_issue and status == "FAIL":
        return 1
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"[pass1-checker] ERROR: {e}", file=sys.stderr)
        raise SystemExit(1)
