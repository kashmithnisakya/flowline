"""The lane view's label column, pinned to the canvas's left edge while the bands
pan under it: each role's name and who holds it, in as many rows as its band has
room for. Hovering a label fades the other lanes' steps (`onHover`)."""

import from .lanes { LANE_LABEL_W }

def:pub LaneLabels(
    rows: list[dict[str, any]],
    left: float,
    width: float,
    onHover: Callable[[str], None] = None
) -> JsxElement {
    return
        <div
            className="absolute inset-y-0 z-30 border-r bg-background"
            style={{"left": str(left) + "px", "width": str(width) + "px"}}
            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
            onPointerDown={lambda (e: any) { e.stopPropagation(); }}
        >
            {for lr in rows {
                <div
                    key={lr["key"]}
                    className={"absolute inset-x-0 flex flex-col justify-center overflow-hidden px-4"
                        + ("" if lr["first"] else " border-t border-border")
                        + (" bg-accent" if lr["hover"] else "")}
                    style={{"top": lr["top"], "height": lr["h"]}}
                    onMouseEnter={lambda { if onHover { onHover(lr["lane"]); }}}
                    onMouseLeave={lambda { if onHover { onHover(""); }}}
                >
                    {if lr["manage"] {
                        <a
                            key="name-link"
                            href="/workspace?tab=roles"
                            title="Manage roles in Workspace"
                            className="flex min-w-0 items-center gap-1.5 text-sm leading-5 font-semibold text-foreground no-underline underline-offset-2 hover:underline"
                        >
                            <span className={"step-swatch " + lr["dot"]}/>
                            <span className="truncate">{lr["label"]}</span>
                        </a>
                    } else {
                        <div
                            key="name"
                            className="flex min-w-0 items-center gap-1.5 text-sm leading-5 font-semibold"
                        >
                            <span className={"step-swatch " + lr["dot"]}/>
                            <span className="truncate">{lr["label"]}</span>
                        </div>
                    } }
                    {if lr["rows"] >= 2 and lr["short"] {
                        <div
                            key="sub"
                            className={"truncate pl-4 text-xs leading-[18px] "
                                + (
                                    "text-warning"
                                        if lr["warn"]
                                        else "text-muted-foreground"
                                )}
                            title={lr["sub"]}
                        >
                            {lr["short"]}
                        </div>
                    }}
                    {if lr["rows"] >= 3 and width >= LANE_LABEL_W {
                        <div
                            key="totals"
                            className={"num truncate pl-4 text-xs leading-[18px] "
                                + (
                                    "text-muted-foreground"
                                        if lr["hover"]
                                        else "text-subtle"
                                )}
                        >
                            {lr["totals"]}
                        </div>
                    }}
                </div>
            }}
        </div>;
}
