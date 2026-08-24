"""What the product actually ships today, four cards, nothing aspirational.
Each card shows its feature with product parts (step pills, log rows, the
roster, the isolation diagram) instead of a paragraph doing the work.
"""

import from ..ui.card { Card, CardContent }
import from ..common.Avatar { Avatar }

# The mini flow the first card draws; wash/ink/bar are step colour tokens.
glob FLOW_PILLS: list[dict[str, str]] = [
         {"name": "Idea", "cls": "bg-step-sky-wash text-step-sky-ink"},
         {"name": "Build", "cls": "bg-step-amber-wash text-step-amber-ink"},
         {"name": "Review", "cls": "bg-step-indigo-wash text-step-indigo-ink"},
         {"name": "Done", "cls": "bg-step-emerald-wash text-step-emerald-ink"}
     ],
     FLOW_COLS: list[str] = [
         "border-t-step-sky bg-step-sky-wash",
         "border-t-step-amber bg-step-amber-wash",
         "border-t-step-indigo bg-step-indigo-wash",
         "border-t-step-emerald bg-step-emerald-wash"
     ],
     LOG_PEEK: list[dict[str, str]] = [
         {
             "who": "Amara",
             "what": "shipped the hero rework",
             "status": "Done",
             "tint": "bg-step-emerald-wash text-step-emerald-ink"
         },
         {
             "who": "Priya",
             "what": "auth rollout behind the flag",
             "status": "In progress",
             "tint": "bg-step-amber-wash text-step-amber-ink"
         }
     ],
     ROSTER: list[str] = ["Amara Perera", "Kasun Silva", "Dev Fernando", "Priya Raman"];

def:pub Features -> JsxElement {
    return
        <section
            id="product"
            className="mx-auto max-w-[1180px] scroll-mt-24 px-7 pt-24"
        >
            <span
                className="text-xs font-semibold uppercase tracking-widest text-primary"
            >
                Product
            </span>
            <h2
                className="font-display mt-3 max-w-xl text-[clamp(1.9rem,4vw,2.65rem)] font-bold leading-tight tracking-[-0.04em]"
            >
                Everything a standup does. None of the 9:45.
            </h2>
            <p className="mt-4 max-w-2xl text-base text-muted-foreground">
                Four things replace the ritual, and unlike the meeting, the record is still there next month.
            </p>
            <div className="mt-10 grid gap-6 sm:grid-cols-2">
                <Card className="card-hover h-full py-0 hover:ring-foreground/20">
                    <CardContent className="flex h-full flex-col gap-3 p-7">
                        <h3 className="font-display text-xl font-bold tracking-tight">
                            A flow line you design
                        </h3>
                        <p className="text-sm leading-relaxed text-muted-foreground">
                            Name the steps your team actually uses and connect them however work moves, loops included. The board is those steps.
                        </p>
                        <div className="mt-auto pt-3" aria-hidden="true">
                            <div className="flex flex-wrap items-center gap-1.5">
                                {for (i, pill) in enumerate(FLOW_PILLS) {
                                    <span
                                        key={pill["name"]}
                                        className="flex items-center gap-1.5"
                                    >
                                        {if i > 0 {
                                            <span
                                                key="arrow"
                                                className="text-[10px] text-muted-foreground"
                                            >
                                                {"⇄" if i == 3 else "→"}
                                            </span>
                                        }}
                                        <span
                                            className={"rounded-full px-2.5 py-0.5 text-[10px] font-bold " + pill[
                                                "cls"
                                            ]}
                                        >
                                            {pill["name"]}
                                        </span>
                                    </span>
                                }}
                            </div>
                            <div className="mt-2.5 grid grid-cols-4 gap-1.5">
                                {for c in FLOW_COLS {
                                    <div
                                        key={c}
                                        className={"h-9 rounded-md border-t-[3px] " + c}
                                    ></div>
                                }}
                            </div>
                        </div>
                    </CardContent>
                </Card>
                <Card className="card-hover h-full py-0 hover:ring-foreground/20">
                    <CardContent className="flex h-full flex-col gap-3 p-7">
                        <h3 className="font-display text-xl font-bold tracking-tight">
                            A written daily log
                        </h3>
                        <p className="text-sm leading-relaxed text-muted-foreground">
                            One row per person per weekday: the work, the status, the links. The archive nobody has to remember.
                        </p>
                        <div className="mt-auto space-y-1.5 pt-3" aria-hidden="true">
                            {for r in LOG_PEEK {
                                <div
                                    key={r["who"]}
                                    className="flex items-center gap-2 rounded-lg border bg-muted/40 px-2.5 py-1.5 text-[11px]"
                                >
                                    <span className="font-bold">{r["who"]}</span>
                                    <span
                                        className="min-w-0 truncate text-muted-foreground"
                                    >
                                        {r["what"]}
                                    </span>
                                    <span
                                        className={"ml-auto shrink-0 rounded-full px-2 py-0.5 text-[9px] font-bold " + r[
                                            "tint"
                                        ]}
                                    >
                                        {r["status"]}
                                    </span>
                                </div>
                            }}
                        </div>
                    </CardContent>
                </Card>
                <Card className="card-hover h-full py-0 hover:ring-foreground/20">
                    <CardContent className="flex h-full flex-col gap-3 p-7">
                        <h3 className="font-display text-xl font-bold tracking-tight">
                            Projects and people you control
                        </h3>
                        <p className="text-sm leading-relaxed text-muted-foreground">
                            Add teammates without accounts, assign them to any project, and archive without losing the history.
                        </p>
                        <div
                            className="mt-auto flex items-center pt-3"
                            aria-hidden="true"
                        >
                            <div className="flex">
                                {for (i, name) in enumerate(ROSTER) {
                                    <span
                                        key={name}
                                        className={"inline-flex" + (
                                            " -ml-2" if i > 0 else ""
                                        )}
                                    >
                                        <Avatar
                                            name={name}
                                            size="sm"
                                            className="ring-2 ring-card"
                                        />
                                    </span>
                                }}
                            </div>
                            <span
                                className="ml-3 text-[11px] font-medium text-muted-foreground"
                            >
                                + your team
                            </span>
                        </div>
                    </CardContent>
                </Card>
                <Card className="card-hover h-full py-0 hover:ring-foreground/20">
                    <CardContent className="flex h-full flex-col gap-3 p-7">
                        <h3 className="font-display text-xl font-bold tracking-tight">
                            A workspace that is yours
                        </h3>
                        <p className="text-sm leading-relaxed text-muted-foreground">
                            Your account is your organization, on its own private graph. Another account cannot read or touch it.
                        </p>
                        <div
                            className="mt-auto flex items-center gap-3 pt-3"
                            aria-hidden="true"
                        >
                            <div className="flex-1 rounded-lg border p-2.5">
                                <div
                                    className="text-[9px] font-semibold uppercase tracking-widest text-muted-foreground"
                                >
                                    your org
                                </div>
                                <div
                                    className="mt-1.5 h-1.5 rounded-full bg-primary/25"
                                ></div>
                                <div className="mt-1 h-1.5 w-2/3 rounded-full bg-muted"></div>
                            </div>
                            <span className="text-sm font-bold text-muted-foreground">
                                ×
                            </span>
                            <div className="flex-1 rounded-lg border p-2.5 opacity-45">
                                <div
                                    className="text-[9px] font-semibold uppercase tracking-widest text-muted-foreground"
                                >
                                    anyone else
                                </div>
                                <div className="mt-1.5 h-1.5 rounded-full bg-muted"></div>
                                <div className="mt-1 h-1.5 w-3/5 rounded-full bg-muted"></div>
                            </div>
                        </div>
                    </CardContent>
                </Card>
            </div>
        </section>;
}
