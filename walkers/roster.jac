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
    HasRole,
    Roles,
    member_view,
    repo_view,
    role_view,
    resolve,
    on_attached,
    owned,
    valid_full_name,
    members_of,
    roles_of,
    steps_of,
    ensure_layout
}

# ------------------------------------------------------------------- roster

# Point the member at exactly these roles, by name. A name with no Role node
# yet gets one in the box: a free-text role becomes managed the moment
# someone holds it.
def link_roles(m: Member, names: list[str], rbox: Roles) {
    wanted: list[str] = [];
    for n in names {
        said = n.strip();
        if said and said not in wanted {
            wanted.append(said);
        }
    }
    for e in [edge m->:HasRole:->] {
        del e;
    }
    known: list[Role] = [rbox-->[?:Role]];
    peak = 0.0;
    for r in known {
        if r.sort_order > peak {
            peak = r.sort_order;
        }
    }
    for said in wanted {
        hit: list[Role] = [
            r
            for r in known
            if r.name == said
        ];
        if hit {
            target = hit[0];
        } else {
            peak = peak + 1024.0;
            target = rbox ++> Role(name=said, sort_order=peak);
            known.append(target);
        }
        m +>:HasRole():+> target;
    }
}


walker ListMembers {
    has reports: list[list[MemberView]] = [];

    # Rows in a local, not a `has` field, or the response carries them twice.
    can gather with Root entry {
        rows: list[MemberView] = [];
        for m in members_of(here) {
            rows.append(member_view(m));
        }
        rows.sort(key=lambda (m: MemberView) { m.name; });
        report rows;
    }
}

walker SaveMember {
    """Empty member_id creates; otherwise updates the addressed Member. The
    first name is required, the last optional. `roles` are names; each
    becomes a HasRole edge (and a Role node if new)."""
    has member_id: str = "",
        first_name: str = "",
        last_name: str = "",
        roles: list[str] = [],
        email: str = "",
        github_username: str = "",
        tags: list[str] = [],
        color: str = "",
        reports: list[MemberView] = [];

    can save with Root entry {
        first = self.first_name.strip();
        last = self.last_name.strip();
        if not first {
            disengage;
        }
        (pbox, mbox, rbox, sbox) = ensure_layout(here);
        if self.member_id {
            target = resolve(self.member_id);
            if isinstance(target, Member) and owned(here, target) {
                target.first_name = first;
                target.last_name = last;
                link_roles(target, self.roles, rbox);
                target.email = self.email;
                target.github_username = self.github_username;
                target.tags = [
                    t.strip()
                    for t in self.tags
                    if t.strip()
                ];
                target.color = self.color;
                report member_view(target);
            }
        } else {
            fresh = mbox ++> Member(
                first_name=first,
                last_name=last,
                email=self.email,
                github_username=self.github_username,
                tags=[
                    t.strip()
                    for t in self.tags
                    if t.strip()
                ],
                color=self.color
            );
            on_attached(here, fresh);
            link_roles(fresh, self.roles, rbox);
            report member_view(fresh);
        }
    }
}

walker SetMemberRoles {
    """Overwrite ONLY the member's roles. The Roles tab toggles one role at
    a time; routing that through SaveMember would overwrite email,
    github_username and tags with whatever the caller happened to send."""
    has member_id: str = "",
        roles: list[str] = [],
        reports: list[MemberView] = [];

    can set_roles with Root entry {
        target = resolve(self.member_id);
        if isinstance(target, Member) and owned(here, target) {
            (pbox, mbox, rbox, sbox) = ensure_layout(here);
            link_roles(target, self.roles, rbox);
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
# Members reach a role through HasRole, so a rename or delete reaches them
# by itself; a step's `owner` still holds the NAME and is kept in step here.
# Everything reads the caller's own root through roles_of, so isolation
# needs no owned() checks.

walker ListRoles {
    has reports: list[list[RoleView]] = [];

    can gather with Root entry {
        rows: list[RoleView] = [];
        for r in roles_of(here) {
            rows.append(role_view(r));
        }
        rows.sort(key=lambda (r: RoleView) { r.sort_order; });
        report rows;
    }
}

walker SaveRole {
    """Create or update the role named `name` (get-or-create). `new_name`
    renames; members follow through their edge, step owners are rewritten;
    renaming onto an existing role is refused. Blurb overwrite is opt-in via
    touch_blurb so assignment can't blank it."""
    has name: str = "",
        new_name: str = "",
        blurb: str = "",
        color: str = "",
        touch_blurb: bool = False,
        reports: list[dict[str, any]] = [];

    can save with Root entry {
        said = self.name.strip();
        if not said {
            disengage;
        }
        wanted = self.new_name.strip();
        roles = roles_of(here);
        if wanted and wanted != said {
            for r in roles {
                if r.name == wanted {
                    report {"ok": False, "error": "name_taken"};
                    disengage;
                }
            }
        }
        existing = [
            r
            for r in roles
            if r.name == said
        ];
        target = existing[0] if existing else None;
        if not target {
            peak = 0.0;
            for r in roles {
                if r.sort_order > peak {
                    peak = r.sort_order;
                }
            }
            (pbox, mbox, rbox, sbox) = ensure_layout(here);
            target = rbox ++> Role(name=said, sort_order=peak + 1024.0);
            on_attached(here, target);
        }
        if self.touch_blurb {
            target.blurb = self.blurb.strip();
        }
        if self.color {
            target.color = self.color;
        }
        if wanted and wanted != said {
            target.name = wanted;
            for s in steps_of(here) {
                if s.owner == said {
                    s.owner = wanted;
                }
            }
        }
        report {"ok": True, "role": role_view(target)};
    }
}

walker DeleteRole {
    """Deletes by name: the Role node (its HasRole edges go with it) and any
    flow line step owner naming it."""
    has name: str = "",
        reports: list[dict[str, any]] = [];

    can remove with Root entry {
        said = self.name.strip();
        if not said {
            disengage;
        }
        for r in roles_of(here) {
            if r.name == said {
                del r;
            }
        }
        for s in steps_of(here) {
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
    """Creates (or reuses) the repo node under root and points the given
    project at it. A project is required: the sync files every issue it
    finds under the repo's project, and a task always has one. Re-adding
    with another project moves the repo there."""
    has full_name: str,
        project_id: str = "",
        reports: list[RepoView] = [];

    can add with Root entry {
        fn = self.full_name.strip();
        # The client normalizes pasted URLs, but the walker is the endpoint
        # anyone can call, and this name later lands in an api.github.com
        # path. Reject anything that is not plainly "org/repo".
        if not fn or not valid_full_name(fn) {
            disengage;
        }
        proj = resolve(self.project_id);
        if not isinstance(proj, Project) or not owned(here, proj) or not proj.active {
            disengage;
        }
        existing = [here-->[?:Repo, full_name==fn]];
        target = existing[0] if existing else None;
        if not target {
            target = here ++> Repo(full_name=fn);
            on_attached(here, target);
        }
        if not [edge proj->:HasRepo:->target] {
            for e in [edge target<-:HasRepo:<-] {
                del e;
            }
            proj +>:HasRepo():+> target;
        }
        report repo_view(target);
    }
}

walker RemoveRepo {
    has repo_id: str;

    can remove with Root entry {
        target = resolve(self.repo_id);
        if isinstance(target, Repo) and owned(here, target) {
            gone = jid(target);
            del target;
            report {"deleted": gone};
        }
    }
}
