"""This-week counts by status and category — the dashboard-lite that lets
v1 defer the full Dashboard sheet."""

import from endpoints { LogEntry }
import from ..constants { STATUSES, CATEGORIES }
import from .ui.badge { Badge }

def:pub WeekStrip(entries: list[LogEntry]) -> JsxElement {
    <div className="flex flex-wrap items-center gap-2 text-xs">
        <span className="font-medium text-muted-foreground">This week:</span>
        {for s in STATUSES {
            <Badge key={s} variant="secondary" className="font-normal">
                {s} {len([e for e in entries if e.status == s])}
            </Badge>
        }}
        <span className="mx-1 text-muted-foreground">·</span>
        {for c in CATEGORIES {
            <Badge key={c} variant="outline" className="font-normal">
                {c} {len([e for e in entries if e.category == c])}
            </Badge>
        }}
    </div>
}
