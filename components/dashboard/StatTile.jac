"""A single headline number with its label and an optional hint line."""

import from ..ui.card { Card, CardContent }

def:pub StatTile(label: str, value: str, hint: str = "") -> JsxElement {
    <Card className="gap-0 py-4">
        <CardContent className="px-4">
            <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                {label}
            </div>
            <div className="font-display text-3xl font-bold tracking-tight">{value}</div>
            {if hint {
                <div className="text-xs text-muted-foreground">{hint}</div>
            }}
        </CardContent>
    </Card>
}
