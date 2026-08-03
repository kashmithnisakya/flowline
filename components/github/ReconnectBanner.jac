"""Shown when GitHub refused the installation's last request.

The server flips the connection to "invalid" on a 401 or a 404 from GitHub,
which is one of two things: the installation was uninstalled, or its repo
access was narrowed. Both are fixed by walking the install flow again.
"""

import from ..ui.button { Button }

def:pub ReconnectBanner(busy: bool, onReconnect: Callable[[], None]) -> JsxElement {
    return <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-warning/50 bg-warning/10 p-3">
        <div className="min-w-0 space-y-0.5">
            <div className="text-sm font-medium">GitHub rejected the last request</div>
            <p className="text-xs text-muted-foreground">
                The installation was removed, or its repository access changed.
                Reconnect to grant it again. Nothing on the board is affected.
            </p>
        </div>
        <Button size="sm" onClick={onReconnect} disabled={busy}>
            {"Opening GitHub…" if busy else "Reconnect"}
        </Button>
    </div>;
}
