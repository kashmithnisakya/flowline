"""Shown when GitHub refused the installation's last request. A 401/404 flips
the connection to "invalid": the installation was uninstalled or its repo
access narrowed, both fixed by walking the install flow again.
"""

import from ..ui.button { Button }
import from ..common.glyphs { Spinner, WarnIcon }

def:pub ReconnectBanner(busy: bool, onReconnect: Callable[[], None]) -> JsxElement {
    return
        <div
            className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-warning/50 bg-warning/10 p-3 animate-in fade-in slide-in-from-top-1 duration-300"
        >
            <div className="flex min-w-0 items-start gap-2.5">
                <WarnIcon size={16} className="mt-0.5 shrink-0 text-warning"/>
                <div className="min-w-0 space-y-0.5">
                    <div className="text-sm font-medium">
                        GitHub rejected the last request
                    </div>
                    <p className="text-xs text-muted-foreground">
                        The installation was removed, or its repository access changed. Reconnect to grant it again. Nothing on the board is affected.
                    </p>
                </div>
            </div>
            <Button size="sm" onClick={onReconnect} disabled={busy}>
                {if busy {
                    <Spinner key="sp"/>
                }}
                {"Opening GitHub…" if busy else "Reconnect"}
            </Button>
        </div>;
}
