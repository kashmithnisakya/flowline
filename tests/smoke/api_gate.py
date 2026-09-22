#!/usr/bin/env python3
"""Smoke test against a running `jac run --no-dev` server: the web app shell
and its bundle are served, the API rejects anonymous calls, and a fresh
account can register, log in and drive the core walkers, including a burst of
concurrent reads. Usage: api_gate.py [base_url]"""
import json
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from collections import Counter
from datetime import date, timedelta
from concurrent.futures import ThreadPoolExecutor

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000").rstrip("/")
READY_TIMEOUT = 420
TOKEN = ""
FAILS: list[str] = []

# The browser caches a walker for 60 s only when the served effects table
# says `unknown: false, writes: []`. These readers are declared through a
# same-module @effects helper; recognition can vary between builds, so the
# table of THIS build is asserted here.
CACHED_READERS = [
    "GetWorkspace", "ListMembers", "ListProjects", "ListRoles", "ListIterations",
    "GetFlowLine", "GetFlowLineMeta", "ListRepos", "GithubStatus",
]
# Task lists stay uncached on purpose: a colleague's move, a webhook drain or
# a sync from another tab must show on the next call, not 60 s later.
LIVE_READERS = [
    "BoardSnapshot", "ListTasks", "OverviewSnapshot", "ListLogEntries",
    "TaskCounts", "TaskHistory", "RoadmapSnapshot", "ListStepTasks",
]
MUTATORS = [
    "CreateTask", "UpdateTask", "MoveTask", "DeleteTask", "SaveMember", "SaveProject",
    "SaveRole", "SaveStep", "SaveIteration", "AddRepo", "SyncGithub", "ApplyTemplate",
    "SetBoardFilters", "SaveFilterSet", "DeleteFilterSet",
]


def req(method, path, body=None, accept="application/json"):
    headers = {"Accept": accept}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    if TOKEN:
        headers["Authorization"] = f"Bearer {TOKEN}"
    r = urllib.request.Request(BASE + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(r, timeout=90) as resp:
            return resp.status, resp.headers.get("content-type", ""), resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get("content-type", ""), e.read()


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + (f"  [{detail}]" if detail and not ok else ""))
    if not ok:
        FAILS.append(name)
    return ok


def find_key(obj, *keys):
    # First value under any of the given keys, searching nested dicts.
    if isinstance(obj, dict):
        for k in keys:
            if k in obj and obj[k]:
                return obj[k]
        for v in obj.values():
            hit = find_key(v, *keys)
            if hit:
                return hit
    if isinstance(obj, list):
        for v in obj:
            hit = find_key(v, *keys)
            if hit:
                return hit
    return None


def walker(name, body=None):
    status, _, raw = req("POST", f"/walker/{name}", body or {})
    try:
        payload = json.loads(raw)
    except ValueError:
        payload = {"raw": raw[:300].decode(errors="replace")}
    data = payload.get("data") if isinstance(payload, dict) else None
    reports = (data or {}).get("reports") if isinstance(data, dict) else None
    if reports is None and isinstance(payload, dict):
        reports = payload.get("reports")
    return status, payload, reports or []


def report(name, body=None):
    # The first report of a walker, or {} / [] when it reports nothing.
    _, _, reports = walker(name, body)
    return reports[0] if reports else {}


STATUS_KIND = {"Backlog": "start", "In Progress": "active", "Review": "handoff",
               "Changes Requested": "active", "Done": "done", "Blocked": "blocked"}


def done_day(t):
    # The rule in services/util.jac: done_at, else updated_at, never before created.
    day = (t.get("done_at") or t.get("updated_at") or "")[:10]
    made = (t.get("created_at") or "")[:10]
    return made if made and day < made else day


def moved_to_done(t):
    return t.get("status") == "Done" and not (t.get("done_at") and t.get("done_at") == t.get("created_at"))


def all_rows():
    rows, page = [], 1
    while True:
        pg = report("ListTasks", {"scope": "all", "page": page, "page_size": 100})
        rows.extend(pg.get("rows", []))
        if not pg.get("has_more"):
            return rows
        page += 1


def board_rows():
    rows, page, older, cats = [], 1, None, None
    while True:
        b = report("BoardSnapshot", {"page": page, "page_size": 500})
        rows.extend(b.get("rows", []))
        older, cats = b.get("older"), b.get("categories")
        if not b.get("has_more"):
            return rows, older, cats
        page += 1


def brute_force(rows, steps, project_ids, member_ids, today, cutoff, weeks):
    # Everything the aggregators report, recomputed from the all-scope rows.
    working = [t for t in rows if t["status"] != "Done" or done_day(t) >= cutoff]
    open_rows = [t for t in rows if t["status"] != "Done"]
    exp = {
        "open": len(open_rows),
        "blocked": sum(1 for t in open_rows if t["status"] == "Blocked"),
        "overdue": sum(1 for t in open_rows if t["due_date"] and t["due_date"] < today),
        "categories": sorted({t["category"] for t in rows if t["category"]}),
        "working": len(working),
        "older": len(rows) - len(working),
        "done": sum(1 for t in rows if t["status"] == "Done"),
        "attention": sum(1 for t in open_rows if t["status"] == "Blocked" or (t["due_date"] and t["due_date"] < today)),
        "all": len(rows),
        "board_ids": sorted(t["id"] for t in working),
    }
    exp["projects"] = {pid: {
        "total": sum(1 for t in rows if t["project_id"] == pid),
        "done": sum(1 for t in rows if t["project_id"] == pid and t["status"] == "Done"),
        "blocked": sum(1 for t in open_rows if t["project_id"] == pid and t["status"] == "Blocked"),
        "active": sum(1 for t in open_rows if t["project_id"] == pid and t["status"] in ("In Progress", "Review", "Changes Requested")),
    } for pid in project_ids}
    exp["members"] = {mid: {
        "open": sum(1 for t in open_rows if mid in t["assignee_ids"]),
        "done_in_week": sum(1 for t in rows if mid in t["assignee_ids"] and moved_to_done(t) and done_day(t) >= weeks[-1]),
    } for mid in member_ids}

    def slot(day):
        found = -1
        for i, w in enumerate(weeks):
            if day and day >= w:
                found = i
        return found
    added = [0] * len(weeks)
    finished = [0] * len(weeks)
    scope_before = done_before = 0
    for t in rows:
        if t["status"] == "Done" and not moved_to_done(t):
            continue
        s = slot(t["created_at"][:10])
        if s < 0:
            scope_before += 1
        else:
            added[s] += 1
        if t["status"] == "Done":
            s = slot(done_day(t))
            if s < 0:
                done_before += 1
            else:
                finished[s] += 1
    scope, done = [], []
    for i in range(len(weeks)):
        scope_before += added[i]
        done_before += finished[i]
        scope.append(scope_before)
        done.append(done_before)
    exp["history"] = {"added": added, "finished": finished, "scope": scope, "done": done}
    known = [s["id"] for s in steps]
    first_of_kind = {}
    for s in steps:
        first_of_kind.setdefault(s["kind"], s["id"])
    counts = {s["id"]: 0 for s in steps}
    for t in working:
        landing = t["step_id"] if t["step_id"] in known else first_of_kind.get(STATUS_KIND.get(t["status"], "active"), "")
        if landing:
            counts[landing] += 1
    exp["step_counts"] = counts
    return exp


def assert_parity(label, project_ids, member_ids, expected_links):
    # Every aggregator against a brute-force pass over ListTasks(scope="all").
    from datetime import datetime, timedelta, timezone
    now = datetime.now(timezone.utc)
    today = now.strftime("%Y-%m-%d")
    cutoff = (now - timedelta(days=7)).strftime("%Y-%m-%d")
    rows = all_rows()
    counts = report("TaskCounts")
    history = report("TaskHistory")
    steps = report("GetFlowLine", {"with_counts": True}) or []
    weeks = history.get("weeks", [])
    exp = brute_force(rows, steps, project_ids, member_ids, today, cutoff, weeks)
    ok_links = all(t["project_id"] == expected_links[t["id"]][0] and sorted(t["assignee_ids"]) == sorted(expected_links[t["id"]][1])
                   for t in rows if t["id"] in expected_links)
    check(f"{label}: rows carry their project and assignee ids", ok_links and len(rows) == len(expected_links),
          f"{[(t['title'], t['project_id'], t['assignee_ids']) for t in rows]}")
    check(f"{label}: TaskCounts open/blocked/overdue/categories",
          (counts.get("open"), counts.get("blocked"), counts.get("overdue"), counts.get("categories"))
          == (exp["open"], exp["blocked"], exp["overdue"], exp["categories"]),
          f"{counts.get('open'), counts.get('blocked'), counts.get('overdue'), counts.get('categories')} vs {exp['open'], exp['blocked'], exp['overdue'], exp['categories']}")
    got_projects = {p["project_id"]: {k: p[k] for k in ("total", "done", "blocked", "active")} for p in counts.get("projects", [])}
    check(f"{label}: TaskCounts per-project tallies", got_projects == exp["projects"], f"{got_projects} vs {exp['projects']}")
    got_members = {m["member_id"]: {k: m[k] for k in ("open", "done_in_week")} for m in counts.get("members", [])}
    check(f"{label}: TaskCounts per-member tallies", got_members == exp["members"], f"{got_members} vs {exp['members']}")
    # Done per week comes from the weekly counts, so it must match both the
    # brute-force pass and TaskHistory's last four weeks, and the Overview
    # must answer the same numbers as TaskCounts.
    check(f"{label}: TaskCounts done_by_week equals the brute-force weeks",
          bool(weeks) and counts.get("done_by_week") == exp["history"]["finished"][-4:],
          f"{counts.get('done_by_week')} vs {exp['history']['finished'][-4:]}")
    snap = report("OverviewSnapshot", {"attention_size": 1}).get("counts", {})

    def keyed(totals, field, key):
        return {row[key]: {k: v for k, v in row.items() if not k.startswith("_")} for row in totals.get(field, [])}
    same = {k: snap.get(k) == counts.get(k) for k in ("open", "overdue", "blocked", "done_by_week")}
    same["projects"] = keyed(snap, "projects", "project_id") == keyed(counts, "projects", "project_id")
    same["members"] = keyed(snap, "members", "member_id") == keyed(counts, "members", "member_id")
    check(f"{label}: OverviewSnapshot counts equal TaskCounts", all(same.values()), f"{same}")
    brows, older, cats = board_rows()
    check(f"{label}: BoardSnapshot rows, older and categories",
          sorted(r["id"] for r in brows) == exp["board_ids"] and older == exp["older"] and cats == exp["categories"],
          f"{len(brows), older, cats} vs {len(exp['board_ids']), exp['older'], exp['categories']}")
    got_history = {k: history.get(k) for k in ("added", "finished", "scope", "done")}
    check(f"{label}: TaskHistory added/finished/scope/done", got_history == exp["history"], f"{got_history} vs {exp['history']}")
    got_counts = {s["id"]: s["task_count"] for s in steps}
    check(f"{label}: GetFlowLine step counts", got_counts == exp["step_counts"] and len(steps) > 0, f"{got_counts} vs {exp['step_counts']}")
    # The titles ride on the flow line so the page's close zoom makes no
    # request: per step, the first two rows the panel would page.
    got_titles = {s["id"]: s.get("task_titles") for s in steps}
    exp_titles = {s["id"]: [t["title"] for t in (report("ListStepTasks", {"step_id": s["id"], "page_size": 2}) or {}).get("rows", [])]
                  for s in steps}
    check(f"{label}: GetFlowLine step titles are the panel's first two", got_titles == exp_titles, f"{got_titles} vs {exp_titles}")
    totals = {sc: report("ListTasks", {"scope": sc, "page_size": 1}) for sc in ("working", "older", "done", "attention", "all")}
    got_totals = {sc: totals[sc].get("total") for sc in totals}
    exp_totals = {sc: exp[sc] for sc in totals}
    check(f"{label}: ListTasks totals per scope", got_totals == exp_totals and totals["working"].get("older") == exp["older"],
          f"{got_totals} older={totals['working'].get('older')} vs {exp_totals} older={exp['older']}")
    # scope_total is the scope's unfiltered count on every page, so a filtered
    # view says "N of M" without a second call: with no filter it equals total,
    # under a project or category filter (pushed into the query) it is still
    # the whole scope.
    plain = {sc: totals[sc].get("scope_total") for sc in totals}
    check(f"{label}: ListTasks scope_total equals total on an unfiltered page", plain == exp_totals, f"{plain} vs {exp_totals}")
    narrowed = {}
    for sc in totals:
        narrowed[sc + "/project"] = report("ListTasks", {"scope": sc, "project_id": project_ids[0], "page_size": 1}).get("scope_total")
        if exp["categories"]:
            narrowed[sc + "/category"] = report("ListTasks", {"scope": sc, "category": exp["categories"][0], "page_size": 1}).get("scope_total")
    want = {k: exp_totals[k.split("/")[0]] for k in narrowed}
    check(f"{label}: ListTasks scope_total under a project or category filter is the whole scope", narrowed == want, f"{narrowed} vs {want}")


def parity_suite(project_id, member_id, tag):
    # Tasks across statuses, projects, members and categories, some created
    # Done and some moved there, then deletes and a re-parent; the counters
    # and the pushed readers must agree with a brute-force pass each time.
    steps = report("ApplyTemplate", {"template_key": "simple"}) or []
    by_kind = {}
    for s in steps:
        by_kind.setdefault(s["kind"], s["id"])
    check("parity: the Simple template is applied", len(steps) == 4, str(steps)[:200])
    p2 = report("SaveProject", {"name": "CI Parity", "description": ""})
    p2_id = str(find_key(p2, "id", "_jac_id") or "")
    m2 = report("SaveMember", {"first_name": "Omar", "last_name": "Diaz"})
    m2_id = str(find_key(m2, "id", "_jac_id") or "")
    check("parity: second project and member", bool(p2_id) and bool(m2_id))
    links = {}
    plan = [
        ("open backlog", "Docs", "Backlog", "", project_id, [member_id], ""),
        ("open doing", "Docs", "In Progress", by_kind.get("active", ""), project_id, [member_id, m2_id], ""),
        ("open review", "Infra", "Review", by_kind.get("handoff", ""), p2_id, [m2_id], ""),
        ("blocked overdue", "Infra", "Blocked", "", p2_id, [member_id], "2020-01-01"),
        ("open overdue", "Ops", "In Progress", "", p2_id, [], "2020-01-01"),
        ("seeded done", "Ops", "Done", "", project_id, [m2_id], ""),
        ("seeded done two", "Docs", "Done", by_kind.get("done", ""), p2_id, [], ""),
        ("to move one", "Infra", "Backlog", by_kind.get("start", ""), project_id, [member_id], ""),
        ("to move two", "Ops", "In Progress", "", p2_id, [m2_id], ""),
        ("to delete open", "Gone", "Backlog", "", project_id, [member_id], ""),
        ("to delete done", "Gone", "Done", "", p2_id, [], ""),
        ("to rehome", "Docs", "Review", "", project_id, [member_id], ""),
    ]
    made = {}
    for title, cat, status, step, pid, who, due in plan:
        t = report("CreateTask", {"title": f"{title} {tag}", "category": cat, "status": status, "step_id": step,
                                  "project_id": pid, "assignee_ids": who, "due_date": due, "priority": "Medium"})
        tid = str(t.get("id") or "")
        made[title] = t
        links[tid] = (pid, who)
    check("parity: every planned task was created", all(t.get("id") for t in made.values()), str(len(made)))
    for title in ("to move one", "to move two"):
        mv = report("MoveTask", {"task_id": made[title]["id"], "status": "Done"})
        check(f"parity: '{title}' moved to Done", mv.get("status") == "Done" and mv.get("done_at") != mv.get("created_at"), str(mv)[:160])
    first_task = report("ListTasks", {"scope": "all", "q": f"CI task {tag}", "page_size": 1}).get("rows", [{}])[0]
    if first_task.get("id"):
        links[first_task["id"]] = (project_id, [])
    assert_parity("parity before", [project_id, p2_id], [member_id, m2_id], links)
    for title in ("to delete open", "to delete done"):
        gone = report("DeleteTask", {"task_id": made[title]["id"]})
        check(f"parity: '{title}' deleted", gone.get("deleted") == made[title]["id"], str(gone))
        links.pop(made[title]["id"], None)
    row = made["to rehome"]
    moved = report("UpdateTask", {"task_id": row["id"], "title": row["title"], "category": "Moved", "tags": [], "estimate": 0,
                                  "priority": row["priority"], "status": row["status"], "step_id": row["step_id"], "due_date": "",
                                  "start_date": "", "iteration_id": "", "notes": "", "issue_link": "", "pr_link": "",
                                  "reviewer_id": "", "review_due": "", "assignee_ids": [m2_id], "project_id": p2_id})
    check("parity: re-parented task reports its new project and assignee",
          moved.get("project_id") == p2_id and moved.get("assignee_ids") == [m2_id], str(moved)[:200])
    links[row["id"]] = (p2_id, [m2_id])
    assert_parity("parity after deletes and a re-parent", [project_id, p2_id], [member_id, m2_id], links)


def log_pages(body):
    # Every page of one ListLogEntries read, in order.
    pages = []
    for page in range(1, 51):
        got = report("ListLogEntries", {**body, "page": page})
        pages.append(got)
        if not got.get("has_more"):
            break
    return pages


def entry_id(row):
    return find_key(row, "id", "_jac_id")


def log_paging_suite(member_id):
    # The log pages in the store: whole days are skipped on their counts and
    # a day answers its slice by a unique key. Pages must partition the range
    # in one order at any page size, and the counts must follow every write.
    span = {"from_date": "2020-01-01", "to_date": "2030-12-31"}
    for date, n in (("2025-06-02", 3), ("2025-06-03", 2), ("2025-06-04", 1)):
        for i in range(n):
            got = report("LogActivity", {"date": date, "member_id": member_id, "activity": f"log gate {date} #{i}"})
            check(f"log: LogActivity writes an entry on {date}", got.get("date") == date, str(got)[:160])
    whole = report("ListLogEntries", {**span, "page_size": 500})
    rows = whole.get("rows", [])
    ids = [entry_id(r) for r in rows]
    total = whole.get("total")
    check("log: one page holds the range and total counts it",
          total == len(ids) and total >= 6 and not whole.get("has_more"), f"{total} {len(ids)}")
    check("log: newest day first, newest stamp first within a day",
          all((a["date"], a.get("at", "")) >= (b["date"], b.get("at", "")) for a, b in zip(rows, rows[1:])),
          str([(r["date"], r.get("at")) for r in rows][:8]))
    for size in (1, 2, 4):
        pages = log_pages({**span, "page_size": size})
        paged = [entry_id(r) for p in pages for r in p.get("rows", [])]
        check(f"log: pages of {size} partition the range in the one-page order", paged == ids,
              f"{len(paged)} rows vs {len(ids)}")
        check(f"log: pages of {size} all report the same total", all(p.get("total") == total for p in pages),
              str([p.get("total") for p in pages]))
    past = report("ListLogEntries", {**span, "page": 999, "page_size": 2})
    check("log: a page past the end is empty", past.get("rows") == [] and not past.get("has_more")
          and past.get("total") == total, str(past)[:160])
    clamp = report("ListLogEntries", {**span, "page_size": 100000})
    check("log: page_size clamps to 500", clamp.get("page_size") == 500, str(clamp.get("page_size")))
    gone = report("DeleteLogEntries", {"entry_ids": [ids[1]]})
    check("log: DeleteLogEntries removes the entry", gone.get("deleted") == [ids[1]], str(gone))
    left = [i for i in ids if i != ids[1]]
    after = log_pages({**span, "page_size": 2})
    check("log: the day count follows a delete", [entry_id(r) for p in after for r in p.get("rows", [])] == left
          and all(p.get("total") == total - 1 for p in after), f"{[p.get('total') for p in after]}")
    moved = Counter(r.get("task_id") for r in rows if r.get("task_id") and entry_id(r) != ids[1])
    task_id = moved.most_common(1)[0][0] if moved else ""
    mine = [entry_id(r) for r in rows if r.get("task_id") == task_id and entry_id(r) != ids[1]]
    only = report("ListLogEntries", {**span, "task_id": task_id, "page_size": 500})
    check("log: task_id keeps that task's rows, in the range's order",
          bool(task_id) and [entry_id(r) for r in only.get("rows", [])] == mine and only.get("total") == len(mine),
          f"{task_id} {len(mine)}")


def log_counts_suite(member_id, project_id, tag):
    # The log's counts come from the days' tallies, kept on write. They must
    # equal a count of the entries themselves, before and after a delete, and
    # the Overview's blocked reason comes from the task's own Blocked line.
    today = date.fromisoformat(time.strftime("%Y-%m-%d", time.gmtime()))
    monday = today - timedelta(days=today.weekday())
    starts = [(monday - timedelta(days=7 * (3 - i))).isoformat() for i in range(4)]
    days = [(monday + timedelta(days=i)).isoformat() for i in range(7)]

    def parity(label):
        rows = [r for p in log_pages({"from_date": starts[0], "to_date": days[6], "page_size": 500}) for r in p.get("rows", [])]
        by_week = [sum(1 for r in rows if starts[i] <= r["date"] < (starts[i + 1] if i < 3 else days[6] + "~")) for i in range(4)]
        by_day = [sum(1 for r in rows if r["date"] == d) for d in days]
        people = {}
        for r in rows:
            if r["date"] in days:
                for name in [n.strip() for n in r.get("member_name", "").split(",") if n.strip()]:
                    people.setdefault(name, [0] * 7)[days.index(r["date"])] += 1
        got = report("LogCounts", {"monday": monday.isoformat()})
        got_people = {m["name"]: m["by_day"] for m in got.get("members", [])}
        check(f"log counts: {label} equal a count of the entries",
              got.get("by_week") == by_week and got.get("by_day") == by_day and got_people == people,
              f"{got.get('by_week')} vs {by_week}; {got.get('by_day')} vs {by_day}; {got_people} vs {people}")

    made = [entry_id(report("LogActivity", {"date": today.isoformat(), "member_id": member_id, "activity": f"counts {tag} #{i}"}))
            for i in range(2)]
    parity("after two notes today")
    report("DeleteLogEntries", {"entry_ids": made[:1]})
    parity("after a delete")
    task = report("CreateTask", {"title": f"Blocked probe {tag}", "priority": "High", "project_id": project_id})
    report("MoveTask", {"task_id": task.get("id", ""), "status": "Blocked"})
    report("SetMoveInfo", {"task_id": task.get("id", ""), "note": f"waiting on keys {tag}"})
    parity("after a move and its note")
    # The assistant's snapshot counts the period from the days' tallies and
    # carries its newest lines, oldest first.
    rows = [r for p in log_pages({"from_date": starts[0], "to_date": days[6], "page_size": 500}) for r in p.get("rows", [])]
    digest = report("Digest", {"from_date": starts[0], "to_date": days[6]})
    counted = {}
    for r in rows:
        for name in [n.strip() for n in r.get("member_name", "").split(",") if n.strip()]:
            counted[name] = counted.get(name, 0) + 1
    got_people = {p["name"]: p["log_entries"] for p in digest.get("people", [])}
    check("digest: the period's log counts equal a count of the entries",
          digest.get("log_entries_in_period") == len(rows) and all(counted.get(n, 0) == c for n, c in got_people.items()),
          f"{digest.get('log_entries_in_period')} vs {len(rows)}; {got_people} vs {counted}")
    check("digest: activity is the newest lines, oldest first",
          [a["what"] for a in digest.get("activity", [])] == [r["activity"] for r in rows[:200]][::-1],
          f"{len(digest.get('activity', []))} lines")
    snap = report("OverviewSnapshot", {"monday": monday.isoformat(), "from_date": (today - timedelta(days=14)).isoformat(),
                                       "attention_size": 50})
    item = next((b for b in snap.get("blocked", []) if b.get("task_id") == task.get("id")), {})
    check("overview: a blocked task's reason is the note on its Blocked line",
          item.get("reason") == f"waiting on keys {tag}" and item.get("since") == today.isoformat(), str(item)[:200])


def history_pages_suite(project_id):
    # An unfiltered history page in updated order is cut in the store. At any
    # page size its pages must be the full history in (updated desc, id asc)
    # order, whole workspace or under a project, with totals from the tallies.
    rows = all_rows()

    def expected(keep):
        picked = sorted((r for r in rows if keep(r)), key=lambda r: r["id"])
        return [r["id"] for r in sorted(picked, key=lambda r: r["updated_at"], reverse=True)]

    def paged(body):
        pages, page = [], 1
        while page <= 200:
            got = report("ListTasks", {**body, "page": page})
            pages.append(got)
            if not got.get("has_more"):
                break
            page += 1
        return [r["id"] for p in pages for r in p.get("rows", [])], pages

    newest = {"sort": "updated", "sort_dir": "desc"}
    cases = [
        ("all", {"scope": "all", **newest}, lambda r: True, len(rows)),
        ("done", {"scope": "done"}, lambda r: r["status"] == "Done", sum(1 for r in rows if r["status"] == "Done")),
        ("all under a project", {"scope": "all", "project_id": project_id, **newest},
         lambda r: r["project_id"] == project_id, len(rows)),
    ]
    for label, body, keep, scope_total in cases:
        want = expected(keep)
        for size in (1, 3):
            ids, pages = paged({**body, "page_size": size})
            check(f"history: '{label}' pages of {size} are the history in updated order", ids == want,
                  f"{len(ids)} rows vs {len(want)}")
            check(f"history: '{label}' pages of {size} say total {len(want)} of {scope_total}",
                  all(p.get("total") == len(want) and p.get("scope_total") == scope_total for p in pages),
                  str([(p.get("total"), p.get("scope_total")) for p in pages][:4]))


def history_store_suite(project_id, member_id):
    # The history scopes page in the store for every sort and filter but a
    # search or a tag. Each page run must equal a Python sort of the whole
    # history (ties by id), with totals, across titles that differ only in
    # case, accents and punctuation; a search takes the loaded path.
    far, rank = "9999-12-31", {"High": 0, "Medium": 1, "Low": 2}
    it = report("SaveIteration", {"name": "Store sprint", "start_date": "2026-09-01",
                                  "end_date": "2026-09-30"}).get("id", "")
    titles = ["alpha", "Alpha-2", "ábaco", "Zeta", "zeta!", "émile", "Émile", "beta", "Beta",
              "_under", "123 go", "ümlaut", "alpha"]
    cats = ["bug", "Bug", "Feature", "", "feature"]
    for i, title in enumerate(titles):
        t = report("CreateTask", {
            "title": title, "category": cats[i % 5], "priority": ["High", "Medium", "Low"][i % 3],
            "due_date": "" if i % 3 == 0 else f"2026-10-{10 + i:02d}", "estimate": [0.0, 1.5, 3.0][i % 3],
            "assignee_ids": [member_id] if i % 2 else [], "project_id": project_id,
            "iteration_id": it if i % 4 == 0 else ""})
        if i % 3 == 1:
            report("MoveTask", {"task_id": t.get("id", ""), "status": "Done"})
        elif i % 5 == 2:
            report("MoveTask", {"task_id": t.get("id", ""), "status": "Blocked"})
    rows = all_rows()
    tallied = sum(p["total"] for p in report("TaskCounts").get("projects", []))
    check("store history: the paged history holds every task once",
          len(rows) == tallied == len({r["id"] for r in rows}), f"{len(rows)} rows, {tallied} tallied")
    steps = report("GetFlowLine", {"with_counts": False}) or []
    order = sorted(sorted(steps, key=lambda s: s["sort_order"]), key=lambda s: s["x"])
    keys = [s["id"] for s in order]
    first_kind = {}
    for i, s in enumerate(order):
        first_kind.setdefault(s["kind"], i)

    def column(r):
        if r["step_id"] in keys:
            return keys.index(r["step_id"])
        return first_kind.get(STATUS_KIND.get(r["status"], "active"), 0)
    key_of = {
        "title": lambda r: r["title"].lower(), "category": lambda r: r["category"].lower(),
        "priority": lambda r: rank.get(r["priority"], 1), "estimate": lambda r: r["estimate"],
        "due": lambda r: r["due_date"] or far, "created": lambda r: r["created_at"],
        "updated": lambda r: r["updated_at"],
    }

    def expected(keep, sort, desc, scope):
        out = sorted((r for r in rows if keep(r)), key=lambda r: r["id"])
        if sort == "step":
            out.sort(key=lambda r: r["sort_order"])
            out.sort(key=column, reverse=desc)
        elif sort:
            out.sort(key=key_of[sort], reverse=desc)
        elif scope == "done":
            out.sort(key=lambda r: r["updated_at"], reverse=True)
        else:
            out.sort(key=lambda r: r["sort_order"])
        return [r["id"] for r in out]

    def paged(body):
        ids, pages, page = [], [], 1
        while page <= 100:
            got = report("ListTasks", {**body, "page": page, "page_size": 4})
            pages.append(got)
            ids.extend(r["id"] for r in got.get("rows", []))
            if not got.get("has_more"):
                break
            page += 1
        return ids, pages
    done = lambda r: r["status"] == "Done"
    blocked_col = keys[column(next(r for r in rows if r["status"] == "Blocked"))]
    filters = [
        ("no filter", {}, lambda r: True),
        ("category", {"category": "bug"}, lambda r: r["category"] == "bug"),
        ("priority", {"priority": "High"}, lambda r: r["priority"] == "High"),
        ("estimated", {"estimated": "yes"}, lambda r: r["estimate"] > 0),
        ("unestimated", {"estimated": "no"}, lambda r: r["estimate"] <= 0),
        ("no iteration", {"iteration_id": "none"}, lambda r: not r["iteration_id"]),
        ("iteration", {"iteration_id": it}, lambda r: r["iteration_id"] == it),
        ("assignee", {"assignee_id": member_id}, lambda r: member_id in r["assignee_ids"]),
        ("column", {"column": blocked_col}, lambda r: keys[column(r)] == blocked_col),
        ("project and assignee", {"project_id": project_id, "assignee_id": member_id},
         lambda r: r["project_id"] == project_id and member_id in r["assignee_ids"]),
        ("priority and column", {"priority": "Low", "column": blocked_col},
         lambda r: r["priority"] == "Low" and keys[column(r)] == blocked_col),
    ]
    cases = [("all", "", sort, desc, {}, lambda r: True) for sort in [""] + list(key_of) + ["step"]
             for desc in (False, True)]
    cases += [("all", name, sort, desc, body, keep) for name, body, keep in filters[1:]
              for sort, desc in (("title", False), ("step", True), ("due", True))]
    cases += [("done", name, sort, False, body, keep) for name, body, keep in filters[:3]
              for sort in ("", "priority", "step")]
    bad = []
    for scope, name, sort, desc, body, keep in cases:
        want = expected(lambda r: (scope == "all" or done(r)) and keep(r), sort, desc, scope)
        ids, pages = paged({"scope": scope, "sort": sort, "sort_dir": "desc" if desc else "asc", **body})
        whole = len(rows) if scope == "all" else sum(1 for r in rows if done(r))
        if ids != want or any(p.get("total") != len(want) or p.get("scope_total") != whole for p in pages):
            bad.append(f"{scope}/{name}/{sort or 'default'}/{'desc' if desc else 'asc'}: "
                       f"{len(ids)} vs {len(want)}, totals {[p.get('total') for p in pages][:2]}")
    check(f"store history: {len(cases)} sort and filter runs page exactly as a full sort", not bad, bad[:4])
    ids, pages = paged({"scope": "all", "q": "a", "priority": "High", "column": blocked_col, "sort": "title"})
    want = expected(lambda r: "a" in r["title"].lower() and r["priority"] == "High"
                    and keys[column(r)] == blocked_col, "title", False, "all")
    check("store history: a search with priority and column filters (loaded path) agrees", ids == want,
          f"{ids} vs {want}")
    empty = report("ListTasks", {"scope": "all", "column": "no-such-column", "page_size": 5})
    check("store history: an unknown column matches nothing", empty.get("total") == 0 and not empty.get("rows"),
          str(empty)[:200])


def sign_up(tag):
    # A second account for the tenant checks: its token, or "" on failure.
    email, password = f"ci-{tag}@flowline-ci.invalid", f"Ci-{tag}-Xy7!"
    req("POST", "/user/register", {"identities": [{"type": "email", "value": email}],
                                   "credential": {"type": "password", "password": password},
                                   "profile": {"org_name": "CI Other"}})
    _, _, raw = req("POST", "/user/login", {"identity": {"type": "email", "value": email},
                                           "credential": {"type": "password", "password": password}})
    return str(find_key(json.loads(raw) if raw else {}, "token", "access_token") or "")


def filter_sets_suite(project_id, member_id, tag):
    # Saved filters: sets validate and keep only the board's keys, the board's
    # own filters round-trip through BoardSnapshot, a delete forgets the set
    # as the board's, and another account can reach none of it.
    global TOKEN

    def sets():
        return report("GetWorkspace").get("filter_sets", [])

    def board():
        b = report("BoardSnapshot", {"page_size": 1, "with_workspace": True})
        return b.get("board_filters"), b.get("board_set"), b.get("board_saved")

    check("filters: a fresh account has no sets and no board filters",
          sets() == [] and board() == ({}, "", False), f"{sets()} {board()}")
    for body, error in (({"name": "  ", "filters": {"priority": "High"}}, "invalid"),
                        ({"name": "Nothing", "filters": {"project": "all", "bogus": "x"}}, "empty"),
                        ({"name": "Elsewhere", "page": "log", "filters": {"priority": "High"}}, "invalid")):
        got = report("SaveFilterSet", body)
        check(f"filters: SaveFilterSet refuses {body['name']!r} as {error}",
              got.get("ok") is False and got.get("error") == error, str(got))
    mine = report("SaveFilterSet", {"name": "  Mine  ", "filters": {
        "project": project_id, "priority": "High", "done": "hide", "tag": "All", "estimate": "maybe", "bogus": "x"}})
    mine_id = (mine.get("set") or {}).get("id", "")
    check("filters: a set keeps the board's keys set away from their default, trimmed name",
          mine.get("ok") and mine["set"].get("name") == "Mine" and mine["set"].get("page") == "board"
          and mine["set"].get("filters") == {"project": project_id, "priority": "High", "done": "hide"}, str(mine))
    dup = report("SaveFilterSet", {"name": "MINE", "filters": {"priority": "Low"}})
    check("filters: a name is unique on its page ignoring case", dup.get("error") == "duplicate", str(dup))
    other = report("SaveFilterSet", {"name": "Z" * 80, "filters": {"assignee": member_id}})
    other_id = (other.get("set") or {}).get("id", "")
    check("filters: a long name is cut to 60 characters", other.get("ok") and len(other["set"]["name"]) == 60, str(other))
    clash = report("SaveFilterSet", {"set_id": other_id, "name": "mine", "filters": {"assignee": member_id}})
    check("filters: a rename cannot take another set's name", clash.get("error") == "duplicate", str(clash))
    renamed = report("SaveFilterSet", {"set_id": other_id, "name": "Priya's work", "filters": {"assignee": member_id}})
    check("filters: a set renames in place", renamed.get("ok") and renamed["set"].get("id") == other_id
          and renamed["set"].get("name") == "Priya's work", str(renamed))
    check("filters: GetWorkspace lists the sets by name",
          [(s.get("name"), s.get("id")) for s in sets()] == [("Mine", mine_id), ("Priya's work", other_id)], str(sets()))
    kept = report("SetBoardFilters", {"filters": {"project": project_id, "priority": "Low", "junk": "1"}, "set_id": mine_id})
    check("filters: SetBoardFilters keeps the board's keys and a set of this account",
          kept.get("filters") == {"project": project_id, "priority": "Low"} and kept.get("set_id") == mine_id, str(kept))
    check("filters: BoardSnapshot carries the board's filters with the workspace",
          board() == ({"project": project_id, "priority": "Low"}, mine_id, True), str(board()))
    poll = report("BoardSnapshot", {"page_size": 1})
    check("filters: the poll carries no filters", poll.get("board_saved") is False and poll.get("filter_sets") == [],
          str({k: poll.get(k) for k in ("board_saved", "filter_sets")}))
    gone = report("DeleteFilterSet", {"set_id": mine_id})
    check("filters: DeleteFilterSet deletes the set", gone.get("deleted") == mine_id, str(gone))
    check("filters: deleting the board's set forgets it and keeps the filters",
          board() == ({"project": project_id, "priority": "Low"}, "", True)
          and [s.get("id") for s in sets()] == [other_id], f"{board()} {sets()}")
    again = report("DeleteFilterSet", {"set_id": mine_id})
    check("filters: a deleted set is not found", again.get("error") == "not_found", str(again))
    made = [report("SaveFilterSet", {"name": f"Set {i:02d}", "filters": {"priority": "High"}}) for i in range(49)]
    full = report("SaveFilterSet", {"name": "One too many", "filters": {"priority": "High"}})
    check("filters: a page holds 50 sets", all(m.get("ok") for m in made) and full.get("error") == "full",
          f"{sum(1 for m in made if m.get('ok'))} {full}")
    for m in made:
        report("DeleteFilterSet", {"set_id": (m.get("set") or {}).get("id", "")})

    home = TOKEN
    TOKEN = sign_up(f"{tag}b")
    if check("filters: a second account signs in", bool(TOKEN)):
        check("filters: another account sees none of the sets", sets() == [], str(sets()))
        for name, body in (("rename", {"set_id": other_id, "name": "Taken", "filters": {"priority": "High"}}),
                           ("delete", {"set_id": other_id})):
            got = report("SaveFilterSet" if name == "rename" else "DeleteFilterSet", body)
            check(f"filters: another account cannot {name} a set", got.get("error") == "not_found", str(got))
        took = report("SetBoardFilters", {"filters": {"priority": "High"}, "set_id": other_id})
        check("filters: another account cannot point its board at a set", took.get("set_id") == "", str(took))
    TOKEN = home
    check("filters: the set is untouched", [(s.get("id"), s.get("name")) for s in sets()] == [(other_id, "Priya's work")],
          str(sets()))


def effects_table(html: str) -> dict:
    # The shell carries the compiler's endpoint effects in its __jac_init__
    # JSON; the client runtime reads its cache verdicts from this table.
    m = re.search(r'<script[^>]*id="__jac_init__"[^>]*>(.*?)</script>', html, re.S)
    if not m:
        return {}
    try:
        table = json.loads(m.group(1)).get("endpointEffects") or {}
    except ValueError:
        return {}
    return {v.get("name"): v for v in table.values()
            if isinstance(v, dict) and v.get("kind") == "walker"}


def check_effects(html: str) -> None:
    table = effects_table(html)
    check("shell carries the endpoint effects table", len(table) > 20, str(len(table)))
    for name in CACHED_READERS:
        row = table.get(name) or {}
        check(f"{name} is a cacheable reader",
              row.get("unknown") is False and row.get("writes") == [],
              f"unknown={row.get('unknown')} writes={row.get('writes')} assumptions={row.get('assumptions')}")
    for name in LIVE_READERS:
        row = table.get(name) or {}
        check(f"{name} is never served from the cache",
              bool(row) and (row.get("unknown") or bool(row.get("writes"))),
              f"unknown={row.get('unknown')} writes={row.get('writes')}")
    for name in MUTATORS:
        row = table.get(name) or {}
        check(f"{name} is a writer", bool(row.get("writes")),
              f"unknown={row.get('unknown')} writes={row.get('writes')}")


def wait_ready():
    deadline = time.time() + READY_TIMEOUT
    while time.time() < deadline:
        try:
            status, _, _ = req("GET", "/healthz/ready")
            if status == 200:
                return True
        except (urllib.error.URLError, OSError):
            pass
        time.sleep(3)
    return False


def main() -> int:
    global TOKEN
    if not check("server ready within timeout", wait_ready()):
        return 2

    status, ctype, raw = req("GET", "/", accept="text/html")
    html = raw.decode(errors="replace")
    check("GET / is the app shell", status == 200 and "text/html" in ctype
          and "<title>Flowline</title>" in html, f"{status} {ctype}")
    script = re.search(r'src="(/static/client\.js[^"]*)"', html)
    if check("shell references the client bundle", script is not None):
        status, ctype, js = req("GET", script.group(1))
        check("client bundle is served", status == 200 and "javascript" in ctype
              and len(js) > 100_000, f"{status} {ctype} {len(js)} bytes")
    status, _, raw = req("GET", "/board", accept="text/html")
    check("GET /board serves the shell (SPA fallback)",
          status == 200 and "<title>Flowline</title>" in raw.decode(errors="replace"), str(status))
    check_effects(html)

    status, _, _ = req("POST", "/walker/ListProjects", {})
    check("anonymous walker call is 401", status == 401, str(status))
    status, _, _ = req("GET", "/user/me")
    check("anonymous /user/me is 401", status == 401, str(status))

    tag = uuid.uuid4().hex[:10]
    email = f"ci-{tag}@flowline-ci.invalid"
    password = f"Ci-{tag}-Xy7!"
    status, _, raw = req("POST", "/user/register", {
        "identities": [{"type": "email", "value": email}],
        "credential": {"type": "password", "password": password},
        "profile": {"org_name": "CI Org"},
    })
    check("register", status in (200, 201), f"{status} {raw[:200]!r}")
    status, _, raw = req("POST", "/user/login", {
        "identity": {"type": "email", "value": email},
        "credential": {"type": "password", "password": password},
    })
    payload = json.loads(raw) if raw else {}
    TOKEN = str(find_key(payload, "token", "access_token") or "")
    if not check("login returns a token", status == 200 and bool(TOKEN), f"{status} {raw[:200]!r}"):
        return 1
    status, _, raw = req("GET", "/user/me")
    check("/user/me carries the org profile", status == 200 and b"CI Org" in raw, f"{status} {raw[:200]!r}")

    status, payload, reports = walker("ListProjects")
    rows = reports[0] if reports and isinstance(reports[0], list) else reports
    check("ListProjects on a fresh account is empty", status == 200 and rows == [], f"{status} {payload}")

    status, payload, reports = walker("SaveProject", {"name": "CI Project", "description": "smoke"})
    project = reports[0] if reports else {}
    project_id = str(find_key(project, "id", "_jac_id") or "")
    check("SaveProject reports the project", status == 200 and bool(project_id), f"{status} {payload}")

    status, payload, reports = walker("ListProjects")
    rows = reports[0] if reports and isinstance(reports[0], list) else reports
    check("ListProjects now lists it", status == 200 and len(rows) == 1
          and rows[0].get("name") == "CI Project", f"{status} {payload}")

    status, payload, reports = walker("CreateTask", {
        "title": f"CI task {tag}", "priority": "High", "project_id": project_id,
    })
    task = reports[0] if reports else {}
    task_id = str(find_key(task, "id", "_jac_id") or "")
    check("CreateTask reports the task", status == 200 and bool(task_id)
          and task.get("title") == f"CI task {tag}", f"{status} {payload}")

    status, payload, reports = walker("CreateTask", {"title": "no project", "priority": "High"})
    check("CreateTask without a project creates nothing", status == 200 and not reports, f"{status} {payload}")

    status, payload, reports = walker("ListTasks", {"scope": "working"})
    page = reports[0] if reports else {}
    titles = [r.get("title") for r in page.get("rows", [])]
    check("ListTasks pages the new task", status == 200 and page.get("total") == 1
          and titles == [f"CI task {tag}"], f"{status} {payload}")

    # #227: a list row is slim. The note's first line and the checklist counts
    # ride instead of the notes and the items, which GetTask carries.
    status, payload, reports = walker("UpdateTask", {
        "task_id": task_id, "title": f"CI task {tag}", "category": "", "tags": [], "estimate": 0, "priority": "High",
        "status": "Backlog", "step_id": "", "due_date": "", "start_date": "", "iteration_id": "",
        "notes": "First line of the notes.\nSecond line.", "issue_link": "", "pr_link": "", "reviewer_id": "",
        "review_due": "", "assignee_ids": [], "project_id": project_id})
    check("UpdateTask reports the notes", status == 200 and bool(reports)
          and str(reports[0].get("notes", "")).startswith("First line"), f"{status} {payload}")
    status, payload, reports = walker("AddChecklistItem", {"task_id": task_id, "text": "one step"})
    check("AddChecklistItem reports the checklist", status == 200 and bool(reports)
          and len(reports[0].get("checklist", [])) == 1, f"{status} {payload}")
    row = report("ListTasks", {"scope": "working"}).get("rows", [{}])[0]
    check("ListTasks rows carry note_lead and the checklist counts, no notes or items",
          "notes" not in row and "checklist" not in row and "gh_assignees" not in row
          and row.get("note_lead") == "First line of the notes." and row.get("checklist_total") == 1
          and row.get("checklist_done") == 0, str(row)[:300])
    full = report("GetTask", {"task_id": task_id})
    check("GetTask carries the notes and the checklist for the task sheet",
          str(full.get("notes", "")).startswith("First line") and len(full.get("checklist", [])) == 1
          and full.get("note_lead") == "First line of the notes." and full.get("checklist_total") == 1
          and full.get("gh_assignees") == [], str(full)[:300])
    status, payload, reports = walker("ListTaskTitles")
    titles_page = reports[0] if reports and isinstance(reports[0], list) else []
    check("ListTaskTitles reports id and title alone, in the working page's order",
          status == 200 and [t.get("id") for t in titles_page] == [row.get("id")]
          and all(set(k for k in t if not k.startswith("_jac")) == {"id", "title"} for t in titles_page),
          f"{status} {payload}")

    status, payload, reports = walker("SaveMember", {"first_name": "Priya", "last_name": "Raman"})
    member = reports[0] if reports else {}
    member_id = str(find_key(member, "id", "_jac_id") or "")
    check("SaveMember stores first and last name", status == 200 and member.get("first_name") == "Priya"
          and member.get("last_name") == "Raman" and member.get("name") == "Priya Raman", f"{status} {payload}")

    status, payload, reports = walker("ListTasks", {"scope": "working", "project_id": project_id})
    page = reports[0] if reports else {}
    check("ListTasks project filter keeps it", status == 200 and page.get("total") == 1, f"{status} {payload}")

    status, payload, reports = walker("TaskCounts")
    check("TaskCounts answers", status == 200 and bool(reports), f"{status} {payload}")
    status, payload, reports = walker("GetFlowLineMeta")
    check("GetFlowLineMeta answers", status == 200 and bool(reports), f"{status} {payload}")
    status, payload, reports = walker("ListMembers")
    check("ListMembers answers", status == 200, f"{status} {payload}")

    # The one read the pages open with: the lists BoardSnapshot carries, the
    # flow line's record and the GitHub connection view, in one call.
    status, payload, reports = walker("GetWorkspace")
    ws = reports[0] if reports and isinstance(reports[0], dict) else {}
    lists = ("members", "projects", "steps", "repos", "roles", "iterations", "filter_sets")
    check("GetWorkspace reports the workspace lists",
          status == 200 and all(isinstance(ws.get(k), list) for k in lists)
          and isinstance(ws.get("github"), dict) and "flow_name" in ws, f"{status} {payload}")
    counts = {}
    for name in ("ListMembers", "ListProjects", "ListRoles"):
        _, _, rows = walker(name)
        counts[name] = len(rows[0]) if rows and isinstance(rows[0], list) else -1
    check("GetWorkspace counts match the list walkers",
          len(ws.get("members", [])) == counts["ListMembers"] == 1
          and len(ws.get("projects", [])) == counts["ListProjects"] == 1
          and len(ws.get("roles", [])) == counts["ListRoles"],
          f"{ {k: len(ws.get(k, [])) for k in lists} } vs {counts}")

    parity_suite(project_id, member_id, tag)
    log_paging_suite(member_id)
    log_counts_suite(member_id, project_id, tag)
    history_pages_suite(project_id)
    history_store_suite(project_id, member_id)
    filter_sets_suite(project_id, member_id, tag)

    with ThreadPoolExecutor(max_workers=8) as pool:
        codes = list(pool.map(lambda _: walker("ListTasks", {"scope": "working"})[0], range(16)))
    check("16 concurrent ListTasks all succeed", all(c == 200 for c in codes), str(codes))

    print("api gate: " + ("PASS" if not FAILS else f"FAIL ({len(FAILS)})"))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
