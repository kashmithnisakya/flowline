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
        response = await fetch("/user/me", {
            "method": "PATCH",
            "headers": authHeaders(),
            "body": JSON.stringify({"profile": changes})
        });
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
