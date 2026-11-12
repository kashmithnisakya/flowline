"""One AI responsibility under its role: its own switch, what it does and
where (opens the editor), and a pause note while the workspace's AI is off.
"""

import from ...ui.switch { Switch }

def:pub ResponsibilityLine(
    label: str,
    detail: str,
    enabled: bool,
    paused: bool,
    switchLabel: str,
    onToggle: Callable[[bool], None],
    onOpen: Callable[[], None],
    onOrganization: Callable[[], None]
) -> JsxElement {
    return
        <div
            className="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-md border bg-card px-2.5 py-1.5"
        >
            <Switch
                size="sm"
                checked={enabled}
                aria-label={switchLabel}
                onCheckedChange={lambda (v: bool) { onToggle(v); }}
            />
            <button
                type="button"
                className="min-w-0 flex-1 text-left text-[13px] hover:underline"
                onClick={lambda { onOpen(); }}
            >
                <span className="font-medium">{label}</span>
                <span className="text-muted-foreground">{" · " + detail}</span>
            </button>
            {if paused {
                <button
                    key="paused"
                    type="button"
                    className="text-[12.5px] text-muted-foreground underline-offset-2 hover:underline"
                    onClick={lambda { onOrganization(); }}
                >
                    Paused: AI is off
                </button>
            }}
        </div>;
}
