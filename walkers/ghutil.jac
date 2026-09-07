"""Server-only GitHub App plumbing: app JWTs, installation tokens, HTTP. Every
Python import the feature needs is quarantined HERE (models.jac must stay
Python-free). Nothing returns a credential: `gh_request` hands back an
envelope and `safe_error` keeps only the status and GitHub's own message."""

import os;
import time;
import base64;
import secrets;
import requests;
import jwt;

# Re-exported so callers get the guard and the request helpers from one
# place; the definition itself is Python-free and lives in models.jac.
import from models { valid_full_name }

glob GITHUB_API: str = "https://api.github.com",
     GITHUB_WEB: str = "https://github.com",
     TOKEN_CACHE: dict[str, dict[str, any]] = {};


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
