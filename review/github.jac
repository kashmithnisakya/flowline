"""The review service's own GitHub calls, made with the installation token the
web app passes in. Separate from services/github/util.jac, which belongs to
the web app (it reads the workspace's graph); this one never does."""

import os;
import requests;

glob API: str = (
         os.environ.get("GITHUB_API_BASE") or "https://api.github.com"
     ).rstrip(
         "/"
     );

# One GitHub call: {"ok", "status", "data"} or {"ok": False, "status",
# "error", "retryable"}. A 5xx, a rate limit or a network failure is worth a
# retry; anything else is not.
def gh(
    token: str,
    method: str,
    path: str,
    params: dict[str, any] | None = None,
    payload: dict[str, any] | None = None
) -> dict[str, any] {
    if not token {
        return {
            "ok": False,
            "status": 0,
            "error": "GitHub is not connected.",
            "retryable": False
        };
    }
    headers = {
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28"
    };
    try {
        resp = requests.request(
            method, API + path, headers=headers, params=params, json=payload, timeout=20
        );
    } except Exception {
        return {
            "ok": False,
            "status": 0,
            "error": "Could not reach GitHub.",
            "retryable": True
        };
    }
    status = resp.status_code as int;
    data: any = None;
    try {
        data = resp.json();
    } except Exception {
        data = None;
    }
    if 200 <= status < 300 {
        return {"ok": True, "status": status, "data": data};
    }
    limited = status == 403
        and str(resp.headers.get("X-RateLimit-Remaining") or "") == "0";
    message = str(data.get("message") or "") if isinstance(data, dict) else "";
    return {
        "ok": False,
        "status": status,
        "error": "GitHub answered " + str(status) + (": " + message if message else ""),
        "retryable": status >= 500 or status == 429 or limited
    };
}
