"""Project walkers: CRUD plus member assignment edges."""

import from models {
    Organization, Project, Member, OnProject, resolve, on_attached, owned
}

# ----------------------------------------------------------------- projects

walker ListProjects {
    has results: list[Project] = [],
        reports: list[list[Project]] = [];

    can start with Root entry {
        orgs = [here-->[?:Organization]];
        if orgs {
            visit [orgs[0]-->[?:Project]];
        }
    }

    can gather with Project entry {
        self.results.append(here);
    }

    can deliver with Root exit {
        self.results.sort(key=lambda (p: Project) { p.name; });
        report self.results;
    }
}

walker SaveProject {
    """Empty project_id creates; otherwise updates the addressed Project."""
    has project_id: str = "",
        name: str = "",
        description: str = "",
        reports: list[Project] = [];

    can save with Root entry {
        orgs = [here-->[?:Organization]];
        if not orgs or not self.name.strip() {
            disengage;
        }
        org = orgs[0];
        if self.project_id {
            target = resolve(self.project_id);
            if isinstance(target, Project) and owned(org, target) {
                target.name = self.name.strip();
                target.description = self.description;
                report target;
            }
        } else {
            fresh = org ++> Project(
                name=self.name.strip(), description=self.description
            );
            on_attached(org, fresh);
            report fresh;
        }
    }
}

walker ArchiveProject {
    """active=False — tasks and history keep pointing at it."""
    has project_id: str;

    can archive with Root entry {
        orgs = [here-->[?:Organization]];
        target = resolve(self.project_id);
        if orgs and isinstance(target, Project) and owned(orgs[0], target) {
            target.active = False;
            report {"archived": self.project_id};
        }
    }
}

walker AssignToProject {
    has member_id: str,
        project_id: str;

    can assign with Root entry {
        orgs = [here-->[?:Organization]];
        m = resolve(self.member_id);
        p = resolve(self.project_id);
        if not orgs or not isinstance(m, Member) or not isinstance(p, Project) {
            disengage;
        }
        if not owned(orgs[0], m) or not owned(orgs[0], p) {
            disengage;
        }
        if not [edge m ->:OnProject:-> p] {
            m +>:OnProject():+> p;
        }
        report {"assigned": True};
    }
}

walker UnassignFromProject {
    has member_id: str,
        project_id: str;

    can unassign with Root entry {
        orgs = [here-->[?:Organization]];
        m = resolve(self.member_id);
        p = resolve(self.project_id);
        if not orgs or not isinstance(m, Member) or not isinstance(p, Project) {
            disengage;
        }
        if not owned(orgs[0], m) or not owned(orgs[0], p) {
            disengage;
        }
        for e in [edge m ->:OnProject:-> p] {
            del e;
        }
        report {"unassigned": True};
    }
}

