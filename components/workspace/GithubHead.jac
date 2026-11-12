"""The GitHub panel's header while connected: the account and how live it is, and
the actions on the connection. Webhook and sync stamps belong to the
installation, not a repository, so they sit here.
"""

import from ...components.ui.button { Button }
import from .icons { IconSync }

def:pub GithubConnNote(
    avatar: str,
    login: str,
    liveNow: bool,
    lastEventAgo: str,
    syncLine: str,
    stamps: str
) -> JsxElement {
    return
        <div className="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1">
            {if avatar {
                <img
                    key="pic"
                    src={avatar}
                    alt=""
                    className="size-5 shrink-0 rounded-full border"
                />
            }}
            <span className="num text-[13px] font-medium">{"@" + login}</span>
            {if liveNow {
                <span
                    key="live"
                    className="flex items-center gap-1.5 text-[12.5px] text-success"
                    title={stamps}
                >
                    <span
                        aria-hidden="true"
                        className="size-[7px] shrink-0 rounded-full bg-success"
                    />
                    {"Live · last event " + lastEventAgo}
                </span>
            } else {
                <span
                    key="quiet"
                    className="text-[12.5px] text-muted-foreground"
                    title={stamps}
                >
                    {syncLine}
                </span>
            } }
        </div>;
}

def:pub GithubConnActions(
    syncing: bool,
    onSync: Callable[[], any],
    onResync: Callable[[], any],
    onDisconnect: Callable[[], None]
) -> JsxElement {
    return
        <>
            <Button variant="outline" size="sm" onClick={onSync} disabled={syncing}>
                <IconSync/>
                {"Syncing…" if syncing else "Sync now"}
            </Button>
            <Button
                variant="ghost"
                size="sm"
                onClick={onResync}
                disabled={syncing}
                title="Read every issue again and refresh what an earlier import stamped"
            >
                Re-sync history
            </Button>
            <Button variant="outline" size="sm" onClick={onDisconnect}>
                Disconnect
            </Button>
        </>;
}
