"""A headline number with label, an optional week-over-week delta and an
optional sparkline. The hint line always reserves its height so value
baselines align across a row; `accent` takes a literal text colour class for
the value.
"""

import from ..ui.card { Card, CardContent }
import from ...lib.utils { cn }


# Sparkline points for a 100x24 box; a flat series draws along the bottom.
def sparkPoints(values: list[int]) -> str {
    peak = 1;
    for v in values {
        if v > peak {
            peak = v;
        }
    }
    n = len(values);
    pts: list[str] = [];
    for (i, v) in enumerate(values) {
        x = 0.0 if n < 2 else i * 100.0 / (n - 1);
        y = 22.0 - (v * 20.0 / peak);
        pts.append(str(x) + "," + str(y));
    }
    return " ".join(pts);
}


def:pub StatTile(
    label: str,
    value: str,
    hint: str = "",
    accent: str = "",
    # Week-over-week change; shown only when `showDelta` is set, since 0 is
    # a real value. `invert` flips the tone (a rise in overdue is bad).
    delta: int = 0,
    showDelta: bool = False,
    invert: bool = False,
    spark: list[int] = []
) -> JsxElement {
    up = delta > 0;
    good = (delta < 0) if invert else (delta > 0);
    tone = (
        ("text-success" if good else "text-destructive")
            if delta != 0
            else "text-muted-foreground"
    );
    hasSpark = len(spark) > 1;
    return
        <Card className="gap-0 py-4 hover:shadow-md hover:ring-foreground/20">
            <CardContent className="px-4">
                <div
                    className="text-xs font-medium uppercase tracking-wide text-muted-foreground"
                >
                    {label}
                </div>
                <div
                    className={cn(
                        "font-display text-3xl font-bold tracking-tight tabular-nums",
                        accent
                    )}
                >
                    {value}
                </div>
                <div
                    className="flex min-h-4 items-center gap-1.5 text-xs text-muted-foreground"
                >
                    {if showDelta {
                        <span
                            key="delta"
                            className={"inline-flex items-center gap-0.5 font-semibold tabular-nums " + tone}
                        >
                            {if delta != 0 {
                                <svg
                                    key="arrow"
                                    width={10}
                                    height={10}
                                    viewBox="0 0 10 10"
                                    fill="currentColor"
                                    aria-hidden="true"
                                >
                                    {if up {
                                        <path key="u" d="M5 1 9 8H1z"/>
                                    } else {
                                        <path key="d" d="M5 9 1 2h8z"/>
                                    } }
                                </svg>
                            }}
                            {("+" + str(delta))
                                if delta > 0
                                else (str(delta) if delta < 0 else "same")}
                        </span>
                    }}
                    {if showDelta {
                        <span key="vs">vs last week</span>
                    } elif hint {
                        <span key="hint">{hint}</span>
                    } }
                </div>
                {if hasSpark {
                    <svg
                        key="spark"
                        className="mt-2 block h-6 w-full text-primary"
                        viewBox="0 0 100 24"
                        preserveAspectRatio="none"
                        aria-hidden="true"
                    >
                        <polygon
                            points={"0,24 " + sparkPoints(spark) + " 100,24"}
                            fill="currentColor"
                            opacity={0.12}
                        />
                        <polyline
                            points={sparkPoints(spark)}
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={1.5}
                            strokeLinejoin="round"
                            strokeLinecap="round"
                            vectorEffect="non-scaling-stroke"
                        />
                    </svg>
                }}
            </CardContent>
        </Card>;
}
