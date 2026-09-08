#!/usr/bin/env python3
"""
Generates Resources/AppIcon.icns.

Pure standard library — no Pillow, no drawing framework. Shapes are rasterised from a signed
distance field, which gives clean antialiasing in a single pass, and PNGs are written by hand
with zlib. Each iconset size is rendered natively rather than downsampled, so the small sizes
stay crisp.

    python3 Scripts/make-icon.py

The design: a violet squircle holding a window split into two panes, the left one solid and the
right one dimmed — the Left Half action, which is the one everybody presses first.
"""

import math
import os
import shutil
import struct
import subprocess
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONSET = os.path.join(ROOT, "Resources", "AppIcon.iconset")
ICNS = os.path.join(ROOT, "Resources", "AppIcon.icns")

# Geometry as fractions of the canvas, so every size renders from the same description.
#
# Tuned for the 16pt rendering, which is where the icon has to survive: the panes take ~70% of
# the tile width, because at smaller ratios the split stops reading at all.
MARGIN = 76 / 1024           # padding around the squircle
CORNER = 190 / 1024          # squircle corner radius
PANE_TOP = 296 / 1024        # window pane bounds
PANE_BOTTOM = 728 / 1024
PANE_LEFT = 206 / 1024
PANE_RIGHT = 818 / 1024
PANE_GAP = 32 / 1024         # gutter between the two panes
PANE_CORNER = 42 / 1024

GRADIENT_TOP = (132, 111, 255)
GRADIENT_BOTTOM = (67, 48, 205)
LEFT_PANE_ALPHA = 1.0
RIGHT_PANE_ALPHA = 0.40

# Sizes iconutil expects, as (pixel size, filename).
ICONSET_SIZES = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]


def rounded_rect_sdf(px, py, x0, y0, x1, y1, radius):
    """Signed distance from (px, py) to a rounded rectangle. Negative means inside."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hw, hh = (x1 - x0) / 2, (y1 - y0) / 2
    radius = min(radius, hw, hh)

    dx = abs(px - cx) - (hw - radius)
    dy = abs(py - cy) - (hh - radius)
    outside = math.hypot(max(dx, 0.0), max(dy, 0.0))
    inside = min(max(dx, dy), 0.0)
    return outside + inside - radius


def coverage(distance):
    """Antialiased coverage from a distance in pixels."""
    return min(max(0.5 - distance, 0.0), 1.0)


def over(dst, src, alpha):
    """Composite a straight-alpha source colour over an opaque destination."""
    return tuple(int(round(s * alpha + d * (1 - alpha))) for s, d in zip(src, dst))


def render(size):
    """Renders one square RGBA image, returned as a list of row bytearrays."""
    s = float(size)
    bg_x0, bg_y0 = MARGIN * s, MARGIN * s
    bg_x1, bg_y1 = s - MARGIN * s, s - MARGIN * s
    bg_r = CORNER * s

    pane_y0, pane_y1 = PANE_TOP * s, PANE_BOTTOM * s
    gap = PANE_GAP * s
    left_x0 = PANE_LEFT * s
    right_x1 = PANE_RIGHT * s
    split = (left_x0 + right_x1) / 2
    left_x1 = split - gap / 2
    right_x0 = split + gap / 2
    pane_r = PANE_CORNER * s

    rows = []
    for y in range(size):
        py = y + 0.5
        row = bytearray()

        # Vertical gradient with a slight diagonal lean, evaluated once per row and nudged per
        # pixel below.
        t_row = py / s
        for x in range(size):
            px = x + 0.5

            bg_alpha = coverage(rounded_rect_sdf(px, py, bg_x0, bg_y0, bg_x1, bg_y1, bg_r))
            if bg_alpha <= 0.0:
                row += b"\x00\x00\x00\x00"
                continue

            t = min(max(t_row * 0.85 + (px / s) * 0.15, 0.0), 1.0)
            colour = tuple(
                int(round(a + (b - a) * t)) for a, b in zip(GRADIENT_TOP, GRADIENT_BOTTOM)
            )

            left = coverage(rounded_rect_sdf(px, py, left_x0, pane_y0, left_x1, pane_y1, pane_r))
            if left > 0.0:
                colour = over(colour, (255, 255, 255), left * LEFT_PANE_ALPHA)

            right = coverage(rounded_rect_sdf(px, py, right_x0, pane_y0, right_x1, pane_y1, pane_r))
            if right > 0.0:
                colour = over(colour, (255, 255, 255), right * RIGHT_PANE_ALPHA)

            row += bytes((colour[0], colour[1], colour[2], int(round(bg_alpha * 255))))

        rows.append(row)
    return rows


def write_png(path, size, rows):
    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    # Filter type 0 (None) on every scanline.
    raw = b"".join(b"\x00" + bytes(row) for row in rows)
    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)  # 8-bit RGBA

    with open(path, "wb") as handle:
        handle.write(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b"")
        )


def main():
    shutil.rmtree(ICONSET, ignore_errors=True)
    os.makedirs(ICONSET)

    cache = {}
    for size, name in ICONSET_SIZES:
        if size not in cache:
            print(f"  rendering {size}x{size}")
            cache[size] = render(size)
        write_png(os.path.join(ICONSET, name), size, cache[size])

    # Keep the largest rendering around as a plain preview.
    write_png(os.path.join(ROOT, "Resources", "AppIcon-preview.png"), 512, cache[512])

    subprocess.run(["iconutil", "-c", "icns", ICONSET, "-o", ICNS], check=True)
    shutil.rmtree(ICONSET, ignore_errors=True)
    print(f"==> {ICNS}")


if __name__ == "__main__":
    sys.exit(main())
