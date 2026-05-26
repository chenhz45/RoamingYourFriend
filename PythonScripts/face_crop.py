#!/usr/bin/env python3
"""
RoamingYourFriend — Face Detection & Circular Avatar Cropping

Uses MediaPipe BlazeFace (short-range) for accurate, consistent face detection
with keypoints. Fully offline once the model file is present.

Usage:
  python face_crop.py --input <path> --output <path> [--size 100] [--pixel-block 6]
"""

import argparse
import os
import random
import sys

import mediapipe as mp
import numpy as np
from mediapipe.tasks.python import BaseOptions, vision
from PIL import Image, ImageDraw

# ---------------------------------------------------------------------------
# MediaPipe model
# ---------------------------------------------------------------------------

if getattr(sys, 'frozen', False):
    _BASE_DIR = sys._MEIPASS
else:
    _BASE_DIR = os.path.dirname(os.path.abspath(__file__))

_MODEL_PATH = os.path.join(_BASE_DIR, "blaze_face_short_range.tflite")


def _create_detector() -> vision.FaceDetector:
    options = vision.FaceDetectorOptions(
        base_options=BaseOptions(model_asset_path=_MODEL_PATH),
        min_detection_confidence=0.5,
    )
    return vision.FaceDetector.create_from_options(options)


# ---------------------------------------------------------------------------
# Face detection (MediaPipe BlazeFace)
# ---------------------------------------------------------------------------

def detect_face(image: Image.Image) -> dict | None:
    """
    Detect the most prominent face using MediaPipe BlazeFace.
    Returns a dict with bbox/center/radius keys for crop_circular_avatar,
    or None if no face found.
    """
    iw, ih = image.size

    rgb = np.array(image.convert("RGB"))
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

    detector = _create_detector()
    try:
        result = detector.detect(mp_image)
    finally:
        detector.close()

    if not result.detections:
        return None

    # Pick the largest face by bbox area
    best = max(result.detections,
               key=lambda d: d.bounding_box.width * d.bounding_box.height)
    bbox = best.bounding_box
    fw = float(bbox.width)
    fh = float(bbox.height)

    # Eye keypoints (MediaPipe always returns 6 keypoints per detection)
    # Keypoints: 0=left_eye, 1=right_eye, 2=nose, 3=mouth, 4=left_ear, 5=right_ear
    kp = best.keypoints
    left_eye_x = kp[0].x * iw
    left_eye_y = kp[0].y * ih
    right_eye_x = kp[1].x * iw
    right_eye_y = kp[1].y * ih

    # Centre on eye midpoint (consistent across all photos)
    cx = (left_eye_x + right_eye_x) / 2.0
    cy = (left_eye_y + right_eye_y) / 2.0

    # Tighter crop so the face fills more of the avatar circle
    crop_size = max(fw, fh) * 1.45

    # Slight upward shift to include forehead
    cy = cy - fh * 0.10

    # Clamp to stay within image bounds
    half = crop_size / 2.0
    cx = max(half, min(iw - half, cx))
    cy = max(half, min(ih - half, cy))

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
    """Crop head region -> squash -> pixelate -> circular mask."""
    iw, ih = image.size
    x, y, s, _ = face_info["bbox"]

    # Clamp crop to image bounds, pad with transparency if needed
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
    squash_w = int(out_size * 1.10)
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
