"""standup brand mark — the single source of truth for the logo.

The mark is a rising bar chart (a standup that trends up) with an ember
status dot over the tallest bar. Run this to regenerate every variant:

    jac run brand/logo.jac

It writes SVGs into assets/brand/. Commit the output so the frontend can
reference plain static paths, and re-run this whenever the palette moves.
"""

import os;


# --- brand palette (see PLAN.md; mirrors styles/global.css) -----------------

glob INK: str = "#14120F";
glob PAPER: str = "#F6F2EB";
glob EMBER: str = "#E8552F";

glob OUT_DIR: str = "assets/brand";

# Bar geometry on the 56x56 tile: (x, y, height).
glob BARS: list[tuple] = [(12.0, 34.0, 12.0), (24.5, 27.0, 19.0), (37.0, 20.0, 26.0)];
glob BAR_W: float = 7.0;
glob BAR_R: float = 3.5;
glob TILE: float = 56.0;
glob TILE_R: float = 16.0;
glob DOT_R: float = 4.5;


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
    tile_fill = tile if tile else INK;
    bars_fill = bar_fill if bar_fill else PAPER;
    dot = accent if accent else EMBER;
    (last_x, last_y, last_h) = BARS[-1];
    cx = last_x + BAR_W / 2;
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {TILE} {TILE}" '
        f'width="{size}" height="{size}" fill="none">'
        f'\n    <title>standup</title>'
        f'\n    <rect x="0" y="0" width="{TILE}" height="{TILE}" '
        f'rx="{TILE_R}" fill="{tile_fill}"/>'
        f'{_bars(bars_fill, dot)}'
        f'\n    <circle cx="{cx}" cy="12" r="{DOT_R}" fill="{dot}"/>'
        f'\n</svg>\n'
    );
}


# Full lockup: the mark plus the `standup` wordmark and trailing dot.
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
        f'\n    <title>standup</title>'
        f'\n    <rect x="0" y="0" width="{TILE}" height="{TILE}" '
        f'rx="{TILE_R}" fill="{tile_fill}"/>'
        f'{_bars(bars_fill, EMBER)}'
        f'\n    <circle cx="{cx}" cy="12" r="{DOT_R}" fill="{EMBER}"/>'
        f'\n    <text x="70" y="38" font-family="\'Bricolage Grotesque\','
        f"'Helvetica Neue',sans-serif\" font-size="
        f'"30" font-weight="700" letter-spacing="-1.2" fill="{text_fill}">standup</text>'
        f'\n    <circle cx="221" cy="34" r="4" fill="{EMBER}"/>'
        f'\n</svg>\n'
    );
}


def _write(name: str, body: str) -> None {
    path = os.path.join(OUT_DIR, name);
    with open(path, "w") as fh {
        fh.write(body);
    }
    print(f"  wrote {path} ({len(body)} bytes)");
}


with entry:__main__ {
    os.makedirs(OUT_DIR, exist_ok=True);
    print("standup brand assets ->");
    _write("logo-mark.svg", mark(size=64));
    _write("logo-mark-dark.svg", mark(size=64, tile=PAPER, bar_fill=INK, accent=EMBER));
    _write("logo-full.svg", wordmark(width=240));
    _write("logo-full-dark.svg", wordmark(width=240, dark=True));
    _write("favicon.svg", mark(size=32));
    print("done.");
}
