"""The Overview's worklist: what needs someone now, grouped by why. The page
builds each group (key, label, tone, rows, more, moreLabel) and each row (id,
title, meta, note, noteWarn, names, time, late, step). `placeholder` draws
skeleton groups shaped like the last visit (`placeholderRows`)."""

import from "@jac/runtime" { Link }
import from .Panel { Panel, PANEL_LINK }
import from .NeedsGroup { NeedsGroup }
import from ..ui.skeleton { Skeleton }

def Placeholder(rows: int) -> JsxElement {
    return
        <div>
            <div className="px-4 pt-2.5 pb-1">
                <Skeleton className="h-3 w-20"/>
            </div>
            {for i in range(rows) {
                <div
                    key={str(i)}
                    className="flex min-h-11 items-center gap-3 border-b border-border-subtle px-4 py-2 last:border-b-0"
                >
                    <Skeleton className="size-3.5 shrink-0 rounded-full"/>
                    <div className="flex-1 space-y-1.5">
                        <Skeleton
                            className={"h-3.5 " + ("w-3/5" if i % 2 else "w-2/5")}
                        />
                        <Skeleton className="h-3 w-24"/>
                    </div>
                    <Skeleton className="size-6 shrink-0 rounded-md"/>
                    <Skeleton className="h-3 w-10"/>
                </div>
            }}
        </div>;
}

def:pub NeedsYou(
    groups: list[dict[str, any]],
    pending: bool = False,
    failNote: str = "",
    onRetry: any = None,
    placeholder: bool = False,
    placeholderRows: list[int] | None = None
) -> JsxElement {
    link = <Link to="/board" className={PANEL_LINK}>Open the board</Link>;
    return
        <Panel
            id="needs-you"
            title="Needs someone now"
            aside={link}
            busy={placeholder}
            flush={True}
        >
            {for (gi, n) in enumerate(
                (placeholderRows or [4]) if placeholder else []
            ) {
                <Placeholder key={"ph" + str(gi)} rows={n}/>
            }}
            {for g in groups {
                <NeedsGroup key={g["key"]} group={g}/>
            }}
            {if failNote {
                <p
                    key="fail"
                    className="px-4 py-3 text-[13px] text-text-secondary"
                    role="status"
                >
                    {failNote + " "}
                    {if onRetry {
                        <button
                            key="retry"
                            type="button"
                            className={PANEL_LINK}
                            onClick={lambda { onRetry(); }}
                        >
                            Try again
                        </button>
                    }}
                </p>
            }}
            {if len(groups) == 0 and not failNote and not placeholder {
                <p key="clear" className="px-4 py-3 text-[13px] text-text-secondary">
                    {"Checking what is due this week."
                        if pending
                        else "Nothing is overdue, blocked, waiting on review or due this week."}
                </p>
            }}
        </Panel>;
}
