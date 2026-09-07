"""GitHub walkers: connect an installation, read issues and PRs, import issues
as tasks, open an issue from a task. Auth is an App installation (tokens minted
per call, never reported). Every walker but GithubStatus reports ONE envelope,
{"ok": True, ...} or {"ok": False, "error", "message"}. Nothing polls."""

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
    ForProject,
    resolve,
    on_attached,
    owned,
    repo_view
}
import from walkers.util { now_iso, minutes_since, clean_tags }
import from walkers.log { record_task_event }
import from walkers.tasks { find_task, status_for_step }
import from walkers.ghutil {
    missing_config,
    install_url,
    new_state,
    installation_token,
    forget_installation,
    valid_full_name,
    gh_request,
    exchange_code,
    user_owns_installation,
    clock
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
     # A board mounts twice on a full page load; the auto pass skips itself
     # when a sync just ran so the double mount costs one GitHub call.
     AUTO_SYNC_COOLDOWN_MINUTES: float = 1.0,
     # Sub-issue child lists fetched per sync, stalest families first by
     # walk order. Counts are free (they ride the issue list); only the
     # child links cost a call, and only when a family changed.
     SUB_ISSUE_CAP: int = 20;

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
        configured=configured,
        missing_config=gaps
    );
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


walker GithubStatus {
    """Cheap, no GitHub call: every page showing GitHub UI opens with it."""
    has reports: list[GithubConnectionView] = [];

    can look with Root entry {
        report connection_view(connection_of(here));
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
        target.installation_id = self.installation_id;
        target.account_login = login;
        target.account_avatar = avatar;
        target.status = "ok";
        target.connected_at = now_iso();
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


def issue_row(
    item: dict[str, any], owned_tasks: list[Task], full_name: str
) -> GhIssueRow {
    number = int(item.get("number") or 0);
    labels = label_names(item);
    assignee = "";
    who = item.get("assignee") or {};
    if isinstance(who, dict) {
        assignee = str(who.get("login") or "");
    }
    linked = "";
    for t in owned_tasks {
        if t.gh_repo == full_name and t.gh_issue_number == number {
            linked = jid(t);
        }
    }
    return GhIssueRow(
        number=number,
        title=str(item.get("title") or ""),
        state=str(item.get("state") or ""),
        labels=labels,
        assignee=assignee,
        html_url=str(item.get("html_url") or ""),
        already_imported=bool(linked),
        imported_task_id=linked
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


walker ListRepoIssues {
    """One page of a repo's issues.

    A foreign repo jid reports an empty page rather than an error: it leaks
    nothing about whether the id exists, and burns no GitHub quota."""
    has repo_id: str = "",
        state: str = "open",
        page: int = 1,
        reports: list[dict[str, any]] = [];

    can browse with Root entry {
        full_name = owned_full_name(here, self.repo_id);
        if not full_name {
            report {"ok": True, "rows": [], "page": self.page, "has_more": False};
            disengage;
        }
        c = connection_of(here);
        token = token_of(c);
        if not token {
            report not_connected();
            disengage;
        }
        want = self.state if self.state in ["open", "closed", "all"] else "open";
        page = self.page if self.page > 0 else 1;
        result = gh_request(
            token,
            "GET",
            "/repos/" + full_name + "/issues",
            {"state": want, "per_page": PAGE_SIZE, "page": page}
        );
        if not result["ok"] {
            mark_invalid(c, result);
            report result;
            disengage;
        }
        data = result["data"];
        raw: list[any] = [];
        if isinstance(data, list) {
            raw = data;
        }
        owned_tasks = [here-->[?:Task]];
        rows: list[GhIssueRow] = [];
        for item in raw {
            if not isinstance(item, dict) {
                continue;
            }
            # /issues returns pull requests too; they carry this key and
            # belong on the pull-request tab, not the import table.
            if item.get("pull_request") {
                continue;
            }
            rows.append(issue_row(item, owned_tasks, full_name));
        }
        report {
            "ok": True,
            "rows": rows,
            "page": page,
            "has_more": len(raw) >= PAGE_SIZE
        };
    }
}


walker ListRepoPulls {
    has repo_id: str = "",
        state: str = "open",
        page: int = 1,
        reports: list[dict[str, any]] = [];

    can browse with Root entry {
        full_name = owned_full_name(here, self.repo_id);
        if not full_name {
            report {"ok": True, "rows": [], "page": self.page, "has_more": False};
            disengage;
        }
        c = connection_of(here);
        token = token_of(c);
        if not token {
            report not_connected();
            disengage;
        }
        want = self.state if self.state in ["open", "closed", "all"] else "open";
        page = self.page if self.page > 0 else 1;
        result = gh_request(
            token,
            "GET",
            "/repos/" + full_name + "/pulls",
            {"state": want, "per_page": PAGE_SIZE, "page": page}
        );
        if not result["ok"] {
            mark_invalid(c, result);
            report result;
            disengage;
        }
        data = result["data"];
        raw: list[any] = [];
        if isinstance(data, list) {
            raw = data;
        }
        owned_tasks = [here-->[?:Task]];
        rows: list[GhPrRow] = [];
        for item in raw {
            if not isinstance(item, dict) {
                continue;
            }
            number = int(item.get("number") or 0);
            url = str(item.get("html_url") or "");
            author = "";
            who = item.get("user") or {};
            if isinstance(who, dict) {
                author = str(who.get("login") or "");
            }
            linked = "";
            for t in owned_tasks {
                if t.gh_repo == full_name and t.pr_number == number {
                    linked = jid(t);
                } elif url and t.pr_link == url {
                    linked = jid(t);
                }
            }
            rows.append(
                GhPrRow(
                    number=number,
                    title=str(item.get("title") or ""),
                    state=pr_state_of(item),
                    author=author,
                    html_url=url,
                    linked_task_id=linked,
                    updated_at=str(item.get("updated_at") or "")
                )
            );
        }
        report {
            "ok": True,
            "rows": rows,
            "page": page,
            "has_more": len(raw) >= PAGE_SIZE
        };
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
        owned_tasks = [here-->[?:Task]];
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
                linked = "";
                for t in owned_tasks {
                    if t.gh_repo == full_name and t.pr_number == number {
                        linked = jid(t);
                    } elif url and t.pr_link == url {
                        linked = jid(t);
                    }
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
                        linked_task_id=linked,
                        updated_at=str(item.get("updated_at") or "")
                    )
                );
            } else {
                if item.get("pull_request") {
                    continue;
                }
                issue_rows.append(issue_row(item, owned_tasks, full_name));
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
    for s in [holder-->[?:WorkflowStep, kind=="done"]] {
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
        peak = 0.0;
        for d in [holder-->[?:Task, status=="Done"]] {
            if d.sort_order > peak {
                peak = d.sort_order;
            }
        }
    }
    peak = peak + 1024.0;
    t.status = "Done";
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
    for s in [holder-->[?:WorkflowStep, kind=="start"]] {
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
    target_project: any,
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
        top = 0.0;
        for t in [holder-->[?:Task, status==landing]] {
            if t.sort_order > top {
                top = t.sort_order;
            }
        }
        peaks[landing] = top;
    }
    peaks[landing] = peaks[landing] + 1024.0;
    subs = item.get("sub_issues_summary") or {};
    sub_total = int(subs.get("total") or 0) if isinstance(subs, dict) else 0;
    sub_done = int(subs.get("completed") or 0) if isinstance(subs, dict) else 0;
    body = str(item.get("body") or "");
    stamp = now_iso();
    fresh = holder ++> Task(
        title=str(item.get("title") or ("Issue #" + str(number))),
        category="",
        tags=clean_tags(label_names(item)),
        priority="Medium",
        status=landing,
        step_id=landing_step,
        notes=body[:2000],
        issue_link=str(item.get("html_url") or ""),
        created_at=stamp,
        updated_at=stamp,
        sort_order=peaks[landing],
        gh_repo=full_name,
        gh_issue_number=number,
        gh_issue_state=issue_state,
        gh_synced_at=stamp,
        gh_sub_total=sub_total,
        gh_sub_done=sub_done
    );
    on_attached(holder, fresh);
    if isinstance(target_project, Project) {
        fresh +>:ForProject():+> target_project;
    }
    # Map GitHub assignees onto roster members by username. Anyone without
    # a match is simply left off; we never invent people.
    logins: list[str] = [];
    raw_assignees = item.get("assignees") or [];
    if isinstance(raw_assignees, list) {
        for a in raw_assignees {
            if isinstance(a, dict) {
                logins.append(str(a.get("login") or "").lower());
            }
        }
    }
    for m in members {
        if m.github_username and m.github_username.lower() in logins {
            fresh +>:AssignedTo():+> m;
        }
    }
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
        repo_node = resolve(self.repo_id);
        target_project = None;
        proj = resolve(self.project_id);
        if isinstance(proj, Project) and owned(here, proj) {
            target_project = proj;
        } elif isinstance(repo_node, Repo) {
            attached = [repo_node<-:HasRepo:<-[?:Project]];
            if attached {
                target_project = attached[0];
            }
        }
        members = [here-->[?:Member]];
        imported: list[TaskView] = [];
        skipped: list[int] = [];
        failed: list[int] = [];
        peaks: dict[str, float] = {};
        wanted = self.numbers[:IMPORT_CAP];
        for number in wanted {
            if number <= 0 {
                continue;
            }
            existing = [here-->[?:Task, gh_repo==full_name, gh_issue_number==number]];
            if existing {
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
                target_project,
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
        # In a Task entry ability `here` is the task, so the caller's root
        # (what ownership is measured against) is one hop back.
        owners = [here<--];
        holder = owners[0];
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


walker SyncGithub {
    """One bounded increment of the GitHub sync. Every tracked repo's issues
    stream (issues AND pull requests, oldest update first) is read from the
    repo's cursor: linked tasks refresh, new issues file on auto-sync repos,
    and the call stops at the page or time budget with `has_more` set."""
    has auto: bool = False,
        # Pages this call may read, clamped to SYNC_PAGE_BUDGET; 0 means
        # the cap. The auto pass asks for less so a board open stays light.
        page_budget: int = 0,
        reports: list[dict[str, any]] = [];

    can refresh with Root entry {
        c = connection_of(here);
        token = token_of(c);
        if not token {
            report not_connected();
            disengage;
        }
        if self.auto
            and isinstance(c, GithubConnection)
            and minutes_since(c.last_sync_at) < AUTO_SYNC_COOLDOWN_MINUTES {
            report sync_summary([0, 0, 0, 0, 0, 0], False, "", c.last_sync_at);
            disengage;
        }
        budget = SYNC_PAGE_BUDGET;
        if self.page_budget > 0 and self.page_budget < SYNC_PAGE_BUDGET {
            budget = self.page_budget;
        }
        started = clock();
        stamp = now_iso();
        # The workspace's repos: which are tracked, which opted into
        # merged-or-closed means done, and each one's node for the cursor.
        tracked: list[str] = [];
        merge_done: list[str] = [];
        by_name: dict[str, Repo] = {};
        for r in [here-->[?:Repo]] {
            if not valid_full_name(r.full_name) {
                continue;
            }
            tracked.append(r.full_name);
            by_name[r.full_name] = r;
            if r.auto_done {
                merge_done.append(r.full_name);
            }
        }
        # One walk over the tasks builds every lookup the stream needs.
        # Hand-pasted PR links are adopted here so they join this increment,
        # but only when they point at a repo the workspace tracks.
        task_by_key: dict[str, Task] = {};
        task_by_pr: dict[str, Task] = {};
        child_stamped: dict[str, bool] = {};
        earliest: dict[str, str] = {};
        linked_tasks: list[Task] = [];
        for t in [here-->[?:Task]] {
            if t.pr_link and t.pr_number == 0 {
                guess_repo = repo_from_link(t.pr_link);
                guess_number = pr_number_from(t.pr_link);
                if guess_number > 0 and guess_repo in tracked {
                    t.pr_number = guess_number;
                    if not t.gh_repo {
                        t.gh_repo = guess_repo;
                    }
                }
            }
            if not t.gh_repo {
                continue;
            }
            if t.gh_issue_number > 0 {
                task_by_key[t.gh_repo + "#" + str(t.gh_issue_number)] = t;
                linked_tasks.append(t);
                if t.gh_parent_repo and t.gh_parent_number > 0 {
                    child_stamped[t.gh_parent_repo + "#" + str(t.gh_parent_number)] = True;
                }
                if t.gh_synced_at
                    and (
                        t.gh_repo not in earliest
                        or t.gh_synced_at < earliest[t.gh_repo]
                    ) {
                    earliest[t.gh_repo] = t.gh_synced_at;
                }
            }
            if t.pr_number > 0 {
                task_by_pr[t.gh_repo + "#" + str(t.pr_number)] = t;
            }
        }
        landing = entry_landing(here);
        done_step = first_done_step(here);
        done_name = "Done";
        if done_step {
            st = resolve(done_step);
            if isinstance(st, WorkflowStep) {
                done_name = st.name;
            }
        }
        members = [here-->[?:Member]];
        peaks: dict[str, float] = {};
        done_peak = -1.0;
        pages = 0;
        scanned = 0;
        refreshed = 0;
        auto_added = 0;
        auto_done_moves = 0;
        family_calls = 0;
        has_more = False;
        failure = "";
        for full_name in tracked {
            r = by_name[full_name];
            # An empty cursor means "from the beginning": right for an
            # auto-sync backfill, wrong for a repo that only holds imported
            # tasks. Those start from the earliest sync stamp among their
            # tasks, since everything older was fresh when it was imported.
            cursor = r.issue_cursor;
            if not cursor and not r.auto_sync {
                if full_name not in earliest {
                    continue;
                }
                cursor = earliest[full_name][:19] + "Z";
            }
            attached = [r<-:HasRepo:<-[?:Project]];
            repo_project = attached[0] if attached else None;
            page = 1;
            while True {
                if pages >= budget or clock() - started > SYNC_SECONDS_BUDGET {
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
                        if key not in task_by_pr {
                            continue;
                        }
                        pt = task_by_pr[key];
                        fresh_pr = pr_state_of(item);
                        if fresh_pr and fresh_pr != pt.pr_state {
                            pt.pr_state = fresh_pr;
                            refreshed = refreshed + 1;
                            # Merged means done, but only for opted-in repos
                            # and only from statuses where the chip would
                            # suggest it.
                            if fresh_pr == "merged"
                                and full_name in merge_done
                                and pt.status in MERGE_SUGGEST_STATUSES {
                                done_peak = auto_done_land(
                                    here,
                                    pt,
                                    done_step,
                                    done_name,
                                    "PR merged",
                                    stamp,
                                    done_peak
                                );
                                auto_done_moves = auto_done_moves + 1;
                            }
                        }
                        pt.gh_synced_at = stamp;
                        continue;
                    }
                    if key not in task_by_key {
                        if r.auto_sync {
                            fresh = file_issue_item(
                                here,
                                item,
                                full_name,
                                number,
                                repo_project,
                                members,
                                landing[0],
                                landing[1],
                                done_step,
                                peaks
                            );
                            task_by_key[key] = fresh;
                            auto_added = auto_added + 1;
                        }
                        continue;
                    }
                    t = task_by_key[key];
                    fresh_state = str(item.get("state") or "");
                    if fresh_state and fresh_state != t.gh_issue_state {
                        t.gh_issue_state = fresh_state;
                        refreshed = refreshed + 1;
                        # A closed issue is terminal on GitHub's side, so an
                        # opted-in repo moves the card from any open status.
                        if fresh_state == "closed"
                            and full_name in merge_done
                            and t.status != "Done" {
                            done_peak = auto_done_land(
                                here,
                                t,
                                done_step,
                                done_name,
                                "issue closed",
                                stamp,
                                done_peak
                            );
                            auto_done_moves = auto_done_moves + 1;
                        }
                    }
                    # Sub-issue family: counts ride the stream; the child
                    # list is refetched when they moved or nothing is stamped
                    # yet, within the family cap and the time budget.
                    subs = item.get("sub_issues_summary") or {};
                    pair = [t.gh_sub_total, t.gh_sub_done];
                    if isinstance(subs, dict) {
                        pair = [
                            int(subs.get("total") or 0),
                            int(subs.get("completed") or 0)
                        ];
                    }
                    moved = pair[0] != t.gh_sub_total or pair[1] != t.gh_sub_done;
                    t.gh_sub_total = pair[0];
                    t.gh_sub_done = pair[1];
                    if moved and pair[0] == 0 {
                        for kid_t in linked_tasks {
                            if kid_t.gh_parent_repo == full_name
                                and kid_t.gh_parent_number == number {
                                kid_t.gh_parent_repo = "";
                                kid_t.gh_parent_number = 0;
                            }
                        }
                    }
                    unstamped = pair[0] > 0 and key not in child_stamped;
                    if ((moved and pair[0] > 0) or unstamped)
                        and family_calls < SUB_ISSUE_CAP
                        and clock() - started <= SYNC_SECONDS_BUDGET {
                        family_calls = family_calls + 1;
                        kids = gh_request(
                            token,
                            "GET",
                            "/repos/"
                                + full_name
                                + "/issues/"
                                + str(number)
                                + "/sub_issues"
                        );
                        if kids["ok"] and isinstance(kids["data"], list) {
                            for kid in kids["data"] {
                                if not isinstance(kid, dict) {
                                    continue;
                                }
                                child_key = repo_from_api_url(
                                    str(kid.get("repository_url") or "")
                                )
                                    + "#"
                                    + str(int(kid.get("number") or 0));
                                if child_key in task_by_key {
                                    task_by_key[child_key].gh_parent_repo = full_name;
                                    task_by_key[child_key].gh_parent_number = number;
                                    child_stamped[key] = True;
                                }
                            }
                        } else {
                            mark_invalid(c, kids);
                        }
                    }
                    t.gh_synced_at = stamp;
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
        if isinstance(c, GithubConnection) {
            c.last_sync_at = stamp;
        }
        report sync_summary(
            [len(linked_tasks), refreshed, auto_added, auto_done_moves, scanned, pages],
            has_more,
            failure,
            stamp
        );
    }
}


# The one report shape every sync path returns, so the client reads the
# same keys after an increment, a cooldown skip, or a GitHub failure.
# `counts` is [linked, refreshed, auto_added, auto_done, scanned, pages].
def sync_summary(
    counts: list[int], has_more: bool, failure: str, last_sync_at: str
) -> dict[str, any] {
    return {
        "ok": True,
        "linked": counts[0],
        "refreshed": counts[1],
        "auto_added": counts[2],
        "auto_done": counts[3],
        "scanned": counts[4],
        "pages": counts[5],
        "has_more": has_more,
        "failure": failure,
        "last_sync_at": last_sync_at
    };
}
