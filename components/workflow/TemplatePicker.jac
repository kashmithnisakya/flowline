"""First-run gallery: pick how the team moves work.

The mini previews are rendered from WORKFLOW_TEMPLATES itself, the same
data ApplyTemplate seeds from, so a preview can never drift from what
actually gets created. Everything is editable after choosing; the choice is
a starting point, not a commitment.
"""

import from ...constants { WORKFLOW_TEMPLATES }
import from .geometry { NODE_W, NODE_H }
import from .kinds { TEXT_FILL, colorKey }
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent }

# Preview canvas: template px scaled down to a card-sized thumbnail.
glob THUMB_SCALE: float = 0.2,
     THUMB_PAD: float = 6.0;


def thumbX(raw: dict[str, any]) -> float {
    return (raw["x"] + NODE_W / 2.0) * THUMB_SCALE + THUMB_PAD;
}


def thumbY(raw: dict[str, any]) -> float {
    return (raw["y"] + NODE_H / 2.0) * THUMB_SCALE + THUMB_PAD;
}


# Render-ready thumbnail data, materialised through typed locals, the
# checker cannot subscript the template's nested `any` values inside JSX.
def thumbLinks(t: dict[str, any]) -> list[dict[str, any]] {
    raws: list[dict[str, any]] = t["steps"];
    pairs: list[list[int]] = t["links"];
    out: list[dict[str, any]] = [];
    for (i, pair) in enumerate(pairs) {
        a = raws[pair[0]];
        b = raws[pair[1]];
        out.append(
            {
                "key": "l" + str(i),
                "x1": thumbX(a),
                "y1": thumbY(a),
                "x2": thumbX(b),
                "y2": thumbY(b)
            }
        );
    }
    return out;
}


def thumbDots(t: dict[str, any]) -> list[dict[str, any]] {
    raws: list[dict[str, any]] = t["steps"];
    out: list[dict[str, any]] = [];
    for (i, s) in enumerate(raws) {
        out.append(
            {
                "key": "c" + str(i),
                "cx": thumbX(s),
                "cy": thumbY(s),
                "tone": TEXT_FILL[colorKey(s["color"])]
            }
        );
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
                {for t in WORKFLOW_TEMPLATES {
                    <Card key={t["key"]} className="flex flex-col">
                        <CardContent className="flex flex-1 flex-col gap-3 py-4">
                            <div
                                className="flex items-center justify-center rounded-md bg-muted/40 py-2"
                            >
                                <svg width={204} height={66}>
                                    {for l in thumbLinks(t) {
                                        <line
                                            key={l["key"]}
                                            x1={l["x1"]}
                                            y1={l["y1"]}
                                            x2={l["x2"]}
                                            y2={l["y2"]}
                                            className="text-muted-foreground/50"
                                            stroke="currentColor"
                                            strokeWidth={1.5}
                                        />
                                    }}
                                    {for d in thumbDots(t) {
                                        <circle
                                            key={d["key"]}
                                            cx={d["cx"]}
                                            cy={d["cy"]}
                                            r={6}
                                            className={d["tone"]}
                                            fill="currentColor"
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
                                {"Setting up…"
                                    if applying == t["key"]
                                    else "Use template"}
                            </Button>
                        </CardContent>
                    </Card>
                }}
                <Card key="scratch" className="flex flex-col">
                    <CardContent className="flex flex-1 flex-col gap-3 py-4">
                        <div
                            className="flex items-center justify-center rounded-md bg-muted/40 py-2"
                        >
                            <svg width={204} height={66}>
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
