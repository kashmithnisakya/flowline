"""Organization membership: invites, the join handshake, levels.

The handshake works within two runtime rules: only the account that owns the
org root can grant or revoke keys on it, and before any grant the two sides
share no reachable graph except the deployment's shared root. So a manager
mints an Invite (org graph), the invitee parks a JoinRequest on root.shared
addressed to the org root, and the owner's ApproveJoin consumes both and
stamps the key. `root` inside every walker is the CALLER's root even when
the walker entered a foreign org root, so jid(root) is caller identity."""

import from models {
    Member,
    Invite,
    JoinRequest,
    Membership,
    OrgMeta,
    GithubConnection,
    MemberView,
    member_view,
    resolve
}
import from constants { ORG_LEVELS }
import from walkers.util {
    now_iso,
    minutes_since,
    caller_level,
    level_rank,
    acl_for_level,
    grant_root_on,
    revoke_root_on,
    shield_node,
    attach_stamp,
    backfill_member,
    new_invite_code,
    hash_invite_code
}

glob INVITE_EXPIRY_MINUTES: float = 14.0 * 24.0 * 60.0;


def invite_status(inv: Invite) -> str {
    if inv.status == "pending"
        and minutes_since(inv.created_at) > INVITE_EXPIRY_MINUTES {
        return "expired";
    }
    return inv.status;
}


def invite_row(inv: Invite) -> dict[str, any] {
    return {
        "id": jid(inv),
        "email": inv.email,
        "level": inv.level,
        "member_id": inv.member_id,
        "created_at": inv.created_at,
        "status": invite_status(inv)
    };
}


# The org meta mirror, created on first need. Callable only with the org
# root in hand, so no ownership re-check here.
def ensure_meta(org_root: Root) -> OrgMeta {
    existing = [org_root-->[?:OrgMeta]];
    if existing {
        return existing[0];
    }
    fresh = org_root ++> OrgMeta();
    return fresh;
}


walker EnsureOrgMeta {
    """Owner mirrors their profile's org name into the graph so members can
    read it. Lazy: the layout calls this once per owner session."""
    has name: str = "",
        reports: list[dict[str, any]] = [];

    can seed with Root entry {
        if caller_level(here, jid(root)) != "owner" {
            report {"ok": False, "error": "forbidden"};
            disengage;
        }
        meta = ensure_meta(here);
        if self.name.strip() {
            meta.name = self.name.strip();
        }
        report {"ok": True, "name": meta.name};
    }
}


walker GetOrgContext {
    """Who am I on this board? Level, identity and the org name, for the
    chrome and for client-side gating. Reads only."""
    has reports: list[dict[str, any]] = [];

    can gather with Root entry {
        lvl = caller_level(here, jid(root));
        if not lvl {
            report {"ok": False, "error": "forbidden"};
            disengage;
        }
        metas = [here-->[?:OrgMeta]];
        org_name = metas[0].name if metas else "";
        member_id = "";
        member_name = "";
        for m in [here-->[?:Member]] {
            if m.account_root_id == jid(root) {
                member_id = jid(m);
                member_name = m.name;
            }
        }
        report {
            "ok": True,
            "level": lvl,
            "is_owner": lvl == "owner",
            "org_name": org_name,
            "org_root_id": jid(here),
            "member_id": member_id,
            "member_name": member_name
        };
    }
}


walker CreateInvite {
    """Mint an invite at a level, optionally pinned to an email and linked
    to an existing roster Member. The code is reported exactly once; only
    its hash persists. Manager and up."""
    has email: str = "",
        level: str = "editor",
        member_id: str = "",
        reports: list[dict[str, any]] = [];

    can mint with Root entry {
        if level_rank(caller_level(here, jid(root))) < 3 {
            report {"ok": False, "error": "forbidden"};
            disengage;
        }
        if self.level not in ORG_LEVELS {
            report {"ok": False, "error": "bad_level"};
            disengage;
        }
        if self.member_id {
            target = resolve(self.member_id);
            linked_ok = False;
            if isinstance(target, Member) {
                for parent in [target<--] {
                    if jid(parent) == jid(here) {
                        linked_ok = True;
                    }
                }
            }
            if not linked_ok {
                report {"ok": False, "error": "bad_member"};
                disengage;
            }
            # One live invite per roster row: minting again revokes the old.
            for inv in [here-->[?:Invite]] {
                if inv.member_id == self.member_id and inv.status == "pending" {
                    inv.status = "revoked";
                }
            }
        }
        code = new_invite_code();
        fresh = here ++> Invite(
            code_hash=hash_invite_code(code),
            email=self.email.strip().lower(),
            level=self.level,
            member_id=self.member_id,
            created_at=now_iso()
        );
        shield_node(here, fresh, 3);
        report {"ok": True, "code": code, "invite": invite_row(fresh)};
    }
}


walker ListInvites {
    """Pending/expired invites plus the join requests parked on the shared
    root that match one of them. Manager and up; reads only."""
    has reports: list[dict[str, any]] = [];

    can gather with Root entry {
        if level_rank(caller_level(here, jid(root))) < 3 {
            report {"ok": False, "error": "forbidden"};
            disengage;
        }
        invites: list[dict[str, any]] = [];
        by_hash: dict[str, Invite] = {};
        for inv in [here-->[?:Invite]] {
            if invite_status(inv) in ["pending", "expired"] {
                invites.append(invite_row(inv));
            }
            by_hash[inv.code_hash] = inv;
        }
        claims: list[dict[str, any]] = [];
        s = root.shared;
        for r in [s-->[?:JoinRequest]] {
            if r.org_root_id != jid(here) {
                continue;
            }
            inv = by_hash.get(hash_invite_code(r.code));
            if not inv or invite_status(inv) != "pending" {
                continue;
            }
            if inv.email and inv.email != r.email.strip().lower() {
                continue;
            }
            claims.append(
                {
                    "request_id": jid(r),
                    "name": r.name,
                    "email": r.email,
                    "level": inv.level,
                    "invite_id": jid(inv)
                }
            );
        }
        report {"ok": True, "invites": invites, "claims": claims};
    }
}


walker RevokeInvite {
    has invite_id: str = "",
        reports: list[dict[str, any]] = [];

    can revoke with Root entry {
        if level_rank(caller_level(here, jid(root))) < 3 {
            report {"ok": False, "error": "forbidden"};
            disengage;
        }
        target = resolve(self.invite_id);
        if isinstance(target, Invite) {
            for parent in [target<--] {
                if jid(parent) == jid(here) {
                    target.status = "revoked";
                    report {"ok": True};
                    disengage;
                }
            }
        }
        report {"ok": False, "error": "not_found"};
    }
}


walker RequestJoin {
    """The invitee's half of the handshake, run on their OWN root: park a
    claim on the shared root, readable by the addressed org. The code is
    not validated here (nothing org-side is reachable yet); ApproveJoin
    proves it."""
    has org_root_id: str = "",
        code: str = "",
        name: str = "",
        email: str = "",
        reports: list[dict[str, any]] = [];

    can request with Root entry {
        if not self.org_root_id or not self.code {
            report {"ok": False, "error": "bad_request"};
            disengage;
        }
        s = root.shared;
        for r in [s-->[?:JoinRequest]] {
            if r.claimant_root_id == jid(root) and r.org_root_id == self.org_root_id {
                r.code = self.code;
                r.name = self.name.strip();
                r.email = self.email.strip().lower();
                report {"ok": True, "request_id": jid(r)};
                disengage;
            }
        }
        fresh = s ++> JoinRequest(
            org_root_id=self.org_root_id,
            code=self.code,
            claimant_root_id=jid(root),
            name=self.name.strip(),
            email=self.email.strip().lower()
        );
        grant_root_on(fresh, self.org_root_id, "READ");
        for e in [edge fresh<--] {
            grant_root_on(e, self.org_root_id, "READ");
        }
        report {"ok": True, "request_id": jid(fresh)};
    }
}


walker ApproveJoin {
    """The owner's half: prove the claim against a live invite, stamp the
    key on the org root, and marry the claim to a roster Member. Owner
    only: the runtime accepts grants on this root from no one else."""
    has request_id: str = "",
        org_name: str = "",
        reports: list[dict[str, any]] = [];

    can approve with Root entry {
        if caller_level(here, jid(root)) != "owner" {
            report {"ok": False, "error": "owner_only"};
            disengage;
        }
        r = resolve(self.request_id);
        if not isinstance(r, JoinRequest) or r.org_root_id != jid(here) {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        matched: any = None;
        wanted = hash_invite_code(r.code);
        for inv in [here-->[?:Invite]] {
            if inv.code_hash == wanted and invite_status(inv) == "pending" {
                matched = inv;
            }
        }
        if not matched {
            report {"ok": False, "error": "invalid_invite"};
            disengage;
        }
        if matched.email and matched.email != r.email.strip().lower() {
            report {"ok": False, "error": "email_mismatch"};
            disengage;
        }
        member: any = None;
        if matched.member_id {
            candidate = resolve(matched.member_id);
            if isinstance(candidate, Member) {
                for parent in [candidate<--] {
                    if jid(parent) == jid(here) {
                        member = candidate;
                    }
                }
            }
        }
        if not member {
            said = r.name or r.email.split("@")[0] or "New member";
            member = here ++> Member(name=said, email=r.email);
            attach_stamp(here, member);
        }
        member.account_root_id = r.claimant_root_id;
        member.level = matched.level;
        if not member.email and r.email {
            member.email = r.email;
        }
        grant_root_on(here, r.claimant_root_id, acl_for_level(matched.level));
        # The root cascade covers owner-created nodes only: stamp the new
        # key across what other members created before this one arrived.
        backfill_member(here, r.claimant_root_id, matched.level);
        # The new key must not open the sensitive nodes: the GitHub
        # connection stays manager/editor territory, invites manager-only.
        if level_rank(matched.level) < 2 {
            for g in [here-->[?:GithubConnection]] {
                grant_root_on(g, r.claimant_root_id, "NO_ACCESS");
            }
        }
        if level_rank(matched.level) < 3 {
            for inv in [here-->[?:Invite]] {
                grant_root_on(inv, r.claimant_root_id, "NO_ACCESS");
            }
        }
        matched.status = "done";
        if self.org_name.strip() {
            meta = ensure_meta(here);
            if not meta.name {
                meta.name = self.org_name.strip();
            }
        }
        report {"ok": True, "member": member_view(member)};
    }
}


walker CheckJoin {
    """Polled by the waiting invitee on their OWN root. Once the org root
    resolves (the grant landed), record the Membership locally and clean
    the claim off the shared root."""
    has org_root_id: str = "",
        reports: list[dict[str, any]] = [];

    can check with Root entry {
        org = resolve(self.org_root_id);
        if not org {
            report {"ok": True, "status": "waiting"};
            disengage;
        }
        member_jid = "";
        my_level = "";
        for m in [org-->[?:Member]] {
            if m.account_root_id == jid(root) {
                member_jid = jid(m);
                my_level = m.level;
            }
        }
        if not member_jid {
            report {"ok": True, "status": "waiting"};
            disengage;
        }
        metas = [org-->[?:OrgMeta]];
        org_name = metas[0].name if metas else "";
        rows = [here-->[?:Membership]];
        mine: any = None;
        for ms in rows {
            if ms.org_root_id == self.org_root_id {
                mine = ms;
            }
        }
        if not mine {
            mine = here ++> Membership(org_root_id=self.org_root_id);
        }
        mine.org_name = org_name;
        mine.member_jid = member_jid;
        mine.level = my_level;
        s = root.shared;
        for r in [s-->[?:JoinRequest]] {
            if r.claimant_root_id == jid(root) and r.org_root_id == self.org_root_id {
                del r;
            }
        }
        report {
            "ok": True,
            "status": "member",
            "org_root_id": self.org_root_id,
            "org_name": org_name,
            "level": my_level
        };
    }
}


walker ListMyMemberships {
    """The orgs this account has joined, from its own root. Login routing
    and the space switcher read this; it never touches an org graph."""
    has reports: list[dict[str, any]] = [];

    can gather with Root entry {
        rows: list[dict[str, any]] = [];
        for ms in [here-->[?:Membership]] {
            rows.append(
                {
                    "org_root_id": ms.org_root_id,
                    "org_name": ms.org_name,
                    "member_jid": ms.member_jid,
                    "level": ms.level
                }
            );
        }
        report {"ok": True, "rows": rows};
    }
}


walker SetMemberLevel {
    """Change a linked member's level. Owner only: the level maps to an ACL
    key on the org root, and the runtime accepts that write from no other
    account. Re-shields or un-shields the sensitive nodes to match."""
    has member_id: str = "",
        level: str = "",
        reports: list[dict[str, any]] = [];

    can set_level with Root entry {
        if caller_level(here, jid(root)) != "owner" {
            report {"ok": False, "error": "owner_only"};
            disengage;
        }
        if self.level not in ORG_LEVELS {
            report {"ok": False, "error": "bad_level"};
            disengage;
        }
        target = resolve(self.member_id);
        if not isinstance(target, Member) or not target.account_root_id {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        ok = False;
        for parent in [target<--] {
            if jid(parent) == jid(here) {
                ok = True;
            }
        }
        if not ok {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        target.level = self.level;
        rid = target.account_root_id;
        grant_root_on(here, rid, acl_for_level(self.level));
        # Overwrite every per-node stamp too: an absolute per-node entry
        # from attach_stamp would otherwise beat the new root-level key.
        backfill_member(here, rid, self.level);
        for g in [here-->[?:GithubConnection]] {
            if level_rank(self.level) < 2 {
                grant_root_on(g, rid, "NO_ACCESS");
            } else {
                revoke_root_on(g, rid);
            }
        }
        for inv in [here-->[?:Invite]] {
            if level_rank(self.level) < 3 {
                grant_root_on(inv, rid, "NO_ACCESS");
            } else {
                revoke_root_on(inv, rid);
            }
        }
        report {"ok": True, "member": member_view(target)};
    }
}


walker RemoveMember {
    """Take a member's key back. Their roster row, tasks and log history
    stay; the row flips back to roster-only. Owner only."""
    has member_id: str = "",
        reports: list[dict[str, any]] = [];

    can remove with Root entry {
        if caller_level(here, jid(root)) != "owner" {
            report {"ok": False, "error": "owner_only"};
            disengage;
        }
        target = resolve(self.member_id);
        if not isinstance(target, Member) or not target.account_root_id {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        ok = False;
        for parent in [target<--] {
            if jid(parent) == jid(here) {
                ok = True;
            }
        }
        if not ok {
            report {"ok": False, "error": "not_found"};
            disengage;
        }
        revoke_root_on(here, target.account_root_id);
        target.account_root_id = "";
        target.level = "";
        for inv in [here-->[?:Invite]] {
            if inv.member_id == self.member_id and inv.status == "pending" {
                inv.status = "revoked";
            }
        }
        report {"ok": True, "member": member_view(target)};
    }
}
