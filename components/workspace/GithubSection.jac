"""standup - GitHub page (/github): the App installation and what it reads.

Stateful shell. GitHub sends the install round trip back to this very URL as
query params, so the mount handler finishes it before anything else runs, and
scrubs the params afterwards: the nonce is one-shot, and a refresh that
replayed it would only ever produce an error toast.
"""

import from ...models {
    Project, RepoView, GithubConnectionView, GhRepoRow, GhIssueRow, GhPrRow
}
import from ...walkers.github {
    GithubStatus, StartGithubInstall, CompleteGithubInstall, DisconnectGithub,
    ListGithubRepos, ListRepoIssues, ListRepoPulls, ImportIssues
}
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
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }

# "2026-08-03T14:20:05" -> "2026-08-03 14:20". Empty in, empty out.
def shortStamp(iso: str) -> str {
    if not iso {
        return "";
    }
    return iso[:16].replace("T", " ");
}

def:pub GithubSection() -> JsxElement {
    has conn: GithubConnectionView | None = None,
        configGaps: list[str] = [],
        loading: bool = True,
        starting: bool = False,
        confirmDisconnect: bool = False,
        repos: list[RepoView] = [],
        projects: list[Project] = [],
        repoId: str = "",
        tab: str = "issues",
        pickerOpen: bool = False,
        pickerQuery: str = "",
        pickerRows: list[GhRepoRow] = [],
        pickerLoading: bool = False,
        pickerProject: str = "none",
        attaching: str = "",
        issues: list[GhIssueRow] = [],
        issueState: str = "open",
        issuePage: int = 1,
        issueHasMore: bool = False,
        issueLoading: bool = False,
        issueMore: bool = False,
        selected: list[int] = [],
        importProject: str = "none",
        importStatus: str = "Backlog",
        importing: bool = False,
        pulls: list[GhPrRow] = [],
        prState: str = "open",
        prPage: int = 1,
        prHasMore: bool = False,
        prLoading: bool = False,
        prMore: bool = False;

    async can with entry {
        boot();
    }

    # The repo, the tab and the state filters all address the same two reads,
    # so one dependent effect covers every way of changing what is shown.
    async can with (repoId, tab, issueState, prState) entry {
        if repoId {
            if tab == "issues" {
                loadIssues(True);
            } else {
                loadPulls(True);
            }
        }
    }

    async def boot -> None;
    async def loadStatus -> None;
    async def loadWorkspace -> None;
    async def startInstall -> None;
    async def disconnect -> None;
    async def openPicker -> None;
    async def searchRepos -> None;
    async def attachRepo(fullName: str) -> None;
    async def loadIssues(reset: bool) -> None;
    async def loadPulls(reset: bool) -> None;
    async def importSelected -> None;
    def toggleIssue(number: int) -> None;
    def selectRepo(value: str) -> None;

    # Initialised before the branch: a name first assigned inside an `if` is
    # block-scoped in the compiled JS and is gone after it.
    connected = False;
    invalid = False;
    login = "";
    avatar = "";
    connectedAt = "";
    lastSync = "";
    if conn {
        connected = conn.connected;
        invalid = conn.status == "invalid";
        login = conn.account_login;
        avatar = conn.account_avatar;
        connectedAt = shortStamp(conn.connected_at);
        lastSync = shortStamp(conn.last_sync_at);
    }

    return <div className="space-y-6">
        <p className="text-sm text-muted-foreground">
            Read issues and pull requests, and import issues onto the board.
        </p>

        {if invalid {
            <ReconnectBanner key="banner" busy={starting} onReconnect={startInstall} />
        }}

        {if loading {
            <Skeleton key="sk" className="h-48 w-full" />
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
                        <Card>
                            <CardContent className="flex flex-wrap items-center gap-4 py-4">
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
                                    <p className="text-xs text-muted-foreground">
                                        {"Connected " + connectedAt if connectedAt else "Connected"}
                                        {" · last sync " + lastSync if lastSync else " · not synced yet"}
                                    </p>
                                </div>
                                <div className="ml-auto flex items-center gap-3">
                                    {if confirmDisconnect {
                                        <span key="warn" className="max-w-72 text-xs text-muted-foreground">
                                            Imported tasks and links stay. Standup just stops
                                            talking to GitHub.
                                        </span>
                                    }}
                                    <Button
                                        variant={"destructive" if confirmDisconnect else "outline"}
                                        size="sm"
                                        onClick={disconnect}
                                    >
                                        {"Click again to disconnect" if confirmDisconnect else "Disconnect"}
                                    </Button>
                                </div>
                            </CardContent>
                        </Card>

                        <div className="flex flex-wrap items-center gap-2">
                            <Select value={repoId} onValueChange={selectRepo}>
                                <SelectTrigger className="w-64">
                                    <SelectValue placeholder="Pick a repo" />
                                </SelectTrigger>
                                <SelectContent>
                                    {for r in repos {
                                        <SelectItem key={r.id} value={r.id}>{r.full_name}</SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                            <Button variant="outline" onClick={openPicker}>
                                Browse GitHub repos
                            </Button>
                            <div className="ml-auto inline-flex gap-1 rounded-lg border p-1">
                                <Button
                                    variant={"secondary" if tab == "issues" else "ghost"}
                                    size="sm"
                                    onClick={lambda { tab = "issues"; }}
                                >
                                    Issues
                                </Button>
                                <Button
                                    variant={"secondary" if tab == "pulls" else "ghost"}
                                    size="sm"
                                    onClick={lambda { tab = "pulls"; }}
                                >
                                    Pull requests
                                </Button>
                            </div>
                        </div>

                        {if not repoId {
                            <Card key="norepo">
                                <CardContent className="py-10 text-center text-sm text-muted-foreground">
                                    Attach a repo to read its issues and pull requests.
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
                                        projects={[p for p in projects if p.active]}
                                        projectId={importProject}
                                        status={importStatus}
                                        importing={importing}
                                        onState={lambda (v: str) { issueState = v; }}
                                        onToggle={toggleIssue}
                                        onProject={lambda (v: str) { importProject = v; }}
                                        onStatus={lambda (v: str) { importStatus = v; }}
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
                                        onState={lambda (v: str) { prState = v; }}
                                        onLoadMore={lambda { loadPulls(False); }}
                                    />
                                }}
                            </div>
                        }}
                    </div>
                }}
            </div>
        }}

        <RepoPicker
            open={pickerOpen}
            query={pickerQuery}
            rows={pickerRows}
            loading={pickerLoading}
            projects={[p for p in projects if p.active]}
            projectId={pickerProject}
            attaching={attaching}
            onQuery={lambda (v: str) { pickerQuery = v; }}
            onSearch={searchRepos}
            onProject={lambda (v: str) { pickerProject = v; }}
            onAttach={attachRepo}
            onOpenChange={lambda (o: bool) { pickerOpen = o; }}
        />
    </div>;
}
