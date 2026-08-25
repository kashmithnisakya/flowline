"""Server-only helpers. Kept out of models.jac so that module stays free of
Python imports, client components import types from models, and a Python
anchor there would drag the wasm host into the browser bundle."""

import datetime;
import hashlib;
import secrets;
import from jaclang { JacRuntime as Jac }
import from uuid { UUID }
import from models { Member, Invite, GithubConnection, on_attached }


def now_iso -> str {
    return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None).isoformat()
        + "Z";
}


# Age of a now_iso() stamp. An unreadable or empty stamp reads as ancient so
# that callers expiring a one-shot token fail closed.
def minutes_since(stamp: str) -> float {
    if not stamp {
        return 999999.0;
    }
    try {
        then = datetime.datetime.fromisoformat(stamp.replace("Z", ""));
    } except Exception {
        return 999999.0;
    }
    now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None);
    return (now - then).total_seconds() / 60.0;
}


# `iso` shifted by `days` (negative for earlier), as an ISO day. Anything that
# is not a full ISO day passes through unchanged.
def shift_day(iso: str, days: int) -> str {
    if len(iso) < 10 {
        return iso;
    }
    try {
        d = datetime.date.fromisoformat(iso[:10]);
    } except Exception {
        return iso;
    }
    return (d + datetime.timedelta(days=days)).isoformat();
}


def today_iso -> str {
    return now_iso()[:10];
}


# Page arithmetic shared by every list walker: a 1-based page, a size clamped
# to [1, cap], and the slice bounds. `page_size` 0 asks for the default.
def page_bounds(
    page: int, page_size: int, fallback: int, cap: int
) -> tuple[int, int, int, int] {
    size = page_size if page_size > 0 else fallback;
    if size > cap {
        size = cap;
    }
    p = page if page > 0 else 1;
    start = (p - 1) * size;
    return (p, size, start, start + size);
}

# ------------------------------------------------------------- organizations
# The grant API wrappers take `any`: the 0.36.1 checker does not accept node
# instances as `Archetype` parameters. Levels travel as the runtime's own
# strings ("READ"/"WRITE"/"NO_ACCESS"); a malformed root id must no-op, not
# 500 the walker with a traceback.

def grant_root_on(target: any, root_id: str, level: str) -> None {
    try {
        Jac.allow_root(target, UUID(root_id), level);
    } except Exception {
        return;
    }
}


def revoke_root_on(target: any, root_id: str) -> None {
    try {
        Jac.disallow_root(target, UUID(root_id));
    } except Exception {
        return;
    }
}


# Org levels, weakest first; "owner" is derived, never stored. rank 0 = no
# standing at all, so every check is a plain rank comparison.
def level_rank(level: str) -> int {
    if level == "owner" {
        return 4;
    }
    if level == "manager" {
        return 3;
    }
    if level == "editor" {
        return 2;
    }
    if level == "viewer" {
        return 1;
    }
    return 0;
}


# The runtime's ACL level a membership level maps to. Viewers get a key that
# physically cannot write, whatever our walkers do.
def acl_for_level(level: str) -> str {
    return "READ" if level == "viewer" else "WRITE";
}


# Who is calling this walker, relative to the org root it entered? `root` is
# always the CALLER's root even when the walker was spawned on a foreign
# root via nd, so `jid(root)` is the authoritative caller identity.
def caller_level(org_root: any, caller_root_id: str) -> str {
    if caller_root_id == jid(org_root) {
        return "owner";
    }
    for m in [org_root-->[?:Member]] {
        if m.account_root_id == caller_root_id and m.active {
            return m.level;
        }
    }
    return "";
}


# Every account-linked, active member as (account_root_id, level) pairs.
def linked_members(org_root: any) -> list[tuple[str, str]] {
    rows: list[tuple[str, str]] = [];
    for m in [org_root-->[?:Member]] {
        if m.account_root_id and m.active {
            rows.append((m.account_root_id, m.level));
        }
    }
    return rows;
}


# Ownership is creator-sticky: a node a member creates inside the org graph
# belongs to the member's account, so the owner's root-level grant does not
# cover it. Stamp every linked member's key (and the org root's) onto the
# fresh node and its incident edges so the whole team keeps seeing it.
def attach_stamp(org_root: any, fresh: any) {
    on_attached(org_root, fresh);
    targets: list[any] = [fresh];
    for e in [edge fresh-->] {
        targets.append(e);
    }
    for e in [edge fresh<--] {
        targets.append(e);
    }
    org_id = jid(org_root);
    for t in targets {
        grant_root_on(t, org_id, "WRITE");
        for (rid, lvl) in linked_members(org_root) {
            grant_root_on(t, rid, acl_for_level(lvl));
        }
    }
}


# Sensitive nodes get an explicit NO_ACCESS for members below min_rank: the
# per-node entry beats the root-level cascade, so those keys open the board
# but not this node. Invites shield below manager (3), the GitHub connection
# below editor (2).
def shield_node(org_root: any, fresh: any, min_rank: int) {
    grant_root_on(fresh, jid(org_root), "WRITE");
    for (rid, lvl) in linked_members(org_root) {
        if level_rank(lvl) < min_rank {
            grant_root_on(fresh, rid, "NO_ACCESS");
        }
    }
}


# Walk the whole org graph (two levels: root children plus LogDay entries)
# stamping one member's key on every node and edge. Two jobs: a NEW member
# must see what other members created before they arrived (the root cascade
# only covers owner-owned nodes), and a LEVEL CHANGE must overwrite the
# per-node stamps attach_stamp left, or a demoted editor's old WRITE
# entries would beat their new viewer key. Sensitive nodes are skipped;
# the caller shields those separately.
def backfill_member(org_root: any, member_root_id: str, level: str) {
    acl = acl_for_level(level);
    for child in [org_root-->] {
        if isinstance(child, Invite) or isinstance(child, GithubConnection) {
            continue;
        }
        grant_root_on(child, member_root_id, acl);
        for e in [edge child<--] {
            grant_root_on(e, member_root_id, acl);
        }
        for e in [edge child-->] {
            grant_root_on(e, member_root_id, acl);
        }
        for gchild in [child-->] {
            grant_root_on(gchild, member_root_id, acl);
            for e2 in [edge gchild-->] {
                grant_root_on(e2, member_root_id, acl);
            }
        }
    }
}


def new_invite_code -> str {
    return secrets.token_urlsafe(16);
}


def hash_invite_code(code: str) -> str {
    return hashlib.sha256(code.encode("utf-8")).hexdigest();
}
