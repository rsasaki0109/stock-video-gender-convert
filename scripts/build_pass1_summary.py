#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

import cv2


def detect_video_size(video_path: str) -> tuple[int, int]:
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"failed to open video: {video_path}")
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 0)
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 0)
    cap.release()
    if width <= 0 or height <= 0:
        raise RuntimeError(f"failed to detect size: {video_path}")
    return width, height


def parse_args():
    parser = argparse.ArgumentParser(
        description="Build a compact Pass 1 summary JSON from a QC report."
    )
    parser.add_argument("--report-json", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--video", required=True)
    parser.add_argument("--source-video")
    parser.add_argument("--ref-image")
    parser.add_argument(
        "--gpt-review-verdict",
        choices=["PASS", "FAIL"],
        help="Optional manual review verdict to fold into the summary.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    report_path = Path(args.report_json)
    output_path = Path(args.output_json)

    with report_path.open("r", encoding="utf-8") as f:
        report = json.load(f)

    width, height = detect_video_size(args.video)
    metrics = report.get("metrics", {})
    female_ratio = metrics.get("gender_female_ratio", 0.0) or 0.0
    female_prob_mean = metrics.get("gender_female_prob_mean", 0.0) or 0.0
    face_similarity_mean = metrics.get("face_similarity_mean", 0.0) or 0.0
    face_switch_ratio = metrics.get("face_switch_ratio", 1.0)

    auto_gate_passed = (
        female_ratio >= 0.70
        and female_prob_mean >= 0.55
        and face_similarity_mean >= 0.95
        and face_switch_ratio <= 0.0
    )

    summary = {
        "prompt_id": report.get("prompt_id"),
        "status": report.get("status"),
        "selected_width": width,
        "selected_height": height,
        "source_video": args.source_video or None,
        "ref_image": args.ref_image or None,
        "auto_gate_passed": auto_gate_passed,
        "gpt_review_required": True,
        "final_decision": (
            "pending_gpt_review" if auto_gate_passed else "rejected_auto_gate"
        ),
        "female_ratio": metrics.get("gender_female_ratio"),
        "female_prob_mean": metrics.get("gender_female_prob_mean"),
        "face_similarity_mean": metrics.get("face_similarity_mean"),
        "face_switch_ratio": metrics.get("face_switch_ratio"),
        "issues": report.get("issues", []),
        "thresholds": {
            "female_ratio_min": 0.70,
            "female_prob_mean_min": 0.55,
            "face_switch_ratio_max": 0.0,
            "face_similarity_mean_min": 0.95,
        },
    }

    if args.gpt_review_verdict:
        summary["gpt_review_required"] = False
        summary["gpt_review_verdict"] = args.gpt_review_verdict
        summary["final_decision"] = (
            "approved_gpt_review"
            if args.gpt_review_verdict == "PASS"
            else "rejected_gpt_review"
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
