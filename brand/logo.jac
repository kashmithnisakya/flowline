"""flowline brand mark, the single source of truth for the logo: a route with an
open start node, one bend and a filled end node. `jac run --no-takeover brand/logo.jac`
regenerates every SVG and PNG/JPG variant into assets/brand/; commit the output.
The app inlines the same path in currentColor (pages/layout.jac `Mark`).
"""

import os;
import math;
import from PIL { Image, ImageDraw }


# --- brand palette (mirrors --mark, --foreground, --background) --------------

glob MARK_LIGHT: str = "#D9530F",
     MARK_DARK: str = "#F47C3F",
     INK_LIGHT: str = "#161A18",
     INK_DARK: str = "#E4E8E5",
     GROUND_LIGHT: str = "#F2F3F1",
     OUT_DIR: str = "assets/brand",
     # The route on a 24x24 grid: start node, a right-then-up bend, end node.
     START: tuple[float, float] = (5.0, 17.0),
     END: tuple[float, float] = (19.0, 7.0),
     NODE_R: float = 3.0,
     STROKE: float = 2.2,
     ROUTE: str = "M8 17h3.5a3 3 0 0 0 3-3v-4a3 3 0 0 1 1.5-2.6";


# The mark's shapes in one colour (a hex or currentColor), no ground.
def _shapes(color: str) -> str {
    (sx, sy) = START;
    (ex, ey) = END;
    return (
        f'\n    <circle cx="{sx}" cy="{sy}" r="{NODE_R}" fill="none" '
        f'stroke="{color}" stroke-width="{STROKE}"/>'
        f'\n    <path d="{ROUTE}" fill="none" stroke="{color}" '
        f'stroke-width="{STROKE}" stroke-linecap="round"/>'
        f'\n    <circle cx="{ex}" cy="{ey}" r="{NODE_R}" fill="{color}"/>'
    );
}


# The bare mark. `adaptive` embeds a prefers-color-scheme rule so an <img> or a
# favicon swaps to the brighter dark-ground colour on its own.
def mark(size: int = 64, color: str = "", adaptive: bool = False) -> str {
    fill = color or MARK_LIGHT;
    style = "";
    body = _shapes(fill);
    if adaptive {
        style = (
            f'\n    <style>.m{{color:{MARK_LIGHT}}}'
            f'@media (prefers-color-scheme: dark){{.m{{color:{MARK_DARK}}}}}</style>'
        );
        body = f'\n    <g class="m">{_shapes("currentColor")}\n    </g>';
    }
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        f'width="{size}" height="{size}" fill="none">'
        f'\n    <title>flowline</title>{style}{body}'
        f'\n</svg>\n'
    );
}


# Full lockup: the mark plus the `flowline` wordmark, for a light or dark ground.
def wordmark(width: int = 240, dark: bool = False) -> str {
    mark_fill = MARK_DARK if dark else MARK_LIGHT;
    text_fill = INK_DARK if dark else INK_LIGHT;
    height = int(width * 64 / 240);
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 64" '
        f'width="{width}" height="{height}" fill="none">'
        f'\n    <title>flowline</title>'
        f'\n    <g transform="translate(2 8) scale(2)">{_shapes(mark_fill)}\n    </g>'
        # textLength pins the rendered width: an SVG loaded through <img>
        # cannot fetch webfonts, so the fallback face must not move the end.
        f'\n    <text x="64" y="42" font-family="Archivo,\'Helvetica Neue\','
        f"Arial,sans-serif\" font-size="
        f'"30" font-weight="700" font-stretch="112%" letter-spacing="-0.3" '
        f'textLength="150" lengthAdjust="spacingAndGlyphs" '
        f'fill="{text_fill}">flowline</text>'
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


def _hex(color: str) -> tuple[int, int, int, int] {
    return (int(color[1:3], 16), int(color[3:5], 16), int(color[5:7], 16), 255);
}


# Draw the mark with Pillow from the same geometry the SVGs use, on a 24-unit
# grid inset by `pad` units, supersampled 4x then downscaled for smooth edges.
def _draw_mark(size: int, color: str, pad: float = 2.0) -> Image.Image {
    ss = 4;
    px = size * ss;
    s = px / (24.0 + 2 * pad);
    img = Image.new("RGBA", (px, px), (0, 0, 0, 0));
    draw = ImageDraw.Draw(img);
    rgba = _hex(color);
    w = max(1, int(round(STROKE * s)));

    def at(x: float, y: float) -> tuple[float, float] {
        return ((x + pad) * s, (y + pad) * s);
    }

    def dot(x: float, y: float, r: float) {
        (cx, cy) = at(x, y);
        draw.ellipse([cx - r * s, cy - r * s, cx + r * s, cy + r * s], fill=rgba);
    }

    (sx, sy) = START;
    (ex, ey) = END;
    # Start node: a ring whose stroke is centred on the node radius.
    (cx, cy) = at(sx, sy);
    outer = (NODE_R + STROKE / 2) * s;
    draw.ellipse(
        [cx - outer, cy - outer, cx + outer, cy + outer], outline=rgba, width=w
    );
    # Route: 8,17 -> 11.5,17, a quarter bend about 11.5,14 up to 14.5,14, a
    # rise to 14.5,10, then a 60 degree turn about 17.5,10 toward the end node.
    draw.line([at(8.0, 17.0), at(11.5, 17.0)], fill=rgba, width=w);
    # Pillow strokes an arc inside its box, so the box grows by half a stroke.
    ar = (3 + STROKE / 2) * s;
    (ax, ay) = at(11.5, 14.0);
    draw.arc([ax - ar, ay - ar, ax + ar, ay + ar], 0, 90, fill=rgba, width=w);
    draw.line([at(14.5, 14.0), at(14.5, 10.0)], fill=rgba, width=w);
    (tx, ty) = at(17.5, 10.0);
    draw.arc([tx - ar, ty - ar, tx + ar, ty + ar], 180, 240, fill=rgba, width=w);
    # Round caps and joins, which Pillow lines do not draw.
    cap = STROKE / 2;
    dot(8.0, 17.0, cap);
    dot(11.5, 17.0, cap);
    dot(14.5, 14.0, cap);
    dot(14.5, 10.0, cap);
    dot(
        17.5 + 3 * math.cos(math.radians(240)),
        10.0 + 3 * math.sin(math.radians(240)),
        cap
    );
    dot(ex, ey, NODE_R);
    return img.resize((size, size), Image.Resampling.LANCZOS);
}


def _write_png(name: str, size: int) {
    path = os.path.join(OUT_DIR, name);
    _draw_mark(size, MARK_LIGHT).save(path);
    print(f"  wrote {path} ({os.path.getsize(path)} bytes)");
}


# JPEG has no alpha channel, so flatten onto the light ground first.
def _write_jpg(name: str, size: int) {
    path = os.path.join(OUT_DIR, name);
    img = _draw_mark(size, MARK_LIGHT, pad=5.0);
    flat = Image.new("RGB", img.size, GROUND_LIGHT);
    flat.paste(img, (0, 0), img);
    flat.save(path, quality=90);
    print(f"  wrote {path} ({os.path.getsize(path)} bytes)");
}


with entry:__main__ {
    os.makedirs(OUT_DIR, exist_ok=True);
    print("flowline brand assets ->");
    _write("logo-mark.svg", mark(size=64, adaptive=True));
    _write("logo-mark-dark.svg", mark(size=64, color=MARK_DARK));
    _write("logo-full.svg", wordmark(width=240));
    _write("logo-full-dark.svg", wordmark(width=240, dark=True));
    _write("favicon.svg", mark(size=32, adaptive=True));
    _write_png("logo-mark.png", size=512);
    _write_jpg("logo-mark.jpg", size=512);
    print("done.");
}
