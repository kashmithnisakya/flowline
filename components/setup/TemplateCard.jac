"""One starting flow line as a radio card: its name, what it does and a small line
of its real steps' glyphs."""

import from ..common.StepBadge { StepIcon }

def:pub TemplateCard(
    template: dict[str, any],
    selected: bool,
    onPick: Callable[[], None],
    onKey: Callable[[KeyboardEvent], None]
) -> JsxElement {
    steps: list[dict[str, any]] = template["steps"];
    return
        <button
            id={"tpl-" + str(template["key"])}
            type="button"
            role="radio"
            aria-checked={selected}
            tabIndex={0 if selected else -1}
            autoFocus={selected}
            onClick={lambda { onPick(); }}
            onKeyDown={lambda (e: KeyboardEvent) { onKey(e); }}
            className={"flex w-full flex-col gap-2.5 rounded-[10px] bg-card text-left transition-colors "
                + (
                    "border-2 border-primary p-[15px]"
                        if selected
                        else "border border-input p-4 hover:bg-bg-hover"
                )}
        >
            <span className="flex items-center gap-2">
                <span className="text-[15px] font-semibold">{template["name"]}</span>
                {if template["key"] == "simple" {
                    <span
                        key="rec"
                        className="inline-flex h-[22px] items-center rounded-md border px-2 text-xs"
                    >
                        Recommended
                    </span>
                }}
            </span>
            <span className="text-[13px] text-text-secondary">
                {template["description"]}
            </span>
            <span aria-hidden="true" className="flex items-center">
                {for (i, s) in enumerate(steps) {
                    <span
                        key={s["name"]}
                        className={"flex items-center "
                            + ("flex-1" if i < len(steps) - 1 else "")}
                    >
                        <StepIcon color={s["color"]} kind={s["kind"]}/>
                        {if i < len(steps) - 1 {
                            <span
                                key="wire"
                                className="mx-[3px] h-0.5 min-w-2 flex-1 rounded-[1px] bg-input"
                            />
                        }}
                    </span>
                }}
            </span>
        </button>;
}
