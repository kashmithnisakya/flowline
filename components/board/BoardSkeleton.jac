"""The board's first-load frame: the flow line strip and one group per step
the last visit in this browser saw (rememberGroups), each with a few rows,
so the page keeps its shape while page 1 loads."""

import from ...lib.session { STEPS_KEY }
import from ..ui.skeleton { Skeleton }

glob WIDTHS: list[str] = ["w-3/5", "w-2/5", "w-1/2", "w-[45%]"];

# How many groups the next first frame draws: the step count of this load.
def:pub rememberGroups(n: int) {
    try {
        localStorage.setItem(STEPS_KEY, str(n));
    } except Exception as e {
        return;
    }
}

def guessGroups -> int {
    raw = "";
    try {
        raw = localStorage.getItem(STEPS_KEY) or "";
    } except Exception as e {
        raw = "";
    }
    n = int(raw) if raw else 5;
    return n if n >= 2 and n <= 10 else 5;
}

def:pub BoardSkeleton -> JsxElement {
    n = guessGroups();
    return
        <div className="flex flex-col gap-6" aria-busy="true">
            <Skeleton className="h-12 w-full rounded-2xl"/>
            {for i in range(n) {
                <div key={"g" + str(i)} className="flex flex-col gap-2">
                    <div
                        className="flex h-14 items-center gap-3 rounded-2xl bg-muted/60 px-3"
                    >
                        <Skeleton className="h-8 w-28 rounded-md"/>
                        <Skeleton className="h-3 w-4"/>
                    </div>
                    {for j in range(2 + (i % 2)) {
                        <div
                            key={"r" + str(j)}
                            className="flex h-12 items-center gap-3 px-3"
                        >
                            <Skeleton className="size-2 rounded-full"/>
                            <Skeleton className={"h-3 " + WIDTHS[(i + j) % 4]}/>
                            <Skeleton className="ml-auto size-6 rounded-full"/>
                        </div>
                    }}
                </div>
            }}
        </div>;
}
