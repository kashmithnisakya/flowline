"""Server-only GitHub App plumbing: app JWTs, installation tokens, HTTP. Every
Python import the feature needs is quarantined HERE (models.jac must stay
Python-free). Nothing returns a credential: `gh_request` hands back an
envelope and `safe_error` keeps only the status and GitHub's own message."""

import os;
import time;
import base64;
import secrets;
import socket;
import requests;
import jwt;
import json;
import logging;
import from urllib.parse { quote }

# Re-exported so callers get the guard and the request helpers from one
# place; the definition itself is Python-free and lives in models.jac.
import from services.util { ensure_arrows }
import from models {
    valid_full_name,
    Task,
    Repo,
    GithubConnection,
    WorkflowStep,
    steps_of
}
import from jaclang.server.shared_store { shared_store }

# The two bases are overridable so the smoke suite can point the app at
# tests/smoke/github_stub.py; a deployment never sets them.
glob log: logging.Logger = logging.getLogger("flowline.github"),
     GITHUB_API: str = os.environ.get("GITHUB_API_BASE") or "https://api.github.com",
     GITHUB_WEB: str = os.environ.get("GITHUB_WEB_BASE") or "https://github.com",
     TOKEN_CACHE: dict[str, dict[str, any]] = {},
     INSTALL_INDEX: str = "gh_installations",
     DELIVERIES: str = "gh_deliveries",
     REPO_LISTS: str = "gh_repo_lists",
     SYNC_LEASE: str = "sync:",
     log: logging.Logger = logging.getLogger("flowline.github");


# Installation tokens live ~1h. Cache them in process memory rather than on
# the connection node: a short-lived credential written to Mongo is still a
# credential at rest, and re-minting after a restart costs one request.
# ------------------------------------------------------------------- config

def app_id -> str {
    return os.environ.get("GITHUB_APP_ID") or "";
}


def app_slug -> str {
    return os.environ.get("GITHUB_APP_SLUG") or "";
}


def oauth_client -> list[str] {
    return [
        os.environ.get("GITHUB_APP_CLIENT_ID") or "",
        os.environ.get("GITHUB_APP_CLIENT_SECRET") or ""
    ];
}


# The PEM is awkward in a .env file, so accept either a base64 blob (one
# line, what most secret stores hand you) or the raw PEM with escaped
# newlines. Both normalize to a real multi-line key here.
def private_key -> str {
    raw = os.environ.get("GITHUB_APP_PRIVATE_KEY") or "";
    if not raw {
        return "";
    }
    if "BEGIN" not in raw {
        try {
            raw = base64.b64decode(raw).decode("utf-8");
        } except Exception {
            return "";
        }
    }
    return raw.replace("\\n", "\n");
}


# Which half of the setup is missing, so the UI can say so instead of
# failing with a bare 500. Empty list means the app is fully configured.
def missing_config -> list[str] {
    gaps: list[str] = [];
    if not app_id() {
        gaps.append("GITHUB_APP_ID");
    }
    if not private_key() {
        gaps.append("GITHUB_APP_PRIVATE_KEY");
    }
    if not app_slug() {
        gaps.append("GITHUB_APP_SLUG");
    }
    pair = oauth_client();
    if not pair[0] {
        gaps.append("GITHUB_APP_CLIENT_ID");
    }
    if not pair[1] {
        gaps.append("GITHUB_APP_CLIENT_SECRET");
    }
    return gaps;
}


def install_url(state: str) -> str {
    slug = app_slug();
    if not slug {
        return "";
    }
    return GITHUB_WEB + "/apps/" + slug + "/installations/new?state=" + state;
}


def new_state -> str {
    return secrets.token_urlsafe(24) as str;
}


# --------------------------------------------------------------- app tokens

# RS256 JWT signed with the app's private key, the credential that proves
# "I am this GitHub App". Max lifetime is 10 minutes; 9 leaves clock slack.
def app_jwt -> str {
    key = private_key();
    if not key or not app_id() {
        return "";
    }
    now = int(time.time());
    payload: dict[str, any] = {"iat": now - 60, "exp": now + 540, "iss": app_id()};
    try {
        return jwt.encode(payload, key, algorithm="RS256") as str;
    } except Exception {
        return "";
    }
}


# Mint (or reuse) the 1-hour token that acts on one installation.
def installation_token(installation_id: int) -> str {
    key = str(installation_id);
    now = time.time();
    cached = TOKEN_CACHE.get(key);
    if cached {
        expiry = cached["exp"] as float;
        if expiry > now + 60.0 {
            return cached["token"] as str;
        }
    }
    signed = app_jwt();
    if not signed {
        return "";
    }
    try {
        resp = requests.post(
            GITHUB_API + "/app/installations/" + key + "/access_tokens",
            headers={
                "Authorization": "Bearer " + signed,
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28"
            },
            timeout=10
        );
    } except Exception {
        return "";
    }
    if (resp.status_code as int) != 201 {
        return "";
    }
    body = resp.json() as dict;
    token = str(body.get("token") or "");
    if not token {
        return "";
    }
    # Trust our own clock over parsing GitHub's expires_at: 55 minutes is
    # inside the 60-minute lifetime with room for a slow request.
    TOKEN_CACHE[key] = {"token": token, "exp": now + 3300.0};
    return token;
}


def forget_installation(installation_id: int) {
    key = str(installation_id);
    if key in TOKEN_CACHE {
        TOKEN_CACHE.pop(key);
    }
}


# ------------------------------------------------------ installation index

# A GitHub App has one webhook URL for every installation, and a delivery
# names its tenant only by installation id. Walkers run on the caller's
# root, so this shared table is the one map from an id back to the
# workspace that connected it: id = installation id, doc = the root jid.
def bind_installation(installation_id: int, root_jid: str) -> bool {
    if installation_id <= 0 or not root_jid {
        return False;
    }
    doc = {
        "root_jid": root_jid,
        "bound_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    };
    try {
        db = shared_store();
        if db is None {
            return False;
        }
        db.rows(
            "INSERT INTO jac_docs (collection, id, doc) "
                + "VALUES (:c, :i, CAST(:d AS jsonb)) "
                + "ON CONFLICT (collection, id) DO UPDATE SET doc = EXCLUDED.doc",
            {"c": INSTALL_INDEX, "i": str(installation_id), "d": json.dumps(doc)}
        );
        return True;
    } except Exception as e {
        log.warning("installation index: bind failed: " + str(e));
        return False;
    }
}


def unbind_installation(installation_id: int) -> bool {
    if installation_id <= 0 {
        return False;
    }
    try {
        db = shared_store();
        if db is None {
            return False;
        }
        db.rows(
            "DELETE FROM jac_docs WHERE collection = :c AND id = :i",
            {"c": INSTALL_INDEX, "i": str(installation_id)}
        );
        drop_deliveries(installation_id);
        return True;
    } except Exception as e {
        log.warning("installation index: unbind failed: " + str(e));
        return False;
    }
}


# Drop an installation's row only while it still names `root_jid`, so a
# workspace that took the installation over in the meantime keeps it. True
# when this call removed the row (its queued deliveries go with it).
def release_binding(installation_id: int, root_jid: str) -> bool {
    if installation_id <= 0 or not root_jid {
        return False;
    }
    try {
        db = shared_store();
        if db is None {
            return False;
        }
        gone = db.rows(
            "DELETE FROM jac_docs WHERE collection = :c AND id = :i "
                + "AND doc->>'root_jid' = :r RETURNING id",
            {"c": INSTALL_INDEX, "i": str(installation_id), "r": root_jid}
        );
        if not gone {
            return False;
        }
        drop_deliveries(installation_id);
        return True;
    } except Exception as e {
        log.warning("installation index: release failed: " + str(e));
        return False;
    }
}


# The root jid bound to an installation, or "" when none is. Never raises:
# a store hiccup reads as unknown, and callers treat unknown as ignore.
def root_for_installation(installation_id: int) -> str {
    if installation_id <= 0 {
        return "";
    }
    try {
        db = shared_store();
        if db is None {
            return "";
        }
        rows = db.rows(
            "SELECT doc FROM jac_docs WHERE collection = :c AND id = :i",
            {"c": INSTALL_INDEX, "i": str(installation_id)}
        );
        if not rows {
            return "";
        }
        raw = rows[0][0];
        doc = raw if isinstance(raw, dict) else json.loads(str(raw));
        return str(doc.get("root_jid") or "");
    } except Exception as e {
        log.warning("installation index: lookup failed: " + str(e));
        return "";
    }
}


# The bound installations a tick should take next: the one whose pass is
# oldest first (an unsynced row sorts by when it was bound), at most `limit`
# of them, so one busy workspace cannot starve the rest and every workspace
# comes up within ceil(workspaces / limit) ticks. A store hiccup reads as no
# workspaces. limit <= 0 reads them all.
def due_installations(limit: int = 0) -> list[dict[str, any]] {
    found: list[dict[str, any]] = [];
    try {
        db = shared_store();
        if db is None {
            return found;
        }
        oldest = "SELECT id, doc FROM jac_docs WHERE collection = :c "
            + "AND doc->>'root_jid' <> '' "
            + "ORDER BY COALESCE(doc->>'synced_at', doc->>'bound_at', '') ASC, id";
        args: dict[str, any] = {"c": INSTALL_INDEX};
        if limit > 0 {
            oldest += " LIMIT :n";
            args["n"] = int(limit);
        }
        rows = db.rows(oldest, args);
        for (rid, raw) in rows {
            doc = raw if isinstance(raw, dict) else json.loads(str(raw));
            key = str(rid);
            found.append(
                {
                    "installation_id": int(key) if key.isdigit() else 0,
                    "root_jid": str(doc.get("root_jid") or ""),
                    "bound_at": str(doc.get("bound_at") or ""),
                    "webhook_seen_at": str(doc.get("webhook_seen_at") or ""),
                    "synced_at": str(doc.get("synced_at") or "")
                }
            );
        }
    } except Exception as e {
        log.warning("installation index: listing failed: " + str(e));
    }
    return found;
}


# The login GitHub stamps on this app's own writes, so a delivery echoing
# them can be told apart from a person's change.
def bot_login -> str {
    slug = app_slug();
    return slug + "[bot]" if slug else "";
}


# ------------------------------------------------------------- deliveries

# Verified deliveries wait here until the workspace's own session applies
# them: the receiver runs as the system identity, which must never write a
# tenant's graph. The row id is GitHub's delivery id, so a redelivery is
# refused by the primary key rather than by anything remembered.
def utc_stamp -> str {
    now = time.time();
    frac = int((now - int(now)) * 1000000);
    return time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(now))
        + "."
        + str(frac).rjust(6, "0")
        + "Z";
}


def enqueue_delivery(
    installation_id: int, delivery_id: str, payload: dict[str, any]
) -> str {
    key = delivery_id or "local-" + secrets.token_hex(12);
    doc = {
        "installation_id": str(installation_id),
        "received_at": utc_stamp(),
        "applied_at": "",
        "outcome": "",
        "payload": payload
    };
    try {
        db = shared_store();
        if db is None {
            return "unavailable";
        }
        rows = db.rows(
            "INSERT INTO jac_docs (collection, id, doc) "
                + "VALUES (:c, :i, CAST(:d AS jsonb)) "
                + "ON CONFLICT (collection, id) DO NOTHING RETURNING id",
            {"c": DELIVERIES, "i": key, "d": json.dumps(doc)}
        );
        return "queued" if rows else "duplicate";
    } except Exception as e {
        log.warning("deliveries: enqueue failed: " + str(e));
        return "unavailable";
    }
}


def pending_deliveries(installation_id: int, limit: int) -> list[dict[str, any]] {
    found: list[dict[str, any]] = [];
    try {
        db = shared_store();
        if db is None {
            return found;
        }
        rows = db.rows(
            "SELECT id, doc FROM jac_docs WHERE collection = :c "
                + "AND doc->>'installation_id' = :i AND doc->>'applied_at' = '' "
                + "ORDER BY doc->>'received_at', id LIMIT "
                + str(int(limit)),
            {"c": DELIVERIES, "i": str(installation_id)}
        );
        for (rid, raw) in rows {
            doc = raw if isinstance(raw, dict) else json.loads(str(raw));
            doc["id"] = str(rid);
            found.append(doc);
        }
    } except Exception as e {
        log.warning("deliveries: read failed: " + str(e));
    }
    return found;
}


def mark_delivered(delivery_id: str, applied_at: str, outcome: str) {
    try {
        db = shared_store();
        if db is None {
            return;
        }
        db.rows(
            "UPDATE jac_docs SET doc = doc || CAST(:p AS jsonb) "
                + "WHERE collection = :c AND id = :i",
            {
                "p": json.dumps({"applied_at": applied_at, "outcome": outcome}),
                "c": DELIVERIES,
                "i": delivery_id
            }
        );
    } except Exception as e {
        log.warning("deliveries: mark failed: " + str(e));
    }
}


# Applied rows stay a week as the delivery log, then go.
def purge_deliveries(installation_id: int, before: str) {
    try {
        db = shared_store();
        if db is None {
            return;
        }
        db.rows(
            "DELETE FROM jac_docs WHERE collection = :c "
                + "AND doc->>'installation_id' = :i "
                + "AND doc->>'applied_at' <> '' AND doc->>'applied_at' < :b",
            {"c": DELIVERIES, "i": str(installation_id), "b": before}
        );
    } except Exception as e {
        log.warning("deliveries: purge failed: " + str(e));
    }
}


def drop_deliveries(installation_id: int) {
    try {
        db = shared_store();
        if db is None {
            return;
        }
        db.rows(
            "DELETE FROM jac_docs WHERE collection = :c AND doc->>'installation_id' = :i",
            {"c": DELIVERIES, "i": str(installation_id)}
        );
    } except Exception as e {
        log.warning("deliveries: drop failed: " + str(e));
    }
}


# The newest verified delivery for an installation, which is what "live"
# means on the GitHub tab even while the deliveries wait in the queue.
def touch_installation(installation_id: int, seen_at: str) {
    try {
        db = shared_store();
        if db is None {
            return;
        }
        db.rows(
            "UPDATE jac_docs SET doc = doc || CAST(:p AS jsonb) "
                + "WHERE collection = :c AND id = :i",
            {
                "p": json.dumps({"webhook_seen_at": seen_at}),
                "c": INSTALL_INDEX,
                "i": str(installation_id)
            }
        );
    } except Exception as e {
        log.warning("installation index: touch failed: " + str(e));
    }
}


def note_sync_at(installation_id: int) {
    try {
        db = shared_store();
        if db is None {
            return;
        }
        db.rows(
            "UPDATE jac_docs SET doc = doc || CAST(:p AS jsonb) "
                + "WHERE collection = :c AND id = :i",
            {
                "p": json.dumps(
                    {"synced_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
                ),
                "c": INSTALL_INDEX,
                "i": str(installation_id)
            }
        );
    } except Exception as e {
        log.warning("installation index: sync stamp failed: " + str(e));
    }
}


def installation_seen_at(installation_id: int) -> str {
    if installation_id <= 0 {
        return "";
    }
    try {
        db = shared_store();
        if db is None {
            return "";
        }
        rows = db.rows(
            "SELECT doc->>'webhook_seen_at' FROM jac_docs WHERE collection = :c AND id = :i",
            {"c": INSTALL_INDEX, "i": str(installation_id)}
        );
        return str(rows[0][0] or "") if rows else "";
    } except Exception as e {
        log.warning("installation index: seen lookup failed: " + str(e));
        return "";
    }
}


# ------------------------------------------------------------ sync lease

# One sync pass per workspace at a time, across workers and pods. The
# schedule takes the lease for a pass and releases it; a manual sync leaves
# it held, so the schedule stays out of a workspace someone is syncing by
# hand until the lease expires. False when another owner holds it.
def lease_owner -> str {
    return socket.gethostname() + ":" + str(os.getpid());
}


def acquire_sync_lease(root_jid: str, owner: str, ttl_seconds: int) -> bool {
    if not root_jid {
        return False;
    }
    try {
        db = shared_store();
        if db is None {
            return False;
        }
        return bool(db.kv_acquire_lease(SYNC_LEASE + root_jid, ttl_seconds, owner));
    } except Exception as e {
        log.warning("sync lease: acquire failed: " + str(e));
        return False;
    }
}


def release_sync_lease(root_jid: str, owner: str) {
    try {
        db = shared_store();
        if db is None {
            return;
        }
        db.kv_release_lease(SYNC_LEASE + root_jid, owner);
    } except Exception as e {
        log.warning("sync lease: release failed: " + str(e));
    }
}


# ------------------------------------------------------------ repo lists

# The issue and pull request pages the GitHub page renders, kept per repo
# in the docs store: the sync writes them and a page load reads them, so no
# page waits on GitHub. One row per repo jid, kind and state filter.
def list_key(repo_id: str, kind: str, state: str) -> str {
    return repo_id + ":" + kind + ":" + state;
}


def store_repo_list(
    repo_id: str,
    kind: str,
    state: str,
    items: list[dict[str, any]],
    has_more: bool,
    synced_at: str
) -> bool {
    doc = {
        "repo_id": repo_id,
        "kind": kind,
        "state": state,
        "synced_at": synced_at,
        "has_more": has_more,
        "items": items
    };
    try {
        db = shared_store();
        if db is None {
            return False;
        }
        db.rows(
            "INSERT INTO jac_docs (collection, id, doc) "
                + "VALUES (:c, :i, CAST(:d AS jsonb)) "
                + "ON CONFLICT (collection, id) DO UPDATE SET doc = EXCLUDED.doc",
            {"c": REPO_LISTS, "i": list_key(repo_id, kind, state), "d": json.dumps(doc)}
        );
        return True;
    } except Exception as e {
        log.warning("repo lists: store failed: " + str(e));
        return False;
    }
}


# The stored page, or {} when none is stored (or the store is away).
def read_repo_list(repo_id: str, kind: str, state: str) -> dict[str, any] {
    nothing: dict[str, any] = {};
    if not repo_id {
        return nothing;
    }
    try {
        db = shared_store();
        if db is None {
            return nothing;
        }
        rows = db.rows(
            "SELECT doc FROM jac_docs WHERE collection = :c AND id = :i",
            {"c": REPO_LISTS, "i": list_key(repo_id, kind, state)}
        );
        if not rows {
            return nothing;
        }
        raw = rows[0][0];
        return raw if isinstance(raw, dict) else json.loads(str(raw));
    } except Exception as e {
        log.warning("repo lists: read failed: " + str(e));
        return nothing;
    }
}


# A removed repo takes its stored pages with it.
def drop_repo_lists(repo_id: str) {
    if not repo_id {
        return;
    }
    try {
        db = shared_store();
        if db is None {
            return;
        }
        db.rows(
            "DELETE FROM jac_docs WHERE collection = :c AND doc->>'repo_id' = :r",
            {"c": REPO_LISTS, "r": repo_id}
        );
    } except Exception as e {
        log.warning("repo lists: drop failed: " + str(e));
    }
}


# Monotonic seconds for a walker's time budget; kept here with the other
# Python imports so models.jac and the client bundle never see `time`.
def clock -> float {
    return time.monotonic() as float;
}


# ----------------------------------------------------------------- requests

# GitHub's error bodies can echo request context, so only the status code and
# the `message` field ever cross back to the client. Exception text never
# does: a requests traceback can carry the full URL and headers.
def safe_error(status: int, body: any) -> dict[str, any] {
    code = "request_failed";
    if status == 401 {
        code = "unauthorized";
    } elif status == 403 {
        code = "forbidden";
    } elif status == 404 {
        code = "not_found";
    } elif status == 422 {
        code = "invalid";
    }
    message = "";
    if isinstance(body, dict) {
        message = str(body.get("message") or "");
    }
    return {"ok": False, "status": status, "error": code, "message": message};
}


# One GitHub REST call, normalized to {"ok", "status", "data"}. Callers
# never see a raw response, an exception, or the token.
def gh_request(
    token: str,
    method: str,
    path: str,
    params: dict[str, any] | None = None,
    payload: dict[str, any] | None = None
) -> dict[str, any] {
    query: dict[str, any] = {};
    body_out: dict[str, any] = {};
    if params {
        query = params;
    }
    if payload {
        body_out = payload;
    }
    if not token {
        return {
            "ok": False,
            "status": 0,
            "error": "not_connected",
            "message": "GitHub is not connected."
        };
    }
    headers = {
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28"
    };
    try {
        if method == "POST" {
            resp = requests.post(
                GITHUB_API + path, headers=headers, json=body_out, timeout=10
            );
        } elif method == "PATCH" {
            resp = requests.patch(
                GITHUB_API + path, headers=headers, json=body_out, timeout=10
            );
        } elif method == "DELETE" {
            resp = requests.delete(GITHUB_API + path, headers=headers, timeout=10);
        } else {
            resp = requests.get(
                GITHUB_API + path, headers=headers, params=query, timeout=10
            );
        }
    } except Exception {
        return {
            "ok": False,
            "status": 0,
            "error": "network",
            "message": "Could not reach GitHub."
        };
    }
    status = resp.status_code as int;
    parsed: any = None;
    try {
        parsed = resp.json();
    } except Exception {
        parsed = None;
    }
    # A rate-limited response is a 403 with the remaining counter at zero.
    # Naming it separately keeps "you are throttled" out of "token revoked".
    if status == 403 {
        remaining = str(resp.headers.get("X-RateLimit-Remaining") or "");
        if remaining == "0" {
            return {
                "ok": False,
                "status": 403,
                "error": "rate_limited",
                "message": "GitHub rate limit reached. Try again shortly."
            };
        }
    }
    if status < 200 or status >= 300 {
        return safe_error(status, parsed);
    }
    return {"ok": True, "status": status, "data": parsed};
}


# ------------------------------------------------------- install completion

# Trade the install-time OAuth code for a USER token. Used once, to prove the
# person completing the install is the person who owns the installation.
# Never stored.
def exchange_code(code: str) -> str {
    pair = oauth_client();
    if not pair[0] or not pair[1] or not code {
        return "";
    }
    try {
        resp = requests.post(
            GITHUB_WEB + "/login/oauth/access_token",
            headers={"Accept": "application/json"},
            data={"client_id": pair[0], "client_secret": pair[1], "code": code},
            timeout=10
        );
    } except Exception {
        return "";
    }
    if (resp.status_code as int) != 200 {
        return "";
    }
    body = resp.json() as dict;
    return str(body.get("access_token") or "");
}


# Is this installation one the calling GitHub user can actually see?
# Installation ids are small integers, so without this a victim's workspace
# could be bound to an attacker's installation. {} on any failure = refuse.
def user_owns_installation(user_token: str, installation_id: int) -> dict[str, any] {
    nothing: dict[str, any] = {};
    if not user_token {
        return nothing;
    }
    result = gh_request(user_token, "GET", "/user/installations", {"per_page": 100});
    if not result["ok"] {
        return nothing;
    }
    data = result["data"];
    if not isinstance(data, dict) {
        return nothing;
    }
    rows = data.get("installations") or [];
    for row in rows {
        if not isinstance(row, dict) {
            continue;
        }
        if int(row.get("id") or 0) == installation_id {
            return row;
        }
    }
    return nothing;
}


# ------------------------------------------------------------- write-back

# Keep the linked issue's state with its card, for repos that opted in:
# `closed` closes an open issue (the card reached Done), otherwise a closed
# issue reopens (the card left Done). Returns the log-line suffix, or "" when
# nothing was written; a failure is logged, never raised.
def sync_issue_state(holder: Root, t: Task, closed: bool, stamp: str) -> str {
    if t.gh_issue_number <= 0
        or not valid_full_name(t.gh_repo)
        or (t.gh_issue_state == "closed") == closed {
        return "";
    }
    if not repo_policy(holder, t.gh_repo, "auto_close") {
        return "";
    }
    access = write_access(holder);
    if not access {
        return "";
    }
    c = access[0];
    token = str(access[1]);
    where = t.gh_repo + " #" + str(t.gh_issue_number);
    want = "closed" if closed else "open";
    result = gh_request(
        token,
        "PATCH",
        "/repos/" + t.gh_repo + "/issues/" + str(t.gh_issue_number),
        {},
        {"state": want}
    );
    if not result["ok"] {
        write_failed(c, result, "issue state write-back skipped for " + where);
        return "";
    }
    item = result["data"];
    updated = str(item.get("updated_at") or "") if isinstance(item, dict) else "";
    t.gh_issue_state = want;
    if updated > t.gh_updated_at {
        t.gh_updated_at = updated;
    }
    t.gh_synced_at = stamp;
    return ("closed " if closed else "reopened ") + where;
}


# A repo's write-back switch ("auto_close" or "label_sync") for one tracked
# repo of this workspace; False when the repo is not tracked.
def repo_policy(holder: Root, full_name: str, policy: str) -> bool {
    for r in [holder-->[?:Repo]] {
        if r.full_name == full_name {
            return bool(getattr(r, policy, False));
        }
    }
    return False;
}


# [connection, token] when this workspace may write to GitHub now, else [].
def write_access(holder: Root) -> list[any] {
    conns = [holder-->[?:GithubConnection]];
    c = conns[0] if conns else None;
    if not isinstance(c, GithubConnection)
        or c.installation_id == 0
        or c.status == "invalid" {
        return [];
    }
    token = installation_token(c.installation_id);
    return [c, token] if token else [];
}


# A refused write never blocks the move that asked for it: log it for the
# operator, and a revoked token marks the connection for the reconnect banner.
def write_failed(c: any, result: dict[str, any], what: str) {
    if result.get("error") == "unauthorized" and isinstance(c, GithubConnection) {
        c.status = "invalid";
    }
    log.warning(what + ": " + str(result.get("message") or result.get("error")));
}


# The name as the task last saw it on GitHub ("" when absent), so a removal
# names the label exactly and an add is skipped when it is already there.
def held_label(held: list[str], name: str) -> str {
    for h in held {
        if h.lower() == name.lower() {
            return h;
        }
    }
    return "";
}


# The label writes one move makes, for a repo with label_sync: crossing an
# arrow adds its GitHub label (on the PR when the arrow carries one and a PR
# is linked, else the issue); leaving a step takes off the labels of the
# arrows into it that are not kept. `already` is the label GitHub just added to
# move the task, which needs no write. Returns the move's log tail, or "".
def sync_step_labels(
    holder: Root, t: Task, from_id: str, to_id: str, already: str
) -> str {
    if not from_id
        or from_id == to_id
        or t.gh_issue_number <= 0
        or not valid_full_name(t.gh_repo)
        or not repo_policy(holder, t.gh_repo, "label_sync") {
        return "";
    }
    ensure_arrows(holder);
    adding = "";
    on_pr = False;
    leaving: list[str] = [];
    for st in steps_of(holder) {
        for tr in st.transitions {
            named = tr.get("github_label", "");
            if jid(st) == from_id and tr["to"] == to_id {
                adding = named;
                on_pr = tr.get("carries", "") == "pr" and t.pr_number > 0;
            }
            if tr["to"] == from_id
                and named
                and tr.get("keep_label", "") != "yes"
                and named not in leaving {
                leaving.append(named);
            }
        }
    }
    # [label, "pr" | "issue", "add" | "drop"], only what GitHub needs.
    writes: list[list[str]] = [];
    for gone in leaving {
        if gone.lower() == adding.lower() {
            continue;
        }
        on_its_pr = held_label(t.pr_labels, gone) if t.pr_number > 0 else "";
        if on_its_pr {
            writes.append([on_its_pr, "pr", "drop"]);
        }
        on_issue = held_label(t.gh_labels, gone);
        if on_issue {
            writes.append([on_issue, "issue", "drop"]);
        }
    }
    held = t.pr_labels if on_pr else t.gh_labels;
    if adding and adding.lower() != already.lower() and not held_label(held, adding) {
        writes.append([adding, "pr" if on_pr else "issue", "add"]);
    }
    if not writes {
        return "";
    }
    access = write_access(holder);
    if not access {
        return "";
    }
    notes: list[str] = [];
    for w in writes {
        number = t.pr_number if w[1] == "pr" else t.gh_issue_number;
        base = "/repos/" + t.gh_repo + "/issues/" + str(number) + "/labels";
        if w[2] == "add" {
            result = gh_request(str(access[1]), "POST", base, {}, {"labels": [w[0]]});
        } else {
            result = gh_request(
                str(access[1]), "DELETE", base + "/" + quote(w[0], safe="")
            );
        }
        # A label already gone answers 404; the task's copy follows either way.
        if not result["ok"] and not (w[2] == "drop" and result.get("status") == 404) {
            write_failed(access[0], result, "label write-back skipped for " + w[0]);
            continue;
        }
        if w[1] == "pr" {
            t.pr_labels = shift_label(t.pr_labels, w[0], w[2] == "add");
        } else {
            t.gh_labels = shift_label(t.gh_labels, w[0], w[2] == "add");
        }
        notes.append(
            ("labelled " if w[2] == "add" else "removed ") + w[0] + " on GitHub"
        );
    }
    return " · ".join(notes);
}


# The task's copy of a label list with one name added or taken off, so the
# next sync reads Flowline's own write as already seen, not as new.
def shift_label(held: list[str], name: str, on: bool) -> list[str] {
    kept = [
        h
        for h in held
        if h.lower() != name.lower()
    ];
    return kept + [name] if on else kept;
}


# GitHub label colours for a step's colour key (the light palette's inks).
glob LABEL_COLORS: dict[str, str] = {
         "sky": "2E6C97",
         "indigo": "5550AC",
         "amber": "A1711A",
         "rose": "A34B83",
         "emerald": "387A51",
         "slate": "6A726E"
     };


# Create every GitHub label the flow line's arrows name in one repo, coloured
# like the step each arrow leads into, so a first write does not make a grey
# one. A label the repo already has is left as it is. Returns how many were
# made, or -1 when this workspace cannot write to GitHub right now.
def ensure_repo_labels(holder: Root, full_name: str) -> int {
    access = write_access(holder);
    if not access or not valid_full_name(full_name) {
        return -1;
    }
    ensure_arrows(holder);
    steps = steps_of(holder);
    names: dict[str, str] = {};
    for st in steps {
        names[jid(st)] = st.name;
    }
    colours: dict[str, str] = {};
    for st in steps {
        colours[jid(st)] = LABEL_COLORS.get(st.color, "6A726E");
    }
    made = 0;
    seen: list[str] = [];
    for st in steps {
        for tr in st.transitions {
            named = tr.get("github_label", "");
            if not named or named.lower() in seen {
                continue;
            }
            seen.append(named.lower());
            result = gh_request(
                str(access[1]),
                "POST",
                "/repos/" + full_name + "/labels",
                {},
                {
                    "name": named,
                    "color": colours.get(tr["to"], "6A726E"),
                    "description": (
                        "Flowline: " + st.name + " → " + names.get(tr["to"], "")
                    )[:100]
                }
            );
            if result["ok"] {
                made = made + 1;
            } elif result.get("status") != 422 {
                write_failed(access[0], result, "label setup skipped for " + named);
            }
        }
    }
    return made;
}
