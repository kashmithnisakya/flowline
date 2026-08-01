"""Roster walkers: members and GitHub repos."""

import from models {
    Organization, Project, Member, Repo, Task, MemberView, AssignedTo,
    member_view, resolve, on_attached, owned
}

# ------------------------------------------------------------------- roster

walker ListMembers {
    has results: list[MemberView] = [],
        reports: list[list[MemberView]] = [];

    can start with Root entry {
        orgs = [here-->[?:Organization]];
        if orgs {
            visit [orgs[0]-->[?:Member]];
        }
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
        role: str = "",
        email: str = "",
        github_username: str = "",
        section: str = "",
        reports: list[MemberView] = [];

    can save with Root entry {
        orgs = [here-->[?:Organization]];
        if not orgs or not self.name.strip() {
            disengage;
        }
        org = orgs[0];
        if self.member_id {
            target = resolve(self.member_id);
            if isinstance(target, Member) and owned(org, target) {
                target.name = self.name.strip();
                target.role = self.role;
                target.email = self.email;
                target.github_username = self.github_username;
                target.section = self.section;
                report member_view(target);
            }
        } else {
            fresh = org ++> Member(
                name=self.name.strip(), role=self.role, email=self.email,
                github_username=self.github_username, section=self.section
            );
            on_attached(org, fresh);
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
        orgs = [here-->[?:Organization]];
        target = resolve(self.member_id);
        if orgs and isinstance(target, Member) and owned(orgs[0], target) {
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
    has results: list[Repo] = [],
        reports: list[list[Repo]] = [];

    can start with Root entry {
        orgs = [here-->[?:Organization]];
        if orgs {
            visit [orgs[0]-->[?:Repo]];
        }
    }

    can gather with Repo entry {
        self.results.append(here);
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (r: Repo) { r.full_name; });
        report self.results;
    }
}

walker AddRepo {
    has full_name: str,
        reports: list[Repo] = [];

    can add with Root entry {
        orgs = [here-->[?:Organization]];
        if not orgs or not self.full_name.strip() {
            disengage;
        }
        org = orgs[0];
        fn = self.full_name.strip();
        existing = [org-->[?:Repo, full_name == fn]];
        if existing {
            report existing[0];
        } else {
            fresh = org ++> Repo(full_name=fn);
            on_attached(org, fresh);
            report fresh;
        }
    }
}

walker RemoveRepo {
    has repo_id: str;

    can remove with Root entry {
        orgs = [here-->[?:Organization]];
        target = resolve(self.repo_id);
        if orgs and isinstance(target, Repo) and owned(orgs[0], target) {
            gone = jid(target);
            del target;
            report {"deleted": gone};
        }
    }
}

