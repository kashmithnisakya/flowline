"""GitHub walkers: connect an installation, read issues and PRs, import issues
as tasks, open an issue from a task. Auth is an App installation (tokens minted
per call, never reported). Every walker but GithubStatus reports ONE envelope,
{"ok": True, ...} or {"ok": False, "error", "message"}. The poll runs on the
server schedule (services/github/schedule.jac) and by hand; no walker a page
load calls reaches GitHub."""

import from jaclang.lib.effects { effects }
import from models {
    Project,
    Member,
    Repo,
    Task,
    TaskView,
    WorkflowStep,
    GithubConnection,
    GithubConnectionView,
    GhRepoRow,
    GhIssueRow,
    GhPrRow,
    HasRepo,
    AssignedTo,
    resolve,
    on_attached,
    owned,
    repo_view,
    tasks_by_issue,
    tasks_by_pr,
    tasks_by_pr_link,
    unnumbered_pr_links,
    children_of,
    earliest_synced,
    status_peak,
    count_task,
    task_project,
    seeded_done,
    members_of,
    steps_of
}
import from services.util { now_iso, minutes_since, clean_tags, shift_day, today_iso }
import from services.log.log { record_task_event }
import from services.tasks.tasks { find_task, status_for_step }
import from services.github.util {
    missing_config,
    install_url,
    new_state,
    installation_token,
    forget_installation,
    valid_full_name,
    gh_request,
    exchange_code,
    user_owns_installation,
    clock,
    bind_installation,
    unbind_installation,
    root_for_installation,
    installation_seen_at,
    pending_deliveries,
    mark_delivered,
    purge_deliveries,
    acquire_sync_lease,
    read_repo_list,
    store_repo_list,
    log
}
import from constants { STATUSES, MERGE_SUGGEST_STATUSES }

# An install round trip that has sat unfinished for this long is a stale tab,
# not a person mid-flow.
glob INSTALL_WINDOW_MINUTES: float = 15.0,
     PAGE_SIZE: int = 50,
     IMPORT_CAP: int = 25,
     # One sync call reads at most this many 100-item pages across every
     # repo, and issues no new request once this many seconds have passed;
     # the repo cursors carry the rest to the next call (has_more).
     SYNC_PAGE_BUDGET: int = 5,
     SYNC_SECONDS_BUDGET: float = 8.0,
     # The scheduled pass (auto=True) skips a workspace synced this recently;
     # shorter than the schedule's interval, so a quiet workspace is polled
     # on every tick.
     AUTO_SYNC_COOLDOWN_MINUTES: float = 1.0,
     # While deliveries are flowing the poll is only a catch-up, so the auto
     # pass waits this long instead (every third tick); a workspace goes back
     # to the short cooldown once the newest delivery is older than the window.
     LIVE_SYNC_COOLDOWN_MINUTES: float = 15.0,
     LIVE_WINDOW_MINUTES: float = 60.0,
     # A stored issue or pull request page older than this reads as stale on
     # the GitHub page (it offers a refresh); a healthy schedule rewrites the
     # pages at least every LIVE_SYNC_COOLDOWN_MINUTES.
     LIST_CACHE_MINUTES: float = 20.0,
     # The per-workspace sync lease: the schedule holds it for one pass and a
     # manual sync leaves it held, so the schedule stays out of a workspace
     # someone is syncing by hand. Shorter than the schedule's interval.
     SYNC_LEASE_SECONDS: int = 240,
     MANUAL_OWNER: str = "manual",
     # The review states that answer a review request. A commented review is
     # not a verdict and leaves a pending request pending.
     REVIEW_VERDICTS: list[str] = ["approved", "changes_requested"],
     # Sub-issue child lists fetched per sync, stalest families first by
     # walk order. Counts are free (they ride the issue list); only the
     # child links cost a call, and only when a family changed.
     SUB_ISSUE_CAP: int = 20,
     # Queued webhook deliveries applied per drain; a longer backlog drains
     # over successive calls.
     DRAIN_LIMIT: int = 200;

# Ceilings, because walker endpoints have no built-in pagination or rate
# limiting: a hostile client should only ever burn its own installation's
# GitHub quota.
# --------------------------------------------------------------- connection

def connection_of(holder: Root) -> any {
    found = [holder-->[?:GithubConnection]];
    return found[0] if found else None;
}


def connection_view(c: any) -> GithubConnectionView {
    gaps = missing_config();
    configured = not gaps;
    if not isinstance(c, GithubConnection) or c.installation_id == 0 {
        return GithubConnectionView(
            connected=False, configured=configured, missing_config=gaps
        );
    }
    return GithubConnectionView(
        connected=True,
        account_login=c.account_login,
        account_avatar=c.account_avatar,
        status=c.status,
        connected_at=c.connected_at,
        last_sync_at=c.last_sync_at,
        webhook_seen_at=installation_seen_at(c.installation_id),
        configured=configured,
        missing_config=gaps
    );
}


# A connected workspace whose installation has no index row claims it on
# its next status call: workspaces connected before the index existed, and
# the one left behind after another workspace took the installation over
# and disconnected. One keyed read per call; a memo would go stale across
# worker processes.
def ensure_bound(holder: Root, c: any) -> None {
    # An invalid connection stays out of the index: a deleted installation
    # must not be re-bound by the next status call, and a reconnect binds
    # the new id itself.
    if not isinstance(c, GithubConnection)
        or c.installation_id == 0
        or c.status == "invalid" {
        return;
    }
    if not root_for_installation(c.installation_id) {
        bind_installation(c.installation_id, jid(holder));
    }
}


# The token for this workspace's installation, or "" when the workspace is
# not connected. A 401 anywhere flips the connection to "invalid" so every
# GitHub surface can show one reconnect banner.
def token_of(c: any) -> str {
    if not isinstance(c, GithubConnection) or c.installation_id == 0 {
        return "";
    }
    return installation_token(c.installation_id);
}


def mark_invalid(c: any, result: dict[str, any]) -> None {
    if not isinstance(c, GithubConnection) {
        return;
    }
    if result.get("error") == "unauthorized" or result.get("error") == "not_found" {
        c.status = "invalid";
    }
}


def not_connected -> dict[str, any] {
    return {
        "ok": False,
        "error": "not_connected",
        "message": "Connect the GitHub App first."
    };
}


# Declared a pure read so the browser caches GithubStatus. ensure_bound's
# one index write (a claim of this workspace's own installation) is
# idempotent and nothing a cached reader shows, so it counts as none.
@effects(reads=["GithubConnection"], writes=[])
def read_connection(holder: Root) -> GithubConnectionView {
    c = connection_of(holder);
    ensure_bound(holder, c);
    return connection_view(c);
}


walker GithubStatus {
    """Cheap, no GitHub call: every page showing GitHub UI opens with it."""
    has reports: list[GithubConnectionView] = [];

    can look with Root entry {
        report read_connection(here);
    }
}


walker StartGithubInstall {
    """Hands back the install URL carrying a one-shot nonce, stored server-side
    and burned on use so a forged callback cannot bind another installation."""
    has reports: list[dict[str, any]] = [];

    can begin with Root entry {
        gaps = missing_config();
        if gaps {
            report {
                "ok": False,
                "error": "not_configured",
                "message": "The server is missing " + ", ".join(gaps) + ".",
                "missing": gaps
            };
            disengage;
        }
        existing = [here-->[?:GithubConnection]];
        target = existing[0] if existing else None;
        if not target {
            target = here ++> GithubConnection();
            on_attached(here, target);
        }
        nonce = new_state();
        target.pending_state = nonce;
        target.pending_at = now_iso();
        report {"ok": True, "url": install_url(nonce)};
    }
}


walker CompleteGithubInstall {
    """Finish the round trip GitHub redirected back from. Two checks before
    anything is stored: the nonce matches the one this workspace issued (CSRF),
    and the GitHub user can actually see the claimed installation, since
    installation ids are small integers a forged link could otherwise pick."""
    has code: str = "",
        installation_id: int = 0,
        state: str = "",
        reports: list[dict[str, any]] = [];

    can finish with Root entry {
        existing = [here-->[?:GithubConnection]];
        target = existing[0] if existing else None;
        if not isinstance(target, GithubConnection) {
            report {
                "ok": False,
                "error": "no_pending_install",
                "message": "Start the install from this page first."
            };
            disengage;
        }
        # One shot: burn the nonce before doing any work with it, so a
        # replayed callback cannot take a second run at the checks.
        expected = target.pending_state;
        stamp = target.pending_at;
        target.pending_state = "";
        target.pending_at = "";
        if not expected or self.state != expected {
            report {
                "ok": False,
                "error": "bad_state",
                "message": "That install link did not come from this workspace."
            };
            disengage;
        }
        if minutes_since(stamp) > INSTALL_WINDOW_MINUTES {
            report {
                "ok": False,
                "error": "expired",
                "message": "That install link expired. Try connecting again."
            };
            disengage;
        }
        if self.installation_id <= 0 {
            report {
                "ok": False,
                "error": "invalid",
                "message": "GitHub did not send an installation id."
            };
            disengage;
        }
        user_token = exchange_code(self.code);
        if not user_token {
            report {
                "ok": False,
                "error": "exchange_failed",
                "message": "GitHub would not confirm who authorized the install."
            };
            disengage;
        }
        record = user_owns_installation(user_token, self.installation_id);
        if not record {
            report {
                "ok": False,
                "error": "not_yours",
                "message": "That installation is not one your GitHub account can see."
            };
            disengage;
        }
        account = record.get("account") or {};
        login = "";
        avatar = "";
        if isinstance(account, dict) {
            login = str(account.get("login") or "");
            avatar = str(account.get("avatar_url") or "");
        }
        if target.installation_id and target.installation_id != self.installation_id {
            unbind_installation(target.installation_id);
        }
        target.installation_id = self.installation_id;
        target.account_login = login;
        target.account_avatar = avatar;
        target.status = "ok";
        target.connected_at = now_iso();
        bind_installation(self.installation_id, jid(here));
        report {"ok": True, "connection": connection_view(target)};
    }
}


walker DisconnectGithub {
    """Forgets the installation. Imported tasks and their links stay: they
    are this workspace's own data, not GitHub's."""
    has reports: list[dict[str, any]] = [];

    # Not `drop`: jac 0.36.1's instrument_drops pass reserves `inst` and an
    # ability named drop collides with it, 422ing the endpoint (issue #123).
    can disconnect with Root entry {
        existing = [here-->[?:GithubConnection]];
        for c in existing {
            forget_installation(c.installation_id);
            unbind_installation(c.installation_id);
            del c;
        }
        report {"ok": True, "disconnected": True};
    }
}


# ---------------------------------------------------------------- reads

walker ListGithubRepos {
    """One GitHub page (100) of the repos this installation was granted,
    filtered by `query` after the fetch, so a page under a query can run
    short. `attached` marks the ones already tracked in the workspace;
    `has_more` says whether GitHub holds another page."""
    has query: str = "",
        page: int = 1,
        reports: list[dict[str, any]] = [];

    can browse with Root entry {
        c = connection_of(here);
        token = token_of(c);
        if not token {
            report not_connected();
            disengage;
        }
        page = self.page if self.page > 0 else 1;
        result = gh_request(
            token, "GET", "/installation/repositories", {"per_page": 100, "page": page}
        );
        if not result["ok"] {
            mark_invalid(c, result);
            report result;
            disengage;
        }
        data = result["data"];
        raw: list[any] = [];
        total = 0;
        if isinstance(data, dict) {
            got = data.get("repositories") or [];
            if isinstance(got, list) {
                raw = got;
            }
            total = int(data.get("total_count") or 0);
        }
        known: list[str] = [];
        for r in [here-->[?:Repo]] {
            known.append(r.full_name);
        }
        needle = self.query.strip().lower();
        rows: list[GhRepoRow] = [];
        for item in raw {
            if not isinstance(item, dict) {
                continue;
            }
            full = str(item.get("full_name") or "");
            if not full {
                continue;
            }
            if needle and needle not in full.lower() {
                continue;
            }
            rows.append(
                GhRepoRow(
                    full_name=full,
                    private=bool(item.get("private")),
                    description=str(item.get("description") or ""),
                    attached=full in known
                )
            );
        }
        rows.sort(key=lambda (r: GhRepoRow) { r.full_name; });
        report {"ok": True, "rows": rows, "page": page, "has_more": total > page * 100};
    }
}


# Shared guard for the repo-addressed reads: resolve, type-check, verify the
# repo hangs off THIS root, then verify the name is safe to interpolate into
# an api.github.com path. Returns "" when any step fails.
def owned_full_name(holder: Root, repo_id: str) -> str {
    target = resolve(repo_id);
    if not isinstance(target, Repo) or not owned(holder, target) {
        return "";
    }
    if not valid_full_name(target.full_name) {
        return "";
    }
    return target.full_name;
}


# An issue's label names, from the API's list of label objects. Shared by
# the browse rows and the import so both read labels the same way.
def assignee_logins(item: dict[str, any]) -> list[str] {
    logins: list[str] = [];
    raw = item.get("assignees") or [];
    if isinstance(raw, list) {
        for a in raw {
            if isinstance(a, dict) {
                login = str(a.get("login") or "").lower();
                if login {
                    logins.append(login);
                }
            }
        }
    }
    return logins;
}


def label_names(item: dict[str, any]) -> list[str] {
    labels: list[str] = [];
    raw_labels = item.get("labels") or [];
    if isinstance(raw_labels, list) {
        for l in raw_labels {
            if isinstance(l, dict) {
                labels.append(str(l.get("name") or ""));
            }
        }
    }
    return labels;
}


# The task jid per issue number for one page of GitHub items: one pushed
# lookup for the page, never a walk over the workspace.
def linked_issues(holder: Root, full_name: str, items: list[any]) -> dict[int, str] {
    numbers: list[int] = [];
    for item in items {
        if isinstance(item, dict) {
            number = int(item.get("number") or 0);
            if number > 0 {
                numbers.append(number);
            }
        }
    }
    found: dict[int, str] = {};
    for t in tasks_by_issue(holder, full_name, numbers) {
        found[t.gh_issue_number] = jid(t);
    }
    return found;
}


# The same for pull requests, by number or by a hand-pasted link.
def linked_pulls(holder: Root, full_name: str, items: list[any]) -> dict[int, str] {
    numbers: list[int] = [];
    links: list[str] = [];
    for item in items {
        if isinstance(item, dict) {
            number = int(item.get("number") or 0);
            if number > 0 {
                numbers.append(number);
            }
            url = str(item.get("html_url") or "");
            if url {
                links.append(url);
            }
        }
    }
    found: dict[int, str] = {};
    for t in tasks_by_pr_link(holder, links, numbers) {
        found[pr_number_from(t.pr_link)] = jid(t);
    }
    for t in tasks_by_pr(holder, full_name, numbers) {
        found[t.pr_number] = jid(t);
    }
    return found;
}


def issue_row(
    item: dict[str, any], linked: dict[int, str], full_name: str
) -> GhIssueRow {
    number = int(item.get("number") or 0);
    labels = label_names(item);
    assignee = "";
    who = item.get("assignee") or {};
    if isinstance(who, dict) {
        assignee = str(who.get("login") or "");
    }
    return GhIssueRow(
        number=number,
        title=str(item.get("title") or ""),
        state=str(item.get("state") or ""),
        labels=labels,
        assignee=assignee,
        html_url=str(item.get("html_url") or ""),
        already_imported=number in linked,
        imported_task_id=linked[number] if number in linked else ""
    );
}


# People pasted PR links by hand long before any of this existed. Reading a
# number out of one lets those tasks join the sync without being re-entered,
# but only for repos the workspace actually tracks.
def pr_number_from(link: str) -> int {
    marker = "/pull/";
    if marker not in link {
        return 0;
    }
    tail = link.split(marker)[-1];
    digits = "";
    for ch in tail {
        if not ch.isdigit() {
            break;
        }
        digits = digits + ch;
    }
    if not digits {
        return 0;
    }
    return int(digits);
}


def repo_from_link(link: str) -> str {
    base = "https://github.com/";
    if not link.startswith(base) {
        return "";
    }
    parts = link[len(base):].split("/");
    if len(parts) < 2 or not parts[0] or not parts[1] {
        return "";
    }
    return parts[0] + "/" + parts[1];
}


# Sub-issue payloads name their repo as an API url; a child can live in a
# different repo than its parent, so the repo is read per child.
def repo_from_api_url(url: str) -> str {
    marker = "/repos/";
    if marker not in url {
        return "";
    }
    parts = [
        p
        for p in url.split(marker)[-1].split("/")
        if p
    ];
    if len(parts) < 2 {
        return "";
    }
    return parts[0] + "/" + parts[1];
}


# GitHub reports a merged PR as state "closed" with a merged_at timestamp,
# and a draft as state "open" with draft=true. The board wants those apart.
# A PR read off the issues stream carries merged_at under `pull_request`.
def pr_state_of(item: dict[str, any]) -> str {
    merged = item.get("merged_at");
    pr = item.get("pull_request");
    if not merged and isinstance(pr, dict) {
        merged = pr.get("merged_at");
    }
    if merged {
        return "merged";
    }
    state = str(item.get("state") or "");
    if state == "open" and bool(item.get("draft")) {
        return "draft";
    }
    return state;
}


# One page of a repo's issues or pull requests from GitHub, the way the
# list walkers and the sync's list refresh both fetch it.
def fetch_repo_page(
    token: str, full_name: str, kind: str, state: str, page: int
) -> dict[str, any] {
    return gh_request(
        token,
        "GET",
        "/repos/" + full_name + "/" + kind,
        {"state": state, "per_page": PAGE_SIZE, "page": page}
    );
}


# What a stored item keeps, in GitHub's own shape so a row is built from a
# stored item and a live one alike. Bodies never go in the store.
def trim_issue(item: dict[str, any]) -> dict[str, any] {
    who = item.get("assignee") or {};
    login = str(who.get("login") or "") if isinstance(who, dict) else "";
    return {
        "number": int(item.get("number") or 0),
        "title": str(item.get("title") or ""),
        "state": str(item.get("state") or ""),
        "labels": [{"name": n} for n in label_names(item)],
        "assignee": {"login": login},
        "html_url": str(item.get("html_url") or "")
    };
}


def trim_pull(item: dict[str, any]) -> dict[str, any] {
    who = item.get("user") or {};
    login = str(who.get("login") or "") if isinstance(who, dict) else "";
    return {
        "number": int(item.get("number") or 0),
        "title": str(item.get("title") or ""),
        "state": str(item.get("state") or ""),
        "draft": bool(item.get("draft")),
        "merged_at": str(item.get("merged_at") or ""),
        "user": {"login": login},
        "html_url": str(item.get("html_url") or ""),
        "updated_at": str(item.get("updated_at") or "")
    };
}


# The rows for one page of GitHub's issues list. Pull requests ride that
# list too (they carry `pull_request`) and belong on the pull request tab.
def issue_rows(holder: Root, full_name: str, raw: list[any]) -> list[GhIssueRow] {
    items: list[any] = [];
    for item in raw {
        if isinstance(item, dict) and not item.get("pull_request") {
            items.append(item);
        }
    }
    linked = linked_issues(holder, full_name, items);
    rows: list[GhIssueRow] = [];
    for item in items {
        rows.append(issue_row(item, linked, full_name));
    }
    return rows;
}


def pull_rows(holder: Root, full_name: str, raw: list[any]) -> list[GhPrRow] {
    items: list[any] = [];
    for item in raw {
        if isinstance(item, dict) {
            items.append(item);
        }
    }
    linked = linked_pulls(holder, full_name, items);
    rows: list[GhPrRow] = [];
    for item in items {
        number = int(item.get("number") or 0);
        author = "";
        who = item.get("user") or {};
        if isinstance(who, dict) {
            author = str(who.get("login") or "");
        }
        rows.append(
            GhPrRow(
                number=number,
                title=str(item.get("title") or ""),
                state=pr_state_of(item),
                author=author,
                html_url=str(item.get("html_url") or ""),
                linked_task_id=linked[number] if number in linked else "",
                updated_at=str(item.get("updated_at") or "")
            )
        );
    }
    return rows;
}


# Keep one fetched page as the repo's stored page for that kind and state.
# GitHub answers at most PAGE_SIZE items; the slice holds a stand-in that
# answers more to the same size.
def keep_repo_list(repo_id: str, kind: str, state: str, raw: list[any], stamp: str) {
    items: list[dict[str, any]] = [];
    for item in raw[:PAGE_SIZE] {
        if not isinstance(item, dict) {
            continue;
        }
        if kind == "issues" {
            if item.get("pull_request") {
                continue;
            }
            items.append(trim_issue(item));
        } else {
            items.append(trim_pull(item));
        }
    }
    store_repo_list(repo_id, kind, state, items, len(raw) >= PAGE_SIZE, stamp);
}


# A list walker's page 1 from the store: no GitHub call. `synced_at` is
# empty when nothing is stored yet, and `stale` says the page is past the
# cache window (or missing), so the GitHub page can offer a refresh.
def stored_page(
    holder: Root, repo_id: str, full_name: str, kind: str, state: str
) -> dict[str, any] {
    stored = read_repo_list(repo_id, kind, state);
    items: list[any] = stored.get("items") or [];
    synced = str(stored.get("synced_at") or "");
    rows: any = (
        issue_rows(holder, full_name, items)
            if kind == "issues"
            else pull_rows(holder, full_name, items)
    );
    return {
        "ok": True,
        "rows": rows,
        "page": 1,
        "has_more": bool(stored.get("has_more")),
        "synced_at": synced,
        "stale": minutes_since(synced) >= LIST_CACHE_MINUTES
    };
}


# A list walker's page from GitHub, on an explicit refresh or for a later
# page; page 1 replaces the stored one.
def live_page(
    holder: Root, c: any, repo_id: str, full_name: str, kind: str, state: str, page: int
) -> dict[str, any] {
    token = token_of(c);
    if not token {
        return not_connected();
    }
    result = fetch_repo_page(token, full_name, kind, state, page);
    if not result["ok"] {
        mark_invalid(c, result);
        return result;
    }
    data = result["data"];
    raw: list[any] = [];
    if isinstance(data, list) {
        raw = data;
    }
    stamp = now_iso();
    if page == 1 {
        keep_repo_list(repo_id, kind, state, raw, stamp);
    }
    rows: any = (
        issue_rows(holder, full_name, raw)
            if kind == "issues"
            else pull_rows(holder, full_name, raw)
    );
    return {
        "ok": True,
        "rows": rows,
        "page": page,
        "has_more": len(raw) >= PAGE_SIZE,
        "synced_at": stamp,
        "stale": False
    };
}


def empty_page(page: int) -> dict[str, any] {
    return {
        "ok": True,
        "rows": [],
        "page": page,
        "has_more": False,
        "synced_at": "",
        "stale": False
    };
}


walker ListRepoIssues {
    """One page of a repo's issues. Page 1 comes from the page the sync
    stored (`synced_at`, `stale`) and never calls GitHub; `refresh` or a
    later page reads GitHub, and page 1 then replaces the stored one.

    A foreign repo jid reports an empty page rather than an error: it leaks
    nothing about whether the id exists, and burns no GitHub quota."""
    has repo_id: str = "",
        state: str = "open",
        page: int = 1,
        refresh: bool = False,
        reports: list[dict[str, any]] = [];

    can browse with Root entry {
        full_name = owned_full_name(here, self.repo_id);
        if not full_name {
            report empty_page(self.page);
            disengage;
        }
        want = self.state if self.state in ["open", "closed", "all"] else "open";
        page = self.page if self.page > 0 else 1;
        if page == 1 and not self.refresh {
            report stored_page(here, self.repo_id, full_name, "issues", want);
            disengage;
        }
        report live_page(
            here, connection_of(here), self.repo_id, full_name, "issues", want, page
        );
    }
}


walker ListRepoPulls {
    """One page of a repo's pull requests, served the way ListRepoIssues is:
    page 1 from the store unless `refresh`, later pages from GitHub."""
    has repo_id: str = "",
        state: str = "open",
        page: int = 1,
        refresh: bool = False,
        reports: list[dict[str, any]] = [];

    can browse with Root entry {
        full_name = owned_full_name(here, self.repo_id);
        if not full_name {
            report empty_page(self.page);
            disengage;
        }
        want = self.state if self.state in ["open", "closed", "all"] else "open";
        page = self.page if self.page > 0 else 1;
        if page == 1 and not self.refresh {
            report stored_page(here, self.repo_id, full_name, "pulls", want);
            disengage;
        }
        report live_page(
            here, connection_of(here), self.repo_id, full_name, "pulls", want, page
        );
    }
}


walker SearchRepoItems {
    """One page of GitHub search results scoped to one repo. `kind` picks issues
    or PRs; rows use the list walkers' shapes. GitHub allows ~30 searches a
    minute, so the client only calls on an explicit action. Foreign repo: empty."""
    has repo_id: str = "",
        kind: str = "issues",
        query: str = "",
        state: str = "open",
        page: int = 1,
        reports: list[dict[str, any]] = [];

    can search with Root entry {
        full_name = owned_full_name(here, self.repo_id);
        if not full_name {
            report {"ok": True, "rows": [], "page": self.page, "has_more": False};
            disengage;
        }
        terms = self.query.strip();
        if not terms {
            report {"ok": True, "rows": [], "page": self.page, "has_more": False};
            disengage;
        }
        c = connection_of(here);
        token = token_of(c);
        if not token {
            report not_connected();
            disengage;
        }
        pulls = self.kind == "pulls";
        q: str = "repo:" + full_name + (" is:pr" if pulls else " is:issue");
        want = self.state if self.state in ["open", "closed", "all"] else "open";
        if want != "all" {
            q = q + " state:" + want;
        }
        q = q + " " + terms;
        page = self.page if self.page > 0 else 1;
        result = gh_request(
            token,
            "GET",
            "/search/issues",
            {"q": q, "per_page": PAGE_SIZE, "page": page}
        );
        if not result["ok"] {
            mark_invalid(c, result);
            report result;
            disengage;
        }
        data = result["data"];
        items: list[any] = [];
        total = 0;
        if isinstance(data, dict) {
            got = data.get("items") or [];
            if isinstance(got, list) {
                items = got;
            }
            total = int(data.get("total_count") or 0);
        }
        linked = (
            linked_pulls(here, full_name, items)
                if pulls
                else linked_issues(here, full_name, items)
        );
        issue_rows: list[GhIssueRow] = [];
        pr_rows: list[GhPrRow] = [];
        for item in items {
            if not isinstance(item, dict) {
                continue;
            }
            if pulls {
                number = int(item.get("number") or 0);
                url = str(item.get("html_url") or "");
                author = "";
                who = item.get("user") or {};
                if isinstance(who, dict) {
                    author = str(who.get("login") or "");
                }
                # Search items nest merge status under pull_request rather
                # than at the top level, so pr_state_of needs a flattened view.
                flat: dict[str, any] = {
                    "state": item.get("state"),
                    "draft": item.get("draft")
                };
                pr_meta = item.get("pull_request") or {};
                if isinstance(pr_meta, dict) {
                    flat["merged_at"] = pr_meta.get("merged_at");
                }
                pr_rows.append(
                    GhPrRow(
                        number=number,
                        title=str(item.get("title") or ""),
                        state=pr_state_of(flat),
                        author=author,
                        html_url=url,
                        linked_task_id=linked[number] if number in linked else "",
                        updated_at=str(item.get("updated_at") or "")
                    )
                );
            } else {
                if item.get("pull_request") {
                    continue;
                }
                issue_rows.append(issue_row(item, linked, full_name));
            }
        }
        report {
            "ok": True,
            "rows": pr_rows if pulls else issue_rows,
            "page": page,
            "has_more": total > page * PAGE_SIZE
        };
    }
}


# ---------------------------------------------------------------- writes

# The done step closed issues land on: first done-kind step by sort order,
# or "" for an org with no flow line yet (plain "Done" then applies).
def first_done_step(holder: Root) -> str {
    done_step = "";
    done_sort = 0.0;
    for s in steps_of(holder) {
        if s.kind != "done" {
            continue;
        }
        if not done_step or s.sort_order < done_sort {
            done_step = jid(s);
            done_sort = s.sort_order;
        }
    }
    return done_step;
}


# One opted-in automation move: append the card to the done column and log
# why. `peak` below zero means the column is not yet scanned; the caller
# keeps the returned peak so a sync scans the done column at most once.
def auto_done_land(
    holder: Root,
    t: Task,
    step_id: str,
    step_name: str,
    why: str,
    stamp: str,
    peak: float
) -> float {
    if peak < 0.0 {
        peak = status_peak(holder, "Done");
    }
    peak = peak + 1024.0;
    t.set_status("Done", stamp);
    t.step_id = step_id;
    t.sort_order = peak;
    t.updated_at = stamp;
    record_task_event(holder, t, "Moved to " + step_name + " · " + why, stamp);
    return peak;
}


# Where auto-filed issues land: the first start-kind step of the flow line
# as [status, step_id], or ["Backlog", ""] for an org with no flow line.
def entry_landing(holder: Root) -> list[str] {
    entry_step = "";
    entry_sort = 0.0;
    for s in steps_of(holder) {
        if s.kind != "start" {
            continue;
        }
        if not entry_step or s.sort_order < entry_sort {
            entry_step = jid(s);
            entry_sort = s.sort_order;
        }
    }
    if entry_step {
        mapped = status_for_step(holder, entry_step);
        if mapped {
            return [mapped, entry_step];
        }
    }
    return ["Backlog", ""];
}


# Create ONE task from a GitHub issue payload; shared by manual import and
# the auto-sync pass. `peaks` caches the top sort_order per landing status,
# one scan per column instead of one per row. The caller has already ruled
# out PRs and existing (gh_repo, gh_issue_number) tasks.
def file_issue_item(
    holder: Root,
    item: dict[str, any],
    full_name: str,
    number: int,
    target_project: Project,
    members: list[Member],
    col: str,
    step: str,
    done_step: str,
    peaks: dict[str, float]
) -> Task {
    issue_state = str(item.get("state") or "open");
    landing = "Done" if issue_state == "closed" else col;
    landing_step = done_step if issue_state == "closed" else step;
    if landing not in peaks {
        peaks[landing] = status_peak(holder, landing);
    }
    peaks[landing] = peaks[landing] + 1024.0;
    subs = item.get("sub_issues_summary") or {};
    sub_total = int(subs.get("total") or 0) if isinstance(subs, dict) else 0;
    sub_done = int(subs.get("completed") or 0) if isinstance(subs, dict) else 0;
    body = str(item.get("body") or "");
    stamp = now_iso();
    # GitHub's own dates: a closed issue then lands in the week it was closed
    # and ages out of the board's recent-done window like any other task.
    made = str(item.get("created_at") or "") or stamp;
    closed = str(item.get("closed_at") or "") or stamp;
    fresh = target_project ++> Task(
        title=str(item.get("title") or ("Issue #" + str(number))),
        category="",
        tags=clean_tags(label_names(item)),
        priority="Medium",
        status=landing,
        step_id=landing_step,
        notes=body[:2000],
        issue_link=str(item.get("html_url") or ""),
        created_at=made,
        updated_at=stamp,
        done_at=closed if landing == "Done" else "",
        sort_order=peaks[landing],
        gh_repo=full_name,
        gh_issue_number=number,
        gh_issue_state=issue_state,
        gh_synced_at=stamp,
        gh_updated_at=str(item.get("updated_at") or ""),
        gh_sub_total=sub_total,
        gh_sub_done=sub_done,
        project_id=jid(target_project)
    );
    on_attached(holder, fresh);
    count_task(target_project, fresh, 1);
    # Map GitHub assignees onto roster members by username. Anyone without
    # a match is simply left off; we never invent people.
    logins = assignee_logins(item);
    fresh.gh_assignees = logins;
    linked: list[str] = [];
    for m in members {
        if m.github_username and m.github_username.lower() in logins {
            fresh +>:AssignedTo():+> m;
            linked.append(jid(m));
        }
    }
    fresh.assignee_ids = linked;
    record_task_event(
        holder, fresh, "Imported from GitHub " + full_name + " #" + str(number), stamp
    );
    return fresh;
}


walker ImportIssues {
    """Turn chosen issues into tasks, once each: (gh_repo, gh_issue_number) is
    the identity. Closed issues land on the done step, the rest on the chosen
    step; `step_id` wins over `status`, which only applies with no flow line."""
    has repo_id: str = "",
        numbers: list[int] = [],
        project_id: str = "",
        status: str = "Backlog",
        step_id: str = "",
        reports: list[dict[str, any]] = [];

    can pull with Root entry {
        full_name = owned_full_name(here, self.repo_id);
        if not full_name {
            report {"ok": False, "error": "not_found", "message": "Unknown repo."};
            disengage;
        }
        c = connection_of(here);
        token = token_of(c);
        if not token {
            report not_connected();
            disengage;
        }
        # Step wins over status: tasks store step_id AND the mapped legacy
        # status, so everything keyed on what a status MEANS keeps working.
        col = self.status if self.status in STATUSES else "Backlog";
        step = "";
        if self.step_id {
            mapped = status_for_step(here, self.step_id);
            if mapped {
                col = mapped;
                step = self.step_id;
            }
        }
        # Closed issues always land on the done step (first by sort order),
        # or plain "Done" for an org that has no flow line yet.
        done_step = first_done_step(here);
        # An explicit project wins; otherwise inherit the repo's own project,
        # which is structurally owned already (root -> Project -> HasRepo).
        # A list, not an Optional: the checker does not narrow through `if`.
        repo_node = resolve(self.repo_id);
        homes: list[Project] = [];
        proj = resolve(self.project_id);
        if isinstance(proj, Project) and owned(here, proj) {
            homes = [proj];
        } elif isinstance(repo_node, Repo) {
            homes = [repo_node<-:HasRepo:<-[?:Project]];
        }
        if not homes {
            report {
                "ok": False,
                "error": "project_required",
                "message": "Attach this repo to a project first."
            };
            disengage;
        }
        members = members_of(here);
        wanted = self.numbers[:IMPORT_CAP];
        held: dict[int, bool] = {};
        for t in tasks_by_issue(here, full_name, wanted) {
            held[t.gh_issue_number] = True;
        }
        imported: list[TaskView] = [];
        skipped: list[int] = [];
        failed: list[int] = [];
        peaks: dict[str, float] = {};
        for number in wanted {
            if number <= 0 {
                continue;
            }
            if number in held {
                skipped.append(number);
                continue;
            }
            result = gh_request(
                token, "GET", "/repos/" + full_name + "/issues/" + str(number)
            );
            if not result["ok"] {
                mark_invalid(c, result);
                failed.append(number);
                continue;
            }
            item = result["data"];
            if not isinstance(item, dict) {
                failed.append(number);
                continue;
            }
            if item.get("pull_request") {
                failed.append(number);
                continue;
            }
            fresh = file_issue_item(
                here,
                item,
                full_name,
                number,
                homes[0],
                members,
                col,
                step,
                done_step,
                peaks
            );
            imported.append(fresh.to_view());
        }
        report {"ok": True, "imported": imported, "skipped": skipped, "failed": failed};
    }
}


walker CreateIssueFromTask(find_task) {
    """Open a GitHub issue for this task. The one and only write to GitHub,
    and one-way: later task edits never touch the issue."""
    has repo_id: str = "",
        reports: list[dict[str, any]] = [];

    can push with Task entry {
        # In a Task entry ability `here` is the task; `root` is the caller's
        # own root, what ownership is measured against.
        holder = root;
        if here.gh_issue_number != 0 {
            report {
                "ok": False,
                "error": "already_linked",
                "message": "This task already has a GitHub issue."
            };
            disengage;
        }
        full_name = owned_full_name(holder, self.repo_id);
        if not full_name {
            report {"ok": False, "error": "not_found", "message": "Unknown repo."};
            disengage;
        }
        c = connection_of(holder);
        token = token_of(c);
        if not token {
            report not_connected();
            disengage;
        }
        body = here.notes;
        if body {
            body = body + "\n\n---\nTracked in Flowline.";
        } else {
            body = "Tracked in Flowline.";
        }
        result = gh_request(
            token,
            "POST",
            "/repos/" + full_name + "/issues",
            {},
            {"title": here.title, "body": body}
        );
        if not result["ok"] {
            mark_invalid(c, result);
            report result;
            disengage;
        }
        item = result["data"];
        if not isinstance(item, dict) {
            report {
                "ok": False,
                "error": "invalid",
                "message": "GitHub did not return the new issue."
            };
            disengage;
        }
        stamp = now_iso();
        here.gh_repo = full_name;
        here.gh_issue_number = int(item.get("number") or 0);
        here.gh_issue_state = str(item.get("state") or "open");
        here.gh_synced_at = stamp;
        here.issue_link = str(item.get("html_url") or "");
        here.updated_at = stamp;
        record_task_event(
            holder,
            here,
            "Opened GitHub issue " + full_name + " #" + str(here.gh_issue_number),
            stamp
        );
        report {"ok": True, "task": here.to_view()};
        disengage;
    }
}


walker SetRepoAutoSync {
    """Turn auto-filing of new issues on or off for one repo. Enabling
    clears the cursor so the next sync backfills the repo's history; the
    (gh_repo, gh_issue_number) identity keeps re-runs duplicate-free."""
    has repo_id: str = "",
        enabled: bool = False,
        reports: list[dict[str, any]] = [];

    can set with Root entry {
        target = resolve(self.repo_id);
        if not isinstance(target, Repo) or not owned(here, target) {
            report {"ok": False, "error": "not_found", "message": "Unknown repo."};
            disengage;
        }
        target.auto_sync = self.enabled;
        if self.enabled {
            target.issue_cursor = "";
        }
        report {"ok": True, "repo": repo_view(target)};
    }
}


walker SetRepoAutoDone {
    """Per-repo policy: a merged PR or a closed issue moves the linked card
    to the done step on the next sync. Off, the board only shows nudges."""
    has repo_id: str = "",
        enabled: bool = False,
        reports: list[dict[str, any]] = [];

    can set with Root entry {
        target = resolve(self.repo_id);
        if not isinstance(target, Repo) or not owned(here, target) {
            report {"ok": False, "error": "not_found", "message": "Unknown repo."};
            disengage;
        }
        target.auto_done = self.enabled;
        report {"ok": True, "repo": repo_view(target)};
    }
}


walker SetRepoAutoClose {
    """Per-repo policy, the reverse of auto_done and off by default: a card
    landing on Done closes its GitHub issue and one leaving Done reopens it.
    The receiver drops the App's own echo, so neither is applied twice."""
    has repo_id: str = "",
        enabled: bool = False,
        reports: list[dict[str, any]] = [];

    can set with Root entry {
        target = resolve(self.repo_id);
        if not isinstance(target, Repo) or not owned(here, target) {
            report {"ok": False, "error": "not_found", "message": "Unknown repo."};
            disengage;
        }
        target.auto_close = self.enabled;
        report {"ok": True, "repo": repo_view(target)};
    }
}


# ------------------------------------------------------------------- sync

# Everything one sync increment needs, built once per call. The task
# lookups are caches filled per page of items (prefetch_*) or per key
# (issue_task / pull_task), each one pushed query, so an increment reads
# the tasks it touches and never the workspace. Request-scoped, never
# persisted; the counters are what sync_summary reports.
obj SyncContext {
    has holder: Root,
        connection: any,
        token: str,
        stamp: str,
        started: float,
        tracked: list[str] = [],
        merge_done: list[str] = [],
        by_name: dict[str, Repo] = {},
        task_by_key: dict[str, Task] = {},
        task_by_pr: dict[str, Task] = {},
        # Keys already looked up, hit or miss, so a miss is not asked twice.
        looked_key: dict[str, bool] = {},
        looked_pr: dict[str, bool] = {},
        child_stamped: dict[str, bool] = {},
        landing: list[str] = [],
        done_step: str = "",
        done_name: str = "Done",
        members: list[Member] = [],
        peaks: dict[str, float] = {},
        done_peak: float = -1.0,
        family_calls: int = 0,
        # Linked tasks this increment looked at (a lookup that hit).
        linked: int = 0,
        refreshed: int = 0,
        auto_added: int = 0,
        auto_done_moves: int = 0,
        # New issues on an auto-sync repo that has no project: nowhere to
        # file them, so they are counted and left for the next pass.
        unfiled: int = 0;
}


# One walk over the repos builds the context. Hand-pasted PR links not yet
# numbered are adopted here so they join this increment, but only when
# they point at a repo the workspace tracks. An adopted task goes straight
# into the lookup cache: a write is not visible to a pushed query until
# the next request, so the store would still answer with the old number.
def sync_context(holder: Root, c: any, token: str, stamp: str) -> SyncContext {
    ctx = SyncContext(
        holder=holder, connection=c, token=token, stamp=stamp, started=clock()
    );
    for r in [holder-->[?:Repo]] {
        if not valid_full_name(r.full_name) {
            continue;
        }
        ctx.tracked.append(r.full_name);
        ctx.by_name[r.full_name] = r;
        if r.auto_done {
            ctx.merge_done.append(r.full_name);
        }
    }
    for t in unnumbered_pr_links(holder) {
        guess_repo = repo_from_link(t.pr_link);
        guess_number = pr_number_from(t.pr_link);
        if guess_number > 0 and guess_repo in ctx.tracked {
            t.pr_number = guess_number;
            if not t.gh_repo {
                t.gh_repo = guess_repo;
            }
            key = t.gh_repo + "#" + str(guess_number);
            ctx.task_by_pr[key] = t;
            ctx.looked_pr[key] = True;
            ctx.linked = ctx.linked + 1;
        }
    }
    ctx.landing = entry_landing(holder);
    ctx.done_step = first_done_step(holder);
    if ctx.done_step {
        st = resolve(ctx.done_step);
        if isinstance(st, WorkflowStep) {
            ctx.done_name = st.name;
        }
    }
    ctx.members = members_of(holder);
    return ctx;
}


# Fill the issue lookup for the numbers on one page of items, one query.
def prefetch_issues(ctx: SyncContext, full_name: str, numbers: list[int]) {
    wanted = [
        n
        for n in numbers
        if full_name + "#" + str(n) not in ctx.looked_key
    ];
    for t in tasks_by_issue(ctx.holder, full_name, wanted) {
        ctx.task_by_key[full_name + "#" + str(t.gh_issue_number)] = t;
        ctx.linked = ctx.linked + 1;
    }
    for n in wanted {
        ctx.looked_key[full_name + "#" + str(n)] = True;
    }
}


def prefetch_pulls(ctx: SyncContext, full_name: str, numbers: list[int]) {
    wanted = [
        n
        for n in numbers
        if full_name + "#" + str(n) not in ctx.looked_pr
    ];
    for t in tasks_by_pr(ctx.holder, full_name, wanted) {
        ctx.task_by_pr[full_name + "#" + str(t.pr_number)] = t;
        ctx.linked = ctx.linked + 1;
    }
    for n in wanted {
        ctx.looked_pr[full_name + "#" + str(n)] = True;
    }
}


# The task linked to one issue or PR, as a list (empty when none). A key
# not prefetched costs one query the first time it is asked for.
def issue_task(ctx: SyncContext, full_name: str, number: int) -> list[Task] {
    key = full_name + "#" + str(number);
    if key not in ctx.looked_key {
        prefetch_issues(ctx, full_name, [number]);
    }
    return [ctx.task_by_key[key]] if key in ctx.task_by_key else [];
}


def pull_task(ctx: SyncContext, full_name: str, number: int) -> list[Task] {
    key = full_name + "#" + str(number);
    if key not in ctx.looked_pr {
        prefetch_pulls(ctx, full_name, [number]);
    }
    return [ctx.task_by_pr[key]] if key in ctx.task_by_pr else [];
}


# A task the increment filed joins the lookup, so a later item for the
# same issue on the same page finds it.
def remember_issue(ctx: SyncContext, key: str, t: Task) {
    ctx.task_by_key[key] = t;
    ctx.looked_key[key] = True;
}


# GitHub's dates can move a Done task between "moved to Done" and "created
# already Done"; the project's seeded tally follows.
def reseed(t: Task, was_seeded: bool) {
    now_seeded = seeded_done(t);
    if was_seeded == now_seeded {
        return;
    }
    for p in task_project(t) {
        p.seeded_done_total = p.seeded_done_total + (1 if now_seeded else -1);
    }
}


# GitHub's own updated_at for the newest item applied to a task, kept
# monotonic so an older event can never roll a newer one back.
def stamp_updated(t: Task, item: dict[str, any]) {
    updated = str(item.get("updated_at") or "");
    if updated > t.gh_updated_at {
        t.gh_updated_at = updated;
    }
}


def stamp_pr_updated(t: Task, item: dict[str, any]) {
    updated = str(item.get("updated_at") or "");
    if updated > t.pr_updated_at {
        t.pr_updated_at = updated;
    }
}


# One PR off the stream: refresh the linked task's PR state and, for an
# opted-in repo, land a merge on the done step. Unlinked PRs are skipped.
def apply_pr_item(
    ctx: SyncContext, full_name: str, key: str, item: dict[str, any]
) -> None {
    hits = pull_task(ctx, full_name, int(item.get("number") or 0));
    if not hits {
        return;
    }
    pt = hits[0];
    fresh_pr = pr_state_of(item);
    if fresh_pr and fresh_pr != pt.pr_state {
        pt.pr_state = fresh_pr;
        ctx.refreshed = ctx.refreshed + 1;
        # Merged means done, but only for opted-in repos and only from
        # statuses where the chip would suggest it.
        if fresh_pr == "merged"
            and full_name in ctx.merge_done
            and pt.status in MERGE_SUGGEST_STATUSES {
            ctx.done_peak = auto_done_land(
                ctx.holder,
                pt,
                ctx.done_step,
                ctx.done_name,
                "PR merged",
                event_time(item),
                ctx.done_peak
            );
            ctx.auto_done_moves = ctx.auto_done_moves + 1;
        }
    }
    pt.gh_synced_at = ctx.stamp;
    stamp_pr_updated(pt, item);
}


# One issue off the stream. A new issue files on an auto-sync repo; a linked
# task refreshes its state, lands on the done step when a closed issue meets
# an opted-in repo, and takes the family counts. True when the sub-issue
# list may have changed and is worth a refetch.
def apply_issue_item(
    ctx: SyncContext,
    r: Repo,
    repo_project: any,
    key: str,
    number: int,
    item: dict[str, any]
) -> bool {
    full_name = r.full_name;
    hits = issue_task(ctx, full_name, number);
    if not hits {
        if r.auto_sync and not isinstance(repo_project, Project) {
            ctx.unfiled = ctx.unfiled + 1;
        } elif r.auto_sync {
            fresh = file_issue_item(
                ctx.holder,
                item,
                full_name,
                number,
                repo_project,
                ctx.members,
                ctx.landing[0],
                ctx.landing[1],
                ctx.done_step,
                ctx.peaks
            );
            remember_issue(ctx, key, fresh);
            ctx.auto_added = ctx.auto_added + 1;
        }
        return False;
    }
    t = hits[0];
    # GitHub's dates win when they are earlier: a sync-stamped import is
    # corrected, while a card that closed its own issue keeps its moment.
    was_seeded = seeded_done(t);
    made = str(item.get("created_at") or "");
    if made and made < t.created_at {
        t.created_at = made;
    }
    closed = str(item.get("closed_at") or "");
    if closed and t.status == "Done" and (not t.done_at or closed < t.done_at) {
        t.done_at = closed;
    }
    reseed(t, was_seeded);
    fresh_state = str(item.get("state") or "");
    if fresh_state and fresh_state != t.gh_issue_state {
        t.gh_issue_state = fresh_state;
        ctx.refreshed = ctx.refreshed + 1;
        # A closed issue is terminal on GitHub's side, so an opted-in repo
        # moves the card from any open status.
        if fresh_state == "closed"
            and full_name in ctx.merge_done
            and t.status != "Done" {
            ctx.done_peak = auto_done_land(
                ctx.holder,
                t,
                ctx.done_step,
                ctx.done_name,
                "issue closed",
                event_time(item),
                ctx.done_peak
            );
            ctx.auto_done_moves = ctx.auto_done_moves + 1;
        }
    }
    # GitHub's assignees ride every issue item, so assigned and unassigned
    # need no action of their own. The card's own assignees are the
    # roster's: the workspace sets those, and a sync never rewrites them.
    logins = assignee_logins(item);
    if logins != t.gh_assignees {
        t.gh_assignees = logins;
        ctx.refreshed = ctx.refreshed + 1;
    }
    # Sub-issue family: counts ride the stream. A family that shrank to
    # nothing releases its children here; one that moved asks for the child
    # list, and the caller decides whether the budget allows the fetch.
    subs = item.get("sub_issues_summary") or {};
    pair = [t.gh_sub_total, t.gh_sub_done];
    if isinstance(subs, dict) {
        pair = [int(subs.get("total") or 0), int(subs.get("completed") or 0)];
    }
    moved = pair[0] != t.gh_sub_total or pair[1] != t.gh_sub_done;
    t.gh_sub_total = pair[0];
    t.gh_sub_done = pair[1];
    if moved and pair[0] == 0 {
        for kid_t in children_of(ctx.holder, full_name, number) {
            kid_t.gh_parent_repo = "";
            kid_t.gh_parent_number = 0;
        }
    }
    # A family whose children were never stamped asks for the child list;
    # one bounded read per parent, remembered for the increment.
    unstamped = False;
    if pair[0] > 0 and key not in ctx.child_stamped {
        if children_of(ctx.holder, full_name, number) {
            ctx.child_stamped[key] = True;
        } else {
            unstamped = True;
        }
    }
    t.gh_synced_at = ctx.stamp;
    stamp_updated(t, item);
    return (moved and pair[0] > 0) or unstamped;
}


# Refetch one parent's sub-issue list and stamp each child we hold. The only
# GitHub call the stream apply makes; the caller caps it by SUB_ISSUE_CAP
# and the time budget.
def refresh_family(ctx: SyncContext, full_name: str, key: str, number: int) {
    ctx.family_calls = ctx.family_calls + 1;
    kids = gh_request(
        ctx.token,
        "GET",
        "/repos/" + full_name + "/issues/" + str(number) + "/sub_issues"
    );
    if kids["ok"] and isinstance(kids["data"], list) {
        for kid in kids["data"] {
            if not isinstance(kid, dict) {
                continue;
            }
            child_repo = repo_from_api_url(str(kid.get("repository_url") or ""));
            for child in issue_task(ctx, child_repo, int(kid.get("number") or 0)) {
                child.gh_parent_repo = full_name;
                child.gh_parent_number = number;
                ctx.child_stamped[key] = True;
            }
        }
    } else {
        mark_invalid(ctx.connection, kids);
    }
}


# ------------------------------------------------------------- deliveries

# Everything below applies the webhook deliveries the receiver queued, in the
# workspace's own session and through the helpers the poll uses; nothing
# here calls GitHub.
def delivery_outcome(kind: str, detail: str = "") -> dict[str, any] {
    return {"ok": True, "outcome": kind, "detail": detail};
}


# When GitHub says the change happened, so the log files it under that day
# rather than under the delivery's arrival.
def event_time(item: dict[str, any]) -> str {
    stamp = str(
        item.get("merged_at")
            or item.get("closed_at")
            or item.get("submitted_at")
            or item.get("updated_at")
            or ""
    );
    return stamp or now_iso();
}


# Deliveries arrive out of order; an item no newer than the last one applied
# to the task would roll state back.
def stale(item: dict[str, any], seen: str) -> bool {
    updated = str(item.get("updated_at") or "");
    return bool(updated) and bool(seen) and updated <= seen;
}


def repo_of(repo: dict[str, any], item: dict[str, any]) -> str {
    named = str(repo.get("full_name") or "");
    return named or repo_from_api_url(str(item.get("repository_url") or ""));
}


def repo_project_of(ctx: SyncContext, full_name: str) -> any {
    attached = [ctx.by_name[full_name]<-:HasRepo:<-[?:Project]];
    return attached[0] if attached else None;
}


def apply_issue(
    ctx: SyncContext, full_name: str, action: str, item: dict[str, any]
) -> dict[str, any] {
    number = int(item.get("number") or 0);
    if number <= 0 {
        return delivery_outcome("ignored", "no issue number");
    }
    key = full_name + "#" + str(number);
    if item.get("pull_request") {
        return apply_pull(ctx, full_name, action, item);
    }
    hits = issue_task(ctx, full_name, number);
    if action == "deleted" or action == "transferred" {
        for t in hits {
            t.gh_issue_number = 0;
            t.gh_issue_state = "";
            t.gh_synced_at = ctx.stamp;
            return delivery_outcome("unlinked", key);
        }
        return delivery_outcome("ignored", key);
    }
    if hits and stale(item, hits[0].gh_updated_at) {
        return delivery_outcome("stale", key);
    }
    apply_issue_item(
        ctx, ctx.by_name[full_name], repo_project_of(ctx, full_name), key, number, item
    );
    return delivery_outcome("applied", key);
}


def apply_pull(
    ctx: SyncContext, full_name: str, action: str, item: dict[str, any]
) -> dict[str, any] {
    number = int(item.get("number") or 0);
    key = full_name + "#" + str(number);
    hits = pull_task(ctx, full_name, number) if number > 0 else [];
    if not hits {
        return delivery_outcome("unlinked", key);
    }
    if stale(item, hits[0].pr_updated_at) {
        return delivery_outcome("stale", key);
    }
    apply_pr_item(ctx, full_name, key, item);
    # Who is waiting on whom rides the PR event: the request is a fact about
    # the PR, and its answer arrives later as a review of its own.
    if action == "review_requested" {
        hits[0].pr_review_state = "requested";
    } elif action == "review_request_removed" {
        hits[0].pr_review_state = "";
    }
    return delivery_outcome("applied", key);
}


# A review submitted on the linked PR. Only a verdict is recorded: a
# commented review answers nothing, and letting it overwrite a pending
# "changes_requested" would say the branch is clear when it is not.
def apply_review(
    ctx: SyncContext, full_name: str, review: dict[str, any], item: dict[str, any]
) -> dict[str, any] {
    number = int(item.get("number") or 0);
    key = full_name + "#" + str(number);
    hits = pull_task(ctx, full_name, number) if number > 0 else [];
    if not hits {
        return delivery_outcome("unlinked", key);
    }
    verdict = str(review.get("state") or "").lower();
    if verdict not in REVIEW_VERDICTS {
        return delivery_outcome("ignored", key + " " + (verdict or "no state"));
    }
    t = hits[0];
    at = str(review.get("submitted_at") or "");
    if at and t.pr_review_at and at <= t.pr_review_at {
        return delivery_outcome("stale", key);
    }
    t.pr_review_state = verdict;
    if at > t.pr_review_at {
        t.pr_review_at = at;
    }
    t.gh_synced_at = ctx.stamp;
    ctx.refreshed = ctx.refreshed + 1;
    return delivery_outcome("applied", key);
}


# Family edges arrive as their own event, so the counts and the parent link
# come straight from the payload instead of the poll's child-list refetch.
def apply_family(
    ctx: SyncContext,
    action: str,
    parent: dict[str, any],
    parent_repo: dict[str, any],
    child: dict[str, any],
    child_repo: dict[str, any]
) -> dict[str, any] {
    p_repo = repo_of(parent_repo, parent);
    c_repo = repo_of(child_repo, child);
    p_num = int(parent.get("number") or 0);
    c_num = int(child.get("number") or 0);
    if not p_repo or not c_repo or p_num <= 0 or c_num <= 0 {
        return delivery_outcome("ignored", "family payload incomplete");
    }
    if p_repo not in ctx.tracked and c_repo not in ctx.tracked {
        return delivery_outcome("untracked", p_repo + " / " + c_repo);
    }
    added = action.endswith("_added");
    touched = 0;
    child_key = c_repo + "#" + str(c_num);
    for kid in issue_task(ctx, c_repo, c_num) {
        if added {
            kid.gh_parent_repo = p_repo;
            kid.gh_parent_number = p_num;
        } elif kid.gh_parent_repo == p_repo and kid.gh_parent_number == p_num {
            kid.gh_parent_repo = "";
            kid.gh_parent_number = 0;
        }
        kid.gh_synced_at = ctx.stamp;
        touched = touched + 1;
    }
    parent_key = p_repo + "#" + str(p_num);
    for par in issue_task(ctx, p_repo, p_num) {
        subs = parent.get("sub_issues_summary") or {};
        if isinstance(subs, dict) and subs {
            par.gh_sub_total = int(subs.get("total") or 0);
            par.gh_sub_done = int(subs.get("completed") or 0);
        } elif added {
            par.gh_sub_total = par.gh_sub_total + 1;
        } elif par.gh_sub_total > 0 {
            par.gh_sub_total = par.gh_sub_total - 1;
        }
        par.gh_synced_at = ctx.stamp;
        touched = touched + 1;
    }
    if touched == 0 {
        return delivery_outcome("unlinked", parent_key + " > " + child_key);
    }
    return delivery_outcome("applied", parent_key + " > " + child_key);
}


# The App's own lifecycle: none of it touches tasks. A deleted installation
# leaves the connection in place, invalid, so the GitHub tab shows the
# reconnect banner; the index row goes so the receiver drops what follows.
def apply_installation(ctx: SyncContext, action: str) -> dict[str, any] {
    c = ctx.connection;
    if not isinstance(c, GithubConnection) {
        return delivery_outcome("ignored", "installation." + action);
    }
    if action == "deleted" {
        c.status = "invalid";
        forget_installation(c.installation_id);
        unbind_installation(c.installation_id);
        return delivery_outcome("applied", "installation deleted");
    }
    if action == "suspend" {
        c.status = "invalid";
        return delivery_outcome("applied", "installation suspended");
    }
    if action == "unsuspend" {
        c.status = "ok";
        return delivery_outcome("applied", "installation unsuspended");
    }
    return delivery_outcome("ignored", "installation." + action);
}


# A repo taken out of the installation keeps its tasks and links (the same
# promise DisconnectGithub makes) but stops auto-filing and auto-moving.
def apply_repo_access(
    ctx: SyncContext, action: str, removed: list[dict[str, any]]
) -> dict[str, any] {
    if action != "removed" {
        return delivery_outcome("ignored", "installation_repositories." + action);
    }
    touched: list[str] = [];
    for row in removed {
        if not isinstance(row, dict) {
            continue;
        }
        full_name = str(row.get("full_name") or "");
        if full_name in ctx.by_name {
            r = ctx.by_name[full_name];
            r.auto_sync = False;
            r.auto_done = False;
            r.auto_close = False;
            touched.append(full_name);
        }
    }
    if not touched {
        return delivery_outcome("untracked", "installation_repositories.removed");
    }
    return delivery_outcome("applied", ", ".join(touched));
}


def apply_delivery(ctx: SyncContext, payload: dict[str, any]) -> dict[str, any] {
    kind = str(payload.get("event") or "");
    action = str(payload.get("action") or "");
    if kind == "installation" {
        return apply_installation(ctx, action);
    }
    if kind == "installation_repositories" {
        return apply_repo_access(
            ctx, action, payload.get("repositories_removed") or []
        );
    }
    item = payload.get("issue") or {};
    if kind == "pull_request" {
        item = payload.get("pull_request") or {};
    } elif kind == "sub_issues" {
        item = payload.get("parent_issue") or {};
    } elif kind == "pull_request_review" {
        item = payload.get("review") or {};
    }
    ctx.stamp = event_time(item if isinstance(item, dict) else {});
    if kind == "sub_issues" {
        return apply_family(
            ctx,
            action,
            payload.get("parent_issue") or {},
            payload.get("parent_issue_repo") or {},
            payload.get("sub_issue") or {},
            payload.get("sub_issue_repo") or {}
        );
    }
    repo = payload.get("repository") or {};
    full_name = str(repo.get("full_name") or "") if isinstance(repo, dict) else "";
    if full_name not in ctx.tracked {
        return delivery_outcome("untracked", full_name);
    }
    if kind == "issues" {
        return apply_issue(ctx, full_name, action, payload.get("issue") or {});
    }
    if kind == "pull_request" {
        return apply_pull(ctx, full_name, action, payload.get("pull_request") or {});
    }
    if kind == "pull_request_review" {
        return apply_review(
            ctx,
            full_name,
            payload.get("review") or {},
            payload.get("pull_request") or {}
        );
    }
    return delivery_outcome("unsupported", kind + "." + action);
}


# Apply what the receiver queued for this workspace, oldest first. The index
# names one workspace per installation, and only that one drains, so two
# accounts holding the same installation cannot race for the queue. One
# context serves the batch; each delivery sets the stamp to its own event
# time; a delivery that raises is marked failed so it cannot block the rest.
def drain_deliveries(holder: Root, c: any, limit: int) -> dict[str, any] {
    counts: dict[str, any] = {
        "drained": 0,
        "applied": 0,
        "added": 0,
        "moved": 0,
        "failed": 0
    };
    if not isinstance(c, GithubConnection) or c.installation_id == 0 {
        return counts;
    }
    if root_for_installation(c.installation_id) != jid(holder) {
        return counts;
    }
    rows = pending_deliveries(c.installation_id, limit);
    if not rows {
        return counts;
    }
    ctx = sync_context(holder, c, "", now_iso());
    for row in rows {
        payload = row.get("payload") or {};
        kind = "";
        try {
            result = apply_delivery(ctx, payload if isinstance(payload, dict) else {});
            kind = str(result.get("outcome") or "");
            if kind == "applied" {
                counts["applied"] = counts["applied"] + 1;
            }
        } except Exception as e {
            kind = "failed";
            counts["failed"] = counts["failed"] + 1;
            log.warning(
                "deliveries: apply failed for "
                    + str(row.get("id"))
                    + ": "
                    + str(e)
                    + "; the poll repairs the row on the next sync"
            );
        }
        mark_delivered(str(row.get("id")), now_iso(), kind);
        counts["drained"] = counts["drained"] + 1;
    }
    counts["added"] = ctx.auto_added;
    counts["moved"] = ctx.auto_done_moves;
    purge_deliveries(c.installation_id, shift_day(today_iso(), -7));
    return counts;
}


# Refresh the open issue and pull request pages the GitHub page reads for
# one tracked repo, in place of what an earlier pass stored.
def refresh_repo_lists(ctx: SyncContext, full_name: str) -> bool {
    r = ctx.by_name[full_name];
    for kind in ["issues", "pulls"] {
        result = fetch_repo_page(ctx.token, full_name, kind, "open", 1);
        if not result["ok"] {
            mark_invalid(ctx.connection, result);
            return False;
        }
        data = result["data"];
        raw: list[any] = [];
        if isinstance(data, list) {
            raw = data;
        }
        keep_repo_list(jid(r), kind, "open", raw, ctx.stamp);
    }
    return True;
}


walker SyncGithub {
    """One bounded increment of the GitHub sync. Every tracked repo's issues
    stream (issues AND pull requests, oldest update first) is read from the
    repo's cursor and each item goes through apply_issue_item or
    apply_pr_item; the call stops at the page or time budget with `has_more`.
    The schedule runs it with `auto`; the Sync buttons run it by hand."""
    has auto: bool = False,
        # Pages this call may read, clamped to SYNC_PAGE_BUDGET; 0 means
        # the cap.
        page_budget: int = 0,
        # Re-walk every tracked repo from its first issue: the update path
        # then corrects what an earlier import stamped. One call resets the
        # cursors; the rounds that follow continue from where it stopped.
        full: bool = False,
        reports: list[dict[str, any]] = [];

    can refresh with Root entry {
        c = connection_of(here);
        if not isinstance(c, GithubConnection) or c.installation_id == 0 {
            report not_connected();
            disengage;
        }
        if c.status == "invalid" {
            report {
                "ok": False,
                "error": "invalid",
                "message": "Reconnect GitHub first."
            };
            disengage;
        }
        # A hand-driven sync holds the workspace's lease so the schedule
        # stays out of its way; a lease held by a pass in flight is no
        # reason to refuse the person.
        if not self.auto {
            acquire_sync_lease(jid(here), MANUAL_OWNER, SYNC_LEASE_SECONDS);
        }
        # Queued deliveries first: they need no token, no budget and no
        # cooldown.
        drained = int(drain_deliveries(here, c, DRAIN_LIMIT)["applied"]);
        cooldown = AUTO_SYNC_COOLDOWN_MINUTES;
        if minutes_since(installation_seen_at(c.installation_id))
            < LIVE_WINDOW_MINUTES {
            cooldown = LIVE_SYNC_COOLDOWN_MINUTES;
        }
        if self.auto and minutes_since(c.last_sync_at) < cooldown {
            report sync_summary(
                [0, 0, 0, 0, 0, 0, 0], False, "", c.last_sync_at, drained, cooldown
            );
            disengage;
        }
        # The token is minted only once a poll will run: a pass on cooldown
        # makes no GitHub call at all.
        token = token_of(c);
        if not token {
            report not_connected();
            disengage;
        }
        budget = SYNC_PAGE_BUDGET;
        if self.page_budget > 0 and self.page_budget < SYNC_PAGE_BUDGET {
            budget = self.page_budget;
        }
        ctx = sync_context(here, c, token, now_iso());
        pages = 0;
        scanned = 0;
        has_more = False;
        failure = "";
        if self.full {
            for full_name in ctx.tracked {
                ctx.by_name[full_name].issue_cursor = "";
            }
        }
        for full_name in ctx.tracked {
            r = ctx.by_name[full_name];
            # An empty cursor means "from the beginning": right for an
            # auto-sync backfill, wrong for a repo that only holds imported
            # tasks. Those start from the earliest sync stamp among their
            # tasks, since everything older was fresh when it was imported.
            cursor = r.issue_cursor;
            if not cursor and not r.auto_sync and not self.full {
                oldest = earliest_synced(here, full_name);
                if not oldest {
                    continue;
                }
                cursor = oldest[0].gh_synced_at[:19] + "Z";
            }
            attached = [r<-:HasRepo:<-[?:Project]];
            repo_project = attached[0] if attached else None;
            page = 1;
            while True {
                if pages >= budget or clock() - ctx.started > SYNC_SECONDS_BUDGET {
                    has_more = True;
                    break;
                }
                params: dict[str, any] = {
                    "state": "all",
                    "per_page": 100,
                    "page": page,
                    "sort": "updated",
                    "direction": "asc"
                };
                if cursor {
                    params["since"] = cursor;
                }
                result = gh_request(
                    token, "GET", "/repos/" + full_name + "/issues", params
                );
                pages = pages + 1;
                if not result["ok"] {
                    mark_invalid(c, result);
                    failure = str(result.get("message") or "GitHub did not answer.");
                    break;
                }
                data = result["data"];
                if not isinstance(data, list) {
                    break;
                }
                # The page's linked tasks in two queries, before any item
                # asks for one of its own.
                issue_numbers: list[int] = [];
                pr_numbers: list[int] = [];
                for item in data {
                    if isinstance(item, dict) and int(item.get("number") or 0) > 0 {
                        if item.get("pull_request") {
                            pr_numbers.append(int(item.get("number") or 0));
                        } else {
                            issue_numbers.append(int(item.get("number") or 0));
                        }
                    }
                }
                prefetch_issues(ctx, full_name, issue_numbers);
                prefetch_pulls(ctx, full_name, pr_numbers);
                newest = cursor;
                for item in data {
                    if not isinstance(item, dict) {
                        continue;
                    }
                    scanned = scanned + 1;
                    updated = str(item.get("updated_at") or "");
                    if updated > newest {
                        newest = updated;
                    }
                    number = int(item.get("number") or 0);
                    if number <= 0 {
                        continue;
                    }
                    key = full_name + "#" + str(number);
                    if item.get("pull_request") {
                        apply_pr_item(ctx, full_name, key, item);
                        continue;
                    }
                    wants_family = apply_issue_item(
                        ctx, r, repo_project, key, number, item
                    );
                    if wants_family
                        and ctx.family_calls < SUB_ISSUE_CAP
                        and clock() - ctx.started <= SYNC_SECONDS_BUDGET {
                        refresh_family(ctx, full_name, key, number);
                    }
                }
                # The cursor moves only once a page is fully applied, so a
                # budget stop between pages resumes cleanly. A page that did
                # not move it (100 items updated the same second) pages on
                # instead, or `since` would return the same page forever.
                if newest > cursor {
                    cursor = newest;
                    r.issue_cursor = newest;
                    page = 1;
                } else {
                    page = page + 1;
                }
                if len(data) < 100 {
                    break;
                }
            }
            if has_more or failure {
                break;
            }
        }
        # The GitHub page's open lists ride on a pass that reached the end
        # of every stream with time left: two GET calls per tracked repo.
        lists = 0;
        if not has_more and not failure {
            for full_name in ctx.tracked {
                if clock() - ctx.started > SYNC_SECONDS_BUDGET {
                    break;
                }
                if refresh_repo_lists(ctx, full_name) {
                    lists = lists + 1;
                }
            }
        }
        if isinstance(c, GithubConnection) {
            c.last_sync_at = ctx.stamp;
        }
        report sync_summary(
            [
                ctx.linked,
                ctx.refreshed,
                ctx.auto_added,
                ctx.auto_done_moves,
                scanned,
                pages,
                lists
            ],
            has_more,
            failure,
            ctx.stamp,
            drained,
            cooldown,
            ctx.unfiled
        );
    }
}


# The one report shape every sync path returns, so the client reads the
# same keys after an increment, a cooldown skip, or a GitHub failure.
# `counts` is [linked, refreshed, auto_added, auto_done, scanned, pages,
# lists] (repos whose stored issue and pull request pages were rewritten).
def sync_summary(
    counts: list[int],
    has_more: bool,
    failure: str,
    last_sync_at: str,
    drained: int = 0,
    cooldown: float = 0.0,
    unfiled: int = 0
) -> dict[str, any] {
    return {
        "ok": True,
        "linked": counts[0],
        "refreshed": counts[1],
        "auto_added": counts[2],
        "auto_done": counts[3],
        "scanned": counts[4],
        "pages": counts[5],
        "drained": drained,
        "unfiled": unfiled,
        "lists": counts[6],
        "cooldown_minutes": cooldown,
        "has_more": has_more,
        "failure": failure,
        "last_sync_at": last_sync_at
    };
}
