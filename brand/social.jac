"""The link preview card (og:image): the route mark, the landing headline and a
flow line strip. `jac run --no-takeover brand/social.jac` writes
assets/brand/og-image.png at 1200x630 with the fonts from the client's
node_modules, so run `jac install` (or boot the app once) first.
"""

import os;
import from PIL { Image, ImageDraw, ImageFont }

glob SCALE: int = 4,
     WIDTH: int = 1200,
     HEIGHT: int = 630,
     OUT_PATH: str = "assets/brand/og-image.png",
     FONT_DIR: str = ".jac/client/node_modules/@fontsource-variable/archivo/files",
     MONO_DIR: str = ".jac/client/node_modules/@fontsource/ibm-plex-mono/files",
     GROUND: str = "#F2F3F1",
     CARD: str = "#FFFFFF",
     BORDER: str = "#D3D8D2",
     INK: str = "#161A18",
     MUTED: str = "#4F5753",
     SUBTLE: str = "#636B67",
     WIRE: str = "#6F7672",
     MARK: str = "#D9530F",
     HEADLINE: list[str] = [
         "Draw how your team works.",
         "The board and the daily",
         "log follow."
     ],
     STEPS: list[tuple[str, str]] = [
         ("Specify", "#2E6C97"),
         ("Build", "#5550AC"),
         ("Review", "#A34B83"),
         ("Done", "#387A51")
     ];

# Archivo at a weight and width, sized in output pixels.
def archivo(size: int, weight: int, width: int) -> any {
    font = ImageFont.truetype(
        os.path.join(FONT_DIR, "archivo-latin-wdth-normal.woff2"), size * SCALE
    );
    font.set_variation_by_axes([weight, width]);
    return font;
}

def mono(size: int) -> any {
    return ImageFont.truetype(
        os.path.join(MONO_DIR, "ibm-plex-mono-latin-400-normal.woff2"), size * SCALE
    );
}

def px(v: float) -> int {
    return int(round(v * SCALE));
}

# The route mark on its 24-unit grid, drawn at `unit` pixels per grid unit.
# Pillow strokes a ring or arc inside its box, so boxes grow by half a stroke,
# and dots at each joint stand in for the round caps Pillow lines lack.
def draw_mark(draw: any, ox: float, oy: float, unit: float) {
    stroke = 2.2;
    width = max(1, px(stroke * unit));
    def at(x: float, y: float) -> tuple[int, int] {
        return (px(ox + x * unit), px(oy + y * unit));
    }
    def box(cx: float, cy: float, r: float) -> list[int] {
        (x0, y0) = at(cx - r, cy - r);
        (x1, y1) = at(cx + r, cy + r);
        return [x0, y0, x1, y1];
    }
    half = stroke / 2;
    draw.ellipse(box(5.0, 17.0, 3.0 + half), outline=MARK, width=width);
    draw.line([at(8.0, 17.0), at(11.5, 17.0)], fill=MARK, width=width);
    draw.arc(box(11.5, 14.0, 3.0 + half), start=0, end=90, fill=MARK, width=width);
    draw.line([at(14.5, 14.0), at(14.5, 10.0)], fill=MARK, width=width);
    draw.arc(box(17.5, 10.0, 3.0 + half), start=180, end=240, fill=MARK, width=width);
    for (cx, cy) in [
        (8.0, 17.0),
        (11.5, 17.0),
        (14.5, 14.0),
        (14.5, 10.0),
        (16.0, 7.4)
    ] {
        draw.ellipse(box(cx, cy, half), fill=MARK);
    }
    draw.ellipse(box(19.0, 7.0, 3.0), fill=MARK);
}

def render {
    img = Image.new("RGB", (WIDTH * SCALE, HEIGHT * SCALE), GROUND);
    draw = ImageDraw.Draw(img);
    left = 72.0;
    draw_mark(draw, left, 56.0, 1.75);
    draw.text(
        (px(left + 50), px(60)), "flowline", font=archivo(30, 800, 125), fill=INK
    );
    head = archivo(62, 800, 125);
    y = 150.0;
    for line in HEADLINE {
        draw.text((px(left), px(y)), line, font=head, fill=INK);
        y += 72.0;
    }
    # The flow line strip: node boxes with a swatch, wires with arrowheads.
    label = archivo(22, 600, 100);
    x = left;
    top = 418.0;
    for (i, (name, color)) in enumerate(STEPS) {
        text_w = draw.textlength(name, font=label) / SCALE;
        w = text_w + 50.0;
        draw.rounded_rectangle(
            [px(x), px(top), px(x + w), px(top + 48)],
            radius=px(5),
            fill=CARD,
            outline=BORDER,
            width=px(1.5)
        );
        draw.rounded_rectangle(
            [px(x + 16), px(top + 19), px(x + 27), px(top + 30)],
            radius=px(2),
            fill=color
        );
        draw.text((px(x + 36), px(top + 10)), name, font=label, fill=INK);
        x += w;
        if i < len(STEPS) - 1 {
            draw.line(
                [(px(x), px(top + 24)), (px(x + 30), px(top + 24))],
                fill=WIRE,
                width=px(2)
            );
            draw.polygon(
                [
                    (px(x + 30), px(top + 18)),
                    (px(x + 40), px(top + 24)),
                    (px(x + 30), px(top + 30))
                ],
                fill=WIRE
            );
            x += 40.0;
        }
    }
    draw.text(
        (px(left), px(532)),
        "Open source, MIT licensed. The board and the log follow your steps.",
        font=mono(21),
        fill=MUTED
    );
    out = img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS);
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True);
    out.save(OUT_PATH, optimize=True);
    print(f"wrote {OUT_PATH}");
}

with entry {
    render();
}
