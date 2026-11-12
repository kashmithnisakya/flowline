"""The board's header actions: Sync GitHub while connected, and New task."""

import from ..ui.button { Button }
import from ..common.glyphs { Spinner }

def:pub BoardActions(
    ghConnected: bool,
    syncing: bool,
    syncNote: str,
    busy: bool,
    onSync: Callable[[], None],
    onNew: Callable[[], None]
) -> JsxElement {
    return
        <>
            {if ghConnected {
                <Button key="sync" variant="ghost" disabled={syncing} onClick={onSync}>
                    {if syncing {
                        <Spinner key="sp"/>
                    }}
                    <span>
                        {(syncNote or "Syncing…") if syncing else "Sync GitHub"}
                    </span>
                </Button>
            }}
            <Button disabled={busy} onClick={onNew}>
                New task
                <span
                    aria-hidden="true"
                    className="kbd kbd-on-accent ml-0.5 max-md:hidden"
                >
                    N
                </span>
            </Button>
        </>;
}
