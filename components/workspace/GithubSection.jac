"""The Workspace's GitHub section: the App installation, the repositories it
reads and what each one may do on its own. GitHub sends the install round
trip to /github, which mounts this section at once, so the mount handler
finishes it first and scrubs the params (the nonce is one-shot).
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
    SetRepoLabelSync,
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
import from ..common.Chevron { Chevron }
import from ..common.Reveal { Reveal }
import from .ConfirmDialog { ConfirmDialog }
import from .GithubFrame { GithubFrame }
import from .GithubHead { GithubConnNote, GithubConnActions }
import from .GithubListBar { GithubListBar }
import from .GithubNoRepo { GithubNoRepo }
import from .GithubRepoTable { GithubRepoTable }
import from .GithubSearchBox { GithubSearchBox }
import from .SectionPanel { SectionPanel, FLUSH }
import from .icons { IconGithub }
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
     LIVE_WINDOW_MINUTES: float = 60.0;

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

# `syncKey` moves each time the page finishes a read, so a write made in another
# section reaches these lists; `onChanged` is the page's reload after a write here.
def:pub GithubSection(
    openNonce: int = 0, syncKey: int = 0, onChanged: Callable[[], any] = None
) -> JsxElement {
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
        # The repository table is the section's resting view; a repository's
        # issue and pull request lists take over the panel while this is on.
        listOpen: bool = False,
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
        handled: Ref[any] = Ref(),
        followed: Ref[any] = Ref();

    async can with entry {
        boot();
    }

    # Repo, tab, state filters and the committed search all address the same
    # two reads, so one dependent effect covers every change, and only while a
    # list is open. Search only commits the query here, sidestepping the
    # stale-snapshot trap.
    async can with (repoId, listOpen, tab, issueState, prState, searchQuery) entry {
        if repoId and listOpen {
            if tab == "issues" {
                loadIssues(True, False);
            } else {
                loadPulls(True, False);
            }
        }
    }

    # The address bar mirrors an open list, so a triage view can be bookmarked
    # or shared and survives a refresh; the resting table leaves it alone.
    can with (repoId, listOpen, tab, searchQuery) entry {
        w: any = window;
        if repoId and listOpen {
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
    def adoptLists(ws: dict[str, any]) -> None;
    async def followPage -> None;
    async def tellPage -> None;
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
    async def toggleLabelSync(rid: str, enabled: bool) -> None;
    async def loadIssues(reset: bool, refresh: bool) -> None;
    async def loadPulls(reset: bool, refresh: bool) -> None;
    async def refreshList -> None;
    async def importSelected -> None;
    def toggleIssue(number: int) -> None;
    def selectRepo(value: str) -> None;
    def openList(value: str) -> None;
    def closeList -> None;
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

    if not followed.current {
        followed.current = syncKey + 1;
    }

    useEffect(
        lambda { if syncKey + 1 != followed.current {
            followed.current = syncKey + 1;
            followPage();
        }},
        [syncKey]
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
    repoName = "";
    for rp in repos {
        if rp.id == repoId {
            repoProjectName = rp.project_name;
            repoName = rp.full_name;
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
    return
        <SectionPanel
            section="github"
            title="GitHub"
            note={<GithubConnNote
                avatar={avatar}
                login={login}
                liveNow={liveNow}
                lastEventAgo={lastEventAgo}
                syncLine={syncLine}
                stamps={exactStamps}
            />
                if connected and not loading
                else None}
            actions={<GithubConnActions
                syncing={syncing}
                onSync={syncNow}
                onResync={resyncAll}
                onDisconnect={lambda { confirmDisconnect = True; }}
            />
                if connected and not loading
                else None}
        >
            {if invalid {
                <div key="banner" className="px-4 pt-4">
                    <ReconnectBanner busy={starting} onReconnect={startInstall}/>
                </div>
            }}
            <Reveal ready={not loading} frame={<GithubFrame/>}>
                {if not connected {
                    <div key="connect" className={FLUSH}>
                        <ConnectCard
                            starting={starting}
                            missing={configGaps}
                            onInstall={startInstall}
                        />
                    </div>
                } elif not listOpen {
                    <div key="table">
                        {if len(repos) == 0 {
                            <GithubNoRepo key="none" onAdd={openPicker}/>
                        } else {
                            <GithubRepoTable
                                key="rows"
                                repos={repos}
                                onOpen={openList}
                                onAdd={openPicker}
                                onSync={toggleAutoSync}
                                onDone={toggleAutoDone}
                                onClose={toggleAutoClose}
                                onLabels={toggleLabelSync}
                            />
                        } }
                    </div>
                } else {
                    <div key="work" className="flex flex-col gap-3 p-4">
                        <div>
                            <Button
                                variant="ghost"
                                size="sm"
                                className="-ml-2 text-muted-foreground"
                                onClick={closeList}
                            >
                                <Chevron facing="left"/>
                                All repositories
                            </Button>
                        </div>
                        <div
                            className="grid items-start gap-5 lg:grid-cols-[220px_minmax(0,1fr)]"
                        >
                            <RepoRail
                                repos={repos}
                                selected={repoId}
                                onSelect={selectRepo}
                                onAdd={openPicker}
                            />
                            <div className="flex min-w-0 flex-col gap-4">
                                {if not repoId {
                                    <div key="norepo" className="surface">
                                        <GithubNoRepo onAdd={openPicker}/>
                                    </div>
                                } else {
                                    <div
                                        key="repo"
                                        className="flex min-w-0 flex-col gap-4"
                                    >
                                        <div
                                            className="flex flex-wrap items-center gap-x-3 gap-y-2"
                                        >
                                            <IconGithub size={18} className="shrink-0"/>
                                            <h3
                                                className="num min-w-0 truncate text-base font-semibold"
                                            >
                                                {repoName}
                                            </h3>
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
                                                onLabels={lambda (v: bool) { toggleLabelSync(
                                                    r.id, v
                                                ); }}
                                            />
                                        }}
                                        <div className="surface">
                                            <GithubListBar
                                                tab={tab}
                                                state={issueState
                                                    if tab == "issues"
                                                    else prState}
                                                countNum={countNum}
                                                countWord={countWord}
                                                listAge={listAge}
                                                showAge={not searchQuery}
                                                refreshing={refreshing}
                                                refreshBusy={refreshing
                                                    or issueLoading
                                                    or prLoading}
                                                onTab={lambda (v: str) { tab = v; }}
                                                onState={lambda (v: str) { if tab
                                                    == "issues" {
                                                    issueState = v;
                                                } else {
                                                    prState = v;
                                                } }}
                                                onRefresh={refreshList}
                                            >
                                                <GithubSearchBox
                                                    label={"Search issues"
                                                        if tab == "issues"
                                                        else "Search pull requests"}
                                                    draft={searchDraft}
                                                    committed={searchQuery}
                                                    onDraft={lambda (v: str) { searchDraft = v; }}
                                                    onRun={runSearch}
                                                    onClear={clearSearch}
                                                />
                                            </GithubListBar>
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
                    </div>
                }  }
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
        </SectionPanel>;
}
