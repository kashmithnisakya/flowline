"""Thin wrapper over the runtime's /user/me endpoints. The account IS the
organization, so org details live in the profile; `@jac/runtime` exports no
/user/me helper, so these fetch by hand with the stored JWT.
"""

def authHeaders -> dict[str, str] {
    token = localStorage.getItem("jac_token") or "";
    return {"Content-Type": "application/json", "Authorization": "Bearer " + token};
}

# GET /user/me -> the account's profile dict ({} when logged out or on error).
async def:pub fetchProfile -> dict[str, any] {
    try {
        response = await fetch("/user/me", {"headers": authHeaders()});
        if not response.ok {
            return {};
        }
        body = await response.json();
        data = body["data"] if body["data"] else {};
        return data["profile"] if data["profile"] else {};
    } except Exception as e {
        return {};
    }
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

# The account's login email, from /user/me identities ("" when logged out).
# The invite flow sends it so an email-pinned invite can match.
async def:pub fetchAccountEmail -> str {
    try {
        response = await fetch("/user/me", {"headers": authHeaders()});
        if not response.ok {
            return "";
        }
        body = await response.json();
        data = body["data"] if body["data"] else {};
        ids = data["identities"] if data["identities"] else [];
        for ident in ids {
            if ident["value"] {
                return str(ident["value"]);
            }
        }
        return "";
    } except Exception as e {
        return "";
    }
}


# ------------------------------------------------------------------- spaces
# Which board this session operates on: "" is the account's own root (the
# founder's org), an org root id means "a board this account joined". Every
# walker call targets `spaceRoot()`: the compiled client sends it as the
# spawn node, and the server enforces the caller's key on every request.

# Declared -> Root because the value is only ever a spawn target and E1115
# rejects str/any there. At runtime it IS a string: the compiled client
# passes it through as the walker's node id ("" = the caller's own root).
def:pub spaceRoot -> Root {
    v: any = "";
    try {
        v = localStorage.getItem("standup_space") or "";
    } except Exception {
        v = "";
    }
    return v;
}


def:pub setSpaceRoot(orgRootId: str) -> None {
    try {
        if orgRootId {
            localStorage.setItem("standup_space", orgRootId);
        } else {
            localStorage.removeItem("standup_space");
        }
    } except Exception {
        return;
    }
}
