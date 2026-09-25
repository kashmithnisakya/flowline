"""The step's entry rules in the inspector: a task lands here only with a due
date, or only with a linked PR. Each tick saves at once (SetStepRules)."""

import from ..ui.checkbox { Checkbox }

glob RULES: list[dict[str, str]] = [
         {"key": "needs_due_date", "text": "Needs a due date"},
         {"key": "needs_pr", "text": "Needs a linked PR"}
     ];


def:pub StepRules(
    needsDue: bool = False,
    needsPr: bool = False,
    onRule: Callable[[str, bool], None] = None
) -> JsxElement {
    held: dict[str, bool] = {"needs_due_date": needsDue, "needs_pr": needsPr};
    return
        <div className="flex flex-col gap-1.5">
            <span className="text-[12.5px] font-semibold">Entry rules</span>
            {for r in RULES {
                <label
                    key={r["key"]}
                    className="flex items-center gap-2 text-[13px]"
                    htmlFor={"rule-" + r["key"]}
                >
                    <Checkbox
                        id={"rule-" + r["key"]}
                        checked={held[r["key"]]}
                        onCheckedChange={lambda (on: bool) { if onRule {
                            onRule(r["key"], bool(on));
                        }}}
                    />
                    {r["text"]}
                </label>
            }}
            <p className="text-xs text-subtle">
                Checked on every move here, by hand or by a GitHub trigger.
            </p>
        </div>;
}
