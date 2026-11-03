#!/usr/bin/env python3
"""Smoke test for AI responsibilities against a running server and
github_stub.py: a move onto a role's step queues the role's responsibilities
(once per task while one is active), the AI switch, a missing PR and a
switched-off responsibility each skip with a log line, another workspace sees
none of it, and the scheduled runner reviews a queued run (FLOWLINE_FAKE_LLM),
retries a 5xx, fails a 403, skips a closed PR and a commit already reviewed,
and retries a GitHub call that times out. Reuses webhook_gate's helpers.
Usage: agents_gate.py [base_url] [stub_url]"""
import base64
import json
import os
import sys
import time

import webhook_gate as wg
from webhook_gate import check, walker, project, req, connect

REPO = "ci-org/agents-repo"
INST = 4747
SETTLED = ("done", "failed", "skipped", "cancelled")


def reports(name, body=None):
    status, raw = req(wg.BASE, "POST", f"/walker/{name}", body or {})
    try:
        data = json.loads(raw).get("data") or {}
    except ValueError:
        return []
    return data.get("reports") or []


def runs(task_id):
    rep = reports("ListRuns", {"task_id": task_id})
    return rep[0] if rep and isinstance(rep[0], list) else []


def flow_steps():
    rep = reports("GetFlowLine", {"with_counts": False})
    return {st["name"]: st for st in (rep[0] if rep and isinstance(rep[0], list) else [])}


def ai_state(task_id):
    return walker("GetTask", {"task_id": task_id}).get("ai_state")


def task_log(task_id):
    pg = walker("ListLogEntries", {"from_date": "2020-01-01", "to_date": "2030-12-31",
                                   "task_id": task_id, "page_size": 100})
    return [r.get("activity", "") for r in pg.get("rows", [])]


def update(t, **changes):
    """UpdateTask overwrites every field, so a save carries the task's own."""
    body = {k: t.get(k, "") for k in ("title", "category", "priority", "status", "step_id",
                                      "due_date", "start_date", "notes", "issue_link",
                                      "pr_link", "reviewer_id", "review_due", "project_id")}
    body.update({"task_id": t["id"], "tags": t.get("tags", []), "estimate": t.get("estimate", 0.0),
                 "assignee_ids": t.get("assignee_ids", [])})
    body.update(changes)
    return walker("UpdateTask", body)


def move(task_id, step_id):
    return walker("MoveTask", {"task_id": task_id, "step_id": step_id})


def queue_suite():
    wg.login("agents")
    pid = project()
    role = walker("SaveRole", {"name": "Product Engineer"}).get("role", {})
    walker("SaveRole", {"name": "Developer"})
    building = walker("SaveStep", {"name": "Building", "kind": "active", "owner": "Developer"})
    review = walker("SaveStep", {"name": "In review", "kind": "handoff", "owner": "Product Engineer"})
    bid, rid = building.get("id", ""), review.get("id", "")
    check("a role and the two steps", bool(role.get("id") and bid and rid), (role, building, review))
    saved = walker("SaveResponsibility", {"role_id": role["id"], "on_steps": [rid]})
    resp_id = (saved.get("responsibility") or {}).get("id", "")
    check("code review on In review", saved.get("ok") is True, saved)

    made = walker("CreateTask", {"title": "Add rate limits", "project_id": pid, "step_id": bid})
    t = update(made, pr_link=f"https://github.com/{REPO}/pull/7")
    tid = t.get("id", "")
    check("a task on Building with a linked PR", t.get("pr_link", "").endswith("/pull/7"), t)

    steps = flow_steps()
    check("with AI off, no step carries an AI mark", all(st.get("ai") == [] for st in steps.values()), steps)
    move(tid, rid)
    check("with AI off, a move queues nothing", runs(tid) == [], runs(tid))
    check("  and the move's log line says AI is off",
          any("AI code review skipped: AI is off" in a for a in task_log(tid)), task_log(tid))

    move(tid, bid)
    walker("SetAiEnabled", {"enabled": True})
    steps = flow_steps()
    check("with AI on, In review carries Code review and Building nothing",
          steps.get("In review", {}).get("ai") == ["Code review"] and steps.get("Building", {}).get("ai") == [], steps)
    landed_view = move(tid, rid)
    check("  and the move's reported row says AI review queued", landed_view.get("ai_state") == "queued", landed_view)
    queued = runs(tid)
    first = queued[0] if queued else {}
    check("with AI on, the move queues one run", len(queued) == 1 and first.get("status") == "queued"
          and first.get("key") == "code_review" and first.get("responsibility_id") == resp_id, queued)
    check("  carrying the PR from the link", first.get("pr_repo") == REPO and first.get("pr_number") == 7, first)
    check("  and the log line names it", any("Queued AI code review" in a for a in task_log(tid)), task_log(tid))

    move(tid, bid)
    move(tid, rid)
    check("a second landing while one is active queues nothing more", len(runs(tid)) == 1, runs(tid))

    plain = walker("CreateTask", {"title": "No PR yet", "project_id": pid, "step_id": bid})
    move(plain["id"], rid)
    check("a task with no PR is skipped", runs(plain["id"]) == []
          and any("skipped: no linked pull request" in a for a in task_log(plain["id"])), task_log(plain["id"]))

    off = walker("CreateTask", {"title": "Responsibility off", "project_id": pid, "step_id": bid})
    off = update(off, pr_link=f"https://github.com/{REPO}/pull/8")
    walker("SaveResponsibility", {"responsibility_id": resp_id, "enabled": False, "on_steps": [rid]})
    move(off["id"], rid)
    check("a switched-off responsibility queues nothing", runs(off["id"]) == [], runs(off["id"]))
    walker("SaveResponsibility", {"responsibility_id": resp_id, "enabled": True, "on_steps": [rid]})

    other = walker("CreateTask", {"title": "Somewhere else", "project_id": pid, "step_id": rid})
    other = update(other, pr_link=f"https://github.com/{REPO}/pull/9")
    move(other["id"], bid)
    check("a step the responsibility is not on queues nothing", runs(other["id"]) == [], runs(other["id"]))

    home = wg.TOKEN
    wg.login("agents-b")
    check("another workspace sees none of the runs", runs(tid) == [], runs(tid))
    wg.TOKEN = home
    return tid


def settle(task_id, want=1, timeout=90):
    """Wait for the task's newest `want` runs to finish; the runner ticks
    every FLOWLINE_AI_INTERVAL_SECONDS."""
    deadline = time.time() + timeout
    rows = runs(task_id)
    while time.time() < deadline:
        rows = runs(task_id)
        if len(rows) >= want and all(r.get("status") in SETTLED for r in rows[:want]):
            return rows
        time.sleep(2)
    return rows


def stub(path, body):
    status, _ = req(wg.STUB, "POST", path, body, auth=False)
    return status == 200


def pull(number, head, state="open"):
    return {"repo": REPO, "number": number, "head_sha": head, "state": state}


def runner_suite():
    stub("/_stub/reset", {"installations": [INST], "repos": {REPO: [{
        "number": 30, "title": "Imported issue", "state": "open", "body": "", "labels": [], "assignees": [],
        "html_url": f"https://github.com/{REPO}/issues/30", "repository_url": f"https://api.github.com/repos/{REPO}",
        "created_at": "2026-09-01T00:00:00Z", "updated_at": "2026-09-02T00:00:00Z", "closed_at": None}]}})
    stub("/_stub/pulls", {"pulls": [pull(7, "sha-7a"), pull(8, "sha-8"), pull(9, "sha-9"),
                                    pull(10, "sha-10", "closed"), pull(11, "sha-11")]})
    wg.login("runner")
    check("runner: connect GitHub", connect(INST).get("ok"))
    pid = project()
    role = walker("SaveRole", {"name": "Product Engineer"}).get("role", {})
    walker("SaveRole", {"name": "Developer"})
    bid = walker("SaveStep", {"name": "Building", "kind": "active", "owner": "Developer"}).get("id", "")
    rid = walker("SaveStep", {"name": "In review", "kind": "handoff", "owner": "Product Engineer"}).get("id", "")
    walker("SaveResponsibility", {"role_id": role["id"], "on_steps": [rid], "instructions": "Check errors."})
    walker("SetAiEnabled", {"enabled": True})

    def landed(title, number):
        t = walker("CreateTask", {"title": title, "project_id": pid, "step_id": bid})
        t = update(t, pr_link=f"https://github.com/{REPO}/pull/{number}")
        move(t["id"], rid)
        return t["id"]

    a = landed("Reviewed once", 7)
    done = settle(a)
    first = done[0] if done else {}
    check("runner: a queued run is reviewed", first.get("status") == "done" and first.get("verdict") == "comment"
          and first.get("head_sha") == "sha-7a" and first.get("model") == "fake", done)
    check("  and the task's log says so", any("AI code review · 0 comments, 0 blocking" in x for x in task_log(a)),
          task_log(a))
    check("  and the row's AI chip clears", ai_state(a) == "", ai_state(a))
    a_row = walker("GetTask", {"task_id": a})
    check("  and the row keeps what the review came to", a_row.get("ai_outcome") == "reviewed", a_row)
    activity = walker("ListAgentRuns", {"page_size": 100})
    a_line = next((r for r in activity.get("rows", []) if r.get("task_id") == a), {})
    check("  and the AI page lists it with its task", a_line.get("status") == "done" and bool(a_line.get("task_title"))
          and bool(a_line.get("project_name")), activity)
    check("  and the AI page counts today's runs", activity.get("runs_today", 0) >= 1
          and activity.get("daily_limit", 0) > 0, activity)
    calls = [c[1] for c in wg.stub_calls(INST)]
    check("  reading the PR with the installation's token", f"/repos/{REPO}/pulls/7" in calls, calls)
    move(a, bid)
    move(a, rid)
    again = settle(a, 2)
    check("runner: the same commit is not reviewed twice", len(again) == 2 and again[0].get("status") == "skipped"
          and "already reviewed" in again[0].get("error", ""), again)

    stub("/_stub/fault", {"method": "GET", "path": f"/repos/{REPO}/pulls/8", "status": 502, "times": 1})
    b = landed("Retried after a 5xx", 8)
    retried = settle(b, 1, 120)
    check("runner: a GitHub 5xx is retried, then succeeds", retried and retried[0].get("status") == "done"
          and retried[0].get("attempts") == 2, retried)

    stub("/_stub/fault", {"method": "GET", "path": f"/repos/{REPO}/pulls/9", "status": 403, "times": 5})
    c = landed("Refused with a 403", 9)
    refused = settle(c)
    check("runner: a 403 fails at once", refused and refused[0].get("status") == "failed"
          and refused[0].get("attempts") == 1 and "403" in refused[0].get("error", ""), refused)
    check("  and the task's log says why", any("AI code review failed" in x for x in task_log(c)), task_log(c))

    stub("/_stub/pulls", {"pulls": [pull(18, "sha-18")]})
    stub("/_stub/fault", {"method": "GET", "path": f"/repos/{REPO}/pulls/18", "times": 1, "delay": 8})
    x = landed("Cancelled, then retried", 18)
    open_run = (runs(x) or [{}])[0]
    cancelled = walker("CancelRun", {"run_id": open_run.get("id", "")})
    check("cancel: an open run is cancelled and the chip clears", cancelled.get("ok") is True
          and ai_state(x) == "", (cancelled, ai_state(x)))
    again_view = walker("RetryRun", {"run_id": open_run.get("id", "")})
    check("retry: the run is queued again with a fresh count", again_view.get("ok") is True
          and (again_view.get("run") or {}).get("attempts") == 0 and ai_state(x) == "queued", again_view)
    redone = settle(x, 1, 120)
    check("  and the runner finishes it", redone and redone[0].get("status") == "done" and ai_state(x) == "", redone)

    d = landed("Closed PR", 10)
    closed = settle(d)
    check("runner: a closed PR is skipped", closed and closed[0].get("status") == "skipped"
          and "closed" in closed[0].get("error", ""), closed)

    patch = "@@ -1,3 +1,5 @@\n import os\n+x = compute()  # BUG: wrong unit\n def f():\n+    pass  # TODO handle errors\n     return 1"
    stub("/_stub/pulls", {"pulls": [dict(pull(12, "sha-12"), files=[
        {"filename": "app/service.py", "status": "modified", "additions": 2, "deletions": 0, "patch": patch},
        {"filename": "package-lock.json", "status": "modified", "additions": 900, "deletions": 3, "patch": "@@ -1 +1 @@\n-a\n+b"},
        {"filename": "old.py", "status": "removed", "additions": 0, "deletions": 10, "patch": "@@ -1 +0,0 @@\n-x"},
        {"filename": "logo.png", "status": "added", "additions": 0, "deletions": 0},
    ])]})
    f = landed("Findings on added lines", 12)
    found = settle(f)
    row = found[0] if found else {}
    check("engine: findings land on added lines, lock, removed and binary files skipped",
          row.get("status") == "done" and row.get("comments") == 2 and row.get("blocking") == 1
          and row.get("verdict") == "request_changes", row)
    rc_view = walker("GetTask", {"task_id": row.get("task_id")})
    check("  and the row says how many are blocking", rc_view.get("ai_outcome") == "changes"
          and rc_view.get("ai_blocking") == 1, rc_view)
    attention = walker("ListAgentRuns", {"attention": True, "page_size": 100}).get("rows", [])
    check("  and it is on the AI page's needs a look", row.get("id") in [r.get("id") for r in attention], attention)
    check("  and the task's log counts them", any("2 comments, 1 blocking" in x for x in task_log(f)), task_log(f))
    files = [c[1] for c in wg.stub_calls(INST) if c[1].endswith("/pulls/12/files")]
    check("  reading the PR's files once", len(files) == 1, files)
    posted = [r for r in wg.stub_state().get("reviews", []) if r["number"] == 12]
    review = posted[0] if posted else {}
    check("post: one review on the PR's head commit, inline comments on the added lines",
          len(posted) == 1 and review.get("commit_id") == "sha-12" and review.get("event") == "COMMENT"
          and sorted((c["path"], c["line"]) for c in review.get("comments", [])) == [("app/service.py", 2), ("app/service.py", 4)]
          and "AI code review" in (review.get("body") or ""), posted)
    check("  and the run links to it", "pullrequestreview-" in row.get("review_url", ""), row)

    def with_bug(number):
        return dict(pull(number, f"sha-{number}"), files=[
            {"filename": "app/a.py", "status": "modified", "additions": 1, "deletions": 0,
             "patch": "@@ -1,1 +1,2 @@\n a = 1\n+b = a / 0  # BUG"}])

    stub("/_stub/pulls", {"pulls": [with_bug(13), with_bug(14)]})
    stub("/_stub/fault", {"method": "POST", "path": f"/repos/{REPO}/pulls/13/reviews", "status": 403, "times": 5})
    g = landed("App lacks PR write", 13)
    lacking = settle(g)
    check("post: a 403 fails at once with the approval hint", lacking and lacking[0].get("status") == "failed"
          and "Pull requests: read and write" in lacking[0].get("error", ""), lacking)
    stub("/_stub/fault", {"method": "POST", "path": f"/repos/{REPO}/pulls/14/reviews", "status": 422, "times": 1})
    h = landed("A comment GitHub refuses", 14)
    fallback = settle(h)
    later = [r for r in wg.stub_state().get("reviews", []) if r["number"] == 14]
    check("post: a refused comment line falls back to the findings in the body",
          fallback and fallback[0].get("status") == "done" and len(later) == 1 and later[0]["comments"] == []
          and "app/a.py:2" in (later[0].get("body") or ""), later)

    # Request-changes mode: a blocking finding posts REQUEST_CHANGES and sends
    # the task back along In review's "changes requested" arrow.
    walker("LinkTransition", {"from_id": rid, "to_id": bid, "trigger": "changes_requested"})
    resp = (walker("ListResponsibilities").get("responsibilities") or [{}])[0]
    walker("SaveResponsibility", {"responsibility_id": resp.get("id", ""), "on_steps": [rid],
                                  "instructions": "Check errors.", "mode": "request_changes"})
    todo_only = "@@ -1,1 +1,2 @@\n a = 1\n+b = 2  # TODO tidy"
    stub("/_stub/pulls", {"pulls": [with_bug(15), with_bug(17), dict(pull(16, "sha-16"), files=[
        {"filename": "app/b.py", "status": "modified", "additions": 1, "deletions": 0, "patch": todo_only}])]})
    k = landed("Blocking finding", 15)
    sent = settle(k)
    back = walker("GetTask", {"task_id": k})
    posted15 = [r for r in wg.stub_state().get("reviews", []) if r["number"] == 15]
    check("request changes: a blocking finding posts REQUEST_CHANGES", sent and sent[0].get("verdict") == "request_changes"
          and posted15 and posted15[0]["event"] == "REQUEST_CHANGES", posted15)
    check("  and sends the task back along the arrow", back.get("step_id") == bid
          and any("Moved to Building · AI code review requested changes" in x for x in task_log(k)), task_log(k))
    m = landed("Warnings only", 16)
    settle(m)
    posted16 = [r for r in wg.stub_state().get("reviews", []) if r["number"] == 16]
    check("request changes: warnings alone comment and leave the task", walker("GetTask", {"task_id": m}).get("step_id") == rid
          and posted16 and posted16[0]["event"] == "COMMENT", posted16)
    ready = walker("SaveStep", {"name": "Ready", "kind": "start", "owner": "Developer"}).get("id", "")
    stub("/_stub/fault", {"method": "GET", "path": f"/repos/{REPO}/pulls/17", "times": 1, "delay": 5})
    n = landed("Moved on meanwhile", 17)
    move(n, ready)
    settle(n)
    check("request changes: a task that moved on meanwhile stays put", walker("GetTask", {"task_id": n}).get("step_id") == ready,
          walker("GetTask", {"task_id": n}).get("step_id"))

    # New commits on a reviewed PR while its task waits in review queue it
    # again; a second delivery for the same commit is skipped. The PR links
    # to an imported issue the way the sync links one ("Closes #30").
    def pr_event(action, number, head, body=""):
        stub("/_stub/pulls", {"pulls": [pull(number, head)]})
        wg.push("pull_request", {
            "action": action, "installation": {"id": INST}, "repository": {"full_name": REPO},
            "sender": {"login": "octocat", "type": "User"},
            "pull_request": {"number": number, "state": "open", "body": body, "labels": [], "head": {"sha": head},
                             "html_url": f"https://github.com/{REPO}/pull/{number}", "updated_at": wg.iso(),
                             "merged_at": None}})

    repo_id = walker("AddRepo", {"full_name": REPO, "project_id": pid}).get("id", "")
    walker("SetRepoAutoSync", {"repo_id": repo_id, "enabled": True})
    walker("SyncGithub", {})
    issue_task = next((r for r in wg.tasks_all() if r.get("gh_repo") == REPO and r.get("gh_issue_number") == 30), {})
    pr_event("opened", 31, "sha-31a", "Closes #30")
    linked = walker("GetTask", {"task_id": issue_task.get("id", "")})
    check("re-review: an imported issue's task links its PR", linked.get("pr_number") == 31, linked)
    move(linked["id"], rid)
    settle(linked["id"])
    before = len(runs(linked["id"]))
    time.sleep(1)
    pr_event("synchronize", 31, "sha-31b")
    fresh = settle(linked["id"], before + 1)
    check("re-review: new commits on the PR are reviewed again", len(fresh) == before + 1
          and fresh[0].get("status") == "done" and fresh[0].get("head_sha") == "sha-31b", fresh[:2])
    check("  and the log says why", any("New commits on PR" in x for x in task_log(linked["id"])), task_log(linked["id"]))
    time.sleep(1)
    pr_event("synchronize", 31, "sha-31b")
    repeat = settle(linked["id"], before + 2)
    check("re-review: the same commit again is skipped", len(repeat) == before + 2
          and repeat[0].get("status") == "skipped" and "already reviewed" in repeat[0].get("error", ""), repeat[:2])

    # Since 0.38 the scheduler holds a function across the service, so no tick can
    # take back a claim while its review is alive, only once its pod dies, and no
    # gate kills a pod. The delay outlasts gh()'s 20 s timeout, so this is its retry.
    stub("/_stub/fault", {"method": "GET", "path": f"/repos/{REPO}/pulls/11", "times": 1, "delay": 25})
    e = landed("GitHub too slow", 11)
    slow = settle(e, 1, 150)
    check("runner: a GitHub call that times out is tried again and finished once",
          slow and slow[0].get("status") == "done" and slow[0].get("attempts") == 2, slow)



def main() -> int:
    if not check("server ready within timeout", wg.wait_ready()):
        return 2
    unconnected = queue_suite()
    queued_home = wg.TOKEN
    runner_suite()
    wg.TOKEN = queued_home
    gone = settle(unconnected)
    check("runner: a workspace with no GitHub connection fails its run",
          gone and gone[0].get("status") == "failed" and "not connected" in gone[0].get("error", ""), gone)
    password = os.environ.get("GRAFANA_ADMIN_PASSWORD", "ci-grafana")
    auth = "Basic " + base64.b64encode(f"admin:{password}".encode()).decode()
    status, raw = req(wg.BASE, "GET", "/metrics", headers={"Authorization": auth}, auth=False)
    text = raw.decode(errors="replace")
    check("metrics: /metrics counts AI runs by outcome",
          status == 200 and 'flowline_ai_runs_total{key="code_review",outcome="done"}' in text
          and 'outcome="failed"' in text and "flowline_ai_run_seconds_bucket" in text, (status, text[:200]))
    print("agents gate: " + ("PASS" if not wg.FAILS else f"FAIL ({len(wg.FAILS)})"))
    return 1 if wg.FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
