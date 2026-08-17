"""A headline number with label and optional hint. The hint line always
reserves its height so value baselines align across a row; `accent` takes a
literal text colour class for the value.
"""

import from ..ui.card { Card, CardContent }
import from ...lib.utils { cn }

def:pub StatTile(
    label: str, value: str, hint: str = "", accent: str = ""
) -> JsxElement {
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
                <div className="min-h-4 text-xs text-muted-foreground">{hint}</div>
            </CardContent>
        </Card>;
}
