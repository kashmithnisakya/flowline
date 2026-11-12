"""The AI card on a step's sheets: what runs when a task lands here, by name, and
the way to the page where it is edited. Its switch lives on that page."""

import from "@jac/runtime" { Link }
import from ..common.AiMark { AiMark }

def:pub StepAiCard(names: list[str]) -> JsxElement {
    return
        <section aria-label="AI on this step" className="ai-card">
            <div className="flex min-w-0 items-center gap-2 text-[13px] font-semibold">
                <AiMark/>
                <span className="min-w-0 truncate">{", ".join(names)}</span>
            </div>
            <p className="text-xs text-text-secondary">
                Runs on its own when a task lands on this step.
            </p>
            <Link
                to="/ai"
                className="text-xs underline decoration-border-strong underline-offset-[3px] hover:decoration-current"
            >
                Edit responsibility
            </Link>
        </section>;
}
