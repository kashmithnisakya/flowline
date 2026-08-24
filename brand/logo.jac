"""flowline brand mark, the single source of truth for the logo: a rising bar
chart with an ember status dot. `jac run brand/logo.jac` regenerates every
SVG and PNG/JPG variant into assets/brand/; commit the output.
"""

import os;
import from PIL { Image, ImageDraw }


# --- brand palette (see PLAN.md; mirrors styles/global.css) -----------------

glob INK: str = "#14120F",
     PAPER: str = "#F6F2EB",
     EMBER: str = "#E8552F",
     OUT_DIR: str = "assets/brand",
     BARS: list[tuple[float, float, float]] = [
         (12.0, 34.0, 12.0),
         (24.5, 27.0, 19.0),
         (37.0, 20.0, 26.0)
     ],
     BAR_W: float = 7.0,
     BAR_R: float = 3.5,
     TILE: float = 56.0,
     TILE_R: float = 16.0,
     DOT_R: float = 4.5;


# Bar geometry on the 56x56 tile: (x, y, height).
# The three ascending bars; the tallest carries the accent colour.
def _bars(bar_fill: str, accent: str) -> str {
    out = "";
    for (i, bar) in enumerate(BARS) {
        (x, y, h) = bar;
        fill = accent if i == len(BARS) - 1 else bar_fill;
        out += (
            f'\n    <rect x="{x}" y="{y}" width="{BAR_W}" height="{h}" '
            f'rx="{BAR_R}" fill="{fill}"/>'
        );
    }
    return out;
}


# Square app icon: rounded tile, bars, and the status dot.
def mark(size: int = 64, tile: str = "", bar_fill: str = "", accent: str = "") -> str {
    tile_fill = tile or INK;
    bars_fill = bar_fill or PAPER;
    dot = accent or EMBER;
    (last_x, last_y, last_h) = BARS[-1];
    cx = last_x + BAR_W / 2;
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {TILE} {TILE}" '
        f'width="{size}" height="{size}" fill="none">'
        f'\n    <title>flowline</title>'
        f'\n    <rect x="0" y="0" width="{TILE}" height="{TILE}" '
        f'rx="{TILE_R}" fill="{tile_fill}"/>'
        f'{_bars(bars_fill, dot)}'
        f'\n    <circle cx="{cx}" cy="12" r="{DOT_R}" fill="{dot}"/>'
        f'\n</svg>\n'
    );
}


# Full lockup: the mark plus the `flowline` wordmark and trailing dot.
def wordmark(width: int = 240, dark: bool = False) -> str {
    tile_fill = PAPER if dark else INK;
    bars_fill = INK if dark else PAPER;
    text_fill = PAPER if dark else INK;
    (last_x, last_y, last_h) = BARS[-1];
    cx = last_x + BAR_W / 2;
    height = int(width * 64 / 240);
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 64" '
        f'width="{width}" height="{height}" fill="none">'
        f'\n    <title>flowline</title>'
        f'\n    <rect x="0" y="0" width="{TILE}" height="{TILE}" '
        f'rx="{TILE_R}" fill="{tile_fill}"/>'
        f'{_bars(bars_fill, EMBER)}'
        f'\n    <circle cx="{cx}" cy="12" r="{DOT_R}" fill="{EMBER}"/>'
        # textLength pins the rendered text width: SVGs loaded via <img>
        # cannot fetch webfonts, and without it the fallback font's metrics
        # move the wordmark's end away from the fixed-position trailing dot.
        f'\n    <text x="70" y="38" font-family="\'Bricolage Grotesque\','
        f"'Helvetica Neue',sans-serif\" font-size="
        f'"30" font-weight="700" letter-spacing="-1.2" textLength="112" '
        f'lengthAdjust="spacingAndGlyphs" fill="{text_fill}">flowline</text>'
        f'\n    <circle cx="193" cy="34" r="4" fill="{EMBER}"/>'
        f'\n</svg>\n'
    );
}


def _write(name: str, body: str) {
    path = os.path.join(OUT_DIR, name);
    with open(path, "w") as fh {
        fh.write(body);
    }
    print(f"  wrote {path} ({len(body)} bytes)");
}


# Draw the mark with Pillow from the same geometry the SVGs use,
# supersampled 4x then downscaled for smooth edges.
def _draw_mark(size: int) -> Image.Image {
    ss = 4;
    s = size * ss / TILE;
    px = size * ss;
    img = Image.new("RGBA", (px, px), (0, 0, 0, 0));
    draw = ImageDraw.Draw(img);
    draw.rounded_rectangle([0, 0, px, px], radius=TILE_R * s, fill=INK);
    for (i, bar) in enumerate(BARS) {
        (x, y, h) = bar;
        fill = EMBER if i == len(BARS) - 1 else PAPER;
        draw.rounded_rectangle(
            [x * s, y * s, (x + BAR_W) * s, (y + h) * s], radius=BAR_R * s, fill=fill,
        );
    }
    (last_x, last_y, last_h) = BARS[-1];
    cx = (last_x + BAR_W / 2) * s;
    cy = 12 * s;
    r = DOT_R * s;
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=EMBER);
    return img.resize((size, size), Image.Resampling.LANCZOS);
}


def _write_png(name: str, size: int) {
    path = os.path.join(OUT_DIR, name);
    _draw_mark(size).save(path);
    print(f"  wrote {path} ({os.path.getsize(path)} bytes)");
}


# JPEG has no alpha channel, so flatten onto PAPER first.
def _write_jpg(name: str, size: int) {
    path = os.path.join(OUT_DIR, name);
    img = _draw_mark(size);
    flat = Image.new("RGB", img.size, PAPER);
    flat.paste(img, (0, 0), img);
    flat.save(path, quality=90);
    print(f"  wrote {path} ({os.path.getsize(path)} bytes)");
}


with entry:__main__ {
    os.makedirs(OUT_DIR, exist_ok=True);
    print("flowline brand assets ->");
    _write("logo-mark.svg", mark(size=64));
    _write("logo-mark-dark.svg", mark(size=64, tile=PAPER, bar_fill=INK, accent=EMBER));
    _write("logo-full.svg", wordmark(width=240));
    _write("logo-full-dark.svg", wordmark(width=240, dark=True));
    _write("favicon.svg", mark(size=32));
    _write_png("logo-mark.png", size=512);
    _write_jpg("logo-mark.jpg", size=512);
    print("done.");
}
