"""Builds the README art: a banner (light and dark) and a sticker strip.

The art is SVG with the wordmark and app stickers embedded, so it stays
sharp on GitHub at any size. Run from the repo root:

    python3 design/readme/make_readme_art.py
"""

import base64
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STICKERS = ROOT / "app/assets/stickers"
OUT = ROOT / "design/readme"

PAPER = {"light": "#F1EEE9", "dark": "#17171C"}
DOT = {"light": "#E4DFD7", "dark": "#24242B"}


# Each sticker's canvas size and the box its visible part fills:
# (canvas, x, y, width, height), measured from the alpha channel.
BOXES = {
    "badge": (408, 68, 79, 272, 274),
    "brb": (468, 109, 107, 249, 216),
    "cat": (408, 105, 102, 198, 223),
    "cloud": (408, 91, 134, 235, 161),
    "dog": (408, 89, 135, 230, 172),
    "flame": (396, 114, 89, 170, 242),
    "googly_eyes": (408, 82, 131, 244, 170),
    "heart_ok": (402, 97, 125, 208, 189),
    "lol_same": (528, 80, 102, 371, 225),
    "nope": (468, 76, 109, 317, 214),
    "on_my_way": (468, 92, 86, 283, 260),
    "running_late": (468, 74, 69, 322, 292),
    "star": (408, 87, 90, 234, 232),
}


def data_uri(path: Path, mime: str) -> str:
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode()}"


def sticker(name: str, x: float, y: float, size: float, angle: float) -> str:
    cx, cy = x + size / 2, y + size / 2
    href = data_uri(STICKERS / f"{name}.webp", "image/webp")
    return (
        f'<image href="{href}" x="{x}" y="{y}" width="{size}" height="{size}" '
        f'transform="rotate({angle} {cx} {cy})"/>'
    )


def banner(theme: str) -> str:
    w, h = 1280, 560
    wordmark = data_uri(ROOT / "design/brand/source/wordmark-tight.svg", "image/svg+xml")
    # The wordmark's viewBox is 810 x 446.
    ww = 700
    wh = ww * 446 / 810
    wx, wy = (w - ww) / 2, (h - wh) / 2 - 6
    stickers = [
        ("cat", 0, 0, 270, -10),
        ("lol_same", 10, 290, 280, 8),
        ("flame", 1020, -6, 260, 9),
        ("heart_ok", 1010, 280, 270, -7),
        ("star", 220, 380, 170, 14),
        ("googly_eyes", 905, 405, 160, -12),
    ]
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-label="Peel">
<defs>
  <pattern id="dots" width="28" height="28" patternUnits="userSpaceOnUse">
    <circle cx="14" cy="14" r="2" fill="{DOT[theme]}"/>
  </pattern>
  <clipPath id="card"><rect width="{w}" height="{h}" rx="56"/></clipPath>
</defs>
<g clip-path="url(#card)">
  <rect width="{w}" height="{h}" fill="{PAPER[theme]}"/>
  <rect width="{w}" height="{h}" fill="url(#dots)"/>
  {''.join(sticker(*s) for s in stickers)}
  <image href="{wordmark}" x="{wx}" y="{wy}" width="{ww}" height="{wh}"/>
</g>
</svg>
"""


def placed(name: str, height: float, angle: float):
    """A sticker cropped to its visible part, tilted by [angle] and scaled
    to [height]. Returns (svg fragment drawn at 0,0, width, height)."""
    canvas, x, y, w, h = BOXES[name]
    k = height / h
    a = math.radians(angle)
    rw = (w * abs(math.cos(a)) + h * abs(math.sin(a))) * k
    rh = (w * abs(math.sin(a)) + h * abs(math.cos(a))) * k
    href = data_uri(STICKERS / f"{name}.webp", "image/webp")
    cx, cy = x + w / 2, y + h / 2
    frag = (
        f'<g transform="translate({rw / 2:.1f} {rh / 2:.1f}) rotate({angle}) '
        f'scale({k:.4f}) translate({-cx} {-cy})">'
        f'<image href="{href}" width="{canvas}" height="{canvas}"/></g>'
    )
    return frag, rw, rh


def single(name: str, angle: float) -> str:
    frag, w, h = placed(name, 200, angle)
    pad = 4
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w + 2 * pad:.0f}" '
        f'height="{h + 2 * pad:.0f}" viewBox="{-pad} {-pad} {w + 2 * pad:.1f} '
        f'{h + 2 * pad:.1f}" role="img" aria-label="">{frag}</svg>\n'
    )


def strip() -> str:
    names = ["dog", "brb", "cloud", "on_my_way", "nope", "badge", "running_late"]
    angles = [-8, 6, -4, 7, -6, 5, -7]
    gap, height, pad = 26, 150, 20
    parts, x, tallest = [], pad, 0.0
    for i, (n, a) in enumerate(zip(names, angles)):
        frag, w, h = placed(n, height, a)
        dy = 10 if i % 2 else 0
        parts.append((frag, x, dy, h))
        x += w + gap
        tallest = max(tallest, h + dy)
    total_w, total_h = x - gap + pad, tallest + 2 * pad
    items = "".join(
        f'<g transform="translate({px:.1f} {pad + dy + (tallest - dy - h) / 2:.1f})">{f}</g>'
        for f, px, dy, h in parts
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{total_w:.0f}" height="{total_h:.0f}" '
        f'viewBox="0 0 {total_w:.1f} {total_h:.1f}" role="img" '
        f'aria-label="Stickers made with Peel">{items}</svg>\n'
    )


SECTION_STICKERS = {
    "star": -8,
    "heart_ok": 7,
    "googly_eyes": -6,
    "flame": 8,
    "cat": -7,
    "badge": 6,
    "lol_same": -5,
}


if __name__ == "__main__":
    for theme in ("light", "dark"):
        (OUT / f"banner-{theme}.svg").write_text(banner(theme))
    (OUT / "stickers.svg").write_text(strip())
    for name, angle in SECTION_STICKERS.items():
        (OUT / f"sticker-{name}.svg").write_text(single(name, angle))
    print("Wrote", *sorted(p.name for p in OUT.glob("*.svg")))
