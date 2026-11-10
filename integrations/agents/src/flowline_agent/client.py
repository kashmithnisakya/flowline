"""One HTTP client for CLI and MCP; no local Flowline or Jac required."""

from __future__ import annotations

import ipaddress
import json
import os
import stat
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

import httpx


class FlowlineError(Exception):
    def __init__(self, code: str, message: str, details: object = None):
        super().__init__(message)
        self.code = code
        self.details = details

    def result(self) -> dict:
        return {
            "ok": False,
            "error": self.code,
            "message": str(self),
            "details": self.details,
        }


def with_node_ids(value):
    """Give raw graph nodes the same public ID field as the API's view objects."""
    if isinstance(value, list):
        return [with_node_ids(item) for item in value]
    if isinstance(value, dict):
        result = {key: with_node_ids(item) for key, item in value.items()}
        if value.get("_jac_archetype") == "node" and isinstance(
            value.get("_jac_id"), str
        ):
            result.setdefault("id", value["_jac_id"])
        return result
    return value


def normalize_url(url: str) -> str:
    try:
        parsed = urlsplit(url)
        hostname = parsed.hostname or ""
        _ = parsed.port
    except ValueError as exc:
        raise FlowlineError("invalid_url", "Invalid Flowline URL") from exc
    try:
        loopback = ipaddress.ip_address(hostname).is_loopback
    except ValueError:
        loopback = hostname == "localhost"
    if (
        not hostname
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
        or any(c.isspace() or ord(c) < 32 or ord(c) == 127 for c in url)
        or (parsed.scheme != "https" and not (parsed.scheme == "http" and loopback))
    ):
        raise FlowlineError(
            "invalid_url",
            "Use an HTTPS Flowline URL (HTTP is allowed only on loopback)",
        )
    return urlunsplit(
        (parsed.scheme, parsed.netloc.lower(), parsed.path.rstrip("/"), "", "")
    )


def config_path() -> Path:
    override = os.environ.get("FLOWLINE_CONFIG")
    return (
        Path(override).expanduser()
        if override
        else Path.home() / ".config" / "flowline" / "credentials.json"
    )


def read_config() -> dict:
    path = config_path()
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    except FileNotFoundError:
        return {"accounts": {}}
    except OSError as exc:
        raise FlowlineError(
            "credentials_unreadable", "Cannot safely open Flowline credentials"
        ) from exc
    with os.fdopen(fd, encoding="utf-8") as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or (
            os.name != "nt" and (info.st_mode & 0o077)
        ):
            raise FlowlineError(
                "credentials_permissions",
                "Credentials must be a private regular file (chmod 600)",
            )
        try:
            config = json.load(stream)
        except (ValueError, UnicodeError) as exc:
            raise FlowlineError(
                "credentials_invalid", "Invalid Flowline credentials file"
            ) from exc
    if (
        not isinstance(config, dict)
        or not isinstance(config.get("accounts"), dict)
        or not isinstance(config.get("default_url", ""), str)
        or not all(isinstance(value, str) for value in config["accounts"].values())
    ):
        raise FlowlineError("credentials_invalid", "Invalid Flowline credentials file")
    return config


def save_token(url: str, token: str) -> None:
    path = config_path()
    config = read_config()
    config["accounts"][url] = token
    config["default_url"] = url
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    # Exclusive temporary file + atomic replacement prevents partial credentials.
    import tempfile

    fd, name = tempfile.mkstemp(prefix=".credentials-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(config, stream)
            stream.write("\n")
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def settings(url: str | None = None) -> tuple[str, str]:
    config = read_config()
    selected = normalize_url(
        url or os.environ.get("FLOWLINE_URL") or config.get("default_url", "")
    )
    # An environment token is bound to its explicitly configured origin.
    env_token = os.environ.get("FLOWLINE_TOKEN", "")
    if env_token:
        configured = os.environ.get("FLOWLINE_URL", "")
        if not configured or normalize_url(configured) != selected:
            raise FlowlineError(
                "token_origin", "FLOWLINE_TOKEN requires a matching FLOWLINE_URL"
            )
    token = env_token or config["accounts"].get(selected, "")
    if not isinstance(token, str) or not token:
        raise FlowlineError(
            "not_authenticated",
            "Run flowline --url URL login, or set FLOWLINE_URL and FLOWLINE_TOKEN",
        )
    return selected, token


class FlowlineClient:
    def __init__(self, url: str, token: str = "", *, timeout: float = 30):
        self.url = normalize_url(url)
        self.token = token
        self.http = httpx.Client(timeout=timeout, follow_redirects=False)

    @classmethod
    def configured(cls, url: str | None = None) -> FlowlineClient:
        return cls(*settings(url))

    def close(self) -> None:
        self.http.close()

    def request(self, path: str, body: dict, *, authenticated: bool = True) -> dict:
        headers = {
            "Accept": "application/json",
            "User-Agent": "flowline-agent-client/0.1.0",
        }
        if authenticated:
            if not self.token:
                raise FlowlineError("not_authenticated", "A Flowline token is required")
            headers["Authorization"] = "Bearer " + self.token
        try:
            response = self.http.post(self.url + path, json=body, headers=headers)
        except httpx.HTTPError as exc:
            # HTTPX exception strings can contain credential-bearing URLs.
            raise FlowlineError(
                "network_error", "Flowline request failed; verify the URL and network"
            ) from exc
        if 300 <= response.status_code < 400:
            raise FlowlineError(
                "redirect_refused",
                "Flowline redirected the request; configure its canonical URL",
            )
        if response.status_code in (401, 403):
            raise FlowlineError(
                "unauthorized", "Flowline refused authentication or workspace access"
            )
        if response.status_code >= 400:
            try:
                failure = response.json()
            except ValueError:
                failure = None
            error = failure.get("error") if isinstance(failure, dict) else None
            if isinstance(error, dict) and error.get("code") == "FAILED_AFTER_COMMIT":
                raise FlowlineError(
                    "failed_after_commit",
                    "Flowline may have committed part of this operation. "
                    "Inspect the workspace before retrying.",
                    {"final": True},
                )
            raise FlowlineError(
                "http_error", f"Flowline returned HTTP {response.status_code}"
            )
        try:
            payload = response.json()
        except ValueError as exc:
            raise FlowlineError(
                "invalid_response", "Flowline returned a non-JSON response"
            ) from exc
        if not isinstance(payload, dict) or payload.get("ok") is False:
            raise FlowlineError("api_error", "Flowline did not accept the request")
        return payload

    def login(self, email: str, password: str) -> str:
        payload = self.request(
            "/user/login",
            {
                "identity": {"type": "email", "value": email},
                "credential": {"type": "password", "password": password},
            },
            authenticated=False,
        )
        data = payload.get("data", {})
        token = data.get("token") if isinstance(data, dict) else None
        if not isinstance(token, str) or not token:
            raise FlowlineError("invalid_response", "Login returned no token")
        return token

    def walker(self, name: str, body: dict | None = None) -> dict:
        # Names come from the fixed operation registry, never from tool input.
        payload = self.request("/walker/" + name, body or {})
        data = payload.get("data", payload)
        reports = data.get("reports") if isinstance(data, dict) else None
        if not isinstance(reports, list) or not reports:
            raise FlowlineError(
                "not_found_or_refused",
                "The object was not found or the operation was refused",
            )
        result = with_node_ids(reports[0])
        if isinstance(result, dict) and result.get("ok") is False:
            code = result.get("error", "operation_refused")
            raise FlowlineError(
                str(code), "Flowline refused the operation: " + str(code), result
            )
        if isinstance(result, dict) and result.get("refused"):
            raise FlowlineError(
                "transition_refused",
                "Flowline's entry rules refused this transition",
                {"refused": result["refused"]},
            )
        return result if isinstance(result, dict) else {"rows": result}
