"""Shown when GitHub refused the installation's last request.

The server flips the connection to "invalid" on a 401 or a 404 from GitHub,
which is one of two things: the installation was uninstalled, or its repo
access was narrowed. Both are fixed by walking the install flow again.
"""

import from ..ui.button { Button }

def:pub ReconnectBanner(busy: bool, onReconnect: Callable[[], None]) -> JsxElement {
    return <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-warning/50 bg-warning/10 p-3 animate-in fade-in slide-in-from-top-1 duration-300">
        <div className="flex min-w-0 items-start gap-2.5">
            <svg
                className="mt-0.5 shrink-0 text-warning"
                width={16}
                height={16}
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth={2}
                strokeLinecap="round"
                strokeLinejoin="round"
            >
                <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 20h16a2 2 0 0 0 1.73-2Z" />
                <path d="M12 9v4" />
                <path d="M12 17h.01" />
            </svg>
            <div className="min-w-0 space-y-0.5">
                <div className="text-sm font-medium">GitHub rejected the last request</div>
                <p className="text-xs text-muted-foreground">
                    The installation was removed, or its repository access changed.
                    Reconnect to grant it again. Nothing on the board is affected.
                </p>
            </div>
        </div>
        <Button size="sm" onClick={onReconnect} disabled={busy}>
            {if busy {
                <svg
                    key="sp"
                    className="animate-spin"
                    width={14}
                    height={14}
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={2}
                    strokeLinecap="round"
                >
                    <path d="M21 12a9 9 0 1 1-6.219-8.56" />
                </svg>
            }}
            {"Opening GitHub…" if busy else "Reconnect"}
        </Button>
    </div>;
}
