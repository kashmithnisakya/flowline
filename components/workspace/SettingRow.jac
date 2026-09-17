"""A settings row: label and one line of help on the left, the control on the
right; stacked on a phone. Rows sit inside one `.surface` with hairlines.
"""

def:pub SettingRow(
    label: str, hint: str = "", htmlFor: str = "", children: any = None
) -> JsxElement {
    return
        <div
            className="grid gap-x-8 gap-y-3 px-4 py-4 not-first:border-t md:grid-cols-[260px_minmax(0,1fr)] md:items-center"
        >
            <div className="min-w-0">
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
