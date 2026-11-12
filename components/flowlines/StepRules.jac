"""A step's entry rules in the inspector: a task lands here only with a due date,
or only with a linked pull request. Each switch saves at once (SetStepRules)."""

import from ..ui.switch { Switch }

glob RULES: list[dict[str, str]] = [
         {"key": "needs_due_date", "text": "Needs a due date"},
         {"key": "needs_pr", "text": "Needs a pull request"}
     ];

def:pub StepRules(
    needsDue: bool = False,
    needsPr: bool = False,
    onRule: Callable[[str, bool], None] = None
) -> JsxElement {
    held: dict[str, bool] = {"needs_due_date": needsDue, "needs_pr": needsPr};
    return
        <section aria-label="Entry rules" className="flex flex-col gap-2">
            <h3 className="text-[13px] font-semibold">To enter this step, a task</h3>
            {for r in RULES {
                <label
                    key={r["key"]}
                    className="flex items-center gap-2 text-[13px]"
                    htmlFor={"rule-" + r["key"]}
                >
                    <Switch
                        id={"rule-" + r["key"]}
                        checked={held[r["key"]]}
                        onCheckedChange={lambda (on: bool) { if onRule {
                            onRule(r["key"], bool(on));
                        }}}
                    />
                    {r["text"]}
                </label>
            }}
            <p className="meta">
                Checked on every move here, by hand or by a GitHub trigger.
            </p>
        </section>;
}
