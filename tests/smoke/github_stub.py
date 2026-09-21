#!/usr/bin/env python3
"""A local stand-in for the handful of GitHub endpoints the app calls, so the
smoke suite can connect an installation, back-fill a repo and receive
webhooks with no credentials. Point the app at it with GITHUB_API_BASE and
GITHUB_WEB_BASE; the gate sets its state through POST /_stub/reset.
Usage: github_stub.py [port]"""
import json
import re
import sys
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

STATE = {"installations": [], "repos": {}, "next_number": 1000, "calls": []}
LOCK = threading.Lock()


def issue_item(repo, number, title, state, updated, closed=None, pull=None):
    item = {
        "number": number, "title": title, "state": state, "body": "", "labels": [],
        "assignees": [], "user": {"login": "stub-user"},
        "html_url": f"https://github.com/{repo}/{'pull' if pull else 'issues'}/{number}",
        "repository_url": f"https://api.github.com/repos/{repo}",
        "created_at": "2026-09-01T00:00:00Z", "updated_at": updated, "closed_at": closed,
        "sub_issues_summary": {"total": 0, "completed": 0},
    }
    if pull is not None:
        item["pull_request"] = {"merged_at": pull.get("merged_at")}
        item["draft"] = bool(pull.get("draft"))
    return item


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):  # quiet
        pass

    def _send(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _token(self):
        # The bearer the app sent, so a gate can tell one installation's
        # calls from another's (install tokens are stub-install-token-<id>).
        auth = self.headers.get("Authorization") or ""
        return auth[7:] if auth.startswith("Bearer ") else ""

    def _body(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        ctype = self.headers.get("Content-Type") or ""
        if "json" in ctype:
            try:
                return json.loads(raw or b"{}")
            except ValueError:
                return {}
        return {k: v[0] for k, v in parse_qs(raw.decode(errors="replace")).items()}

    def do_GET(self):
        url = urlparse(self.path)
        q = {k: v[0] for k, v in parse_qs(url.query).items()}
        with LOCK:
            STATE["calls"].append(("GET", url.path, self._token()))
            if url.path == "/_stub/state":
                return self._send(200, STATE)
            if url.path == "/user/installations":
                rows = [{"id": i, "account": {"login": "stub-org", "avatar_url": ""}}
                        for i in STATE["installations"]]
                return self._send(200, {"installations": rows})
            if url.path == "/installation/repositories":
                rows = [{"full_name": r, "private": False, "description": "stub"}
                        for r in sorted(STATE["repos"])]
                return self._send(200, {"repositories": rows if q.get("page", "1") == "1" else []})
            m = re.fullmatch(r"/repos/([^/]+/[^/]+)/issues", url.path)
            if m:
                items = STATE["repos"].get(m.group(1))
                if items is None:
                    return self._send(404, {"message": "Not Found"})
                since = q.get("since", "")
                rows = sorted((i for i in items.values() if i["updated_at"] >= since),
                              key=lambda i: (i["updated_at"], i["number"]))
                return self._send(200, rows if q.get("page", "1") == "1" else [])
            m = re.fullmatch(r"/repos/([^/]+/[^/]+)/pulls", url.path)
            if m:
                if m.group(1) not in STATE["repos"]:
                    return self._send(404, {"message": "Not Found"})
                return self._send(200, [])
            if url.path == "/search/issues":
                # Title search over the stub's issues, enough for the GitHub page's search box.
                words = [w for w in q.get("q", "").split() if ":" not in w]
                repos = [w[5:] for w in q.get("q", "").split() if w.startswith("repo:")]
                rows = [i for r, items in STATE["repos"].items() if not repos or r in repos
                        for i in items.values()
                        if all(w.lower() in i["title"].lower() for w in words)]
                return self._send(200, {"total_count": len(rows), "incomplete_results": False, "items": rows})
            m = re.fullmatch(r"/repos/([^/]+/[^/]+)/issues/(\d+)/sub_issues", url.path)
            if m:
                return self._send(200, [])
            m = re.fullmatch(r"/repos/([^/]+/[^/]+)/issues/(\d+)", url.path)
            if m:
                item = STATE["repos"].get(m.group(1), {}).get(int(m.group(2)))
                return self._send(200, item) if item else self._send(404, {"message": "Not Found"})
        return self._send(404, {"message": f"stub: no route for GET {url.path}"})

    def do_POST(self):
        url = urlparse(self.path)
        body = self._body()
        with LOCK:
            STATE["calls"].append(("POST", url.path, self._token()))
            if url.path == "/_stub/reset":
                STATE["installations"] = list(body.get("installations") or [])
                STATE["repos"] = {}
                for repo, items in (body.get("repos") or {}).items():
                    STATE["repos"][repo] = {int(i["number"]): i for i in items}
                STATE["next_number"] = 1000
                STATE["calls"] = []
                return self._send(200, {"ok": True})
            if url.path == "/login/oauth/access_token":
                return self._send(200, {"access_token": "stub-user-token", "token_type": "bearer"})
            m = re.fullmatch(r"/app/installations/(\d+)/access_tokens", url.path)
            if m:
                return self._send(201, {"token": f"stub-install-token-{m.group(1)}",
                                        "expires_at": "2099-01-01T00:00:00Z"})
            m = re.fullmatch(r"/repos/([^/]+/[^/]+)/issues", url.path)
            if m:
                repo = m.group(1)
                STATE["repos"].setdefault(repo, {})
                number = STATE["next_number"]
                STATE["next_number"] += 1
                item = issue_item(repo, number, str(body.get("title") or ""), "open",
                                  "2026-09-01T00:00:00Z")
                item["body"] = str(body.get("body") or "")
                STATE["repos"][repo][number] = item
                return self._send(201, item)
        return self._send(404, {"message": f"stub: no route for POST {url.path}"})

    def do_PATCH(self):
        # The app's one write-back: PATCH /repos/{r}/issues/{n} with a state.
        url = urlparse(self.path)
        body = self._body()
        with LOCK:
            STATE["calls"].append(("PATCH", url.path, self._token()))
            m = re.fullmatch(r"/repos/([^/]+/[^/]+)/issues/(\d+)", url.path)
            if m:
                item = STATE["repos"].get(m.group(1), {}).get(int(m.group(2)))
                if not item:
                    return self._send(404, {"message": "Not Found"})
                state = str(body.get("state") or item["state"])
                stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
                item["state"] = state
                item["updated_at"] = stamp
                item["closed_at"] = stamp if state == "closed" else None
                return self._send(200, item)
        return self._send(404, {"message": f"stub: no route for PATCH {url.path}"})


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8099
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"github stub listening on http://127.0.0.1:{port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
