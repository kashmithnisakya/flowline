"""Roster walkers: members and GitHub repos."""

import from models {
    Project, Member, Repo, Task, MemberView, RepoView, AssignedTo, HasRepo,
    member_view, repo_view, resolve, on_attached, owned
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

walker ArchiveMember {
    """active=False, never delete — history edges must survive. Open
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
        if not self.full_name.strip() {
            disengage;
        }
        fn = self.full_name.strip();
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

