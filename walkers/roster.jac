"""Roster walkers: members and GitHub repos."""

import from models {
    Project,
    Member,
    Repo,
    Task,
    Role,
    WorkflowStep,
    MemberView,
    RepoView,
    RoleView,
    AssignedTo,
    HasRepo,
    member_view,
    repo_view,
    role_view,
    resolve,
    owned,
    valid_full_name
}
import from walkers.util { caller_level, level_rank, attach_stamp }

# ------------------------------------------------------------------- roster

walker ListMembers {
    has reports: list[list[MemberView]] = [];

    # Rows in a local, not a `has` field, or the response carries them twice.
    can gather with Root entry {
        rows: list[MemberView] = [];
        for m in [here-->[?:Member]] {
            rows.append(member_view(m));
        }
        rows.sort(key=lambda (m: MemberView) { m.name; });
        report rows;
    }
}

walker SaveMember {
    """Empty member_id creates; otherwise updates the addressed Member."""
    has member_id: str = "",
        name: str = "",
        roles: list[str] = [],
        email: str = "",
        github_username: str = "",
        tags: list[str] = [],
        reports: list[MemberView] = [];

    can save with Root entry {
        # Members below manager cannot touch the roster; silent no-op like
        # every other unauthorized mutation.
        if level_rank(caller_level(here, jid(root))) < 3 {
            disengage;
        }
        if not self.name.strip() {
            disengage;
        }
        if self.member_id {
            target = resolve(self.member_id);
            if isinstance(target, Member) and owned(here, target) {
                target.name = self.name.strip();
                target.roles = [
                    r.strip()
                    for r in self.roles
                    if r.strip()
                ];
                target.email = self.email;
                target.github_username = self.github_username;
                target.tags = [
                    t.strip()
                    for t in self.tags
                    if t.strip()
                ];
                report member_view(target);
            }
        } else {
            fresh = here ++> Member(
                name=self.name.strip(),
                roles=[
                    r.strip()
                    for r in self.roles
                    if r.strip()
                ],
                email=self.email,
                github_username=self.github_username,
                tags=[
                    t.strip()
                    for t in self.tags
                    if t.strip()
                ]
            );
            attach_stamp(here, fresh);
            report member_view(fresh);
        }
    }
}

walker SetMemberRoles {
    """Overwrite ONLY the member's role list. The Roles tab toggles one
    role at a time; routing that through SaveMember would overwrite email,
    github_username and tags with whatever the caller happened to send."""
    has member_id: str = "",
        roles: list[str] = [],
        reports: list[MemberView] = [];

    can set_roles with Root entry {
        # Manager gate (see SaveMember).
        if level_rank(caller_level(here, jid(root))) < 3 {
            disengage;
        }
        target = resolve(self.member_id);
        if isinstance(target, Member) and owned(here, target) {
            target.roles = [
                r.strip()
                for r in self.roles
                if r.strip()
            ];
            report member_view(target);
        }
    }
}

walker ArchiveMember {
    """active=False, never delete, history edges must survive. Open
    (non-Done) tasks lose their AssignedTo edge so live work returns to
    Unassigned; Done-task edges stay for history."""
    has member_id: str;

    can archive with Root entry {
        # Manager gate (see SaveMember).
        if level_rank(caller_level(here, jid(root))) < 3 {
            disengage;
        }
        target = resolve(self.member_id);
        if isinstance(target, Member) and owned(here, target) {
            target.active = False;
            # Filter to Task explicitly: the reverse read also surfaces the
            # Organization's generic parent edge, which has no `status`.
            for t in [target<-:AssignedTo:<-[?:Task]] {
                if t.status != "Done" {
                    for e in [edge t->:AssignedTo:->] {
                        del e;
                    }
                }
            }
            report {"archived": self.member_id};
        }
    }
}

# -------------------------------------------------------------------- roles
# Name-centric, not jid-centric: member.roles and step owners hold role NAMES,
# so the name is the identity to keep consistent. Everything runs on
# [here-->] under the caller's root, so isolation needs no owned() checks.

walker ListRoles {
    has reports: list[list[RoleView]] = [];

    can gather with Root entry {
        rows: list[RoleView] = [];
        for r in [here-->[?:Role]] {
            rows.append(role_view(r));
        }
        rows.sort(key=lambda (r: RoleView) { r.sort_order; });
        report rows;
    }
}

walker SaveRole {
    """Create or update the role named `name` (get-or-create, so a free-text
    role becomes managed on first edit). `new_name` renames and propagates
    through members and step owners; renaming onto an existing role is refused.
    Blurb overwrite is opt-in via touch_blurb so assignment can't blank it."""
    has name: str = "",
        new_name: str = "",
        blurb: str = "",
        color: str = "",
        touch_blurb: bool = False,
        reports: list[dict[str, any]] = [];

    can save with Root entry {
        # Manager gate (see SaveMember).
        if level_rank(caller_level(here, jid(root))) < 3 {
            disengage;
        }
        said = self.name.strip();
        if not said {
            disengage;
        }
        wanted = self.new_name.strip();
        if wanted and wanted != said {
            if [here-->[?:Role, name==wanted]] {
                report {"ok": False, "error": "name_taken"};
                disengage;
            }
        }
        existing = [here-->[?:Role, name==said]];
        target = existing[0] if existing else None;
        if not target {
            peak = 0.0;
            for r in [here-->[?:Role]] {
                if r.sort_order > peak {
                    peak = r.sort_order;
                }
            }
            target = here ++> Role(name=said, sort_order=peak + 1024.0);
            attach_stamp(here, target);
        }
        if self.touch_blurb {
            target.blurb = self.blurb.strip();
        }
        if self.color {
            target.color = self.color;
        }
        if wanted and wanted != said {
            target.name = wanted;
            for m in [here-->[?:Member]] {
                if said in m.roles {
                    m.roles = [(wanted if r == said else r) for r in m.roles];
                }
            }
            for s in [here-->[?:WorkflowStep]] {
                if s.owner == said {
                    s.owner = wanted;
                }
            }
        }
        report {"ok": True, "role": role_view(target)};
    }
}

walker DeleteRole {
    """Deletes by name: the Role node if one exists, the name out of every
    member's role list, and any flow line step owner naming it. Works on
    unmanaged free-text roles too, where it is just the strip."""
    has name: str = "",
        reports: list[dict[str, any]] = [];

    can remove with Root entry {
        # Manager gate (see SaveMember).
        if level_rank(caller_level(here, jid(root))) < 3 {
            disengage;
        }
        said = self.name.strip();
        if not said {
            disengage;
        }
        for r in [here-->[?:Role, name==said]] {
            del r;
        }
        for m in [here-->[?:Member]] {
            if said in m.roles {
                m.roles = [
                    x
                    for x in m.roles
                    if x != said
                ];
            }
        }
        for s in [here-->[?:WorkflowStep]] {
            if s.owner == said {
                s.owner = "";
            }
        }
        report {"ok": True, "deleted": said};
    }
}

walker ListRepos {
    has reports: list[list[RepoView]] = [];

    can gather with Root entry {
        rows: list[RepoView] = [];
        for r in [here-->[?:Repo]] {
            rows.append(repo_view(r));
        }
        rows.sort(key=lambda (r: RepoView) { r.full_name; });
        report rows;
    }
}

walker AddRepo {
    """Creates (or reuses) the repo node under root and, when project_id
    resolves to an owned project, points that project at it."""
    has full_name: str,
        project_id: str = "",
        reports: list[RepoView] = [];

    can add with Root entry {
        # Manager gate (see SaveMember).
        if level_rank(caller_level(here, jid(root))) < 3 {
            disengage;
        }
        fn = self.full_name.strip();
        # The client normalizes pasted URLs, but the walker is the endpoint
        # anyone can call, and this name later lands in an api.github.com
        # path. Reject anything that is not plainly "org/repo".
        if not fn or not valid_full_name(fn) {
            disengage;
        }
        existing = [here-->[?:Repo, full_name==fn]];
        target = existing[0] if existing else None;
        if not target {
            target = here ++> Repo(full_name=fn);
            attach_stamp(here, target);
        }
        if self.project_id {
            proj = resolve(self.project_id);
            if isinstance(proj, Project) and owned(here, proj) {
                if not [edge proj->:HasRepo:->target] {
                    proj +>:HasRepo():+> target;
                    # Re-stamp: the HasRepo edge postdates the node stamp.
                    attach_stamp(here, target);
                }
            }
        }
        report repo_view(target);
    }
}

walker RemoveRepo {
    has repo_id: str;

    can remove with Root entry {
        # Manager gate (see SaveMember).
        if level_rank(caller_level(here, jid(root))) < 3 {
            disengage;
        }
        target = resolve(self.repo_id);
        if isinstance(target, Repo) and owned(here, target) {
            gone = jid(target);
            del target;
            report {"deleted": gone};
        }
    }
}
