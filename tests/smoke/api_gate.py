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
from concurrent.futures import ThreadPoolExecutor

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000").rstrip("/")
READY_TIMEOUT = 420
TOKEN = ""
FAILS: list[str] = []


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
          and "<title>flowline</title>" in html, f"{status} {ctype}")
    script = re.search(r'src="(/static/client\.js[^"]*)"', html)
    if check("shell references the client bundle", script is not None):
        status, ctype, js = req("GET", script.group(1))
        check("client bundle is served", status == 200 and "javascript" in ctype
              and len(js) > 100_000, f"{status} {ctype} {len(js)} bytes")
    status, _, raw = req("GET", "/board", accept="text/html")
    check("GET /board serves the shell (SPA fallback)",
          status == 200 and "<title>flowline</title>" in raw.decode(errors="replace"), str(status))

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
        "profile": {"org_name": "CI Org", "full_name": "CI Runner"},
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

    status, payload, reports = walker("ListTasks", {"scope": "working"})
    page = reports[0] if reports else {}
    titles = [r.get("title") for r in page.get("rows", [])]
    check("ListTasks pages the new task", status == 200 and page.get("total") == 1
          and titles == [f"CI task {tag}"], f"{status} {payload}")

    status, payload, reports = walker("ListTasks", {"scope": "working", "project_id": project_id})
    page = reports[0] if reports else {}
    check("ListTasks project filter keeps it", status == 200 and page.get("total") == 1, f"{status} {payload}")

    status, payload, reports = walker("TaskCounts")
    check("TaskCounts answers", status == 200 and bool(reports), f"{status} {payload}")
    status, payload, reports = walker("GetFlowLineMeta")
    check("GetFlowLineMeta answers", status == 200 and bool(reports), f"{status} {payload}")
    status, payload, reports = walker("ListMembers")
    check("ListMembers answers", status == 200, f"{status} {payload}")

    with ThreadPoolExecutor(max_workers=8) as pool:
        codes = list(pool.map(lambda _: walker("ListTasks", {"scope": "working"})[0], range(16)))
    check("16 concurrent ListTasks all succeed", all(c == 200 for c in codes), str(codes))

    print("api gate: " + ("PASS" if not FAILS else f"FAIL ({len(FAILS)})"))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
