"""The hero demo: the flow line strip, the board's steps stacked as groups of
task rows, and the picked task's travel so far. Dragging a task onto a step,
clicking it or pressing Enter moves it and writes a travel line. Sample data,
no autoplay."""

import from .demoData { ROUTE, TASKS }
import from .DemoStrip { DemoStrip }
import from .DemoGroup { DemoGroup }
import from .DemoTravel { DemoTravel }
import from .DemoHint { DemoHint }

glob DAY_SHORT: list[str] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

def pad2(n: int) -> str {
    return ("0" + str(n))[-2:];
}

def:pub HeroBoard(loggedIn: bool = False) -> JsxElement {
    has lanes: list[int] = [t["lane"] for t in TASKS],
        written: list[dict[str, str]] = [],
        picked: str = "Invoice PDF redesign";

    def moveTo(title: str, target: int) {
        picked = title;
        at = -1;
        for (k, cand) in enumerate(TASKS) {
            if cand["title"] == title {
                at = k;
            }
        }
        if at < 0 or lanes[at] == target {
            return;
        }
        updated = [v for v in lanes];
        updated[at] = target;
        lanes = updated;
        d: any = new(Date);
        stamp = DAY_SHORT[int(d.getDay())]
            + " "
            + pad2(int(d.getHours()))
            + ":"
            + pad2(int(d.getMinutes()));
        line = {
            "title": title,
            "at": stamp,
            "what": "Moved to " + ROUTE[target]["name"]
        };
        written = [line] + written;
    }

    # A moved row remounts in its new group, so a keyboard move puts focus
    # back on it and Enter keeps moving the same task.
    def advance(task: dict[str, any], index: int, keyboard: bool) {
        moveTo(task["title"], (lanes[index] + 1) % len(ROUTE));
        if keyboard {
            window.requestAnimationFrame(
                lambda {
                    el: any = document.getElementById("demo-row-" + str(index));
                    if el {
                        el.focus({"preventScroll": True});
                    }
                }
            );
        }
    }

    counts: list[int] = [0 for s in ROUTE];
    for lane in lanes {
        counts[lane] = counts[lane] + 1;
    }
    return
        <div className="mt-5 mb-2">
            <div
                role="group"
                aria-label="Sample board you can try"
                className="grid gap-4 rounded-3xl border bg-card p-3 sm:p-4"
            >
                <DemoStrip
                    steps={ROUTE}
                    counts={counts}
                    loop="Review sends back to Build"
                />
                <div className="grid gap-3">
                    {for (i, step) in enumerate(ROUTE) {
                        <DemoGroup
                            key={step["name"]}
                            index={i}
                            lanes={lanes}
                            count={counts[i]}
                            picked={picked}
                            onDrop={moveTo}
                            onAdvance={advance}
                        />
                    }}
                </div>
                <DemoTravel picked={picked} written={written}/>
            </div>
            <DemoHint moved={len(written) > 0} loggedIn={loggedIn}/>
        </div>;
}
