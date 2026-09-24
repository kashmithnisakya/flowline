"""The line under the timeline: tasks with no dates and where to give them
some (the task sheet on the board), a cut-off note, and how to read a bar."""

import from "@jac/runtime" { Link }

def:pub RoadmapNotes(unscheduled: int, truncated: bool, shown: int) -> JsxElement {
    return
        <div
            className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground"
        >
            {if unscheduled > 0 {
                <span key="unscheduled">
                    {(
                        "1 open task has"
                            if unscheduled == 1
                            else str(unscheduled) + " open tasks have"
                    )
                        + " no dates. Dates are set in the task sheet on the "}
                    <Link
                        to="/board"
                        className="font-medium text-foreground underline underline-offset-4 hover:decoration-2"
                    >
                        board
                    </Link>
                    .
                </span>
            }}
            {if truncated {
                <span key="truncated">
                    {"Showing the first " + str(shown) + " scheduled tasks."}
                </span>
            }}
            <span className="text-subtle sm:ml-auto">
                A bar runs from start to due date. Hatched is blocked.
            </span>
        </div>;
}
