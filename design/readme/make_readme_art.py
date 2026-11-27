"""Builds the README art: a banner (light and dark) and a sticker strip.

The art is SVG with the wordmark and app stickers embedded, so it stays
sharp on GitHub at any size. Run from the repo root:

    python3 design/readme/make_readme_art.py
"""

import base64
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STICKERS = ROOT / "app/assets/stickers"
OUT = ROOT / "design/readme"

PAPER = {"light": "#F1EEE9", "dark": "#17171C"}
DOT = {"light": "#E4DFD7", "dark": "#24242B"}


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


def strip() -> str:
    names = ["dog", "brb", "cloud", "on_my_way", "nope", "badge", "running_late"]
    size, gap = 260, -70
    w = len(names) * size + (len(names) - 1) * gap + 40
    h = 290
    angles = [-8, 6, -4, 7, -6, 5, -7]
    items = "".join(
        sticker(n, 20 + i * (size + gap), 12 + (14 if i % 2 else 0), size, a)
        for i, (n, a) in enumerate(zip(names, angles))
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" role="img" aria-label="Stickers made with Peel">{items}</svg>
"""


if __name__ == "__main__":
    for theme in ("light", "dark"):
        (OUT / f"banner-{theme}.svg").write_text(banner(theme))
    (OUT / "stickers.svg").write_text(strip())
    print("Wrote", *sorted(p.name for p in OUT.glob("*.svg")))
