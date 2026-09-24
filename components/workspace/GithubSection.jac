"""The Workspace's GitHub section: the App installation, the repositories it
reads and what each one may do on its own. GitHub sends the install round
trip to /github, which renders this section, so the mount handler finishes
it first and scrubs the params (the nonce is one-shot).
"""

import from ...lib.session { GITHUB_KEY }
import from ...models {
    Project,
    RepoView,
    StepView,
    GithubConnectionView,
    GhRepoRow,
    GhIssueRow,
    GhPrRow
}
import from ...services.github.github {
    GithubStatus,
    StartGithubInstall,
    CompleteGithubInstall,
    DisconnectGithub,
    ListGithubRepos,
    ListRepoIssues,
    ListRepoPulls,
    SearchRepoItems,
    ImportIssues,
    SetRepoAutoSync,
    SetRepoAutoDone,
    SetRepoAutoClose,
    SyncGithub
}
import from ...services.roster.roster { ListRepos, AddRepo }
import from ...lib.workspace { loadWorkspace, forgetWorkspace }
import from ...components.github.ConnectCard { ConnectCard }
import from ...components.github.ReconnectBanner { ReconnectBanner }
import from ...components.github.RepoPicker { RepoPicker }
import from ...components.github.RepoRail { RepoRail }
import from ...components.github.RepoAutomation { RepoAutomation }
import from ...components.github.IssueImportTable { IssueImportTable }
import from ...components.github.PrTable { PrTable }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ...components.ui.skeleton { Skeleton }
import from ..common.Reveal { Reveal }
import from .ConfirmDialog { ConfirmDialog }
import from .icons { IconGithub, IconPlus, IconSearch, IconSync, IconX }
import from "sonner" { toast }
import from "react" { useEffect }

# GitHub's redirect is finished once per page load. The page used to mount
# twice on a full load (a remount is still one route change away) and every
# mount runs `boot`, so the in-flight callback lives in module state: the
# first mount starts it, every mount awaits it before it reads status
# (issue #187). A dict cell, so a function never rebinds a glob.
glob INSTALL_ONCE: dict[str, any] = {"pending": None},
     # One "Sync now" press reads at most this many increments; the server
     # bounds each one by its own page and time budget.
     SYNC_ROUNDS: int = 6,
     # GitHub events arriving inside this window mean live updates are
     # working; the same window the server uses to shorten its cooldown.
     LIVE_WINDOW_MINUTES: float = 60.0,
     ISSUE_STATES: list[list[str]] = [
         ["open", "Open"],
         ["closed", "Closed"],
         ["all", "Every state"]
     ];

# "2026-08-03T14:20:05" -> "2026-08-03 14:20". Empty in, empty out.
def shortStamp(iso: str) -> str {
    if not iso {
        return "";
    }
    return iso[:16].replace("T", " ");
}

def minutesSince(iso: str) -> float {
    if not iso {
        return -1.0;
    }
    then = new(Date, iso);
    now = new(Date);
    ms: float = (now.getTime() - then.getTime()) as float;
    if ms < 0.0 {
        ms = 0.0;
    }
    return ms / 60000.0;
}

# Relative "3d ago" label from an ISO stamp. Empty in, empty out; anything
# older than a month falls back to the plain date. No date libs, just an
# explicit if-chain over truncated divisions.
def timeAgo(iso: str) -> str {
    if not iso {
        return "";
    }
    mins = int(minutesSince(iso));
    if mins < 1 {
        return "just now";
    }
    if mins < 60 {
        return str(mins) + "m ago";
    }
    hours = int(mins / 60);
    if hours < 24 {
        return str(hours) + "h ago";
    }
    days = int(hours / 24);
    if days < 31 {
        return str(days) + "d ago";
    }
    return iso[:10];
}

# Whether this browser last saw the workspace connected, so the first load
# draws the frame the page will most likely land on.
def wasConnected -> bool {
    try {
        return localStorage.getItem(GITHUB_KEY) == "1";
    } except Exception as e {
        return False;
    }
}

def:pub GithubSection(openNonce: int = 0) -> JsxElement {
    has conn: GithubConnectionView | None = None,
        configGaps: list[str] = [],
        loading: bool = True,
        starting: bool = False,
        confirmDisconnect: bool = False,
        disconnecting: bool = False,
        syncing: bool = False,
        repos: list[RepoView] = [],
        projects: list[Project] = [],
        repoId: str = "",
        tab: str = "issues",
        # The committed search: set on an explicit action only (GitHub's
        # search API allows ~30 requests a minute, so never per keystroke).
        # The draft is what sits in the input box.
        searchQuery: str = "",
        searchDraft: str = "",
        pickerOpen: bool = False,
        pickerQuery: str = "",
        pickerRows: list[GhRepoRow] = [],
        pickerLoading: bool = False,
        pickerPage: int = 1,
        # The query the loaded rows answer, live across awaits: a new search
        # must win over a "more" page that started before it.
        pickerRef: Ref[any] = Ref(),
        pickerMore: bool = False,
        pickerLoadingMore: bool = False,
        pickerProject: str = "",
        attaching: str = "",
        issues: list[GhIssueRow] = [],
        issueState: str = "open",
        issuePage: int = 1,
        issueHasMore: bool = False,
        issueLoading: bool = False,
        issueMore: bool = False,
        # When the server last read each list from GitHub (the stored page's
        # stamp); empty until a list has been read once.
        issueSyncedAt: str = "",
        prSyncedAt: str = "",
        refreshing: bool = False,
        selected: list[int] = [],
        # Destination for a repo added without a project; "none" keeps the
        # import inheriting nothing. A repo WITH a project ignores this.
        importProject: str = "none",
        importStatus: str = "Backlog",
        steps: list[StepView] = [],
        importStep: str = "",
        importing: bool = False,
        pulls: list[GhPrRow] = [],
        prState: str = "open",
        prPage: int = 1,
        prHasMore: bool = False,
        prLoading: bool = False,
        prMore: bool = False,
        handled: Ref[any] = Ref();

    async can with entry {
        boot();
    }

    # Repo, tab, state filters and the committed search all address the same
    # two reads, so one dependent effect covers every change. Search only
    # commits the query here, sidestepping the stale-snapshot trap.
    async can with (repoId, tab, issueState, prState, searchQuery) entry {
        if repoId {
            if tab == "issues" {
                loadIssues(True, False);
            } else {
                loadPulls(True, False);
            }
        }
    }

    # The address bar mirrors what is on screen, so a triage view can be
    # bookmarked or shared and survives a refresh.
    can with (repoId, tab, searchQuery) entry {
        w: any = window;
        if repoId {
            qs = "?tab=github&repo=" + repoId + "&view=" + tab;
            if searchQuery {
                qs = qs + "&q=" + encodeURIComponent(searchQuery);
            }
            blank: dict[str, any] = {};
            w.history.replaceState(blank, "", "/workspace" + qs);
        }
    }

    async def boot -> None;
    async def finishInstall(code: str, installId: int, state: str) -> None;
    async def loadStatus -> None;
    async def loadShared -> None;
    async def startInstall -> None;
    async def disconnect -> None;
    async def syncNow -> None;
    async def resyncAll -> None;
    async def runSync(full: bool) -> None;
    async def openPicker -> None;
    async def searchRepos -> None;
    async def moreRepos -> None;
    async def attachRepo(fullName: str) -> None;
    async def toggleAutoSync(rid: str, enabled: bool) -> None;
    async def toggleAutoDone(rid: str, enabled: bool) -> None;
    async def toggleAutoClose(rid: str, enabled: bool) -> None;
    async def loadIssues(reset: bool, refresh: bool) -> None;
    async def loadPulls(reset: bool, refresh: bool) -> None;
    async def refreshList -> None;
    async def importSelected -> None;
    def toggleIssue(number: int) -> None;
    def selectRepo(value: str) -> None;
    def runSearch -> None;
    def clearSearch -> None;

    # Something outside the page (the command palette, a header action) asks
    # for the picker by bumping a counter; `handled` stores (nonce + 1) so a
    # fresh ref reads as 0 and a remount records it instead of firing.
    if not handled.current {
        handled.current = openNonce + 1;
    }

    useEffect(
        lambda { if openNonce + 1 != handled.current {
            handled.current = openNonce + 1;
            openPicker();
        }},
        [openNonce]
    );

    # Initialised before the branch: a name first assigned inside an `if` is
    # block-scoped in the compiled JS and is gone after it.
    connected = False;
    invalid = False;
    login = "";
    avatar = "";
    connectedAgo = "";
    lastSyncAgo = "";
    lastEventAgo = "";
    liveNow = False;
    exactStamps = "";
    if conn {
        connected = conn.connected;
        invalid = conn.status == "invalid";
        login = conn.account_login;
        avatar = conn.account_avatar;
        connectedAgo = timeAgo(conn.connected_at);
        lastSyncAgo = timeAgo(conn.last_sync_at);
        lastEventAgo = timeAgo(conn.webhook_seen_at);
        liveNow = bool(conn.webhook_seen_at)
            and minutesSince(conn.webhook_seen_at) < LIVE_WINDOW_MINUTES;
        exactStamps = shortStamp(conn.connected_at);
        if conn.last_sync_at {
            exactStamps = exactStamps + " · last sync " + shortStamp(conn.last_sync_at);
        }
        if conn.webhook_seen_at {
            exactStamps = exactStamps
                + " · last event "
                + shortStamp(conn.webhook_seen_at);
        }
    }
    # Webhook and sync stamps belong to the installation, not a repository, so
    # the status sits in the connection strip beside the account.
    syncLine = "The server syncs every five minutes";
    if lastEventAgo and not liveNow {
        syncLine = "Last GitHub event " + lastEventAgo;
    }
    syncLine = syncLine
        + ((" · synced " + lastSyncAgo) if lastSyncAgo else " · not synced yet");
    if connectedAgo {
        exactStamps = "Connected " + connectedAgo + " (" + exactStamps + ")";
    }
    # The import destination is the repo's own project, chosen when the repo
    # was added; the import bar shows it instead of asking every time.
    repoProjectName: str = "";
    for rp in repos {
        if rp.id == repoId {
            repoProjectName = rp.project_name;
        }
    }
    shownCount = len(issues) if tab == "issues" else len(pulls);
    moreLeft = issueHasMore if tab == "issues" else prHasMore;
    countNum = str(shownCount) + ("+" if moreLeft else "");
    countWord = " issues" if tab == "issues" else " pull requests";
    if shownCount == 1 and not moreLeft {
        countWord = " issue" if tab == "issues" else " pull request";
    }
    # The list is the page the server stored; the stamp says how old it is.
    listSyncedAt = issueSyncedAt if tab == "issues" else prSyncedAt;
    listAge = ("read " + timeAgo(listSyncedAt)) if listSyncedAt else "not read yet";
    def loadFrame -> JsxElement {
        return
            <div key="sk" aria-busy="true">
                {if wasConnected() {
                    <div
                        key="two"
                        className="grid items-start gap-5 lg:grid-cols-[250px_minmax(0,1fr)]"
                    >
                        <RepoRail
                            repos={[]}
                            selected=""
                            onSelect={selectRepo}
                            onAdd={openPicker}
                            placeholder={2}
                        />
                        <div className="flex min-w-0 flex-col gap-4">
                            <div className="flex h-7 items-center gap-3">
                                <Skeleton
                                    className="size-[18px] shrink-0 rounded-full"
                                />
                                <Skeleton className="h-4 w-48"/>
                                <Skeleton className="h-3 w-40"/>
                            </div>
                            <div className="surface">
                                <div
                                    className="flex flex-wrap items-center gap-2 border-b px-3 py-2"
                                >
                                    <div
                                        className="inline-flex items-center gap-0.5 rounded-md border bg-muted p-0.5"
                                    >
                                        <span
                                            className="rounded-sm bg-card px-2.5 py-1 text-[13px] font-semibold text-foreground"
                                        >
                                            Issues
                                        </span>
                                        <span
                                            className="px-2.5 py-1 text-[13px] text-muted-foreground"
                                        >
                                            Pull requests
                                        </span>
                                    </div>
                                    <Skeleton className="h-[30px] w-20 rounded-md"/>
                                    <Skeleton className="h-3 w-16"/>
                                    <div className="ml-auto w-full sm:w-56">
                                        <Skeleton className="h-8 w-full rounded-md"/>
                                    </div>
                                </div>
                                <div className="flex flex-col gap-1 p-3">
                                    {for i in [0, 1, 2, 3, 4] {
                                        <div
                                            key={"row" + str(i)}
                                            className="flex items-center gap-3 py-2"
                                        >
                                            <Skeleton
                                                className="size-4 shrink-0 rounded-xs"
                                            />
                                            <Skeleton className="h-4 w-10 shrink-0"/>
                                            <Skeleton className="h-4 w-full max-w-80"/>
                                            <Skeleton
                                                className="ml-auto hidden h-4 w-16 shrink-0 sm:block"
                                            />
                                        </div>
                                    }}
                                </div>
                            </div>
                        </div>
                    </div>
                } else {
                    <div
                        key="card"
                        className="surface grid gap-8 p-6 md:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)] md:gap-0 md:p-0"
                    >
                        <div className="flex flex-col items-start gap-4 md:p-7">
                            <Skeleton className="size-7 rounded-full"/>
                            <div className="flex h-[30px] items-center">
                                <Skeleton className="h-5 w-72 max-w-full"/>
                            </div>
                            <div className="flex w-full flex-col gap-2.5 pl-5">
                                <Skeleton className="h-3.5 w-64 max-w-full"/>
                                <Skeleton className="h-3.5 w-56 max-w-full"/>
                                <Skeleton className="h-3.5 w-72 max-w-full"/>
                            </div>
                            <Skeleton className="h-9 w-36 rounded-md"/>
                        </div>
                        <div className="border-t pt-6 md:border-t-0 md:border-l md:p-7">
                            <Skeleton className="h-3.5 w-44"/>
                            <div className="mt-2 flex flex-col">
                                {for i in [0, 1, 2] {
                                    <div
                                        key={"perm" + str(i)}
                                        className="flex items-center border-b py-2.5 last:border-b-0"
                                    >
                                        <Skeleton
                                            className={"h-3.5 "
                                                + ("w-3/4" if i else "w-2/3")}
                                        />
                                    </div>
                                }}
                            </div>
                            <Skeleton className="mt-3 h-3 w-56"/>
                            <Skeleton className="mt-2 h-3 w-48"/>
                        </div>
                    </div>
                } }
            </div>;
    }

    return
        <div className="flex w-full flex-col gap-5">
            <div className="flex flex-wrap items-center gap-x-6 gap-y-2">
                <h1 className="page-title text-xl">GitHub</h1>
                {if connected and not loading {
                    <div
                        key="conn"
                        className="flex flex-wrap items-center gap-x-3 gap-y-2 sm:ml-auto"
                    >
                        {if avatar {
                            <img
                                key="pic"
                                src={avatar}
                                alt=""
                                className="size-6 shrink-0 rounded-full border"
                            />
                        }}
                        <span className="num text-[13px] font-medium">
                            {"@" + login}
                        </span>
                        {if liveNow {
                            <span
                                key="live"
                                className="flex items-center gap-1.5 text-[12.5px] text-success"
                                title={exactStamps}
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
                                title={exactStamps}
                            >
                                {syncLine}
                            </span>
                        } }
                        <div className="flex items-center gap-2">
                            <Button
                                variant="outline"
                                size="sm"
                                onClick={syncNow}
                                disabled={syncing}
                            >
                                <IconSync/>
                                {"Syncing…" if syncing else "Sync now"}
                            </Button>
                            <Button
                                variant="ghost"
                                size="sm"
                                onClick={resyncAll}
                                disabled={syncing}
                                title="Read every issue again and refresh what an earlier import stamped"
                            >
                                {"Re-sync history"}
                            </Button>
                            <Button
                                variant="outline"
                                size="sm"
                                onClick={lambda { confirmDisconnect = True; }}
                            >
                                Disconnect
                            </Button>
                        </div>
                    </div>
                }}
            </div>
            {if invalid {
                <ReconnectBanner
                    key="banner"
                    busy={starting}
                    onReconnect={startInstall}
                />
            }}
            <Reveal ready={not loading} frame={loadFrame()}>
                {if not connected {
                    <div key="connect">
                        <ConnectCard
                            starting={starting}
                            missing={configGaps}
                            onInstall={startInstall}
                        />
                    </div>
                } else {
                    <div
                        key="work"
                        className="grid items-start gap-5 lg:grid-cols-[250px_minmax(0,1fr)]"
                    >
                        <RepoRail
                            repos={repos}
                            selected={repoId}
                            onSelect={selectRepo}
                            onAdd={openPicker}
                        />
                        <div className="flex min-w-0 flex-col gap-4">
                            {if not repoId {
                                <div
                                    key="norepo"
                                    className="surface flex flex-col items-center gap-2 px-6 py-12 text-center"
                                >
                                    <p className="text-sm font-semibold">
                                        No repository yet
                                    </p>
                                    <p
                                        className="max-w-sm text-sm text-muted-foreground"
                                    >
                                        Add one of the repositories you granted the App, and pick the project its issues land in.
                                    </p>
                                    <Button
                                        size="sm"
                                        className="mt-1"
                                        onClick={openPicker}
                                    >
                                        <IconPlus/>
                                        Add repository
                                    </Button>
                                </div>
                            } else {
                                <div key="repo" className="flex min-w-0 flex-col gap-4">
                                    <div
                                        className="flex flex-wrap items-center gap-x-3 gap-y-2"
                                    >
                                        <IconGithub size={18} className="shrink-0"/>
                                        <h2
                                            className="num min-w-0 truncate text-base font-semibold"
                                        >
                                            {[
                                                r.full_name
                                                for r in repos
                                                if r.id == repoId
                                            ][0]
                                                if len(
                                                    [
                                                        r
                                                        for r in repos
                                                        if r.id == repoId
                                                    ]
                                                )
                                                    > 0
                                                else ""}
                                        </h2>
                                        <span
                                            className="text-[12.5px] text-muted-foreground"
                                        >
                                            {("Issues land in " + repoProjectName)
                                                if repoProjectName
                                                else "No project picked for its issues"}
                                        </span>
                                    </div>
                                    {for r in [
                                        x
                                        for x in repos
                                        if x.id == repoId
                                    ] {
                                        <RepoAutomation
                                            key={r.id}
                                            repo={r}
                                            onSync={lambda (v: bool) { toggleAutoSync(
                                                r.id, v
                                            ); }}
                                            onDone={lambda (v: bool) { toggleAutoDone(
                                                r.id, v
                                            ); }}
                                            onClose={lambda (v: bool) { toggleAutoClose(
                                                r.id, v
                                            ); }}
                                        />
                                    }}
                                    <div className="surface">
                                        <div
                                            className="flex flex-wrap items-center gap-2 border-b px-3 py-2"
                                        >
                                            <div
                                                className="inline-flex items-center gap-0.5 rounded-md border bg-muted p-0.5"
                                            >
                                                <button
                                                    type="button"
                                                    aria-pressed={tab == "issues"}
                                                    className={"rounded-sm px-2.5 py-1 text-[13px] "
                                                        + (
                                                            "bg-card font-semibold text-foreground"
                                                                if tab == "issues"
                                                                else "text-muted-foreground hover:text-foreground"
                                                        )}
                                                    onClick={lambda { tab = "issues"; }}
                                                >
                                                    Issues
                                                </button>
                                                <button
                                                    type="button"
                                                    aria-pressed={tab == "pulls"}
                                                    className={"rounded-sm px-2.5 py-1 text-[13px] "
                                                        + (
                                                            "bg-card font-semibold text-foreground"
                                                                if tab == "pulls"
                                                                else "text-muted-foreground hover:text-foreground"
                                                        )}
                                                    onClick={lambda { tab = "pulls"; }}
                                                >
                                                    Pull requests
                                                </button>
                                            </div>
                                            <Select
                                                value={issueState
                                                    if tab == "issues"
                                                    else prState}
                                                onValueChange={lambda (v: str) { if tab
                                                    == "issues" {
                                                    issueState = v;
                                                } else {
                                                    prState = v;
                                                } }}
                                            >
                                                <SelectTrigger
                                                    className="toolbar-filter"
                                                    aria-label="Filter by state"
                                                    data-active={"true"
                                                        if (
                                                            issueState
                                                                if tab == "issues"
                                                                else prState
                                                        )
                                                            != "open"
                                                        else "false"}
                                                >
                                                    <SelectValue placeholder="State"/>
                                                </SelectTrigger>
                                                <SelectContent>
                                                    {for s in ISSUE_STATES {
                                                        <SelectItem
                                                            key={s[0]}
                                                            value={s[0]}
                                                        >
                                                            {s[1]}
                                                        </SelectItem>
                                                    }}
                                                </SelectContent>
                                            </Select>
                                            <span className="text-xs text-subtle">
                                                <span className="num">{countNum}</span>
                                                {countWord}
                                            </span>
                                            {if not searchQuery {
                                                <span
                                                    key="age"
                                                    className="flex items-center gap-1 text-xs text-subtle"
                                                >
                                                    {"· " + listAge}
                                                    <button
                                                        type="button"
                                                        className="rounded-sm px-1.5 py-0.5 text-xs text-muted-foreground transition-colors duration-150 hover:bg-accent hover:text-foreground disabled:opacity-50"
                                                        onClick={refreshList}
                                                        disabled={refreshing
                                                            or issueLoading
                                                            or prLoading}
                                                        title="Read this list from GitHub again"
                                                    >
                                                        {"Refreshing…"
                                                            if refreshing
                                                            else "Refresh"}
                                                    </button>
                                                </span>
                                            }}
                                            <div
                                                className="relative ml-auto w-full sm:w-56"
                                            >
                                                <IconSearch
                                                    className="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-subtle"
                                                />
                                                <Input
                                                    value={searchDraft}
                                                    className={"h-8 pl-8 "
                                                        + (
                                                            "pr-14"
                                                                if searchDraft
                                                                    != searchQuery
                                                                else "pr-8"
                                                        )}
                                                    placeholder={"Search issues"
                                                        if tab == "issues"
                                                        else "Search pull requests"}
                                                    aria-label={"Search issues"
                                                        if tab == "issues"
                                                        else "Search pull requests"}
                                                    onChange={lambda (e: ChangeEvent) { searchDraft = e.target.value; }}
                                                    onKeyDown={lambda (
                                                        e: KeyboardEvent
                                                    ) { if e.key == "Enter" {
                                                        runSearch();
                                                    }}}
                                                />
                                                {if searchDraft != searchQuery {
                                                    <span
                                                        key="enter"
                                                        aria-hidden="true"
                                                        className="kbd pointer-events-none absolute top-1/2 right-8 -translate-y-1/2"
                                                    >
                                                        ↵
                                                    </span>
                                                }}
                                                {if searchQuery or searchDraft {
                                                    <button
                                                        key="clear"
                                                        type="button"
                                                        aria-label="Clear search"
                                                        className="absolute top-1/2 right-2 -translate-y-1/2 rounded-sm p-1 text-subtle transition-colors duration-150 hover:bg-accent hover:text-foreground"
                                                        onClick={clearSearch}
                                                    >
                                                        <IconX/>
                                                    </button>
                                                }}
                                            </div>
                                        </div>
                                        {if tab == "issues" {
                                            <IssueImportTable
                                                key="issues"
                                                rows={issues}
                                                loading={issueLoading}
                                                loadingMore={issueMore}
                                                hasMore={issueHasMore}
                                                state={issueState}
                                                selected={selected}
                                                projectName={repoProjectName}
                                                projects={[
                                                    p
                                                    for p in projects
                                                    if p.active
                                                ]}
                                                projectId={importProject}
                                                status={importStatus}
                                                steps={steps}
                                                stepId={importStep}
                                                query={searchQuery}
                                                importing={importing}
                                                onState={lambda (v: str) { issueState = v; }}
                                                onToggle={toggleIssue}
                                                onProject={lambda (v: str) { importProject = v; }}
                                                onStatus={lambda (v: str) { importStatus = v; }}
                                                onStep={lambda (v: str) { importStep = v; }}
                                                onImport={importSelected}
                                                onLoadMore={lambda { loadIssues(
                                                    False, False
                                                ); }}
                                                onClear={lambda { selected = []; }}
                                            />
                                        } else {
                                            <PrTable
                                                key="pulls"
                                                rows={pulls}
                                                loading={prLoading}
                                                loadingMore={prMore}
                                                hasMore={prHasMore}
                                                state={prState}
                                                query={searchQuery}
                                                onState={lambda (v: str) { prState = v; }}
                                                onLoadMore={lambda { loadPulls(
                                                    False, False
                                                ); }}
                                            />
                                        } }
                                    </div>
                                </div>
                            } }
                        </div>
                    </div>
                } }
            </Reveal>
            <RepoPicker
                open={pickerOpen}
                query={pickerQuery}
                rows={pickerRows}
                loading={pickerLoading}
                projects={[
                    p
                    for p in projects
                    if p.active
                ]}
                projectId={pickerProject}
                attaching={attaching}
                onQuery={lambda (v: str) { pickerQuery = v; }}
                onSearch={searchRepos}
                onProject={lambda (v: str) { pickerProject = v; }}
                onAttach={attachRepo}
                onOpenChange={lambda (o: bool) { pickerOpen = o; }}
                hasMore={pickerMore}
                loadingMore={pickerLoadingMore}
                onMore={moreRepos}
            />
            <ConfirmDialog
                open={confirmDisconnect}
                title="Disconnect GitHub?"
                body="Imported tasks and their links stay on the board. Flowline stops reading issues and pull requests, and every repository's automation stops with it."
                confirmLabel="Disconnect"
                busy={disconnecting}
                onConfirm={disconnect}
                onOpenChange={lambda (o: bool) { confirmDisconnect = o; }}
            />
        </div>;
}
