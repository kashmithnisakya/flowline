"""A settings row: label and one line of help on the left, the control at the
right; it wraps on a phone. Rows sit together under one panel with hairlines.
"""

def:pub SettingRow(
    label: str, hint: str = "", htmlFor: str = "", children: any = None
) -> JsxElement {
    return
        <div
            className="flex min-h-11 flex-wrap items-center gap-x-3 gap-y-2 px-4 py-2.5 not-first:border-t"
        >
            <div className="min-w-0 flex-1 basis-[220px]">
                <label htmlFor={htmlFor or None} className="text-sm font-medium">
                    {label}
                </label>
                {if hint {
                    <p key="hint" className="mt-0.5 text-[13px] text-muted-foreground">
                        {hint}
                    </p>
                }}
            </div>
            <div className="min-w-0">{children}</div>
        </div>;
}
