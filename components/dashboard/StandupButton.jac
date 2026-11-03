"""The Overview's dashed AI button: opens Ask and has it write today's standup,
by the same window event the palette asks through."""

import from ..common.AiMark { AiMark }

def askStandup {
    w: any = window;
    w.dispatchEvent(new(w.CustomEvent, "flowline:ask", {"detail": {"standup": True}}));
}

def:pub StandupButton(className: str = "") -> JsxElement {
    return
        <button
            type="button"
            className={"inline-flex h-8 items-center gap-1.5 rounded-md border border-dashed border-ai bg-ai-wash px-3 text-[13px] font-medium whitespace-nowrap text-ai outline-none transition-colors focus-visible:ring-2 focus-visible:ring-ring "
                + className}
            onClick={lambda { askStandup(); }}
        >
            <AiMark/>
            Write today's standup
        </button>;
}
