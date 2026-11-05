"""Probe a deployed Flowline after a rollout.

Logs in, then reports what a deploy can silently lose: the served bundle,
the review service bridge (CheckReviewService) and the GitHub connection.
Usage: FLOWLINE_EMAIL=... FLOWLINE_PASSWORD=... deploy_probe.py https://host
"""

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

PROBES = ["CheckReviewService", "GithubStatus", "ListResponsibilities"]


def post(base, path, body, token=""):
    headers = {"content-type": "application/json"}
    if token:
        headers["authorization"] = "Bearer " + token
    req = urllib.request.Request(
        base + path, data=json.dumps(body).encode(), headers=headers, method="POST"
    )
    started = time.time()
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status, json.loads(resp.read().decode()), time.time() - started
    except urllib.error.HTTPError as err:
        return err.code, err.read().decode()[:300], time.time() - started


def bundle_hash(base):
    with urllib.request.urlopen(base + "/", timeout=30) as resp:
        found = re.search(r"client\.[\w-]+\.js", resp.read().decode())
    return found.group(0) if found else "(no bundle)"


def main():
    if len(sys.argv) != 2:
        print(__doc__.strip())
        return 2
    base = sys.argv[1].rstrip("/")
    email = os.environ.get("FLOWLINE_EMAIL", "")
    password = os.environ.get("FLOWLINE_PASSWORD", "")
    if not email or not password:
        print("set FLOWLINE_EMAIL and FLOWLINE_PASSWORD")
        return 2
    print("bundle", bundle_hash(base))
    status, body, _ = post(
        base,
        "/user/login",
        {
            "identity": {"type": "email", "value": email},
            "credential": {"type": "password", "password": password},
        },
    )
    if status != 200:
        print("login failed", status, body)
        return 1
    token = body.get("data", {}).get("token", "")
    failed = False
    for name in PROBES:
        status, body, took = post(base, "/walker/" + name, {}, token)
        reports = body.get("reports", []) if isinstance(body, dict) else []
        if not reports and isinstance(body, dict):
            reports = body.get("data", {}).get("reports", []) or []
        first = reports[0] if reports else body
        ok = status == 200 and (not isinstance(first, dict) or first.get("ok", True))
        failed = failed or not ok
        print(f"{name} {status} {took * 1000:.0f} ms {json.dumps(first)[:160]}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
