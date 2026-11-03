"""What every setup step shares: its title block, a field's error line and the
save error."""

import from ..common.glyphs { WarnIcon }

def:pub StepTitle(title: str, sub: str = "") -> JsxElement {
    return
        <div>
            <h1
                className="text-[32px] leading-[1.04] font-bold tracking-[-0.03em] text-balance"
            >
                {title}
            </h1>
            {if sub {
                <p key="sub" className="mt-1.5 text-sm text-text-secondary">{sub}</p>
            }}
        </div>;
}

def:pub FieldError(id: str, message: str) -> JsxElement {
    return
        <p id={id} className="flex items-center gap-1.5 text-xs text-destructive">
            <WarnIcon size={12} className="shrink-0"/>
            {message}
        </p>;
}

def:pub SaveError(message: str) -> JsxElement {
    return <p role="alert" className="text-sm text-destructive">{message}</p>;
}
