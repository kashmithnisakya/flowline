"""Move to step, in route order: the step's forward transitions first, its
send-backs second, then every other column. Number keys jump by column
position. The card mounts it only while open, so a board of hundreds of
cards carries no idle menu roots."""

import from ...models { StepView }
import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuLabel,
    DropdownMenuItem
}

glob SWATCH: dict[str, str] = {
         "sky": "bg-step-sky",
         "indigo": "bg-step-indigo",
         "amber": "bg-step-amber",
         "rose": "bg-step-rose",
         "emerald": "bg-step-emerald",
         "slate": "bg-step-slate"
     };

def:pub swatchFor(color: str) -> str {
    return SWATCH[color] if color in SWATCH else SWATCH["slate"];
}

# Where a card can go from `current`. Send-backs are outgoing transitions to
# an earlier column, else the nearest earlier step that leads in; with no
# transitions at all (legacy columns) the neighbouring columns stand in.
def:pub routeFrom(
    current: str, keys: list[str], steps: list[StepView]
) -> dict[str, list[str]] {
    here = -1;
    for (i, k) in enumerate(keys) {
        if k == current {
            here = i;
        }
    }
    outgoing: list[str] = [];
    incoming: list[str] = [];
    for s in steps {
        if s.id == current {
            outgoing = s.next_ids;
            incoming = s.prev_ids;
        }
    }
    nexts: list[str] = [];
    backs: list[str] = [];
    for (i, k) in enumerate(keys) {
        if i > here and k in outgoing {
            nexts.append(k);
        }
    }
    j = here - 1;
    while j >= 0 {
        if keys[j] in outgoing {
            backs.append(keys[j]);
        }
        j = j - 1;
    }
    if len(backs) == 0 {
        j = here - 1;
        while j >= 0 and len(backs) == 0 {
            if keys[j] in incoming {
                backs.append(keys[j]);
            }
            j = j - 1;
        }
    }
    if here >= 0 and len(nexts) == 0 and len(outgoing) == 0 and here + 1 < len(keys) {
        nexts.append(keys[here + 1]);
    }
    if here > 0 and len(backs) == 0 and len(steps) == 0 {
        backs.append(keys[here - 1]);
    }
    rest: list[str] = [];
    for k in keys {
        if k not in nexts and k not in backs {
            rest.append(k);
        }
    }
    return {"next": nexts, "back": backs, "rest": rest};
}

def:pub MoveMenu(
    open: bool,
    onOpenChange: Callable[[bool], None],
    current: str,
    keys: list[str],
    labels: list[str],
    colors: list[str],
    steps: list[StepView],
    onPick: Callable[[str], None],
    # The trigger's classes and content: an icon on a card, a labelled
    # button in the task sheet. Both callers render the same element while
    # closed, so opening swaps nothing visible.
    triggerClass: str = "",
    triggerLabel: str = "Move to another step",
    showLabel: bool = False,
    align: str = "start",
    onClosed: Callable[[], None] = None
) -> JsxElement {
    groups = routeFrom(current, keys, steps);

    def pick(key: str) {
        if key != current {
            onPick(key);
        }
        onOpenChange(False);
    }

    def row(key: str) -> JsxElement {
        idx = -1;
        for (i, k) in enumerate(keys) {
            if k == key {
                idx = i;
            }
        }
        label = labels[idx] if idx >= 0 and idx < len(labels) else key;
        color = colors[idx] if idx >= 0 and idx < len(colors) else "slate";
        isHere = key == current;
        return
            <DropdownMenuItem
                key={key}
                className={"gap-2 px-2 py-1.5 text-[13px]"
                    + (" text-subtle" if isHere else "")}
                onSelect={lambda { pick(key); }}
            >
                <span className={"step-swatch " + swatchFor(color)} aria-hidden="true"/>
                <span className="min-w-0 flex-1 truncate">{label}</span>
                {if isHere {
                    <svg
                        key="here"
                        width={14}
                        height={14}
                        viewBox="0 0 16 16"
                        aria-label="Current step"
                        role="img"
                    >
                        <path
                            d="m3.5 8.5 3 3 6-7"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={1.8}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        />
                    </svg>
                } elif idx < 9 {
                    <span key="kbd" className="kbd pointer-coarse:hidden">
                        {str(idx + 1)}
                    </span>
                } }
            </DropdownMenuItem>;
    }

    return
        <DropdownMenu open={open} onOpenChange={onOpenChange}>
            <DropdownMenuTrigger
                className={triggerClass}
                aria-label={triggerLabel if not showLabel else None}
                onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                onKeyDown={lambda (e: KeyboardEvent) { e.stopPropagation(); }}
            >
                {if showLabel {
                    <span key="label">Move</span>
                } else {
                    <svg
                        key="icon"
                        width={14}
                        height={14}
                        viewBox="0 0 16 16"
                        aria-hidden="true"
                        className="shrink-0"
                    >
                        <path
                            d="M3 8h9.5M9 4.5 12.5 8 9 11.5"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={1.6}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        />
                    </svg>
                } }
                {if showLabel {
                    <span key="kbd" className="kbd max-md:hidden pointer-coarse:hidden">
                        M
                    </span>
                }}
            </DropdownMenuTrigger>
            <DropdownMenuContent
                align={align}
                className="w-60 p-1.5"
                onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
                onKeyDown={lambda (e: KeyboardEvent) {
                    # Menu content is portaled, but React still bubbles its
                    # events to the card that owns it.
                    e.stopPropagation();
                    k = str(e.key);
                    if len(k) == 1 and k >= "1" and k <= "9" {
                        idx = int(k) - 1;
                        if idx < len(keys) {
                            e.preventDefault();
                            pick(keys[idx]);
                        }
                    }
                }}
                onOpenAutoFocus={lambda (e: Event) {
                    # Land on the first row, the next step, so Enter moves on.
                    box: any = e.target;
                    first: any = box.querySelector("[role=menuitem]") if box else None;
                    if first {
                        e.preventDefault();
                        first.focus({"preventScroll": True});
                    }
                }}
                onCloseAutoFocus={lambda (e: Event) { if onClosed {
                    e.preventDefault();
                    onClosed();
                }}}
            >
                {if len(groups["next"]) > 0 {
                    <DropdownMenuLabel
                        key="hn"
                        className="px-2 pt-1.5 pb-1 text-subtle"
                    >
                        Next on the route
                    </DropdownMenuLabel>
                }}
                {[row(k) for k in groups["next"]]}
                {if len(groups["back"]) > 0 {
                    <DropdownMenuLabel key="hb" className="px-2 pt-2 pb-1 text-subtle">
                        Send back
                    </DropdownMenuLabel>
                }}
                {[row(k) for k in groups["back"]]}
                <DropdownMenuLabel className="px-2 pt-2 pb-1 text-subtle">
                    Any step
                </DropdownMenuLabel>
                {[row(k) for k in groups["rest"]]}
            </DropdownMenuContent>
        </DropdownMenu>;
}
