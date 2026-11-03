"""What AI a role holds, as chips that lead to the AI page, which edits them: one
per responsibility (settled and marked "off" while disabled), or a dashed Add AI
when it has none."""

import from "@jac/runtime" { Link }
import from ...constants { AI_RESPONSIBILITIES }
import from ...models { ResponsibilityView }
import from ..common.AiMark { AiMark }

def chipName(key: str) -> str {
    for known in AI_RESPONSIBILITIES {
        if known["key"] == key {
            return known["name"];
        }
    }
    return key;
}

def:pub RoleAiChips(role: str, items: list[ResponsibilityView]) -> JsxElement {
    if len(items) == 0 {
        return
            <Link
                to="/ai"
                aria-label={"Add AI to " + role}
                className="ai-chip ai-chip-settled border-dashed border-input hover:bg-bg-hover"
            >
                Add AI
            </Link>;
    }
    return
        <div className="flex flex-wrap items-center gap-1.5">
            {for item in items {
                <Link
                    key={item.id}
                    to="/ai"
                    className={"ai-chip" if item.enabled else "ai-chip ai-chip-settled"}
                >
                    <AiMark/>
                    {chipName(item.key) + ("" if item.enabled else ", off")}
                </Link>
            }}
        </div>;
}
