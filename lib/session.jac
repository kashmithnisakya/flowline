"""Thin wrapper over the runtime's /user/me endpoints. The account IS the
organization, so org details live in the profile; `@jac/runtime` exports no
/user/me helper, so these fetch by hand with the stored JWT. One read per
page load: `fetchMe` keeps the in-flight promise and the answer in module
state, and a profile write or a session change drops them. It also keeps
the last known workspace name and account in localStorage, so the header,
the workspace rail and the Organization form paint them before /user/me
answers on the next load.
"""

import from .workspace { forgetWorkspace }

glob ORG_KEY: str = "flowline-org",
     ACCOUNT_KEY: str = "flowline-account";

# The first-load frames' shape caches (what the last visit of each page
# looked like in this browser). Session-scoped like the name: dropped when
# a session starts or ends, so another account never inherits them.
glob:pub LANES_KEY: str = "flowline-lanes",
     OVERVIEW_SHAPE_KEY: str = "flowline-overview-shape",
     LOG_SHAPE_KEY: str = "flowline-log-shape",
     ROADMAP_SHAPE_KEY: str = "flowline-roadmap-shape",
     GITHUB_KEY: str = "flowline-github";

glob SESSION_KEYS: list[str] = [
         ORG_KEY,
         ACCOUNT_KEY,
         LANES_KEY,
         OVERVIEW_SHAPE_KEY,
         LOG_SHAPE_KEY,
         ROADMAP_SHAPE_KEY,
         GITHUB_KEY
     ],
     ME: dict[str, any] = {"promise": None, "data": None};

# The one /user/me read of this page load: the promise while it is in
# flight, then the `data` body ({profile, identities}). A dict cell, not a
# `has`: every mount and page shares it.
def readKey(key: str) -> str {
    try {
        return localStorage.getItem(key) or "";
    } except Exception as e {
        return "";
    }
}

def:pub cachedOrgName -> str {
    return readKey(ORG_KEY);
}

def:pub cachedAccount -> str {
    return readKey(ACCOUNT_KEY);
}

def:pub rememberOrgName(name: str) -> None {
    try {
        if name {
            localStorage.setItem(ORG_KEY, name);
        }
    } except Exception as e {
        return;
    }
}

def:pub rememberAccount(who: str) -> None {
    try {
        if who {
            localStorage.setItem(ACCOUNT_KEY, who);
        }
    } except Exception as e {
        return;
    }
}

# Drop the memoised /user/me answer: the next reader fetches again.
def:pub forgetMe {
    ME["promise"] = None;
    ME["data"] = None;
}

# A session starting (login, SSO callback) or ending (sign out) drops the
# caches, so another account's name or page shapes never show first.
def:pub forgetSession -> None {
    forgetMe();
    forgetWorkspace();
    try {
        for key in SESSION_KEYS {
            localStorage.removeItem(key);
        }
    } except Exception as e {
        return;
    }
}

def authHeaders -> dict[str, str] {
    token = localStorage.getItem("jac_token") or "";
    return {"Content-Type": "application/json", "Authorization": "Bearer " + token};
}

# One GET /user/me; {} when logged out or on error, and only a good answer
# is kept, so a failed read is retried by the next caller.
async def readMe -> dict[str, any] {
    try {
        response = await fetch("/user/me", {"headers": authHeaders()});
        if not response.ok {
            return {};
        }
        body: any = await response.json();
        data: any = body["data"] if body["data"] else {};
        ME["data"] = data;
        return data;
    } except Exception as e {
        return {};
    }
}

# GET /user/me -> its `data` body ({profile, identities}), read once per
# page load: concurrent callers share the in-flight promise.
async def:pub fetchMe -> dict[str, any] {
    if ME["data"] {
        return ME["data"];
    }
    if not ME["promise"] {
        ME["promise"] = readMe();
    }
    promise: any = ME["promise"];
    data = await promise;
    if ME["promise"] == promise {
        ME["promise"] = None;
    }
    return data;
}

# The account's profile dict ({} when logged out or on error).
async def:pub fetchProfile -> dict[str, any] {
    data = await fetchMe();
    return data["profile"] if data["profile"] else {};
}

# PATCH /user/me, merges the given keys into the existing profile.
async def:pub patchProfile(changes: dict[str, any]) -> bool {
    try {
        response = await fetch(
            "/user/me",
            {
                "method": "PATCH",
                "headers": authHeaders(),
                "body": JSON.stringify({"profile": changes})
            }
        );
        # The setup wizard and the Organization form both land here, so the
        # cache follows a rename without either page knowing about it, and
        # the memoised profile is dropped for the next reader, with the
        # workspace view (the org rename path).
        forgetMe();
        forgetWorkspace();
        if response.ok and "org_name" in changes and changes["org_name"] {
            rememberOrgName(str(changes["org_name"]));
        }
        return response.ok;
    } except Exception as e {
        return False;
    }
}

# The organization name shown in the nav, or "" if never set.
async def:pub fetchOrgName -> str {
    profile = await fetchProfile();
    name = profile["org_name"] if profile["org_name"] else "";
    return name;
}
