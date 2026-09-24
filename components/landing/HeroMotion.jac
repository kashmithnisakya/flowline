"""The hero's moving figure: one task travelling the flow line while its
travel writes itself underneath. It is the product's one idea in miniature, so it
shows the real step kinds and the real colours rather than a generic loop.

Decorative, and marked so: the playable board below is the thing a reader can
actually touch, and this figure is hidden from assistive technology. Every
animation here collapses to its final frame under reduced motion, which is a
complete picture rather than a blank one.
"""

glob STEPS: list[dict[str, str]] = [
         {"name": "Specify", "dot": "bg-step-sky"},
         {"name": "Build", "dot": "bg-step-indigo"},
         {"name": "Review", "dot": "bg-step-rose"},
         {"name": "Done", "dot": "bg-step-emerald"}
     ],
     LINES: list[dict[str, str]] = [
         {"at": "09:24", "who": "Priya", "what": "moved it to Build"},
         {"at": "09:31", "who": "Priya", "what": "sent it to Review"},
         {"at": "09:48", "who": "Leo", "what": "finished it"}
     ];

def:pub HeroMotion -> JsxElement {
    return
        <figure
            className="hero-frame overflow-hidden border bg-card p-4 sm:p-5"
            aria-hidden="true"
        >
            <div className="hm-track gap-1.5">
                {for s in STEPS {
                    <span
                        key={s["name"]}
                        className="hm-step flex min-w-0 items-center gap-1.5 rounded-full border px-2.5 py-1.5 text-[12px] font-medium"
                    >
                        <span className={"size-1.5 shrink-0 rounded-full " + s["dot"]}/>
                        <span className="truncate">{s["name"]}</span>
                    </span>
                }}
            </div>
            <div className="hm-track mt-4">
                <div className="hm-card">
                    <div
                        className="mr-1.5 rounded-md border bg-card p-2.5 shadow-[var(--float-1)]"
                    >
                        <p className="truncate text-[12.5px] font-semibold">
                            Invoice PDF
                        </p>
                        <p className="num mt-1 truncate text-[11px] text-subtle">
                            Billing
                        </p>
                    </div>
                </div>
            </div>
            <div className="mt-5 border-t pt-3">
                <p className="meta font-mono">Travel so far</p>
                <ul className="mt-2 grid gap-1.5">
                    {for l in LINES {
                        <li
                            key={l["at"]}
                            className="hm-line flex items-baseline gap-2 text-[12.5px]"
                        >
                            <span className="num shrink-0 text-subtle">{l["at"]}</span>
                            <span className="min-w-0 truncate text-muted-foreground">
                                <span className="font-medium text-foreground">
                                    {l["who"]}
                                </span>
                                {" " + l["what"]}
                            </span>
                        </li>
                    }}
                </ul>
            </div>
        </figure>;
}
