#!/usr/bin/env python3
"""Draws MARQUEE's three original icon concepts as vectors (rendered at 1024 px)
and writes the asset catalog: AppIcon (default), two alternates, the launch logo
and colours. Usage: python3 tools/make_icons.py [preview-dir]
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "MARQUEE" / "Resources" / "Assets.xcassets"
S = 1024
SS = 3
BIG = S * SS
BG_TOP = (24, 22, 26)
BG_BOTTOM = (8, 8, 10)
GOLD_A = (242, 198, 109)
GOLD_B = (227, 154, 59)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background():
    img = Image.new("RGB", (BIG, BIG))
    d = ImageDraw.Draw(img)
    for y in range(0, BIG, SS):
        d.rectangle([0, y, BIG, y + SS], fill=lerp(BG_TOP, BG_BOTTOM, y / BIG))
    return img


def gold_fill(mask):
    """Fills a mask with a diagonal gold gradient and a soft glow behind it."""
    grad = Image.new("RGB", (BIG, BIG))
    gd = ImageDraw.Draw(grad)
    for i in range(0, 2 * BIG, 6):
        t = min(1, i / (2 * BIG))
        gd.line([(i, 0), (0, i)], fill=lerp(GOLD_A, GOLD_B, t), width=8)
    glow = mask.filter(ImageFilter.GaussianBlur(60 * SS)).point(lambda v: int(v * 0.45))
    return grad, glow


def compose(mask, extra=None):
    img = background()
    grad, glow = gold_fill(mask)
    warm = Image.new("RGB", (BIG, BIG), GOLD_B)
    img = Image.composite(warm, img, glow)
    img = Image.composite(grad, img, mask)
    if extra:
        extra(img)
    return img.resize((S, S), Image.LANCZOS)


def ticket_page():
    """A ticket stub whose right end folds over like the corner of a page."""
    m = Image.new("L", (BIG, BIG), 0)
    d = ImageDraw.Draw(m)
    x0, y0, x1, y1 = BIG * 0.13, BIG * 0.27, BIG * 0.87, BIG * 0.73
    d.rounded_rectangle([x0, y0, x1, y1], radius=BIG * 0.045, fill=255)
    r = BIG * 0.06
    cy = (y0 + y1) / 2
    d.ellipse([x0 - r, cy - r, x0 + r, cy + r], fill=0)
    # folded corner: cut the top-right triangle, then draw the fold flap darker
    fold = BIG * 0.17
    d.polygon([(x1 - fold, y0 - 2), (x1 + 2, y0 - 2), (x1 + 2, y0 + fold)], fill=0)
    # perforation
    px = BIG * 0.60
    y = y0 + BIG * 0.035
    while y < y1 - BIG * 0.03:
        d.ellipse([px - BIG * 0.011, y, px + BIG * 0.011, y + BIG * 0.022], fill=0)
        y += BIG * 0.045

    def flap(img):
        dd = ImageDraw.Draw(img)
        dd.polygon([(x1 - fold, y0), (x1 - fold, y0 + fold), (x1, y0 + fold)], fill=(150, 92, 30))
        dd.line([(x1 - fold, y0), (x1, y0 + fold)], fill=(255, 226, 160), width=int(BIG * 0.006))
    return compose(m, flap)


def bulb_m():
    """A bold M traced in marquee light bulbs."""
    m = Image.new("L", (BIG, BIG), 0)
    d = ImageDraw.Draw(m)
    pts = [(0.22, 0.76), (0.22, 0.26), (0.50, 0.56), (0.78, 0.26), (0.78, 0.76)]
    pts = [(x * BIG, y * BIG) for x, y in pts]
    r = BIG * 0.037
    def along(p0, p1, ts):
        return [(p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t) for t in ts]
    centres = (along(pts[0], pts[1], [0, 0.25, 0.5, 0.75, 1])
               + along(pts[1], pts[2], [0.25, 0.5, 0.75, 1])
               + along(pts[2], pts[3], [0.25, 0.5, 0.75])
               + along(pts[3], pts[4], [0, 0.25, 0.5, 0.75, 1]))
    for cx, cy in centres:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)

    def sparkle(img):
        dd = ImageDraw.Draw(img)
        for cx, cy in centres:
            rr = r * 0.32
            dd.ellipse([cx - rr - r * 0.25, cy - rr - r * 0.3, cx + rr - r * 0.25, cy + rr - r * 0.3], fill=(255, 244, 214))
    return compose(m, sparkle)


def frame_bookmark():
    """A film frame with sprocket holes that is also a bookmark ribbon."""
    m = Image.new("L", (BIG, BIG), 0)
    d = ImageDraw.Draw(m)
    x0, x1 = BIG * 0.30, BIG * 0.70
    y0, y1 = BIG * 0.14, BIG * 0.88
    notch = BIG * 0.13
    d.polygon([(x0, y0), (x1, y0), (x1, y1), ((x0 + x1) / 2, y1 - notch), (x0, y1)], fill=255)
    # sprocket holes down both edges
    hole_w, hole_h = BIG * 0.035, BIG * 0.05
    y = y0 + BIG * 0.04
    while y < y1 - notch - BIG * 0.02:
        for cx in (x0 + BIG * 0.045, x1 - BIG * 0.045):
            d.rounded_rectangle([cx - hole_w / 2, y, cx + hole_w / 2, y + hole_h], radius=BIG * 0.01, fill=0)
        y += BIG * 0.085
    # the frame window
    d.rounded_rectangle([x0 + BIG * 0.095, y0 + BIG * 0.10, x1 - BIG * 0.095, y0 + BIG * 0.36], radius=BIG * 0.02, fill=0)
    return compose(m)


def launch_logo():
    """A faint film-frame bookmark for the static launch screen (matches the intro's first frame)."""
    img = frame_bookmark().resize((720, 720), Image.LANCZOS).convert("RGBA")
    bg = Image.new("RGBA", img.size, (11, 11, 13, 255))
    diff = ImageChops.difference(img, bg).convert("L").point(lambda v: 255 if v > 24 else 0)
    img.putalpha(diff.point(lambda v: int(v * 0.16)))
    return img


def write_appiconset(name, image):
    folder = ASSETS / f"{name}.appiconset"
    folder.mkdir(parents=True, exist_ok=True)
    image.save(folder / f"{name}-1024.png")
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")


def write_color(name, rgb):
    folder = ASSETS / f"{name}.colorset"
    folder.mkdir(parents=True, exist_ok=True)
    r, g, b = rgb
    (folder / "Contents.json").write_text(json.dumps({
        "colors": [{"color": {"color-space": "srgb", "components": {"alpha": "1.000", "red": f"{r / 255:.3f}", "green": f"{g / 255:.3f}", "blue": f"{b / 255:.3f}"}}, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    concepts = {"AppIcon": frame_bookmark(), "AppIcon-Bulbs": bulb_m(), "AppIcon-Ticket": ticket_page()}
    for name, image in concepts.items():
        write_appiconset(name, image)
    write_color("AccentColor", GOLD_A)
    write_color("LaunchBackground", (11, 11, 13))
    logo = ASSETS / "LaunchLogo.imageset"
    logo.mkdir(parents=True, exist_ok=True)
    launch_logo().save(logo / "LaunchLogo.png")
    (logo / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "LaunchLogo.png", "idiom": "universal", "scale": "3x"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")
    # Small previews of each alternate for the in-app icon picker.
    for name, image in concepts.items():
        preview = ASSETS / f"{name}Preview.imageset"
        preview.mkdir(parents=True, exist_ok=True)
        image.resize((180, 180), Image.LANCZOS).save(preview / f"{name}Preview.png")
        (preview / "Contents.json").write_text(json.dumps({
            "images": [{"filename": f"{name}Preview.png", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
        }, indent=2) + "\n")
    if len(sys.argv) > 1:
        out = Path(sys.argv[1])
        out.mkdir(parents=True, exist_ok=True)
        sheet = Image.new("RGB", (S * 3 + 80, S + 40), (30, 30, 30))
        for i, image in enumerate(concepts.values()):
            sheet.paste(image, (20 + i * (S + 20), 20))
            image.save(out / f"icon-{i + 1}.png")
        sheet.resize((sheet.width // 3, sheet.height // 3), Image.LANCZOS).save(out / "icon-concepts.png")
    print("icons written")


if __name__ == "__main__":
    main()
