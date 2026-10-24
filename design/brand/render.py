"""Render the Kairos mark to PNGs (no SVG renderer needed: the mark is circles and an arc)."""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

TEAL, AMBER, BG = (45, 212, 191, 255), (245, 165, 36, 255), (10, 14, 19, 255)


def mark(size: int, background: bool, pad: float = 0.0) -> Image.Image:
    s = 4 * size  # supersample, then downscale for smooth edges
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = s / 64 * (1 - 2 * pad)
    o = s * pad
    P = lambda v: o + v * u  # noqa: E731
    if background:
        d.rounded_rectangle([0, 0, s - 1, s - 1], radius=14 * s / 64, fill=BG)
    r, w = 18 * u, 6 * u
    box = [P(32) - r, P(32) - r, P(32) + r, P(32) + r]
    d.arc(box, start=20, end=320, fill=TEAL, width=int(w))
    mr = 4.6 * u
    mx, my = P(32) + (r - w / 2) * math.cos(math.radians(-10)), P(32) + (r - w / 2) * math.sin(math.radians(-10))
    d.ellipse([mx - mr, my - mr, mx + mr, my + mr], fill=AMBER)
    cr = 6 * u
    d.ellipse([P(32) - cr, P(32) - cr, P(32) + cr, P(32) + cr], fill=TEAL)
    return img.resize((size, size), Image.LANCZOS)


root = Path(sys.argv[1])
web = root / "web" / "public"
mark(180, True).save(web / "apple-touch-icon.png")
mark(192, True).save(web / "icon-192.png")
mark(512, True).save(web / "icon-512.png")
mark(32, True).save(web / "favicon-32.png")
mob = root / "mobile"
for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    mark(px, True).save(mob / "android" / "app" / "src" / "main" / "res" / f"mipmap-{folder}" / "ic_launcher.png")
(mob / "assets" / "brand").mkdir(parents=True, exist_ok=True)
mark(256, False).save(mob / "assets" / "brand" / "kairos_mark.png")
mark(1024, True).save(root / "design" / "brand" / "kairos-app-icon-1024.png")
print("rendered")
