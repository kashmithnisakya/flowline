"""The tour's board: the flow line strip, then one project's steps stacked as
groups, each a tinted header over its task rows. Static; the hero demo is
the one you can move tasks in."""

import from .tourData { BOARD }
import from .DemoStrip { DemoStrip }
import from .DemoHeader { DemoHeader }
import from .DemoLine { DemoLine }

def:pub TourBoard -> JsxElement {
    counts: list[int] = [len(s["tasks"]) for s in BOARD];
    return
        <div className="grid gap-4 rounded-3xl border bg-card p-3 sm:p-4">
            <DemoStrip steps={BOARD} counts={counts}/>
            <div className="grid gap-3">
                {for step in BOARD {
                    <div key={step["name"]} className="grid gap-1">
                        <DemoHeader
                            name={step["name"]}
                            color={step["color"]}
                            kind={step["kind"]}
                            count={len(step["tasks"])}
                        />
                        {for t in step["tasks"] {
                            <div key={t["title"]} className="px-2.5 py-2">
                                <DemoLine
                                    task={t}
                                    color={step["color"]}
                                    done={step["kind"] == "done"}
                                />
                            </div>
                        }}
                    </div>
                }}
            </div>
        </div>;
}
