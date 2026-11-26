#!/usr/bin/env python3
"""Renders the sticker artwork from the UI design canvas into PNGs.

The SVG/HTML below is copied from the design canvas (Home and My stickers
screens) so the app uses exactly the same art. Each sticker is rendered by
headless Chrome at 3x on a transparent background, with the same white
die-cut edge and shadow (CSS drop-shadow) and the same tilt as the design.

Every image has PAD logical px of transparent margin around the design box,
so in Flutter: offset the image by -PAD and size it at (w + 2*PAD).

Usage:  python3 tool/render_design_stickers.py <out_dir>
Then:   flutter test tool/encode_sticker_assets_test.dart  (PNG -> WebP)
"""

import pathlib
import subprocess
import sys
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SCALE = 3
PAD = 28  # Room for the white edge, shadow and rotation.

FONTS = (
    '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?'
    "family=Inter+Tight:wght@800&family=Instrument+Serif:ital@1&display=block\">"
)
DIECUT = (
    "filter:drop-shadow(4px 0 0 #fff) drop-shadow(-4px 0 0 #fff) "
    "drop-shadow(0 4px 0 #fff) drop-shadow(0 -4px 0 #fff) "
    "drop-shadow(0 6px 10px rgba(17,17,19,.16))"
)
DIECUT_SMALL = (
    "filter:drop-shadow(3px 0 0 #fff) drop-shadow(-3px 0 0 #fff) "
    "drop-shadow(0 3px 0 #fff) drop-shadow(0 -3px 0 #fff) "
    "drop-shadow(0 4px 6px rgba(17,17,19,.14))"
)

BADGE = """<svg viewBox="0 0 100 100" width="100%" height="100%">
<defs><path id="ring" d="M50,50 m-35,0 a35,35 0 1,1 70,0 a35,35 0 1,1 -70,0"/></defs>
<circle cx="50" cy="50" r="48" fill="#CFE6FB"/>
<text font-family="Inter Tight, sans-serif" font-size="10.5" font-weight="800" letter-spacing="1.5" fill="#1E3F7A"><textPath href="#ring">MADE BY ME · MADE BY ME · </textPath></text>
<circle cx="50" cy="50" r="15" fill="none" stroke="#1E3F7A" stroke-width="2.6"/>
<circle cx="45" cy="47" r="1.8" fill="#1E3F7A"/><circle cx="55" cy="47" r="1.8" fill="#1E3F7A"/>
<path d="M43.5 53 Q50 58.5 56.5 53" fill="none" stroke="#1E3F7A" stroke-width="2.6" stroke-linecap="round"/>
</svg>"""

STAR = """<svg viewBox="0 0 100 100" width="100%" height="100%">
<path d="M50 8 L61.5 36 L91 37.5 L68 56.5 L76 86 L50 69.5 L24 86 L32 56.5 L9 37.5 L38.5 36 Z" fill="#FFE08A" stroke="#B85C00" stroke-width="3.2" stroke-linejoin="round"/>
<circle cx="43" cy="50" r="2.6" fill="#B85C00"/><circle cx="57" cy="50" r="2.6" fill="#B85C00"/>
<path d="M44 58 Q50 63.5 56 58" fill="none" stroke="#B85C00" stroke-width="2.8" stroke-linecap="round"/>
</svg>"""

FLAME = """<svg viewBox="0 0 100 100" width="100%" height="100%">
<path d="M50 8 C63 28 80 40 76 64 C73 83 60 92 50 92 C37 92 24 82 24 64 C24 50 34 44 37 32 C44 40 46 45 46 50 C53 39 55 24 50 8 Z" fill="#FFC6EC" stroke="#C2188B" stroke-width="3.4" stroke-linejoin="round"/>
<path d="M50 52 C58 60 63 67 61 75 C59 83 53 86 50 86 C44 86 39 80 40 73 C41 66 47 62 50 52 Z" fill="#C2188B"/>
</svg>"""

DOG = """<svg viewBox="0 0 100 100" width="100%" height="100%">
<path d="M22 30 Q9 34 11 58 Q13 67 24 62 Q28 46 31 34 Z" fill="#8B5A3C"/>
<path d="M78 30 Q91 34 89 58 Q87 67 76 62 Q72 46 69 34 Z" fill="#8B5A3C"/>
<ellipse cx="50" cy="52" rx="28" ry="27" fill="#E6B07E"/>
<ellipse cx="61" cy="45" rx="8.5" ry="7.5" fill="#C98A58"/>
<ellipse cx="50" cy="65" rx="14.5" ry="10.5" fill="#F6DCC0"/>
<circle cx="40" cy="46" r="3.6" fill="#2A1B14"/><circle cx="61" cy="46" r="3.6" fill="#2A1B14"/>
<circle cx="41.2" cy="44.8" r="1.1" fill="#FFFFFF"/><circle cx="62.2" cy="44.8" r="1.1" fill="#FFFFFF"/>
<ellipse cx="50" cy="59" rx="5.2" ry="3.7" fill="#2A1B14"/>
<path d="M48 68 Q50 77 53 68 Z" fill="#F07A8E"/>
<path d="M43.5 66.5 Q50 71.5 56.5 66.5" fill="none" stroke="#2A1B14" stroke-width="2" stroke-linecap="round"/>
</svg>"""

CAT = """<svg viewBox="0 0 100 100" width="100%" height="100%">
<path d="M22 42 L25 13 L43 28 Q50 26 57 28 L75 13 L78 42 Q85 60 74 73 Q64 85 50 85 Q36 85 26 73 Q15 60 22 42 Z" fill="#DCCBFF" stroke="#4B2A9B" stroke-width="3.2" stroke-linejoin="round"/>
<path d="M35 53 Q40 48.5 45 53" fill="none" stroke="#4B2A9B" stroke-width="2.8" stroke-linecap="round"/>
<path d="M55 53 Q60 48.5 65 53" fill="none" stroke="#4B2A9B" stroke-width="2.8" stroke-linecap="round"/>
<path d="M47 60 L53 60 L50 64 Z" fill="#4B2A9B"/>
<path d="M50 64 Q46 69 42 66 M50 64 Q54 69 58 66" fill="none" stroke="#4B2A9B" stroke-width="2.4" stroke-linecap="round"/>
<path d="M18 60 L34 62 M18 68 L34 66 M82 60 L66 62 M82 68 L66 66" stroke="#4B2A9B" stroke-width="2" stroke-linecap="round"/>
</svg>"""

HEART = """<svg viewBox="0 0 100 100" width="100%" height="100%">
<path d="M50 86 C20 66 9 47 17 32 C25 17 44 19 50 32 C56 19 75 17 83 32 C91 47 80 66 50 86 Z" fill="#E5484D"/>
<path d="M37 48 L46 57 L64 39" fill="none" stroke="#FFFFFF" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>"""

EYES = """<svg viewBox="0 0 100 100" width="100%" height="100%">
<rect x="8" y="24" width="84" height="52" rx="26" fill="#111113"/>
<circle cx="33" cy="50" r="18" fill="#FFFFFF"/><circle cx="67" cy="50" r="18" fill="#FFFFFF"/>
<circle cx="38" cy="55" r="8.5" fill="#111113"/><circle cx="61" cy="44" r="8.5" fill="#111113"/>
</svg>"""

CLOUD = """<svg viewBox="0 0 100 100" width="100%" height="100%">
<path d="M28 72 Q12 72 13 58 Q14 46 27 46 Q28 30 44 29 Q56 22 66 33 Q85 32 86 50 Q95 58 87 68 Q82 73 74 72 Z" fill="#DCCBFF" stroke="#4B2A9B" stroke-width="3.2" stroke-linejoin="round"/>
<circle cx="42" cy="54" r="2.6" fill="#4B2A9B"/><circle cx="60" cy="54" r="2.6" fill="#4B2A9B"/>
<path d="M46 62 Q51 59 56 62" fill="none" stroke="#4B2A9B" stroke-width="2.6" stroke-linecap="round"/>
</svg>"""

SERIF = "font-family:'Instrument Serif',Georgia,serif;font-style:italic;line-height:1"


def pill(text, bg, fg, size, pad, radius, rotate):
    return (
        f'<div style="display:flex;align-items:center;justify-content:center;'
        f'width:100%;height:100%"><span style="{DIECUT_SMALL};background:{bg};'
        f"color:{fg};{SERIF};font-size:{size}px;padding:{pad};"
        f'border-radius:{radius};transform:rotate({rotate}deg);white-space:nowrap;'
        f'text-align:center">{text}</span></div>'
    )


NAME_TAG = (
    '<div style="display:flex;align-items:center;justify-content:center;width:100%;height:100%">'
    f'<span style="{DIECUT_SMALL};width:84px;border-radius:9px;overflow:hidden;'
    "background:#fff;transform:rotate(-6deg);display:flex;flex-direction:column;"
    'border:2px solid #D62F33">'
    '<span style="background:#D62F33;color:#fff;font:800 9px \'Inter Tight\',sans-serif;'
    'letter-spacing:.08em;padding:4px 0 3px;text-align:center">HELLO, I\'M</span>'
    f'<span style="{SERIF};font-size:19px;color:#111113;padding:7px 4px 9px;'
    'text-align:center">running late</span></span></div>'
)

# name: (box width, box height, rotation degrees, die-cut filter or None, html)
STICKERS = {
    # Home hero (sizes and tilts as on the Home screen).
    "home_badge": (122, 122, 10, DIECUT, BADGE),
    "home_star": (82, 82, -12, DIECUT, STAR),
    "home_flame": (62, 62, 9, DIECUT, FLAME),
    # My stickers grid (80 px art inside a tile).
    "dog": (80, 80, 0, DIECUT_SMALL, DOG),
    "cat": (80, 80, 0, DIECUT_SMALL, CAT),
    "badge": (80, 80, 0, DIECUT_SMALL, BADGE),
    "star": (80, 80, 0, DIECUT_SMALL, STAR),
    "flame": (76, 76, 0, DIECUT_SMALL, FLAME),
    "heart_ok": (78, 78, 0, DIECUT_SMALL, HEART),
    "googly_eyes": (80, 80, 0, DIECUT_SMALL, EYES),
    "cloud": (80, 80, 0, DIECUT_SMALL, CLOUD),
    "running_late": (100, 80, 0, None, NAME_TAG),
    "lol_same": (120, 80, 0, None,
                 pill("lol, same", "#3D5AFE", "#fff", 26, "12px 14px 14px", "999px", -8)),
    "on_my_way": (100, 80, 0, None,
                  pill("on my<br>way", "#CFF5B4", "#1C5B2C", 23, "12px 14px 13px", "40px", 5)),
    "nope": (100, 80, 0, None,
             pill("nope.", "#FFD0EE", "#A3166F", 30, "10px 16px 13px", "18px", -4)),
    "brb": (100, 80, 0, None,
            pill("brb", "#CFE6FB", "#1E3F7A", 30, "12px 16px 14px", "999px", 6)),
}


def render(out_dir: pathlib.Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, (w, h, rot, filt, html) in STICKERS.items():
            style = (
                f"position:absolute;left:{PAD}px;top:{PAD}px;width:{w}px;height:{h}px;"
                f"transform:rotate({rot}deg);{filt or ''}"
            )
            page = pathlib.Path(tmp) / f"{name}.html"
            page.write_text(
                f"<!doctype html><html><head><meta charset='utf-8'>{FONTS}"
                "<style>html,body{margin:0;background:transparent}</style></head>"
                f"<body><div style=\"{style}\">{html}</div></body></html>"
            )
            target = out_dir / f"{name}.png"
            subprocess.run(
                [
                    CHROME,
                    "--headless",
                    "--disable-gpu",
                    "--hide-scrollbars",
                    f"--force-device-scale-factor={SCALE}",
                    "--default-background-color=00000000",
                    "--virtual-time-budget=4000",
                    f"--window-size={w + 2 * PAD},{h + 2 * PAD}",
                    f"--screenshot={target}",
                    page.as_uri(),
                ],
                check=True,
                capture_output=True,
            )
            print(f"{name}: {target.stat().st_size // 1024} KB")


if __name__ == "__main__":
    render(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/design_stickers"))
