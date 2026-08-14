"""Roster walkers: members and GitHub repos."""

import from models {
    Project, Member, Repo, Task, Role, WorkflowStep, MemberView, RepoView,
    RoleView, AssignedTo, HasRepo, member_view, repo_view, role_view,
    resolve, on_attached, owned, valid_full_name
}

# ------------------------------------------------------------------- roster

walker ListMembers {
    has results: list[MemberView] = [],
        reports: list[list[MemberView]] = [];

    can start with Root entry {
        visit [here-->[?:Member]];
    }

    can gather with Member entry {
        self.results.append(member_view(here));
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (m: MemberView) { m.name; });
        report self.results;
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
        if not self.name.strip() {
            disengage;
        }
        if self.member_id {
            target = resolve(self.member_id);
            if isinstance(target, Member) and owned(here, target) {
                target.name = self.name.strip();
                target.roles = [r.strip() for r in self.roles if r.strip()];
                target.email = self.email;
                target.github_username = self.github_username;
                target.tags = [t.strip() for t in self.tags if t.strip()];
                report member_view(target);
            }
        } else {
            fresh = here ++> Member(
                name=self.name.strip(),
                roles=[r.strip() for r in self.roles if r.strip()],
                email=self.email, github_username=self.github_username,
                tags=[t.strip() for t in self.tags if t.strip()]
            );
            on_attached(here, fresh);
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
        target = resolve(self.member_id);
        if isinstance(target, Member) and owned(here, target) {
            target.roles = [r.strip() for r in self.roles if r.strip()];
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
                    for e in [edge t ->:AssignedTo:->] {
                        del e;
                    }
                }
            }
            report {"archived": self.member_id};
        }
    }
}

# -------------------------------------------------------------------- roles
# Role walkers are name-centric, not jid-centric: member.roles and each
# workflow step's `owner` hold role NAMES, so the name is the identity that
# has to be kept consistent. Everything runs on [here-->] under the caller's
# own root, so structural isolation covers them without owned() checks.

walker ListRoles {
    has results: list[RoleView] = [],
        reports: list[list[RoleView]] = [];

    can start with Root entry {
        visit [here-->[?:Role]];
    }

    can gather with Role entry {
        self.results.append(role_view(here));
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (r: RoleView) { r.sort_order; });
        report self.results;
    }
}

walker SaveRole {
    """Create or update the role addressed by `name`, get-or-created so a
    free-text role becomes managed on its first edit. A non-empty `new_name`
    renames and propagates through every member's role list and every
    workflow step's owner. Renaming onto an existing role is refused rather
    than silently merging two roles. Blurb overwrite is opt-in via
    touch_blurb so assignment-only callers cannot blank it."""
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
        if wanted and wanted != said {
            if [here-->[?:Role, name == wanted]] {
                report {"ok": False, "error": "name_taken"};
                disengage;
            }
        }
        existing = [here-->[?:Role, name == said]];
        target = existing[0] if existing else None;
        if not target {
            peak = 0.0;
            for r in [here-->[?:Role]] {
                if r.sort_order > peak {
                    peak = r.sort_order;
                }
            }
            target = here ++> Role(name=said, sort_order=peak + 1024.0);
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
            for m in [here-->[?:Member]] {
                if said in m.roles {
                    m.roles = [
                        (wanted if r == said else r)
                        for r in m.roles
                    ];
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
    member's role list, and any workflow step owner naming it. Works on
    unmanaged free-text roles too, where it is just the strip."""
    has name: str = "",
        reports: list[dict[str, any]] = [];

    can remove with Root entry {
        said = self.name.strip();
        if not said {
            disengage;
        }
        for r in [here-->[?:Role, name == said]] {
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
    has results: list[RepoView] = [],
        reports: list[list[RepoView]] = [];

    can start with Root entry {
        visit [here-->[?:Repo]];
    }

    can gather with Repo entry {
        self.results.append(repo_view(here));
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (r: RepoView) { r.full_name; });
        report self.results;
    }
}

walker AddRepo {
    """Creates (or reuses) the repo node under root and, when project_id
    resolves to an owned project, points that project at it."""
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
        existing = [here-->[?:Repo, full_name == fn]];
        target = existing[0] if existing else None;
        if not target {
            target = here ++> Repo(full_name=fn);
            on_attached(here, target);
        }
        if self.project_id {
            proj = resolve(self.project_id);
            if isinstance(proj, Project) and owned(here, proj) {
                if not [edge proj ->:HasRepo:-> target] {
                    proj +>:HasRepo():+> target;
                }
            }
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

