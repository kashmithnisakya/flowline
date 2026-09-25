"""The Overview's "Needs someone now" as the tour draws it: a tinted pill per
reason (overdue, blocked, waiting on review), each over its task, with the
person, the reason and the step badge. Sample data."""

import from ..common.Avatar { Avatar }
import from ..common.StepBadge { StepBadge }

glob NEEDS: list[dict[str, str]] = [
         {
             "label": "Overdue",
             "tone": "bg-destructive/10 text-destructive",
             "title": "Lighthouse score to 95",
             "who": "Leo Martins",
             "note": "Marketing site · 1 day overdue",
             "step": "Build",
             "kind": "active",
             "color": "indigo"
         },
         {
             "label": "Blocked",
             "tone": "bg-destructive/10 text-destructive",
             "title": "Crash when rotating on Android 14",
             "who": "Kasun Silva",
             "note": "Waiting on a Pixel 8 to test on",
             "step": "Build",
             "kind": "active",
             "color": "indigo"
         },
         {
             "label": "Waiting on review",
             "tone": "bg-bg-surface text-text-secondary",
             "title": "Webhook for cancelled subscriptions",
             "who": "Priya Raman",
             "note": "Reviewer Dev Fernando · PR #412",
             "step": "Review",
             "kind": "handoff",
             "color": "rose"
         }
     ];

def:pub TourNeeds -> JsxElement {
    return
        <div className="grid content-start gap-3">
            <h4 className="text-sm font-semibold">Needs someone now</h4>
            {for n in NEEDS {
                <div key={n["label"]} role="group" aria-label={n["label"]}>
                    <span
                        className={"inline-flex h-6 items-center rounded-full px-2.5 text-xs font-semibold "
                            + n["tone"]}
                    >
                        {n["label"]}
                    </span>
                    <div className="mt-1.5 flex items-center gap-3">
                        <Avatar name={n["who"]} size="md"/>
                        <span className="grid min-w-0 flex-1">
                            <span className="truncate text-sm font-medium">
                                {n["title"]}
                            </span>
                            <span className="truncate text-xs text-muted-foreground">
                                {n["note"]}
                            </span>
                        </span>
                        <span className="hidden shrink-0 sm:flex">
                            <StepBadge
                                name={n["step"]}
                                color={n["color"]}
                                kind={n["kind"]}
                                size="sm"
                            />
                        </span>
                    </div>
                </div>
            }}
        </div>;
}
