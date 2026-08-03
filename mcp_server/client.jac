"""HTTP client for the standup walker API.

The MCP server is a dumb proxy. It forwards a JWT and a JSON body to the
walker endpoints the browser already uses, and never reaches the graph
directly. Every tenant boundary stays exactly where it lives today, in the
walkers' `owned()` checks, so this module adds no authorization of its own.

Stdlib only on purpose: `requests` is not present in the jac runtime env, and
the SDK's dependency tree is already heavy enough.
"""

import os;
import json;
import from urllib.request { Request, urlopen }
import from urllib.error { HTTPError, URLError }


class StandupError(Exception) {}


# Peel the transport envelope off a response body. The serve layer wraps
# payloads as {"data": ...}, and some transports hand back a [status, body]
# pair instead.
def unwrap(payload: any) -> any {
    if isinstance(payload, list) and len(payload) == 2 {
        payload = payload[1];
    }
    if isinstance(payload, dict) and "data" in payload {
        return payload["data"];
    }
    return payload;
}


obj StandupClient {
    has base_url: str,
        token: str = "",
        email: str = "",
        password: str = "",
        timeout: int = 30;

    def request(
        method: str, path: str, body: dict[str, any] | None = None, auth: bool = True
    ) -> any;
    def login -> None;
    def health_check -> None;
    def call_walker(name: str, payload: dict[str, any] | None = None) -> list[any];
    def get_profile -> dict[str, any];
}


impl StandupClient.request(
    method: str, path: str, body: dict[str, any] | None = None, auth: bool = True
) -> any {
    headers: dict[str, str] = {"Content-Type": "application/json"};
    if auth {
        if not self.token {
            self.login();
        }
        headers["Authorization"] = f"Bearer {self.token}";
    }
    data = json.dumps(body).encode("utf-8") if body is not None else None;
    req = Request(
        f"{self.base_url}{path}", data=data, headers=headers, method=method
    );
    try {
        resp = urlopen(req, timeout=self.timeout);
        raw = resp.read().decode("utf-8");
        resp.close();
        return json.loads(raw) if raw else {};
    } except HTTPError as e {
        # A 401 on an authenticated call usually means the token aged out.
        # Re-login once and retry; a second failure is a real error.
        if e.code == 401 and auth and self.email and self.password {
            self.token = "";
            self.login();
            headers["Authorization"] = f"Bearer {self.token}";
            retry = Request(
                f"{self.base_url}{path}", data=data, headers=headers, method=method
            );
            try {
                resp2 = urlopen(retry, timeout=self.timeout);
                raw2 = resp2.read().decode("utf-8");
                resp2.close();
                return json.loads(raw2) if raw2 else {};
            } except HTTPError as e2 {
                raise StandupError(f"{method} {path} failed: HTTP {e2.code}");
            }
        }
        detail = "";
        try {
            detail = e.read().decode("utf-8")[:300];
        } except Exception {
            detail = "";
        }
        raise StandupError(f"{method} {path} failed: HTTP {e.code} {detail}");
    } except URLError as e {
        raise StandupError(
            f"cannot reach standup at {self.base_url} ({e.reason}). "
            + "Check STANDUP_URL and that the server is running."
        );
    }
}


impl StandupClient.login -> None {
    if self.token {
        return;
    }
    if not self.email or not self.password {
        raise StandupError(
            "no credentials: set STANDUP_TOKEN, or STANDUP_EMAIL and "
            + "STANDUP_PASSWORD"
        );
    }
    body = {
        "identity": {"type": "username", "value": self.email},
        "credential": {"type": "password", "password": self.password}
    };
    data = unwrap(self.request("POST", "/user/login", body, auth=False));
    tok = data["token"] if isinstance(data, dict) and "token" in data else "";
    if not tok {
        raise StandupError(f"login failed for {self.email}: no token in response");
    }
    self.token = str(tok);
}


# Fail loudly at startup rather than letting every tool time out. `jac start`
# drifts to the next port pair when a stale process holds the API port, so a
# stale STANDUP_URL is a routine mistake, not an exotic one.
impl StandupClient.health_check -> None {
    try {
        self.request("GET", "/healthz", auth=False);
    } except StandupError as e {
        raise StandupError(f"standup is not reachable: {e}");
    }
}


impl StandupClient.call_walker(name: str, payload: dict[str, any] | None = None) -> list[any] {
    data = unwrap(self.request("POST", f"/walker/{name}", payload or {}));
    if isinstance(data, dict) and "reports" in data {
        reports = data["reports"];
        return reports if isinstance(reports, list) else [reports];
    }
    return [];
}


impl StandupClient.get_profile -> dict[str, any] {
    data = unwrap(self.request("GET", "/user/me"));
    if not isinstance(data, dict) {
        return {};
    }
    profile = data["profile"] if "profile" in data else {};
    return profile if isinstance(profile, dict) else {};
}


# Build a client from the environment. STANDUP_TOKEN short-circuits login.
def build_client -> StandupClient {
    url = os.environ.get("STANDUP_URL", "http://localhost:8000").rstrip("/");
    return StandupClient(
        base_url=url,
        token=os.environ.get("STANDUP_TOKEN", ""),
        email=os.environ.get("STANDUP_EMAIL", ""),
        password=os.environ.get("STANDUP_PASSWORD", "")
    );
}
