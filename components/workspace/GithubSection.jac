"""flowline - GitHub page (/github): the App installation and what it reads.
GitHub sends the install round trip back to this URL as query params, so the
mount handler finishes it first and scrubs the params (the nonce is one-shot).
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
import from ...walkers.github {
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
    SetRepoAutoDone
}
import from ...components.ui.input { Input }
import from ...walkers.flowlines { GetFlowLine }
import from ...walkers.projects { ListProjects }
import from ...walkers.roster { ListRepos, AddRepo }
import from ...components.github.ConnectCard { ConnectCard }
import from ...components.github.ReconnectBanner { ReconnectBanner }
import from ...components.github.RepoPicker { RepoPicker }
import from ...components.github.IssueImportTable { IssueImportTable }
import from ...components.github.PrTable { PrTable }
import from ...components.ui.button { Button }
import from ...components.ui.card { Card, CardContent }
import from ...components.ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ...components.ui.skeleton { Skeleton }
import from ...components.ui.checkbox { Checkbox }
import from "sonner" { toast }
import from "react" { useEffect }

# "2026-08-03T14:20:05" -> "2026-08-03 14:20". Empty in, empty out.
def shortStamp(iso: str) -> str {
    if not iso {
        return "";
    }
    return iso[:16].replace("T", " ");
}

# Relative "3d ago" label from an ISO stamp. Empty in, empty out; anything
# older than a month falls back to the plain date. No date libs, just an
# explicit if-chain over truncated divisions.
def timeAgo(iso: str) -> str {
    if not iso {
        return "";
    }
    then = new(Date, iso);
    now = new(Date);
    ms = now.getTime() - then.getTime();
    if ms < 0 {
        ms = 0;
    }
    mins = int(ms / 60000);
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
        pickerProject: str = "none",
        attaching: str = "",
        issues: list[GhIssueRow] = [],
        issueState: str = "open",
        issuePage: int = 1,
        issueHasMore: bool = False,
        issueLoading: bool = False,
        issueMore: bool = False,
        selected: list[int] = [],
        # Destination for a repo attached without a project; "none" keeps the
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
    async def loadStatus -> None;
    async def loadWorkspace -> None;
    async def startInstall -> None;
    async def disconnect -> None;
    async def openPicker -> None;
    async def searchRepos -> None;
    async def moreRepos -> None;
    async def attachRepo(fullName: str) -> None;
    async def toggleAutoSync(rid: str, enabled: bool) -> None;
    async def toggleAutoDone(rid: str, enabled: bool) -> None;
    async def loadIssues(reset: bool) -> None;
    async def loadPulls(reset: bool) -> None;
    async def importSelected -> None;
    def toggleIssue(number: int) -> None;
    def selectRepo(value: str) -> None;
    def runSearch -> None;
    def clearSearch -> None;

    # The page header owns this tab's primary action and signals it by bumping
    # a counter. Switching tabs UNMOUNTS this panel, so the effect re-runs on
    # remount; `handled` stores (nonce + 1) so a fresh ref reads as 0 and a
    # remount records the current value instead of firing the action again.
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
    connectedAt = "";
    lastSync = "";
    connectedAgo = "";
    lastSyncAgo = "";
    if conn {
        connected = conn.connected;
        invalid = conn.status == "invalid";
        login = conn.account_login;
        avatar = conn.account_avatar;
        connectedAt = shortStamp(conn.connected_at);
        lastSync = shortStamp(conn.last_sync_at);
        connectedAgo = timeAgo(conn.connected_at);
        lastSyncAgo = timeAgo(conn.last_sync_at);
    }
    exactStamps = connectedAt;
    if lastSync {
        exactStamps = exactStamps + " · last sync " + lastSync;
    }

    # The import destination is the repo's own project, chosen when the repo
    # was attached; the import bar shows it instead of asking every time.
    repoProjectName: str = "";
    for rp in repos {
        if rp.id == repoId {
            repoProjectName = rp.project_name;
        }
    }

    return
        <div className="space-y-6">
            {if invalid {
                <ReconnectBanner
                    key="banner"
                    busy={starting}
                    onReconnect={startInstall}
                />
            }}
            {if loading {
                <div key="sk" className="space-y-6">
                    <div
                        className="flex items-center gap-4 rounded-xl border bg-card p-4"
                    >
                        <Skeleton className="h-10 w-10 shrink-0 rounded-full"/>
                        <div className="min-w-0 flex-1 space-y-2">
                            <Skeleton className="h-4 w-32"/>
                            <Skeleton className="h-3 w-56 max-w-full"/>
                        </div>
                        <Skeleton className="h-7 w-24 rounded-lg"/>
                    </div>
                    <div className="flex items-center gap-2">
                        <Skeleton className="h-8 w-64 rounded-lg"/>
                        <Skeleton className="ml-auto h-8 w-44 rounded-lg"/>
                    </div>
                    <Skeleton className="h-64 w-full rounded-xl"/>
                </div>
            } else {
                <div key="body" className="space-y-6">
                    {if not connected {
                        <ConnectCard
                            key="connect"
                            starting={starting}
                            missing={configGaps}
                            onInstall={startInstall}
                        />
                    } else {
                        <div key="work" className="space-y-6">
                            <Card className="py-0">
                                <CardContent
                                    className="flex flex-wrap items-center gap-4 py-4"
                                >
                                    {if avatar {
                                        <img
                                            key="pic"
                                            src={avatar}
                                            alt=""
                                            className="h-10 w-10 shrink-0 rounded-full border"
                                        />
                                    }}
                                    <div className="min-w-0">
                                        <div className="font-medium">{"@" + login}</div>
                                        <p
                                            className="text-xs tabular-nums text-muted-foreground"
                                            title={exactStamps}
                                        >
                                            {"Connected " + connectedAgo
                                                if connectedAgo
                                                else "Connected"}{" · last sync "
                                                + lastSyncAgo
                                                if lastSyncAgo
                                                else " · not synced yet"}
                                        </p>
                                    </div>
                                    <div className="ml-auto flex items-center gap-3">
                                        <span
                                            key="warn"
                                            aria-hidden={not confirmDisconnect}
                                            title="Imported tasks and links stay. Flowline just stops talking to GitHub."
                                            className={"overflow-hidden whitespace-nowrap text-xs text-muted-foreground transition-all duration-300 ease-out "
                                                + (
                                                    "max-w-56 opacity-100"
                                                        if confirmDisconnect
                                                        else "max-w-0 opacity-0"
                                                )}
                                        >
                                            Imported tasks and links stay.
                                        </span>
                                        <Button
                                            variant={"destructive"
                                                if confirmDisconnect
                                                else "outline"}
                                            size="sm"
                                            onClick={disconnect}
                                        >
                                            {"Click again to disconnect"
                                                if confirmDisconnect
                                                else "Disconnect"}
                                        </Button>
                                    </div>
                                </CardContent>
                            </Card>
                            <div className="flex flex-wrap items-center gap-2">
                                <Select value={repoId} onValueChange={selectRepo}>
                                    <SelectTrigger className="w-64">
                                        <SelectValue placeholder="Pick a repo"/>
                                    </SelectTrigger>
                                    <SelectContent>
                                        {for r in repos {
                                            <SelectItem key={r.id} value={r.id}>
                                                {r.full_name}
                                            </SelectItem>
                                        }}
                                    </SelectContent>
                                </Select>
                                {for r in [
                                    x
                                    for x in repos
                                    if x.id == repoId
                                ] {
                                    <label
                                        key={"auto-" + r.id}
                                        className="flex cursor-pointer items-center gap-2 whitespace-nowrap text-xs text-muted-foreground"
                                        title="New issues in this repo become cards on the entry step whenever the board syncs"
                                    >
                                        <Checkbox
                                            checked={r.auto_sync}
                                            onCheckedChange={lambda { toggleAutoSync(
                                                r.id, not r.auto_sync
                                            ); }}
                                        />
                                        Auto-add new issues
                                    </label>
                                }}
                                {for r in [
                                    x
                                    for x in repos
                                    if x.id == repoId
                                ] {
                                    <label
                                        key={"done-" + r.id}
                                        className="flex cursor-pointer items-center gap-2 whitespace-nowrap text-xs text-muted-foreground"
                                        title="A merged PR or a closed issue moves its card to the done step on the next sync"
                                    >
                                        <Checkbox
                                            checked={r.auto_done}
                                            onCheckedChange={lambda { toggleAutoDone(
                                                r.id, not r.auto_done
                                            ); }}
                                        />
                                        Done on merge &amp; close
                                    </label>
                                }}
                                {for r in [
                                    x
                                    for x in repos
                                    if x.id == repoId and x.project_name
                                ] {
                                    <span
                                        key={"proj-" + r.id}
                                        className="hidden items-center gap-1 whitespace-nowrap text-xs text-muted-foreground lg:inline-flex"
                                        title={"Issues from this repo land in "
                                            + r.project_name}
                                    >
                                        <svg
                                            width={12}
                                            height={12}
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            strokeWidth={2}
                                            strokeLinecap="round"
                                        >
                                            <path d="M5 12h14"/>
                                            <path d="m12 5 7 7-7 7"/>
                                        </svg>
                                        {r.project_name}
                                    </span>
                                }}
                                <div className="relative min-w-56 flex-1 sm:max-w-xs">
                                    <svg
                                        className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground"
                                        width={14}
                                        height={14}
                                        viewBox="0 0 24 24"
                                        fill="none"
                                        stroke="currentColor"
                                        strokeWidth={2}
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                    >
                                        <circle cx={11} cy={11} r={8}/>
                                        <path d="m21 21-4.3-4.3"/>
                                    </svg>
                                    <Input
                                        value={searchDraft}
                                        placeholder={"Search issues, Enter to run"
                                            if tab == "issues"
                                            else "Search pull requests, Enter to run"}
                                        className="pl-8 pr-8"
                                        onChange={lambda (e: ChangeEvent) { searchDraft = e.target.value; }}
                                        onKeyDown={lambda (e: any) { if e.key
                                            == "Enter" {
                                            runSearch();
                                        }}}
                                    />
                                    {if searchQuery or searchDraft {
                                        <button
                                            key="clear"
                                            type="button"
                                            aria-label="Clear search"
                                            className="absolute right-1.5 top-1/2 -translate-y-1/2 rounded-full p-1 text-muted-foreground transition-colors hover:bg-accent hover:text-foreground"
                                            onClick={clearSearch}
                                        >
                                            <svg
                                                width={12}
                                                height={12}
                                                viewBox="0 0 24 24"
                                                fill="none"
                                                stroke="currentColor"
                                                strokeWidth={2}
                                                strokeLinecap="round"
                                            >
                                                <path d="M18 6 6 18"/>
                                                <path d="m6 6 12 12"/>
                                            </svg>
                                        </button>
                                    }}
                                </div>
                                <div
                                    className="ml-auto inline-flex items-center gap-0.5 rounded-lg border border-border/70 bg-muted p-0.5"
                                >
                                    <button
                                        type="button"
                                        className={"rounded-md bg-background px-2.5 py-1 text-sm font-medium text-foreground shadow-sm"
                                            if tab == "issues"
                                            else "rounded-md px-2.5 py-1 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"}
                                        onClick={lambda { tab = "issues"; }}
                                    >
                                        Issues
                                    </button>
                                    <button
                                        type="button"
                                        className={"rounded-md bg-background px-2.5 py-1 text-sm font-medium text-foreground shadow-sm"
                                            if tab == "pulls"
                                            else "rounded-md px-2.5 py-1 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"}
                                        onClick={lambda { tab = "pulls"; }}
                                    >
                                        Pull requests
                                    </button>
                                </div>
                            </div>
                            {if not repoId {
                                <Card key="norepo">
                                    <CardContent
                                        className="flex flex-col items-center gap-2 py-10 text-center"
                                    >
                                        <svg
                                            className="text-muted-foreground/50"
                                            width={28}
                                            height={28}
                                            viewBox="0 0 24 24"
                                            fill="none"
                                            stroke="currentColor"
                                            strokeWidth={2}
                                            strokeLinecap="round"
                                            strokeLinejoin="round"
                                        >
                                            <path
                                                d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"
                                            />
                                        </svg>
                                        <p className="mt-1 text-sm font-medium">
                                            No repo attached yet
                                        </p>
                                        <p className="text-sm text-muted-foreground">
                                            Attach a repo to read its issues and pull requests.
                                        </p>
                                        <Button
                                            size="sm"
                                            className="mt-2"
                                            onClick={openPicker}
                                        >
                                            Attach a repo
                                        </Button>
                                    </CardContent>
                                </Card>
                            } else {
                                <div key="tables">
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
                            } }
                        </div>
                    } }
                </div>
            } }
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
        </div>;
}
