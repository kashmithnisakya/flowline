"""Review-queue and gone-quiet cards for the Overview. Rows are plain dicts
straight from the Digest snapshot (typing them as objs would drag the walkers
module into the client bundle); both cards cap at eight rows and deep-link
into the board the same way the needs-attention list does."""

import from "@jac/runtime" { Link }
import from ..ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ..ui.badge { Badge }
import from ...lib.dates { todayIso, dueLabel, dueTone }

glob SHOW_MAX: int = 8;

# A same-day handoff reads "new", not "0d".
def waitChip(days: int) -> str {
    if days <= 0 {
        return "new";
    }
    return str(days) + "d";
}

def:pub ReviewQueueCard(rows: list[dict]) -> JsxElement {
    today = todayIso();
    return
        <Card>
            <CardHeader>
                <CardTitle className="text-base">Review queue</CardTitle>
                <CardDescription>
                    Waiting on a reviewer, longest wait first.
                </CardDescription>
            </CardHeader>
            <CardContent className="space-y-1">
                {for (i, r) in enumerate(rows) {
                    if i < SHOW_MAX {
                        <Link
                            key={r["task_id"]}
                            to={"/board?task=" + r["task_id"]}
                            className="flex items-center gap-3 rounded-lg px-2 py-2 transition-colors hover:bg-accent"
                        >
                            <span
                                className="shrink-0 rounded-md bg-warning/10 px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide tabular-nums text-warning"
                            >
                                {waitChip(r["waiting_days"])}
                            </span>
                            <span
                                className="min-w-0 flex-1 truncate text-sm font-medium"
                            >
                                {r["title"]}
                            </span>
                            {if len(r["pr_link"]) > 0 {
                                <Badge key="pr" variant="secondary">PR</Badge>
                            }}
                            {if len(r["review_due"]) >= 10 {
                                <span
                                    key="due"
                                    className={"shrink-0 text-xs "
                                        + (
                                            "font-medium text-destructive"
                                                if dueTone(
                                                    r["review_due"], "Review", today
                                                )
                                                    == "overdue"
                                                else "text-muted-foreground"
                                        )}
                                >
                                    {dueLabel(r["review_due"], "Review", today)}
                                </span>
                            }}
                            <span
                                className="hidden shrink-0 text-xs text-muted-foreground sm:inline"
                            >
                                {((r["project"] + " · ") if r["project"] else "")
                                    + (
                                        r["reviewer"]
                                            if r["reviewer"]
                                            else "no reviewer"
                                    )}
                            </span>
                        </Link>
                    }
                }}
                {if len(rows) > SHOW_MAX {
                    <Link
                        key="more"
                        to="/board"
                        className="block px-2 pt-2 text-xs font-medium text-primary hover:underline"
                    >
                        {"+" + str(len(rows) - SHOW_MAX) + " more on the board"}
                    </Link>
                }}
                {if len(rows) == 0 {
                    <div
                        key="clear"
                        className="px-2 py-3 text-sm text-muted-foreground"
                    >
                        Nothing is waiting on review.
                    </div>
                }}
            </CardContent>
        </Card>;
}

def:pub GoneQuietCard(rows: list[dict]) -> JsxElement {
    return
        <Card>
            <CardHeader>
                <CardTitle className="text-base">Gone quiet</CardTitle>
                <CardDescription>
                    Open work untouched for a week or more, stalest first.
                </CardDescription>
            </CardHeader>
            <CardContent className="space-y-1">
                {for (i, r) in enumerate(rows) {
                    if i < SHOW_MAX {
                        <Link
                            key={r["task_id"]}
                            to={"/board?task=" + r["task_id"]}
                            className="flex items-center gap-3 rounded-lg px-2 py-2 transition-colors hover:bg-accent"
                        >
                            <span
                                className="shrink-0 rounded-md bg-warning/10 px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide tabular-nums text-warning"
                            >
                                {str(r["idle_days"]) + "d"}
                            </span>
                            <span
                                className="min-w-0 flex-1 truncate text-sm font-medium"
                            >
                                {r["title"]}
                            </span>
                            <Badge
                                variant="secondary"
                                className="hidden sm:inline-flex"
                            >
                                {r["status"]}
                            </Badge>
                            <span
                                className="hidden max-w-40 shrink-0 truncate text-xs text-muted-foreground sm:inline"
                            >
                                {((r["project"] + " · ") if r["project"] else "")
                                    + (
                                        r["assignees"]
                                            if r["assignees"]
                                            else "unassigned"
                                    )}
                            </span>
                        </Link>
                    }
                }}
                {if len(rows) > SHOW_MAX {
                    <Link
                        key="more"
                        to="/board"
                        className="block px-2 pt-2 text-xs font-medium text-primary hover:underline"
                    >
                        {"+" + str(len(rows) - SHOW_MAX) + " more on the board"}
                    </Link>
                }}
                {if len(rows) == 0 {
                    <div
                        key="clear"
                        className="px-2 py-3 text-sm text-muted-foreground"
                    >
                        Nothing has gone quiet. Everything open was touched this week.
                    </div>
                }}
            </CardContent>
        </Card>;
}
