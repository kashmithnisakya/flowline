"""One step in the phone's step list: its badge and count, owner and blurb,
then where work can go from it (a send-back marked as one). `outs` rows are
{key, to, note, back} (back "1" or ""); tapping the step opens its work."""

import from ...models { StepView }
import from .kinds { colorKey }
import from .CountChip { CountChip }
import from ..common.StepBadge { StepBadge }

def:pub StepListRow(
    step: StepView,
    outs: list[dict[str, str]],
    selected: bool = False,
    onOpen: Callable[[str], None] = None
) -> JsxElement {
    c = colorKey(step.color);
    owner = step.owner.strip() if step.owner else "";
    blurb = step.blurb.strip() if step.blurb else "";
    return
        <li className="flex flex-col">
            <button
                type="button"
                aria-current={"true" if selected else None}
                className={"flex w-full flex-col items-start gap-1.5 rounded-xl px-3 py-2.5 text-left transition-colors hover:bg-accent"
                    + (" bg-accent" if selected else "")}
                onClick={lambda { if onOpen { onOpen(step.id); }}}
            >
                <span className="flex w-full min-w-0 items-center gap-2">
                    <span className="flex min-w-0 flex-1">
                        <StepBadge
                            name={step.name}
                            color={c}
                            kind={step.kind}
                            size="sm"
                        />
                    </span>
                    <CountChip count={step.task_count} kind={step.kind} color={c}/>
                </span>
                {if owner {
                    <span key="owner" className="text-xs text-muted-foreground">
                        {"Anyone" if owner == "anyone" else owner}
                    </span>
                }}
                {if blurb {
                    <span
                        key="blurb"
                        className="line-clamp-2 text-[13px] leading-5 text-muted-foreground"
                    >
                        {blurb}
                    </span>
                }}
            </button>
            {if len(outs) > 0 {
                <ul
                    key="outs"
                    className="flex flex-col gap-0.5 px-3 pb-2.5 pl-6 text-[13px] leading-5 text-muted-foreground"
                >
                    {for o in outs {
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
        </li>;
}
