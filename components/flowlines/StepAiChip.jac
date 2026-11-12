"""A step's AI responsibilities as the dashed chip under its card, linking to the
AI page; at the lowest zoom it is the mark alone. The wrapper keeps the press and
the click from the canvas, so neither moves the view nor selects anything."""

import from "@jac/runtime" { Link }
import from ..common.AiMark { AiMark }

def:pub StepAiChip(names: list[str], compact: bool = False) -> JsxElement {
    said = ", ".join(names);
    return
        <span
            data-step-ai=""
            className="absolute top-full left-0 mt-1.5 flex max-w-full"
            onClick={lambda (e: MouseEvent) { e.stopPropagation(); }}
            onPointerDown={lambda (e: any) { e.stopPropagation(); }}
        >
            <Link
                to="/ai"
                title={"AI runs here: " + said}
                aria-label={"AI runs here: " + said + ". Open AI"}
                className="ai-chip max-w-full min-w-0"
            >
                <AiMark/>
                {if not compact {
                    <span key="names" className="min-w-0 truncate">{said}</span>
                }}
            </Link>
        </span>;
}
