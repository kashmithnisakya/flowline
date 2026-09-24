"""The hero demo's task history: the picked task's travel so far, newest
first, laid out like the task sheet's own. Moves made in the demo (`written`)
land on top of the sample lines."""

import from .demoData { TASKS }

def:pub DemoTravel(picked: str, written: list[dict[str, str]]) -> JsxElement {
    lines: list[dict[str, str]] = [
        w
        for w in written
        if w["title"] == picked
    ];
    for t in TASKS {
        if t["title"] == picked {
            lines = lines + t["travel"];
        }
    }
    return
        <section
            aria-label="Travel so far"
            aria-live="polite"
            className="grid gap-2 rounded-2xl bg-muted px-4 py-3"
        >
            <h3 className="flex min-w-0 gap-1.5 text-[13px]">
                <span className="shrink-0 font-semibold">Travel so far</span>
                <span className="truncate text-muted-foreground">{"· " + picked}</span>
            </h3>
            <ol className="grid gap-1">
                {for (i, line) in enumerate(lines) {
                    <li
                        key={line["at"] + line["what"] + str(len(lines) - i)}
                        className="grid grid-cols-[4.5rem_minmax(0,1fr)] gap-2.5 text-[13px] leading-snug"
                    >
                        <time className="num pt-px text-xs text-subtle">
                            {line["at"]}
                        </time>
                        <span className="min-w-0 break-words">{line["what"]}</span>
                    </li>
                }}
            </ol>
        </section>;
}
