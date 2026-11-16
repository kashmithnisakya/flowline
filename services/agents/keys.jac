"""The workspace's own model accounts. Agents run on a key the workspace saves
here, never on Flowline's. A key is sealed with FLOWLINE_SECRETS_KEY before it
is stored, is never reported (only its last four characters are), and rides in
a run's call to the review service, which holds it for that call only. Also the
daily token budget those runs share."""

import os;
import base64;
import hashlib;
import logging;
import ipaddress;
import requests;
import from urllib.parse { urlparse }
import from cryptography.fernet { Fernet }
import from models {
    Agent,
    Agents,
    AiKeys,
    AiProvider,
    AiProviders,
    ProviderView,
    ai_providers_box
}
import from constants { AI_PROVIDERS }
import from services.util { now_iso, today_iso }

glob log: logging.Logger = logging.getLogger("flowline.keys"),
     KEY_MIN: int = 8,
     KEY_MAX: int = 400,
     TOKENS_MIN: int = 1000,
     TOKENS_MAX: int = 50000000,
     TEST_SECONDS: int = 8;

def refusal(error: str, message: str) -> dict[str, any] {
    return {"ok": False, "error": error, "message": message};
}


def provider_info(key: str) -> dict[str, any] {
    for item in AI_PROVIDERS {
        if item["key"] == key {
            return item;
        }
    }
    return {};
}


# The sealing secret, or "" when unset. A deploy that never received it can leave
# the literal ${...} text, which is a guessable value, so that reads as unset.
def secret_text -> str {
    raw = os.environ.get("FLOWLINE_SECRETS_KEY", "").strip();
    return "" if raw.startswith("${") else raw;
}


def secrets_ready -> bool {
    return bool(secret_text());
}


def sealer -> any {
    raw = secret_text();
    if not raw {
        return None;
    }
    return Fernet(base64.urlsafe_b64encode(hashlib.sha256(raw.encode()).digest()));
}


def seal(text: str) -> str {
    box = sealer();
    return box.encrypt(text.encode()).decode() if box else "";
}


# The key back, or "" when it cannot be opened (no secrets key, or one that
# changed since the key was saved).
def unseal(token: str) -> str {
    box = sealer();
    if not box or not token {
        return "";
    }
    try {
        return box.decrypt(token.encode()).decode();
    } except Exception {
        return "";
    }
}


# Why a custom endpoint may not be called, or "" when it may. The web app makes
# this call for the workspace, so it must not reach inward: https only, no
# credentials in the address, no loopback, private or link-local host.
def base_problem(url: str) -> str {
    try {
        parts = urlparse(url.strip());
    } except Exception {
        return "That address is not a web address.";
    }
    host = (parts.hostname or "").lower();
    if parts.scheme != "https" or not host {
        return "Use an https address.";
    }
    if parts.username or parts.password {
        return "Leave credentials out of the address.";
    }
    if host == "localhost" or host.endswith((".local", ".localhost", ".internal")) {
        return "That host is not reachable from here.";
    }
    ip: any = None;
    try {
        ip = ipaddress.ip_address(host);
    } except ValueError {
        ip = None;
    }
    if ip is not None
        and (
            ip.is_private
            or ip.is_loopback
            or ip.is_link_local
            or ip.is_reserved
            or ip.is_multicast
            or ip.is_unspecified
        ) {
        return "That host is not reachable from here.";
    }
    return "";
}


def is_connected(p: AiProvider) -> bool {
    if not p.key_last {
        return False;
    }
    return p.key != "custom" or bool(p.base_url and p.custom_model);
}


def rows_by_key(holder: Root) -> dict[str, AiProvider] {
    out: dict[str, AiProvider] = {};
    for box in [holder-->[?:AiProviders]] {
        for p in [box-->[?:AiProvider]] {
            out[p.key] = p;
        }
    }
    return out;
}


def read_keys(holder: Root) -> AiKeys {
    rows = rows_by_key(holder);
    boxes = [holder-->[?:AiProviders]];
    box = boxes[0] if boxes else None;
    shown: list[ProviderView] = [];
    models: list[list[str]] = [];
    for info in AI_PROVIDERS {
        p = rows.get(info["key"]);
        on = p is not None and is_connected(p);
        shown.append(
            ProviderView(
                key=info["key"],
                name=info["name"],
                connected=on,
                key_last=p.key_last if p else "",
                base_url=p.base_url if p else "",
                custom_model=p.custom_model if p else "",
                tested_at=p.tested_at if p else ""
            )
        );
        if on and p is not None {
            named = [p.custom_model] if info["key"] == "custom" else info["models"];
            for m in named {
                models.append([info["key"] + ":" + m, info["name"] + " / " + m]);
            }
        }
    }
    return AiKeys(
        providers=shown,
        models=models,
        default_model=box.default_model if box else "",
        daily_tokens=box.daily_tokens if box else 500000,
        tokens_today=int(box.day_tokens.get(today_iso(), 0)) if box else 0,
        secrets_ready=secrets_ready()
    );
}


# What a run needs to call the model with the workspace's own key:
# {"ok", "model", "api_key", "api_base"}, or {"ok": False, "error"}. The key
# goes into the run's call and nowhere else.
def provider_credentials(holder: Root, model: str) -> dict[str, any] {
    if ":" not in model {
        return {"ok": False, "error": "This agent has no model chosen."};
    }
    pk = model.split(":", 1)[0];
    name = model.split(":", 1)[1];
    info = provider_info(pk);
    row = rows_by_key(holder).get(pk);
    if not info or row is None or not is_connected(row) {
        return {
            "ok": False,
            "error": "No API key for this agent's model. Add one under Models and keys."
        };
    }
    wanted = [row.custom_model] if pk == "custom" else info["models"];
    if name not in wanted {
        return {
            "ok": False,
            "error": "That model is not offered by its provider here."
        };
    }
    secret = unseal(row.secret);
    if not secret {
        return {
            "ok": False,
            "error": "The saved key cannot be opened. Save it again under Models and keys."
        };
    }
    return {
        "ok": True,
        "model": info["prefix"] + name,
        "api_key": secret,
        "api_base": row.base_url if pk == "custom" else ""
    };
}


def tokens_today(holder: Root) -> int {
    for box in [holder-->[?:AiProviders]] {
        return int(box.day_tokens.get(today_iso(), 0));
    }
    return 0;
}


# Is there budget left today? True when no budget was ever set.
def tokens_left(holder: Root) -> bool {
    for box in [holder-->[?:AiProviders]] {
        return int(box.day_tokens.get(today_iso(), 0)) < box.daily_tokens;
    }
    return True;
}


def note_tokens(holder: Root, count: int) {
    if count <= 0 {
        return;
    }
    box = ai_providers_box(holder);
    day = today_iso();
    box.day_tokens = {day: int(box.day_tokens.get(day, 0)) + count};
}


walker:protect ListAiKeys {
    """The workspace's model accounts, models and token budget. Never a key."""
    has reports: list[AiKeys] = [];

    can start with Root entry {
        report read_keys(here);
    }
}

walker:protect SaveProviderKey {
    """Save or replace a provider's key. A custom provider also names its
    OpenAI-compatible address and model. The key is sealed before it is stored."""
    has provider: str = "",
        api_key: str = "",
        base_url: str = "",
        custom_model: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        info = provider_info(self.provider);
        secret = self.api_key.strip();
        if not info {
            report refusal("unknown_provider", "There is no provider called that.");
            disengage;
        }
        if not secrets_ready() {
            report refusal(
                "no_secrets",
                "This server cannot store keys yet. Ask whoever runs it to set FLOWLINE_SECRETS_KEY."
            );
            disengage;
        }
        if len(secret) < KEY_MIN or len(secret) > KEY_MAX {
            report refusal("bad_key", "That does not look like an API key.");
            disengage;
        }
        if self.provider == "custom" {
            problem = base_problem(self.base_url);
            if problem {
                report refusal("bad_base", problem);
                disengage;
            }
            named = self.custom_model.strip();
            if not named or len(named) > 100 {
                report refusal("bad_model", "Name the model to call.");
                disengage;
            }
        }
        visit ai_providers_box(here);
    }

    can save with AiProviders entry {
        found = [here-->[?:AiProvider, key==self.provider]];
        row: AiProvider | None = found[0] if found else None;
        if row is None {
            row = here ++> AiProvider(key=self.provider);
        }
        row.secret = seal(self.api_key.strip());
        row.key_last = self.api_key.strip()[-4:];
        row.base_url = self.base_url.strip() if self.provider == "custom" else "";
        row.custom_model = self.custom_model.strip()
            if self.provider == "custom"
            else "";
        row.tested_at = "";
        row.updated_at = now_iso();
        report {"ok": True};
        disengage;
    }
}

walker:protect RemoveProviderKey {
    """Forget a provider's key. Agents on that provider are switched off, and a
    default model on it is cleared."""
    has provider: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        visit [here-->[?:AiProviders]] else {
            report {"ok": True};
        }
    }

    can remove with AiProviders entry {
        for row in [here-->[?:AiProvider, key==self.provider]] {
            del row;
        }
        if here.default_model.startswith(self.provider + ":") {
            here.default_model = "";
        }
        for agents in [root-->[?:Agents]] {
            for a in [agents-->[?:Agent]] {
                if a.model.startswith(self.provider + ":") {
                    a.enabled = False;
                }
            }
        }
        report {"ok": True};
        disengage;
    }
}

walker:protect TestProvider {
    """Ask the provider for its model list with the saved key. Reports only
    whether it answered, never the key or the provider's own error text."""
    has provider: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        info = provider_info(self.provider);
        row = rows_by_key(here).get(self.provider);
        if not info or row is None or not is_connected(row) {
            report refusal("no_key", "Save a key first.");
            disengage;
        }
        secret = unseal(row.secret);
        if not secret {
            report refusal(
                "unreadable", "The saved key cannot be opened. Save it again."
            );
            disengage;
        }
        base = row.base_url if self.provider == "custom" else str(info["base"]);
        if self.provider == "custom" {
            problem = base_problem(base);
            if problem {
                report refusal("bad_base", problem);
                disengage;
            }
        }
        headers = {"x-api-key": secret, "anthropic-version": "2023-06-01"}
            if self.provider == "anthropic"
            else {"Authorization": "Bearer " + secret};
        try {
            got = requests.get(
                base.rstrip("/") + "/models",
                headers=headers,
                timeout=TEST_SECONDS,
                allow_redirects=False
            );
            if got.status_code == 200 {
                row.tested_at = now_iso();
                report {"ok": True};
            } elif got.status_code in [401, 403] {
                report refusal("refused", "The provider refused that key.");
            } else {
                report refusal(
                    "unexpected",
                    "The provider answered with status " + str(got.status_code) + "."
                );
            }
        } except Exception as e {
            log.warning("provider test failed: " + type(e).__name__);
            report refusal("unreachable", "Could not reach the provider.");
        }
    }
}

walker:protect SaveAiLimits {
    """The default model for new agents and the daily token budget."""
    has default_model: str = "",
        daily_tokens: int = 500000,
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        if self.daily_tokens < TOKENS_MIN or self.daily_tokens > TOKENS_MAX {
            report refusal(
                "bad_budget",
                "Use a budget between "
                    + str(TOKENS_MIN)
                    + " and "
                    + str(TOKENS_MAX)
                    + " tokens."
            );
            disengage;
        }
        if self.default_model {
            offered = [m[0] for m in read_keys(here).models];
            if self.default_model not in offered {
                report refusal("bad_model", "That model has no key yet.");
                disengage;
            }
        }
        visit ai_providers_box(here);
    }

    can save with AiProviders entry {
        here.default_model = self.default_model;
        here.daily_tokens = self.daily_tokens;
        report {"ok": True};
        disengage;
    }
}
