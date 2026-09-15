"""The Overview's worklist: what needs someone now, grouped by why. The page
builds the groups as dicts (key, label, glyph, alarm, rows, more, moreLabel)
and each row (id, title, meta, note, noteWarn, names, time, late) links to
its card on the board."""

import from "@jac/runtime" { Link }
import from ..common.KindGlyph { KindGlyph }
import from ..common.Avatar { AvatarStack }

glob SHOW_MAX: int = 6;

def GroupGlyph(glyph: str) -> JsxElement {
    if glyph == "calendar" {
        return
            <svg
                className="shrink-0"
                width={14}
                height={14}
                viewBox="0 0 16 16"
                aria-hidden="true"
            >
                <rect
                    x={2.5}
                    y={3.5}
                    width={11}
                    height={10}
                    rx={1.5}
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                />
                <path
                    d="M2.5 6.5h11M5.5 2v3M10.5 2v3"
                    stroke="currentColor"
                    strokeWidth={1.5}
                    strokeLinecap="round"
                />
            </svg>;
    }
    if glyph == "quiet" {
        return
            <svg
                className="shrink-0"
                width={14}
                height={14}
                viewBox="0 0 16 16"
                aria-hidden="true"
            >
                <circle
                    cx={8}
                    cy={8}
                    r={5.75}
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                />
                <path
                    d="M8 4.8V8l2.2 1.4"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                />
            </svg>;
    }
    return <KindGlyph kind={glyph}/>;
}

def:pub NeedsYou(groups: list[dict], total: int, pending: bool = False) -> JsxElement {
    return
        <section className="surface min-w-0" aria-labelledby="needs-you">
            <div className="flex items-baseline gap-2 px-3.5 pt-3 pb-2">
                <h2 id="needs-you" className="section-title text-[15px]">Needs you</h2>
                <span className="num text-xs text-subtle">{str(total)}</span>
                <Link
                    to="/board"
                    className="ml-auto text-[12.5px] text-primary underline underline-offset-[3px] hover:decoration-2"
                >
                    Open on the board
                </Link>
            </div>
            {for (gi, g) in enumerate(groups) {
                <div
                    key={g["key"]}
                    className={"px-3.5 pb-2 "
                        + ("border-t pt-2" if gi > 0 else "pt-0.5")}
                    role="group"
                    aria-label={g["label"]}
                >
                    <h3
                        className={"flex items-center gap-1.5 py-1 text-[12.5px] "
                            + (
                                "font-semibold text-destructive"
                                    if g["alarm"]
                                    else "font-normal text-muted-foreground"
                            )}
                    >
                        <GroupGlyph glyph={g["glyph"]}/>
                        {g["label"]}
                    </h3>
                    <ul>
                        {for (i, r) in enumerate(g["rows"]) {
                            if i < SHOW_MAX {
                                <li
                                    key={r["id"]}
                                    className={"border-t" if i > 0 else ""}
                                >
                                    <Link
                                        to={"/board?task=" + r["id"]}
                                        className="-mx-2 grid grid-cols-[minmax(0,1fr)_auto_auto] items-center gap-3 rounded-sm px-2 py-1.5 text-[13.5px] hover:bg-accent"
                                    >
                                        <span className="min-w-0 sm:truncate">
                                            <span className="block truncate sm:inline">
                                                {r["title"]}
                                            </span>
                                            <span
                                                className="block truncate text-xs text-muted-foreground sm:ml-1.5 sm:inline"
                                            >
                                                {r["meta"]}
                                                {(
                                                    " · "
                                                        if r["meta"] and r["note"]
                                                        else ""
                                                )}
                                                <span
                                                    className={"text-warning"
                                                        if r["noteWarn"]
                                                        else ""}
                                                >
                                                    {r["note"]}
                                                </span>
                                            </span>
                                        </span>
                                        <span className="flex justify-end">
                                            {if len(r["names"]) > 0 {
                                                <AvatarStack
                                                    key="who"
                                                    names={r["names"]}
                                                />
                                            }}
                                        </span>
                                        <time
                                            className={"num whitespace-nowrap text-right text-[12.5px] "
                                                + (
                                                    "font-semibold text-destructive"
                                                        if r["late"]
                                                        else "text-muted-foreground"
                                                )}
                                        >
                                            {r["time"]}
                                        </time>
                                    </Link>
                                </li>
                            }
                        }}
                    </ul>
                    {if len(g["rows"]) > SHOW_MAX or g["more"] > 0 {
                        <Link
                            key="more"
                            to="/board"
                            className="block border-t pt-1.5 text-xs text-muted-foreground hover:text-foreground"
                        >
                            {"+"
                                + str(
                                    (
                                        len(g["rows"]) - SHOW_MAX
                                            if len(g["rows"]) > SHOW_MAX
                                            else 0
                                    )
                                        + g["more"]
                                )
                                + " more "
                                + g["moreLabel"]
                                + "on the board"}
                        </Link>
                    }}
                </div>
            }}
            {if len(groups) == 0 {
                <p
                    key="clear"
                    className="px-3.5 pt-0.5 pb-3.5 text-[13.5px] text-muted-foreground"
                >
                    {"Checking what is due this week."
                        if pending
                        else "Nothing is overdue, blocked, waiting on review or due this week."}
                </p>
            }}
        </section>;
}
