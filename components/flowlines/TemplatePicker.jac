"""First-run gallery: pick how the team moves work. Previews render from
FLOW_LINE_TEMPLATES itself, so they cannot drift from what ApplyTemplate seeds.
Each thumbnail's viewBox comes from its own step extents, and the curve math is
a thumb-scale copy of geometry.wire() so previews read like the real canvas."""

import from ...constants { FLOW_LINE_TEMPLATES }
import from .geometry { NODE_W, NODE_H }
import from .kinds { TEXT_FILL, colorKey }
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent }
import from ..common.glyphs { Spinner }

# Preview canvas: template px scaled down to a card-sized thumbnail.
glob THUMB_SCALE: float = 0.2,
     THUMB_PAD: float = 8.0;


# The svg viewBox for one template, sized from its step extents. Explicit
# loop rather than max(): max() over a list compiles to Math.max(array),
# which is NaN.
def thumbBox(t: dict[str, any]) -> str {
    raws: list[dict[str, any]] = t["steps"];
    maxX = 0.0;
    maxY = 0.0;
    for s in raws {
        if s["x"] > maxX {
            maxX = s["x"];
        }
        if s["y"] > maxY {
            maxY = s["y"];
        }
    }
    w = (maxX + NODE_W) * THUMB_SCALE + THUMB_PAD * 2.0;
    h = (maxY + NODE_H) * THUMB_SCALE + THUMB_PAD * 2.0;
    return "0 0 " + str(w) + " " + str(h);
}


# Render-ready node rects, materialised through typed locals, the checker
# cannot subscript the template's nested `any` values inside JSX.
def thumbRects(t: dict[str, any]) -> list[dict[str, any]] {
    raws: list[dict[str, any]] = t["steps"];
    out: list[dict[str, any]] = [];
    for (i, s) in enumerate(raws) {
        out.append(
            {
                "key": "n" + str(i),
                "x": s["x"] * THUMB_SCALE + THUMB_PAD,
                "y": s["y"] * THUMB_SCALE + THUMB_PAD,
                "w": NODE_W * THUMB_SCALE,
                "h": NODE_H * THUMB_SCALE,
                "tone": TEXT_FILL[colorKey(s["color"])]
            }
        );
    }
    return out;
}


# Curved, directed edges at thumbnail scale: same facing-border layout and
# two-way sideways shift as geometry.wire(), with a small arrowhead.
def thumbLinks(t: dict[str, any]) -> list[dict[str, any]] {
    raws: list[dict[str, any]] = t["steps"];
    pairs: list[list[int]] = t["links"];
    nw = NODE_W * THUMB_SCALE;
    nh = NODE_H * THUMB_SCALE;
    seen: dict[str, bool] = {};
    for pair in pairs {
        seen[str(pair[0]) + ">" + str(pair[1])] = True;
    }
    out: list[dict[str, any]] = [];
    for (i, pair) in enumerate(pairs) {
        a = raws[pair[0]];
        b = raws[pair[1]];
        ax = a["x"] * THUMB_SCALE + THUMB_PAD;
        ay = a["y"] * THUMB_SCALE + THUMB_PAD;
        bx = b["x"] * THUMB_SCALE + THUMB_PAD;
        by = b["y"] * THUMB_SCALE + THUMB_PAD;
        dx = bx - ax;
        dy = by - ay;
        adx = dx if dx >= 0.0 else 0.0 - dx;
        ady = dy if dy >= 0.0 else 0.0 - dy;
        horizontal = adx >= ady;
        twoWay = (str(pair[1]) + ">" + str(pair[0])) in seen;
        # A name first assigned inside a branch is block-scoped in the
        # compiled JS, so everything the branches write starts here.
        sx = 0.0;
        sy = 0.0;
        ex = 0.0;
        ey = 0.0;
        h1x = 0.0;
        h1y = 0.0;
        h2x = 0.0;
        h2y = 0.0;
        a1x = 0.0;
        a1y = 0.0;
        a2x = 0.0;
        a2y = 0.0;
        dirn = 1.0;
        shift = 0.0;
        if horizontal {
            dirn = 1.0 if dx >= 0.0 else -1.0;
            if twoWay {
                shift = -2.5 if dx >= 0.0 else 2.5;
            }
            sx = ax + nw if dx >= 0.0 else ax;
            sy = ay + nh / 2.0 + shift;
            ex = bx if dx >= 0.0 else bx + nw;
            ey = by + nh / 2.0 + shift;
            span = ex - sx;
            if span < 0.0 {
                span = 0.0 - span;
            }
            bend = span * 0.45;
            if bend < 7.0 {
                bend = 7.0;
            }
            if bend > 24.0 {
                bend = 24.0;
            }
            h1x = sx + bend * dirn;
            h1y = sy;
            h2x = ex - bend * dirn;
            h2y = ey;
            a1x = ex - 4.0 * dirn;
            a1y = ey - 2.4;
            a2x = ex - 4.0 * dirn;
            a2y = ey + 2.4;
        } else {
            dirn = 1.0 if dy >= 0.0 else -1.0;
            if twoWay {
                shift = -2.5 if dy >= 0.0 else 2.5;
            }
            sy = ay + nh if dy >= 0.0 else ay;
            sx = ax + nw / 2.0 + shift;
            ey = by if dy >= 0.0 else by + nh;
            ex = bx + nw / 2.0 + shift;
            span = ey - sy;
            if span < 0.0 {
                span = 0.0 - span;
            }
            bend = span * 0.45;
            if bend < 7.0 {
                bend = 7.0;
            }
            if bend > 24.0 {
                bend = 24.0;
            }
            h1x = sx;
            h1y = sy + bend * dirn;
            h2x = ex;
            h2y = ey - bend * dirn;
            a1x = ex - 2.4;
            a1y = ey - 4.0 * dirn;
            a2x = ex + 2.4;
            a2y = ey - 4.0 * dirn;
        }
        d = (
            "M " + str(sx) + " " + str(sy) + " C " + str(h1x) + " " + str(h1y) + ", " + str(
                h2x
            ) + " " + str(h2y) + ", " + str(ex) + " " + str(ey)
        );
        arrow = (
            "M " + str(ex) + " " + str(ey) + " L " + str(a1x) + " " + str(a1y) + " L " + str(
                a2x
            ) + " " + str(a2y) + " Z"
        );
        out.append({"key": "l" + str(i), "d": d, "arrow": arrow});
    }
    return out;
}


def:pub TemplatePicker(
    applying: str = "",
    onPick: Callable[[str], None] = None,
    onScratch: Callable[[], None] = None
) -> JsxElement {
    return
        <div className="flex w-full flex-col gap-8">
            <div className="flex flex-col items-center gap-2 pt-6 text-center">
                <h2 className="font-display text-2xl font-semibold tracking-tight">
                    How does your team move work?
                </h2>
                <p className="max-w-md text-sm text-muted-foreground">
                    Start from a template or design your own. You can reshape everything later, steps, names, connections, loops.
                </p>
            </div>
            <div
                className="grid gap-4"
                style={{
                    "gridTemplateColumns": "repeat(auto-fit, minmax(min(16rem, 100%), 1fr))"
                }}
            >
                {for t in FLOW_LINE_TEMPLATES {
                    <Card
                        key={t["key"]}
                        className={"group flex flex-col card-hover hover:ring-foreground/20 transition-opacity" + (
                            " opacity-60"
                                if applying != "" and applying != t["key"]
                                else ""
                        )}
                    >
                        <CardContent className="flex flex-1 flex-col gap-3 py-4">
                            <div
                                className="flex items-center justify-center overflow-hidden rounded-lg bg-muted/40 p-2 transition-transform duration-200 group-hover:scale-[1.02]"
                            >
                                <svg
                                    viewBox={thumbBox(t)}
                                    preserveAspectRatio="xMidYMid meet"
                                    className="h-20 w-full"
                                >
                                    {for l in thumbLinks(t) {
                                        <g
                                            key={l["key"]}
                                            className="text-muted-foreground/60"
                                        >
                                            <path
                                                d={l["d"]}
                                                fill="none"
                                                stroke="currentColor"
                                                strokeWidth={1.25}
                                                strokeLinecap="round"
                                                vectorEffect="non-scaling-stroke"
                                            />
                                            <path
                                                d={l["arrow"]}
                                                fill="currentColor"
                                                stroke="none"
                                            />
                                        </g>
                                    }}
                                    {for n in thumbRects(t) {
                                        <rect
                                            key={n["key"]}
                                            x={n["x"]}
                                            y={n["y"]}
                                            width={n["w"]}
                                            height={n["h"]}
                                            rx={3}
                                            className={n["tone"]}
                                            fill="currentColor"
                                            fillOpacity={0.18}
                                            stroke="currentColor"
                                            strokeWidth={1.25}
                                            vectorEffect="non-scaling-stroke"
                                        />
                                    }}
                                </svg>
                            </div>
                            <div className="flex-1 space-y-1">
                                <h3 className="font-display text-sm font-semibold">
                                    {t["name"]}
                                </h3>
                                <p className="text-xs text-muted-foreground">
                                    {t["description"]}
                                </p>
                            </div>
                            <Button
                                variant="outline"
                                disabled={bool(applying)}
                                onClick={lambda { if onPick { onPick(t["key"]); }}}
                            >
                                {if applying == t["key"] {
                                    <Spinner key="sp"/>
                                }}
                                {"Setting up…"
                                    if applying == t["key"]
                                    else "Use template"}
                            </Button>
                        </CardContent>
                    </Card>
                }}
                <Card
                    key="scratch"
                    className={"group flex flex-col card-hover hover:ring-foreground/20 transition-opacity" + (
                        " opacity-60" if applying != "" else ""
                    )}
                >
                    <CardContent className="flex flex-1 flex-col gap-3 py-4">
                        <div
                            className="flex items-center justify-center overflow-hidden rounded-lg bg-muted/40 p-2 transition-transform duration-200 group-hover:scale-[1.02]"
                        >
                            <svg
                                viewBox="0 0 204 66"
                                preserveAspectRatio="xMidYMid meet"
                                className="h-20 w-full"
                            >
                                <rect
                                    x={72}
                                    y={10}
                                    width={60}
                                    height={46}
                                    rx={9}
                                    className="text-muted-foreground/60"
                                    stroke="currentColor"
                                    strokeWidth={1.5}
                                    strokeDasharray="4 4"
                                    fill="none"
                                />
                                <path
                                    d="M 102 24 V 42 M 93 33 H 111"
                                    className="text-muted-foreground/60"
                                    stroke="currentColor"
                                    strokeWidth={1.5}
                                    strokeLinecap="round"
                                    fill="none"
                                />
                            </svg>
                        </div>
                        <div className="flex-1 space-y-1">
                            <h3 className="font-display text-sm font-semibold">
                                Start from scratch
                            </h3>
                            <p className="text-xs text-muted-foreground">
                                A blank canvas. Add steps and connect them yourself.
                            </p>
                        </div>
                        <Button
                            variant="outline"
                            disabled={bool(applying)}
                            onClick={lambda { if onScratch { onScratch(); }}}
                        >
                            Open designer
                        </Button>
                    </CardContent>
                </Card>
            </div>
            <p className="text-center text-xs text-muted-foreground">
                Templates seed the steps and connections, then open the designer.
            </p>
        </div>;
}
