"""flowline - GitHub page (/github): the App installation, the repositories it
reads and what each one is allowed to do on its own. GitHub sends the install
round trip back to this URL as query params, so the mount handler finishes it
first and scrubs the params (the nonce is one-shot).
"""

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
import from ...services.flowlines.flowlines { GetFlowLine }
import from ...services.projects.projects { ListProjects }
import from ...services.roster.roster { ListRepos, AddRepo }
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
import from .ConfirmDialog { ConfirmDialog }
import from .icons { IconGithub, IconPlus, IconSearch, IconSync, IconX }
import from "sonner" { toast }
import from "react" { useEffect }

# GitHub's redirect is finished once per page load. The page mounts twice on
# a full load and both mounts run `boot`, so the in-flight callback lives in
# module state: the first mount starts it, every mount awaits it before it
# reads status (issue #187). A dict cell, so a function never rebinds a glob.
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
                loadIssues(True);
            } else {
                loadPulls(True);
            }
        }
    }

    # The address bar mirrors what is on screen, so a triage view can be
    # bookmarked or shared and survives a refresh.
    can with (repoId, tab, searchQuery) entry {
        w: any = window;
        if str(w.location.pathname) == "/github" and repoId {
            qs = "?repo=" + repoId + "&tab=" + tab;
            if searchQuery {
                qs = qs + "&q=" + encodeURIComponent(searchQuery);
            }
            blank: dict[str, any] = {};
            w.history.replaceState(blank, "", "/github" + qs);
        }
    }

    async def boot -> None;
    async def finishInstall(code: str, installId: int, state: str) -> None;
    async def loadStatus -> None;
    async def loadWorkspace -> None;
    async def startInstall -> None;
    async def disconnect -> None;
    async def syncNow -> None;
    async def openPicker -> None;
    async def searchRepos -> None;
    async def moreRepos -> None;
    async def attachRepo(fullName: str) -> None;
    async def toggleAutoSync(rid: str, enabled: bool) -> None;
    async def toggleAutoDone(rid: str, enabled: bool) -> None;
    async def toggleAutoClose(rid: str, enabled: bool) -> None;
    async def loadIssues(reset: bool) -> None;
    async def loadPulls(reset: bool) -> None;
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
    syncLine = "Updates arrive when the board syncs";
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
    return
        <div className="flex w-full flex-col gap-5">
            <div className="flex flex-wrap items-center gap-x-6 gap-y-2">
                <h1 className="page-title">GitHub</h1>
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
            {if loading {
                <div key="sk" className="flex flex-col gap-5 lg:flex-row">
                    <Skeleton className="h-64 w-full lg:w-[250px]"/>
                    <Skeleton className="h-64 w-full flex-1"/>
                </div>
            } elif not connected {
                <ConnectCard
                    key="connect"
                    starting={starting}
                    missing={configGaps}
                    onInstall={startInstall}
                />
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
                                <p className="max-w-sm text-sm text-muted-foreground">
                                    Add one of the repositories you granted the App, and pick the project its issues land in.
                                </p>
                                <Button size="sm" className="mt-1" onClick={openPicker}>
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
                                                    <SelectItem key={s[0]} value={s[0]}>
                                                        {s[1]}
                                                    </SelectItem>
                                                }}
                                            </SelectContent>
                                        </Select>
                                        <span className="text-xs text-subtle">
                                            <span className="num">{countNum}</span>
                                            {countWord}
                                        </span>
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
                                                onKeyDown={lambda (e: KeyboardEvent) { if e.key
                                                    == "Enter" {
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
                                            onLoadMore={lambda { loadIssues(False); }}
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
                                            onLoadMore={lambda { loadPulls(False); }}
                                        />
                                    } }
                                </div>
                            </div>
                        } }
                    </div>
                </div>
            }  }
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
