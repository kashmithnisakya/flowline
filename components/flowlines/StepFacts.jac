"""A step's settings as plain words on its tasks sheet (view mode changes
nothing), so a reader need not enter Edit to see who holds it or what it asks."""

import from ...models { StepView }
import from .kinds { KIND_LABEL, ownerWord, ruleWords }

def:pub StepFacts(step: StepView) -> JsxElement {
    rules = ruleWords(step);
    return
        <section aria-label="Step settings" className="flex flex-col gap-2">
            <h3 className="text-[13px] font-semibold">Settings</h3>
            <dl
                className="grid grid-cols-[auto_minmax(0,1fr)] gap-x-3 gap-y-1 text-[13px]"
            >
                <dt className="text-text-tertiary">Owner</dt>
                <dd>{ownerWord(step.owner)}</dd>
                <dt className="text-text-tertiary">Kind</dt>
                <dd>
                    {KIND_LABEL[step.kind] if step.kind in KIND_LABEL else step.kind}
                </dd>
                <dt className="text-text-tertiary">To enter</dt>
                <dd>{"A task " + rules if rules else "No rules"}</dd>
            </dl>
        </section>;
}
