"""The flow line as an ordered list, the phone's default view: each step with
its kind, owner, count and blurb, then where work can go from it. Order is flow
depth, then sort order, so the list reads the way the diagram runs."""

import from ...models { StepView }
import from .kinds { KIND_LABEL, KIND_TONE, CARRY_LABEL, colorKey }
import from ..common.KindGlyph { KindGlyph }
import from ..common.StepName { StepName }


def:pub StepList(
    steps: list[StepView],
    colOf: dict[str, int] = {},
    selectedId: str = "",
    onOpen: Callable[[str], None] = None
) -> JsxElement {
    byId: dict[str, StepView] = {};
    for s in steps {
        byId[s.id] = s;
    }
    ordered = [s for s in steps];
    ordered.sort(key=lambda (st: StepView) { st.sort_order; });
    ordered.sort(key=lambda (st: StepView) { colOf[st.id] if st.id in colOf else 0; });

    rows: list[dict[str, any]] = [];
    for s in ordered {
        outs: list[dict[str, any]] = [];
        for (i, nid) in enumerate(s.next_ids) {
            if nid not in byId {
                continue;
            }
            said = s.next_labels[i] if i < len(s.next_labels) else "";
            carried = s.next_carries[i] if i < len(s.next_carries) else "";
            tag = CARRY_LABEL[carried] if carried in CARRY_LABEL else "";
            note = tag + (", " if tag and said else "") + said;
            outs.append(
                {
                    "key": s.id + ">" + nid,
                    "to": byId[nid].name,
                    "note": "(" + note + ")" if note else "",
                    "back": byId[nid].sort_order < s.sort_order
                }
            );
        }
        owner = s.owner.strip() if s.owner else "";
        rows.append(
            {
                "step": s,
                "owner": "Anyone" if owner == "anyone" else owner,
                "blurb": s.blurb.strip() if s.blurb else "",
                "outs": outs
            }
        );
    }

    return
        <ol aria-label="Steps in order" className="flex flex-col">
            {for row in rows {
                <li
                    key={(row["step"] as StepView).id}
                    className="border-b last:border-b-0"
                >
                    <button
                        type="button"
                        aria-current={"true"
                            if (row["step"] as StepView).id == selectedId
                            else None}
                        className={"flex w-full flex-col gap-1 px-4 pt-3 text-left transition-colors hover:bg-accent "
                            + ("pb-1.5" if len(row["outs"]) > 0 else "pb-3")
                            + (
                                " bg-accent"
                                    if (row["step"] as StepView).id == selectedId
                                    else ""
                            )}
                        onClick={lambda { if onOpen {
                            onOpen((row["step"] as StepView).id);
                        }}}
                    >
                        <span className="flex w-full items-center gap-3">
                            <span className="min-w-0 flex-1">
                                <StepName
                                    name={(row["step"] as StepView).name}
                                    color={colorKey((row["step"] as StepView).color)}
                                    className="text-[15px] leading-6 font-semibold"
                                />
                            </span>
                            <span
                                className="num shrink-0 text-[13px] text-muted-foreground"
                            >
                                {str((row["step"] as StepView).task_count)
                                    + (
                                        " task"
                                            if (row["step"] as StepView).task_count == 1
                                            else " tasks"
                                    )}
                            </span>
                        </span>
                        <span
                            className="flex min-w-0 items-center gap-1.5 text-xs text-muted-foreground"
                        >
                            <KindGlyph
                                kind={(row["step"] as StepView).kind}
                                size={14}
                                className={KIND_TONE[(row["step"] as StepView).kind]
                                    if (row["step"] as StepView).kind in KIND_TONE
                                    else "text-subtle"}
                            />
                            <span className="truncate">
                                {(
                                    KIND_LABEL[(row["step"] as StepView).kind]
                                        if (row["step"] as StepView).kind in KIND_LABEL
                                        else (row["step"] as StepView).kind
                                )
                                    + (" · " + row["owner"] if row["owner"] else "")}
                            </span>
                        </span>
                        {if row["blurb"] {
                            <span
                                key="blurb"
                                className="line-clamp-2 text-[13px] leading-5 text-muted-foreground"
                            >
                                {row["blurb"]}
                            </span>
                        }}
                    </button>
                    {if len(row["outs"]) > 0 {
                        <ul
                            key="outs"
                            className="flex flex-col gap-0.5 px-4 pb-3 pl-8 text-[13px] leading-5 text-muted-foreground"
                        >
                            {for o in row["outs"] {
                                <li key={o["key"]} className="min-w-0">
                                    <span
                                        aria-hidden="true"
                                        className="mr-1.5 inline-block w-3 text-subtle"
                                    >
                                        {"↩" if o["back"] else "→"}
                                    </span>
                                    <span className="font-medium text-foreground">
                                        {o["to"]}
                                    </span>
                                    {if o["note"] {
                                        <span key="note">{" " + o["note"]}</span>
                                    }}
                                    {if o["back"] {
                                        <span key="back" className="text-subtle">
                                            {", sends back"}
                                        </span>
                                    }}
                                </li>
                            }}
                        </ul>
                    }}
                </li>
            }}
        </ol>;
}
