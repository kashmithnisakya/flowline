"""The inline error strip under a form: warning glyph plus the message, in the
destructive tone, animating in from above.
"""

import from .glyphs { WarnIcon }

def:pub ErrorNote(message: str) -> JsxElement {
    return
        <div
            className="flex items-start gap-2 rounded-lg border border-destructive/30 bg-destructive/10 px-3 py-2 text-sm text-destructive animate-in fade-in slide-in-from-top-1"
        >
            <WarnIcon className="mt-0.5 shrink-0"/>
            <span>{message}</span>
        </div>;
}
