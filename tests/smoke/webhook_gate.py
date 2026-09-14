#!/usr/bin/env python3
"""Smoke test for the GitHub integration against a running `jac run --no-dev`
server whose GITHUB_API_BASE / GITHUB_WEB_BASE point at github_stub.py: the
real connect round trip binds the installation, the poll back-fills the
stub's issues, and signed deliveries to /webhook/GithubEvent are queued by
the receiver and applied by the workspace's drain, with every guard and the
isolation between workspaces asserted. Usage:
webhook_gate.py [base_url] [stub_url]; the webhook secret comes from
GITHUB_APP_WEBHOOK_SECRET and the App slug from GITHUB_APP_SLUG."""
import hashlib
import hmac
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from urllib.parse import parse_qs, urlparse

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000").rstrip("/")
STUB = (sys.argv[2] if len(sys.argv) > 2 else "http://127.0.0.1:8099").rstrip("/")
SECRET = os.environ.get("GITHUB_APP_WEBHOOK_SECRET", "ci-webhook-secret")
BOT = os.environ.get("GITHUB_APP_SLUG", "ci-app") + "[bot]"
REPO = "ci-org/ci-repo"
INST_A, INST_B, INST_A2, INST_D = 111, 222, 333, 444
READY_TIMEOUT = 420
TOKEN = ""
FAILS: list[str] = []


def req(base, method, path, body=None, headers=None, raw=None, auth=True):
    h = {"Accept": "application/json"}
    data = raw
    if body is not None:
        h["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    if raw is not None:
        h["Content-Type"] = "application/json"
    if auth and TOKEN:
        h["Authorization"] = f"Bearer {TOKEN}"
    if headers:
        h.update(headers)
    r = urllib.request.Request(base + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=90) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def walker(name, body=None):
    status, raw = req(BASE, "POST", f"/walker/{name}", body or {})
    try:
        payload = json.loads(raw)
    except ValueError:
        payload = {}
    data = payload.get("data") if isinstance(payload, dict) else None
    reports = (data or {}).get("reports") if isinstance(data, dict) else None
    rep = reports[0] if reports else None
    return rep if isinstance(rep, dict) else {"_status": status, "_raw": raw[:300].decode(errors="replace")}


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + (f"  [{str(detail)[:300]}]" if detail and not ok else ""))
    if not ok:
        FAILS.append(name)
    return ok


def wait_ready():
    deadline = time.time() + READY_TIMEOUT
    while time.time() < deadline:
        try:
            if req(BASE, "GET", "/healthz/ready", auth=False)[0] == 200:
                return True
        except (urllib.error.URLError, OSError):
            pass
        time.sleep(3)
    return False


def login(label):
    global TOKEN
    tag = uuid.uuid4().hex[:8]
    email, password = f"wh-{label}-{tag}@flowline-ci.invalid", f"Ci-{tag}-Xy7!"
    status, raw = req(BASE, "POST", "/user/register", {
        "identities": [{"type": "email", "value": email}],
        "credential": {"type": "password", "password": password},
        "profile": {"org_name": f"Webhook {label}", "full_name": "CI Runner"},
    }, auth=False)
    assert status in (200, 201), ("register", status, raw[:200])
    status, raw = req(BASE, "POST", "/user/login", {
        "identity": {"type": "email", "value": email},
        "credential": {"type": "password", "password": password},
    }, auth=False)
    tok = json.loads(raw).get("data", {}).get("token", "") if raw else ""
    assert tok, ("login", status, raw[:200])
    TOKEN = tok
    return TOKEN


def connect(installation_id):
    """The real install round trip: nonce from StartGithubInstall, then the
    callback the App would redirect to, answered by the stub."""
    start = walker("StartGithubInstall")
    state = parse_qs(urlparse(start.get("url", "")).query).get("state", [""])[0]
    if not state:
        return start
    return walker("CompleteGithubInstall", {"code": "stub-code", "installation_id": installation_id, "state": state})


def iso(delta_minutes=0):
    return (datetime.now(timezone.utc) + timedelta(minutes=delta_minutes)).strftime("%Y-%m-%dT%H:%M:%SZ")


def sign(body):
    return "sha256=" + hmac.new(SECRET.encode(), body, hashlib.sha256).hexdigest()


def deliver(event, payload, secret=None, delivery=None):
    body = json.dumps(payload).encode()
    sig = sign(body) if secret is None else "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    headers = {"X-Hub-Signature-256": sig, "X-GitHub-Event": event,
               "X-GitHub-Delivery": delivery or str(uuid.uuid4())}
    status, raw = req(BASE, "POST", "/webhook/GithubEvent", headers=headers, raw=body, auth=False)
    rep = {}
    try:
        data = json.loads(raw).get("data") or {}
        reps = data.get("reports") or []
        rep = reps[0] if reps and isinstance(reps[0], dict) else {}
    except (ValueError, AttributeError):
        pass
    return status, rep


def drain():
    return walker("DrainGithubEvents")


def push(event, payload, **kw):
    status, rep = deliver(event, payload, **kw)
    return rep, drain()


def tasks_all():
    rows, page = [], 1
    while True:
        pg = walker("ListTasks", {"scope": "all", "page": page, "page_size": 100})
        rows += pg.get("rows", [])
        if not pg.get("has_more"):
            return rows
        page += 1


def task_by_issue(number):
    return next((r for r in tasks_all() if r.get("gh_repo") == REPO and r.get("gh_issue_number") == number), None)


def task_by_title(title):
    return next((r for r in tasks_all() if r.get("title") == title), None)


def repo_flags(full_name):
    status, raw = req(BASE, "POST", "/walker/ListRepos", {})
    reps = (json.loads(raw).get("data") or {}).get("reports") or []
    rows = reps[0] if reps and isinstance(reps[0], list) else reps
    for r in rows:
        if r.get("full_name") == full_name:
            return (bool(r.get("auto_sync")), bool(r.get("auto_done")))
    return None


def log_rows():
    rows, page = [], 1
    while True:
        pg = walker("ListLogEntries", {"from_date": "2020-01-01", "to_date": "2030-12-31", "page": page, "page_size": 100})
        rows += pg.get("rows", [])
        if not pg.get("has_more"):
            return rows
        page += 1


def issue(number, state, updated, closed=None, title="probe", extra=None):
    item = {
        "number": number, "title": title, "state": state, "body": "", "labels": [], "assignees": [],
        "html_url": f"https://github.com/{REPO}/issues/{number}", "updated_at": updated,
        "closed_at": closed, "created_at": "2026-09-01T00:00:00Z",
        "repository_url": f"https://api.github.com/repos/{REPO}",
    }
    if extra:
        item.update(extra)
    return item


def envelope(action, sender="octocat", inst=INST_A, **kw):
    p = {"action": action, "installation": {"id": inst}, "repository": {"full_name": REPO},
         "sender": {"login": sender, "type": "User"}}
    p.update(kw)
    return p


def main() -> int:
    global TOKEN
    if not check("server ready within timeout", wait_ready()):
        return 2
    status, _ = req(STUB, "POST", "/_stub/reset", {
        "installations": [INST_A, INST_B, INST_A2, INST_D],
        "repos": {REPO: [
            issue(1, "open", "2026-09-02T10:00:00Z", title="Stub issue one"),
            issue(2, "open", "2026-09-02T11:00:00Z", title="Stub issue two"),
            issue(3, "closed", "2026-09-02T12:00:00Z", "2026-09-02T12:00:00Z", title="Stub issue three"),
        ]},
    }, auth=False)
    if not check("github stub reachable", status == 200, str(status)):
        return 2

    # ---------------------------------------------------------- workspace A
    print("== workspace A")
    login("a")
    conn = connect(INST_A)
    check("connect round trip binds the installation", conn.get("ok") and conn.get("connection", {}).get("connected"), conn)
    status_view = walker("GithubStatus")
    check("GithubStatus: connected to the stub account, no deliveries yet",
          status_view.get("connected") and status_view.get("account_login") == "stub-org"
          and not status_view.get("webhook_seen_at"), status_view)
    rid = walker("AddRepo", {"full_name": REPO}).get("id", "")
    check("AddRepo", bool(rid))
    walker("SetRepoAutoSync", {"repo_id": rid, "enabled": True})
    walker("SetRepoAutoDone", {"repo_id": rid, "enabled": True})
    s = walker("SyncGithub")
    check("poll back-fills the stub's issues", s.get("ok") and s.get("auto_added") == 3 and not s.get("failure"), s)
    t3 = task_by_issue(3) or {}
    check("  closed issue lands on Done", t3.get("status") == "Done" and t3.get("gh_issue_state") == "closed", t3)
    check("drain on an empty queue", drain().get("drained") == 0)
    N = 1

    status, rep = deliver("ping", {"zen": "Keep it logically awesome.", "hook_id": 1, "hook": {"type": "App"}})
    check("ping answers", status == 200 and rep.get("outcome") == "ping", (status, rep))
    status, rep = deliver("issues", envelope("closed", issue=issue(N, "closed", iso(1), iso(1))), secret="wrong")
    check("wrong secret refused (401)", status == 401, status)
    rep, dr = push("issues", envelope("closed", inst=424242, issue=issue(N, "closed", iso(1), iso(1))))
    check("unknown installation dropped at the receiver", rep.get("outcome") == "unknown_installation" and dr.get("drained") == 0, (rep, dr))

    closed_at, did = iso(1), str(uuid.uuid4())
    status, rep = deliver("issues", envelope("closed", issue=issue(N, "closed", closed_at, closed_at)), delivery=did)
    check("issues.closed is queued", status == 200 and rep.get("outcome") == "queued", (status, rep))
    check("  webhook_seen_at set before any drain", bool(walker("GithubStatus").get("webhook_seen_at")))
    check("  card untouched until the workspace drains", (task_by_issue(N) or {}).get("status") != "Done")
    dr = drain()
    check("  drain applies it and moves the card", dr.get("drained") == 1 and dr.get("applied") == 1 and dr.get("moved") == 1, dr)
    t = task_by_issue(N) or {}
    check("  task Done, state closed", t.get("status") == "Done" and t.get("gh_issue_state") == "closed", t)
    moved = [r for r in log_rows() if r.get("task_title") == t.get("title") and "issue closed" in r.get("activity", "")]
    check("  one log line dated closed_at", len(moved) == 1 and moved[0].get("at", "")[:16] == closed_at[:16], moved)

    log_mid = len(log_rows())
    rep, dr = push("issues", envelope("closed", issue=issue(N, "closed", closed_at, closed_at)), delivery=did)
    check("duplicate delivery id refused, nothing drained", rep.get("outcome") == "duplicate" and dr.get("drained") == 0 and len(log_rows()) == log_mid, (rep, dr))
    rep, dr = push("issues", envelope("reopened", issue=issue(N, "open", iso(-5))))
    check("stale event drained but not applied", dr.get("drained") == 1 and dr.get("applied") == 0 and (task_by_issue(N) or {}).get("gh_issue_state") == "closed", dr)
    rep, dr = push("issues", envelope("reopened", issue=issue(N, "open", iso(2))))
    t = task_by_issue(N) or {}
    check("newer reopen refreshes state, card stays", dr.get("applied") == 1 and t.get("gh_issue_state") == "open" and t.get("status") == "Done", (dr, t.get("gh_issue_state"), t.get("status")))

    NEW = 999999
    rep, dr = push("issues", envelope("opened", issue=issue(NEW, "open", iso(0), title="Webhook-filed probe")))
    check("issues.opened files a task", dr.get("added") == 1 and task_by_issue(NEW) is not None, dr)
    check("  with its import log line", len([r for r in log_rows() if r.get("task_title") == "Webhook-filed probe"]) == 1)
    p = envelope("opened", issue=issue(999998, "open", iso(0)))
    p["repository"] = {"full_name": "someone/else"}
    rep, dr = push("issues", p)
    check("untracked repo drained without effect", rep.get("outcome") == "queued" and dr.get("applied") == 0 and task_by_issue(999998) is None, (rep, dr))
    rep, dr = push("issues", envelope("closed", sender=BOT, issue=issue(NEW, "closed", iso(3), iso(3))))
    check("the App's own echo dropped at the receiver", rep.get("outcome") == "echo" and dr.get("drained") == 0, (rep, dr))
    rep, dr = push("issue_comment", envelope("created", issue=issue(NEW, "open", iso(3))))
    check("unsupported event not queued", rep.get("outcome") == "unsupported" and dr.get("drained") == 0, (rep, dr))

    pt = walker("CreateTask", {"title": "PR-linked probe", "status": "In Progress"})
    pid = pt.get("id", "")
    check("CreateTask for the PR case", bool(pid), pt)
    walker("UpdateTask", {"task_id": pid, "title": "PR-linked probe", "status": "In Progress", "priority": "Medium",
                          "pr_link": f"https://github.com/{REPO}/pull/50"})
    merged_at = iso(1)
    pr = {"number": 50, "state": "closed", "merged_at": merged_at, "updated_at": merged_at, "draft": False,
          "html_url": f"https://github.com/{REPO}/pull/50", "title": "x"}
    rep, dr = push("pull_request", envelope("closed", pull_request=pr))
    t = task_by_title("PR-linked probe") or {}
    check("pull_request merged moves the linked card", dr.get("moved") == 1 and t.get("status") == "Done" and t.get("pr_state") == "merged", (dr, t.get("status"), t.get("pr_state")))
    pr_rows = [r for r in log_rows() if r.get("task_title") == "PR-linked probe" and "PR merged" in r.get("activity", "")]
    check("  log line dated merged_at", len(pr_rows) == 1 and pr_rows[0].get("at", "")[:16] == merged_at[:16], pr_rows)
    rep, dr = push("pull_request", envelope("reopened", pull_request=dict(pr, state="open", merged_at=None, updated_at=iso(-10))))
    check("stale PR event not applied", dr.get("applied") == 0 and (task_by_title("PR-linked probe") or {}).get("pr_state") == "merged", dr)
    rep, dr = push("pull_request", envelope("closed", pull_request=dict(pr, number=424242)))
    check("unlinked PR drained without effect", dr.get("drained") == 1 and dr.get("applied") == 0, dr)

    parent = issue(N, "open", iso(4), extra={"sub_issues_summary": {"total": 1, "completed": 0}})
    child = issue(NEW, "open", iso(4))
    fam = dict(parent_issue=parent, parent_issue_repo={"full_name": REPO}, sub_issue=child, sub_issue_repo={"full_name": REPO})
    rep, dr = push("sub_issues", envelope("sub_issue_added", **fam))
    tp, tc = task_by_issue(N) or {}, task_by_issue(NEW) or {}
    check("sub_issue_added links the family", dr.get("applied") == 1 and tc.get("gh_parent_number") == N and tp.get("gh_sub_total") == 1, (dr, tc.get("gh_parent_number"), tp.get("gh_sub_total")))
    parent["sub_issues_summary"] = {"total": 0, "completed": 0}
    rep, dr = push("sub_issues", envelope("sub_issue_removed", **fam))
    tp, tc = task_by_issue(N) or {}, task_by_issue(NEW) or {}
    check("sub_issue_removed clears it", tc.get("gh_parent_number") == 0 and tp.get("gh_sub_total") == 0, (tc.get("gh_parent_number"), tp.get("gh_sub_total")))
    rep, dr = push("issues", envelope("deleted", issue=issue(NEW, "open", iso(5))))
    check("issues.deleted unlinks the task, keeps the card", dr.get("drained") == 1 and task_by_issue(NEW) is None and task_by_title("Webhook-filed probe") is not None, dr)

    status, rep = deliver("issues", envelope("opened", issue=issue(999997, "open", iso(0), title="Sync-drained probe")))
    s = walker("SyncGithub")
    check("SyncGithub drains the queue before polling", s.get("ok") and s.get("drained") == 1 and task_by_title("Sync-drained probe") is not None, s)
    one = [r for r in log_rows() if r.get("task_title") == "Stub issue one" and "issue closed" in r.get("activity", "")]
    check("  the poll adds no duplicate auto-done line", len(one) == 1, len(one))
    status, rep = deliver("issues", envelope("opened", issue=issue(999996, "open", iso(0), title="Auto-pass probe")))
    s = walker("SyncGithub", {"auto": True})
    check("auto pass while live: 15-minute cooldown skips the poll but still drains",
          s.get("ok") and s.get("cooldown_minutes") == 15.0 and s.get("pages") == 0 and s.get("drained") == 1
          and task_by_title("Auto-pass probe") is not None, s)
    s = walker("SyncGithub")
    check("  manual sync ignores the cooldown", s.get("ok") and s.get("pages", 0) >= 1, s)
    token_a = TOKEN

    # ---------------------------------------------------------- workspace B
    print("== workspace B")
    login("b")
    connect(INST_B)
    rid_b = walker("AddRepo", {"full_name": REPO}).get("id", "")
    walker("SetRepoAutoSync", {"repo_id": rid_b, "enabled": True})
    rep, dr = push("issues", envelope("opened", inst=INST_B, issue=issue(777001, "open", iso(0), title="B-only probe")))
    check("B drains its own installation's delivery", rep.get("outcome") == "queued" and dr.get("added") == 1 and task_by_title("B-only probe") is not None, (rep, dr))
    status, rep = deliver("issues", envelope("opened", issue=issue(777002, "open", iso(0), title="A-only probe")))
    dr = drain()
    check("A's delivery never drains into B", dr.get("drained") == 0 and task_by_title("A-only probe") is None, dr)
    TOKEN = token_a
    dr = drain()
    check("A drains it; B's task never appears in A", dr.get("added") == 1 and task_by_title("A-only probe") is not None and task_by_title("B-only probe") is None, dr)

    # ---------------------------------------------------------- workspace C takes over A's installation, then leaves
    print("== workspace C")
    login("c")
    connect(INST_A)
    rid_c = walker("AddRepo", {"full_name": REPO}).get("id", "")
    walker("SetRepoAutoSync", {"repo_id": rid_c, "enabled": True})
    token_c = TOKEN
    status, rep = deliver("issues", envelope("opened", issue=issue(777003, "open", iso(0), title="Handover probe")))
    TOKEN = token_a
    dr = drain()
    check("the last workspace to connect an installation owns its queue: A drains nothing", dr.get("drained") == 0 and task_by_title("Handover probe") is None, dr)
    TOKEN = token_c
    dr = drain()
    check("  C drains it", dr.get("added") == 1 and task_by_title("Handover probe") is not None, dr)
    walker("DisconnectGithub")
    TOKEN = token_a
    walker("GithubStatus")
    status, rep = deliver("issues", envelope("opened", issue=issue(777004, "open", iso(0), title="Handback probe")))
    dr = drain()
    check("after C disconnects, A's status call reclaims it and drains again", dr.get("added") == 1 and task_by_title("Handback probe") is not None, dr)

    # ---------------------------------------------------------- reconnect with a new installation
    conn = connect(INST_A2)
    check("A reconnects with a new installation", conn.get("ok"), conn)
    status, rep = deliver("issues", envelope("opened", inst=INST_A, issue=issue(777005, "open", iso(0), title="Old install probe")))
    check("  deliveries for the old installation are dropped", rep.get("outcome") == "unknown_installation", rep)
    rep, dr = push("issues", envelope("opened", inst=INST_A2, issue=issue(777006, "open", iso(0), title="New install probe")))
    check("  and the new one flows", dr.get("added") == 1 and task_by_title("New install probe") is not None, (rep, dr))

    # ---------------------------------------------------------- workspace D never saw a delivery
    print("== workspace D")
    login("d")
    connect(INST_D)
    rid_d = walker("AddRepo", {"full_name": REPO}).get("id", "")
    walker("SetRepoAutoSync", {"repo_id": rid_d, "enabled": True})
    s = walker("SyncGithub", {"auto": True})
    check("auto pass with no deliveries: 1-minute cooldown, first pass polls",
          s.get("ok") and s.get("cooldown_minutes") == 1.0 and s.get("pages", 0) >= 1, s)
    s = walker("SyncGithub", {"auto": True})
    check("  second auto pass inside the minute is skipped", s.get("ok") and s.get("pages") == 0 and s.get("cooldown_minutes") == 1.0, s)

    # ---------------------------------------------------------- the App's lifecycle, on D
    print("== installation lifecycle (D)")
    walker("SetRepoAutoDone", {"repo_id": rid_d, "enabled": True})
    check("repo starts with auto-sync and auto-done on", repo_flags(REPO) == (True, True), repo_flags(REPO))
    rep, dr = push("installation_repositories", envelope("removed", inst=INST_D, repositories_removed=[{"full_name": REPO}, {"full_name": "someone/else"}]))
    check("installation_repositories.removed turns auto-sync and auto-done off", dr.get("applied") == 1 and repo_flags(REPO) == (False, False), (dr, repo_flags(REPO)))
    req(STUB, "POST", "/_stub/reset", {
        "installations": [INST_A, INST_B, INST_A2, INST_D],
        "repos": {REPO: [
            issue(1, "open", "2026-09-02T10:00:00Z", title="Stub issue one"),
            issue(2, "open", "2026-09-02T11:00:00Z", title="Stub issue two"),
            issue(3, "closed", "2026-09-02T12:00:00Z", "2026-09-02T12:00:00Z", title="Stub issue three"),
            issue(4, "open", "2026-09-03T09:00:00Z", title="Stub issue four"),
        ]},
    }, auth=False)
    s = walker("SyncGithub")
    check("  the next sync scans the repo but files nothing", s.get("ok") and s.get("scanned", 0) >= 1 and s.get("auto_added") == 0 and task_by_issue(4) is None, s)
    rep, dr = push("installation", envelope("suspend", inst=INST_D))
    check("installation.suspend marks the connection invalid", dr.get("applied") == 1 and walker("GithubStatus").get("status") == "invalid", (dr, walker("GithubStatus")))
    rep, dr = push("installation", envelope("unsuspend", inst=INST_D))
    check("installation.unsuspend restores it", dr.get("applied") == 1 and walker("GithubStatus").get("status") == "ok", (dr, walker("GithubStatus")))
    rep, dr = push("installation", envelope("deleted", inst=INST_D))
    check("installation.deleted marks the connection invalid", dr.get("applied") == 1 and walker("GithubStatus").get("status") == "invalid", (dr, walker("GithubStatus")))
    status, rep = deliver("issues", envelope("opened", inst=INST_D, issue=issue(777007, "open", iso(0), title="After delete probe")))
    check("  later deliveries for it are dropped at the receiver", rep.get("outcome") == "unknown_installation", rep)
    walker("GithubStatus")
    status, rep = deliver("issues", envelope("opened", inst=INST_D, issue=issue(777008, "open", iso(0), title="After status probe")))
    check("  and the status call does not rebind it", rep.get("outcome") == "unknown_installation" and drain().get("drained") == 0, rep)

    print("webhook gate: " + ("PASS" if not FAILS else f"FAIL ({len(FAILS)})"))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
