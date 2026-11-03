"""A step's arrows in the inspector: what it goes to and comes from, a send-back
marked as one (an earlier step on the line, the same rule the canvas dashes its
wire by), and a remove button on each."""

import from ...models { StepView }

def TransitionRow(
    label: str, back: bool, onRemove: Callable[[], None] = None
) -> JsxElement {
    return
        <div
            className="flex items-center justify-between gap-2 rounded-md border px-2.5 py-1 text-[13px]"
        >
            <span className="flex min-w-0 items-center gap-1.5">
                <span className="truncate">{label}</span>
                {if back {
                    <span key="loop" className="meta shrink-0">sends back</span>
                }}
            </span>
            <button
                type="button"
                aria-label={"Remove the arrow with " + label}
                className="flex size-6 shrink-0 items-center justify-center rounded-sm text-text-secondary transition-colors hover:text-danger"
                onClick={lambda { if onRemove { onRemove(); }}}
            >
                <svg
                    width={12}
                    height={12}
                    viewBox="0 0 16 16"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                    strokeLinecap="round"
                    aria-hidden="true"
                >
                    <path d="m4 4 8 8M12 4l-8 8"/>
                </svg>
            </button>
        </div>;
}

def:pub StepLinks(
    step: StepView, steps: list[StepView], onUnlink: Callable[[str, str], None] = None
) -> JsxElement {
    byId: dict[str, StepView] = {};
    for s in steps {
        byId[s.id] = s;
    }

    def nameOf(sid: str) -> str {
        return byId[sid].name if sid in byId else "?";
    }

    def isBack(fromId: str, toId: str) -> bool {
        if fromId not in byId or toId not in byId {
            return False;
        }
        return byId[toId].sort_order < byId[fromId].sort_order;
    }

    return
        <section aria-label="Arrows" className="flex flex-col gap-3">
            <div className="flex flex-col gap-1.5">
                <h3 className="text-[13px] font-semibold">Goes to</h3>
                {if len(step.next_ids) == 0 {
                    <p key="none" className="meta">
                        Nothing yet. Drag from this step's edge to another step.
                    </p>
                }}
                {for nid in step.next_ids {
                    <TransitionRow
                        key={nid}
                        label={nameOf(nid)}
                        back={isBack(step.id, nid)}
                        onRemove={lambda { if onUnlink { onUnlink(step.id, nid); }}}
                    />
                }}
            </div>
            <div className="flex flex-col gap-1.5">
                <h3 className="text-[13px] font-semibold">Comes from</h3>
                {if len(step.prev_ids) == 0 {
                    <p key="none" className="meta">Nothing points here.</p>
                }}
                {for pid in step.prev_ids {
                    <TransitionRow
                        key={pid}
                        label={nameOf(pid)}
                        back={isBack(pid, step.id)}
                        onRemove={lambda { if onUnlink { onUnlink(pid, step.id); }}}
                    />
                }}
            </div>
        </section>;
}
