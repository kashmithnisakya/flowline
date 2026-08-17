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
    owned
}
import from walkers.util { now_iso, minutes_since }
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
    user_owns_installation
}
import from constants { STATUSES }

# An install round trip that has sat unfinished for this long is a stale tab,
# not a person mid-flow.
glob INSTALL_WINDOW_MINUTES: float = 15.0,
     PAGE_SIZE: int = 50,
     IMPORT_CAP: int = 25,
     SYNC_PR_CAP: int = 20;

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

    can drop with Root entry {
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
    """The repos this installation was granted, filtered client-side by
    `query`. `attached` marks the ones already tracked in the workspace."""
    has query: str = "",
        reports: list[dict[str, any]] = [];

    can browse with Root entry {
        c = connection_of(here);
        token = token_of(c);
        if not token {
            report not_connected();
            disengage;
        }
        result = gh_request(
            token, "GET", "/installation/repositories", {"per_page": 100}
        );
        if not result["ok"] {
            mark_invalid(c, result);
            report result;
            disengage;
        }
        data = result["data"];
        raw: list[any] = [];
        if isinstance(data, dict) {
            got = data.get("repositories") or [];
            if isinstance(got, list) {
                raw = got;
            }
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
        report {"ok": True, "rows": rows};
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


def issue_row(
    item: dict[str, any], owned_tasks: list[Task], full_name: str
) -> GhIssueRow {
    number = int(item.get("number") or 0);
    labels: list[str] = [];
    raw_labels = item.get("labels") or [];
    if isinstance(raw_labels, list) {
        for l in raw_labels {
            if isinstance(l, dict) {
                labels.append(str(l.get("name") or ""));
            }
        }
    }
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


# GitHub reports a merged PR as state "closed" with a merged_at timestamp,
# and a draft as state "open" with draft=true. The board wants those apart.
def pr_state_of(item: dict[str, any]) -> str {
    if item.get("merged_at") {
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

walker ImportIssues {
    """Turn chosen issues into tasks, once each: (gh_repo, gh_issue_number) is
    the identity. Closed issues land on the done step, the rest on the chosen
    step; `step_id` wins over `status`, which only applies with no workflow."""
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
        # or plain "Done" for an org that has no workflow yet.
        done_step = "";
        done_sort = 0.0;
        for s in [here-->[?:WorkflowStep, kind=="done"]] {
            if not done_step or s.sort_order < done_sort {
                done_step = jid(s);
                done_sort = s.sort_order;
            }
        }
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
        peak = 0.0;
        for t in [here-->[?:Task, status==col]] {
            if t.sort_order > peak {
                peak = t.sort_order;
            }
        }
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
            issue_state = str(item.get("state") or "open");
            landing = "Done" if issue_state == "closed" else col;
            landing_step = done_step if issue_state == "closed" else step;
            body = str(item.get("body") or "");
            stamp = now_iso();
            peak = peak + 1024.0;
            fresh = here ++> Task(
                title=str(item.get("title") or ("Issue #" + str(number))),
                category="",
                priority="Medium",
                status=landing,
                step_id=landing_step,
                notes=body[:2000],
                issue_link=str(item.get("html_url") or ""),
                created_at=stamp,
                updated_at=stamp,
                sort_order=peak,
                gh_repo=full_name,
                gh_issue_number=number,
                gh_issue_state=issue_state,
                gh_synced_at=stamp
            );
            on_attached(here, fresh);
            if isinstance(target_project, Project) {
                fresh +>:ForProject():+> target_project;
            }
            # Map GitHub assignees onto roster members by username. Anyone
            # without a match is simply left off; we never invent people.
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
                here,
                fresh,
                "Imported from GitHub " + full_name + " #" + str(number),
                stamp
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
            body = body + "\n\n---\nTracked in standup.";
        } else {
            body = "Tracked in standup.";
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


walker SyncGithub {
    """Refresh cached issue and PR state for linked tasks.

    Read-only by design: it never moves a card. A closed issue or a merged
    PR shows up as a suggestion on the board and a person decides."""
    has reports: list[dict[str, any]] = [];

    can refresh with Root entry {
        c = connection_of(here);
        token = token_of(c);
        if not token {
            report not_connected();
            disengage;
        }
        linked = [
            t
            for t in [here-->[?:Task]]
            if t.gh_repo and t.gh_issue_number > 0
        ];
        changed: list[TaskView] = [];
        stamp = now_iso();
        # One list call per repo beats one GET per task: a workspace with 60
        # linked tasks across 3 repos costs 3 requests, not 60.
        repos: list[str] = [];
        for t in linked {
            if t.gh_repo not in repos and valid_full_name(t.gh_repo) {
                repos.append(t.gh_repo);
            }
        }
        for full_name in repos {
            states: dict[int, str] = {};
            for page in [1, 2] {
                result = gh_request(
                    token,
                    "GET",
                    "/repos/" + full_name + "/issues",
                    {"state": "all", "per_page": 100, "page": page}
                );
                if not result["ok"] {
                    mark_invalid(c, result);
                    break;
                }
                data = result["data"];
                if not isinstance(data, list) {
                    break;
                }
                for item in data {
                    if isinstance(item, dict) and not item.get("pull_request") {
                        states[int(item.get("number") or 0)] = str(
                            item.get("state") or ""
                        );
                    }
                }
                if len(data) < 100 {
                    break;
                }
            }
            for t in linked {
                if t.gh_repo != full_name {
                    continue;
                }
                fresh_state = states.get(t.gh_issue_number) or "";
                if fresh_state and fresh_state != t.gh_issue_state {
                    t.gh_issue_state = fresh_state;
                    changed.append(t.to_view());
                }
                t.gh_synced_at = stamp;
            }
        }
        # Adopt hand-pasted PR links so they sync too, but only when they
        # point at a repo this workspace tracks.
        tracked: list[str] = [];
        for r in [here-->[?:Repo]] {
            tracked.append(r.full_name);
        }
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
        }
        # PRs are per-task GETs, so they are capped and the stalest go first.
        pr_tasks = [
            t
            for t in [here-->[?:Task]]
            if t.status != "Done" and t.pr_number > 0 and valid_full_name(t.gh_repo)
        ];
        pr_tasks.sort(key=lambda (t: Task) { t.gh_synced_at; });
        checked = 0;
        for t in pr_tasks {
            if checked >= SYNC_PR_CAP {
                break;
            }
            checked = checked + 1;
            result = gh_request(
                token, "GET", "/repos/" + t.gh_repo + "/pulls/" + str(t.pr_number)
            );
            if not result["ok"] {
                mark_invalid(c, result);
                continue;
            }
            item = result["data"];
            if not isinstance(item, dict) {
                continue;
            }
            fresh_state = pr_state_of(item);
            if fresh_state and fresh_state != t.pr_state {
                t.pr_state = fresh_state;
                changed.append(t.to_view());
            }
            t.gh_synced_at = stamp;
        }
        if isinstance(c, GithubConnection) {
            c.last_sync_at = stamp;
        }
        report {
            "ok": True,
            "synced": len(linked),
            "changed": changed,
            "last_sync_at": stamp
        };
    }
}
