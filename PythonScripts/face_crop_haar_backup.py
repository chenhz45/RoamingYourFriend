#!/usr/bin/env python3
"""
RoamingYourFriend — Face Detection & Circular Avatar Cropping

Fully offline: uses OpenCV Haar Cascades only. No network, no model download.
Detection tries multiple cascade models for better coverage.

Usage:
  python face_crop.py --input <path> --output <path> [--size 100] [--pixel-block 6]
"""

import argparse
import os
import random
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------
# Face detection (OpenCV Haar Cascades — fully offline)
# ---------------------------------------------------------------------------

# Cascade files to try, in order of preference
CASCADE_FILES = [
    "haarcascade_frontalface_default.xml",
    "haarcascade_frontalface_alt2.xml",
    "haarcascade_profileface.xml",
]


def _merge_overlapping(faces: list, iou_threshold: float = 0.3) -> list:
    """Simple non-maximum suppression: merge overlapping face detections."""
    if len(faces) <= 1:
        return faces

    # Sort by area descending
    faces = sorted(faces, key=lambda r: r[2] * r[3], reverse=True)
    kept = []

    for f in faces:
        fx, fy, fw, fh = f
        overlap = False
        for k in kept:
            kx, ky, kw, kh = k
            # Intersection over Union
            ix = max(fx, kx)
            iy = max(fy, ky)
            ix2 = min(fx + fw, kx + kw)
            iy2 = min(fy + fh, ky + kh)
            if ix < ix2 and iy < iy2:
                inter = (ix2 - ix) * (iy2 - iy)
                union = fw * fh + kw * kh - inter
                if inter / union > iou_threshold:
                    overlap = True
                    break
        if not overlap:
            kept.append(f)

    return kept


def detect_face(image: Image.Image) -> dict | None:
    """
    Multi-region face detection (OpenCV only, fully offline).
    Tries full image first, then upper portion (for full-body portraits).
    Uses bbox-based sizing + eye centering refinement.
    """
    iw, ih = image.size

    # Region strategies: (image, offset_x, offset_y)
    regions = [
        (image, 0, 0),                                    # full image
        (image.crop((0, 0, iw, int(ih * 0.50))), 0, 0),   # upper half
        (image.crop((0, 0, iw, int(ih * 0.45))), 0, 0),   # upper 45%
    ]

    best_face = None
    best_area = 0

    for region, ox, oy in regions:
        face = _detect_in_region(region, ox, oy)
        if face:
            _, _, s, _ = face["bbox"]
            area = s * s
            if area > best_area:
                best_area = area
                best_face = face

    return best_face


def _detect_in_region(image: Image.Image, ox: int, oy: int) -> dict | None:
    """Run Haar cascade detection on a single image region."""
    iw, ih = image.size
    cv_image = cv2.cvtColor(np.array(image.convert("RGB")), cv2.COLOR_RGB2BGR)
    gray = cv2.cvtColor(cv_image, cv2.COLOR_BGR2GRAY)
    gray = cv2.equalizeHist(gray)

    all_faces = []

    for cascade_name in CASCADE_FILES:
        cascade_path = cv2.data.haarcascades + cascade_name
        if not os.path.exists(cascade_path):
            continue

        cascade = cv2.CascadeClassifier(cascade_path)
        for scale in (1.05, 1.1):
            for neigh in (3, 4):
                faces = cascade.detectMultiScale(
                    gray,
                    scaleFactor=scale,
                    minNeighbors=neigh,
                    minSize=(25, 25),
                )
                for (fx, fy, fw, fh) in faces:
                    all_faces.append((fx + ox, fy + oy, fw, fh))

    if not all_faces:
        return None

    merged = _merge_overlapping(all_faces)
    best = max(merged, key=lambda r: r[2] * r[3])
    fx, fy, fw, fh = best

    # Sizing: bbox-based, tighter crop so the face fills more of the avatar
    crop_size = max(fw, fh) * 1.35

    # Centering: always use bbox centre (consistent across all photos)
    cx = fx + fw / 2.0
    cy = fy + fh / 2.0

    # Subtle upward shift for forehead
    cy = cy - fh * 0.10

    # Clamp to original image bounds
    ow, oh = iw, ih
    half = crop_size / 2.0
    cx = max(half - ow * 0.05, min(ow + ow * 0.05 - half, cx))
    cy = max(half - oh * 0.05, min(oh + oh * 0.05 - half, cy))

    return {
        "bbox": (cx - half, cy - half, crop_size, crop_size),
        "center": (cx, cy),
        "radius": half,
    }


# ---------------------------------------------------------------------------
# No-signal fallback
# ---------------------------------------------------------------------------

def create_no_signal_avatar(size: int) -> Image.Image:
    """TV-static circular avatar with fixed seed for consistent noise."""
    rng = random.Random(42)
    noise = Image.new("RGBA", (size, size))
    pixels = [(0 if rng.random() < 0.5 else 255,) * 3 + (255,) for _ in range(size * size)]
    noise.putdata(pixels)

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size, size), fill=255)

    result = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    result.paste(noise, (0, 0), mask)

    draw = ImageDraw.Draw(result)
    draw.ellipse([2, 2, size - 2, size - 2], outline=(80, 80, 80, 200), width=2)
    return result


# ---------------------------------------------------------------------------
# Circular avatar crop + pixel filter
# ---------------------------------------------------------------------------

def crop_circular_avatar(
    image: Image.Image,
    face_info: dict,
    out_size: int,
    pixel_block: int,
) -> Image.Image:
    """Crop head region -> circular mask -> pixelate."""
    iw, ih = image.size
    x, y, s, _ = face_info["bbox"]

    # Clamp crop to image bounds, pad with black if needed
    x1 = max(0, int(x))
    y1 = max(0, int(y))
    x2 = min(iw, int(x + s))
    y2 = min(ih, int(y + s))

    cropped = image.crop((x1, y1, x2, y2)).convert("RGBA")

    # If crop doesn't cover the full square, paste onto square canvas
    if (x2 - x1) != int(s) or (y2 - y1) != int(s):
        canvas = Image.new("RGBA", (int(s), int(s)), (0, 0, 0, 0))
        canvas.paste(cropped, (x1 - int(x), y1 - int(y)))
        cropped = canvas

    cropped = cropped.resize((out_size, out_size), Image.LANCZOS)

    # Squash: stretch horizontally, then centre-crop so the face appears
    # wider/shorter and fills the circular avatar better.
    squash_w = int(out_size * 1.15)
    cropped = cropped.resize((squash_w, out_size), Image.LANCZOS)
    left = (squash_w - out_size) // 2
    cropped = cropped.crop((left, 0, left + out_size, out_size))

    # Pixel filter — shrink then expand with nearest-neighbour
    small_size = max(1, out_size // pixel_block)
    pixelated = cropped.resize((small_size, small_size), Image.NEAREST)
    pixelated = pixelated.resize((out_size, out_size), Image.NEAREST)

    # Circular mask
    mask = Image.new("L", (out_size, out_size), 0)
    ImageDraw.Draw(mask).ellipse((2, 2, out_size - 2, out_size - 2), fill=255)

    result = Image.new("RGBA", (out_size, out_size), (0, 0, 0, 0))
    result.paste(pixelated, (0, 0), mask)
    return result


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Face crop & pixelate avatar")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--size", type=int, default=100)
    parser.add_argument("--pixel-block", type=int, default=6)
    args = parser.parse_args()

    if not os.path.exists(args.input):
        print(f"Error: input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)

    image = Image.open(args.input)

    try:
        face_info = detect_face(image)
        if face_info is not None:
            avatar = crop_circular_avatar(image, face_info, args.size, args.pixel_block)
            status = "success"
        else:
            avatar = create_no_signal_avatar(args.size)
            status = "no_face"
    except Exception as exc:
        print(f"Detection error: {exc}", file=sys.stderr)
        avatar = create_no_signal_avatar(args.size)
        status = "no_face"

    avatar.save(args.output, "PNG")
    print(status)


if __name__ == "__main__":
    main()
