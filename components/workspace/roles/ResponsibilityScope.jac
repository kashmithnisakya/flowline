"""Where an AI responsibility runs (the role's own steps) and how far it may
go (comment only, or send the task back), as toggle chips like the member
dialog's. No step picked means every step the role owns.
"""

import from ....models { StepView }
import from ...ui.label { Label }
import from ..icons { IconCheck }

glob MODES: list[list[str]] = [
         [
             "comment",
             "Comment only",
             "Leaves a review with comments. The task stays where it is."
         ],
         [
             "request_changes",
             "Request changes",
             "A blocking problem sends the task back along the flow line."
         ]
     ];

def Pick(label: str, on: bool, onClick: Callable[[], None]) -> JsxElement {
    return
        <button
            type="button"
            aria-pressed={on}
            className={"inline-flex h-7 items-center gap-1.5 rounded-sm border px-2 text-[13px] transition-colors duration-150 "
                + (
                    "border-foreground bg-card font-semibold text-foreground"
                        if on
                        else "border-border text-muted-foreground hover:bg-accent hover:text-foreground"
                )}
            onClick={lambda { onClick(); }}
        >
            {if on {
                <IconCheck key="tick" size={12}/>
            }}
            <span>{label}</span>
        </button>;
}

def:pub ResponsibilityScope(
    mode: str,
    picked: list[str],
    steps: list[StepView],
    onField: Callable[[str, str], None],
    onToggleStep: Callable[[str], None]
) -> JsxElement {
    hint = "Runs only where you pick; none picked means every step this role owns."
        if len(steps) > 0
        else "This role owns no step yet. Make it a step's owner on the flow line.";
    return
        <div className="flex flex-col gap-5">
            <div className="flex flex-col gap-2">
                <Label>Runs on</Label>
                <div className="flex flex-wrap gap-1.5">
                    {for s in steps {
                        <Pick
                            key={s.id}
                            label={s.name}
                            on={s.id in picked}
                            onClick={lambda { onToggleStep(s.id); }}
                        />
                    }}
                </div>
                <p className="text-[12.5px] text-muted-foreground">{hint}</p>
            </div>
            <div className="flex flex-col gap-2">
                <Label>How far it may go</Label>
                <div className="grid gap-2 sm:grid-cols-2">
                    {for m in MODES {
                        <button
                            key={m[0]}
                            type="button"
                            aria-pressed={mode == m[0]}
                            aria-label={m[1]}
                            onClick={lambda { onField("mode", m[0]); }}
                            className={"flex flex-col gap-0.5 rounded-xl p-3 text-left transition-colors "
                                + (
                                    "border-2 border-primary"
                                        if mode == m[0]
                                        else "border border-border-strong hover:bg-bg-hover"
                                )}
                        >
                            <span className="text-[13px] font-medium">{m[1]}</span>
                            <span className="text-[12.5px] text-muted-foreground">
                                {m[2]}
                            </span>
                        </button>
                    }}
                </div>
            </div>
        </div>;
}
