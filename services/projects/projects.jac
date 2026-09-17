"""Project walkers. Each visits the Projects box or the addressed project
and works there: the traversal from the caller's root is the isolation, so
only a jid-addressed row needs the owned() check."""

import from models {
    Project,
    Projects,
    Member,
    OnProject,
    resolve,
    on_attached,
    owned,
    projects_box
}
import from services.util { now_iso }

# ----------------------------------------------------------------- projects

walker ListProjects {
    has reports: list[list[Project]] = [];

    # A read never makes the box: no box, no projects.
    can start with Root entry {
        visit [here-->[?:Projects]] else {
            report [];
        }
    }

    # Rows live in a local, never a `has` field: a walker's public fields
    # are serialised into the response beside the report.
    can gather with Projects entry {
        rows = [here-->[?:Project]];
        rows.sort(key=lambda (p: Project) { p.name; });
        report rows;
    }
}

walker find_project {
    """Lookup base: resolve the jid once, verify org parentage, then visit.
    Resolution is NOT authorization."""
    has project_id: str = "";

    can locate with Root entry {
        target = resolve(self.project_id);
        if isinstance(target, Project) and owned(here, target) {
            visit [target];
        }
    }
}

walker SaveProject {
    """Empty project_id creates in the box; otherwise updates the addressed
    Project."""
    has project_id: str = "",
        name: str = "",
        description: str = "",
        reports: list[Project] = [];

    can start with Root entry {
        if not self.name.strip() {
            disengage;
        }
        if self.project_id {
            target = resolve(self.project_id);
            if isinstance(target, Project) and owned(here, target) {
                visit [target];
            }
        } else {
            visit projects_box(here);
        }
    }

    # A new project's tallies are exact at zero, so it is stamped here and
    # ensure_tallies never loads it.
    can create with Projects entry {
        fresh = here ++> Project(
            name=self.name.strip(), description=self.description, tallies_at=now_iso()
        );
        on_attached(root, fresh);
        report fresh;
    }

    can update with Project entry {
        here.name = self.name.strip();
        here.description = self.description;
        report here;
    }
}

walker ArchiveProject(find_project) {
    """active=False, tasks and history keep pointing at it."""
    can archive with Project entry {
        here.active = False;
        report {"archived": jid(here)};
        disengage;
    }
}

walker AssignToProject {
    has member_id: str,
        project_id: str;

    can start with Root entry {
        m = resolve(self.member_id);
        p = resolve(self.project_id);
        if not isinstance(m, Member) or not isinstance(p, Project) {
            disengage;
        }
        if owned(here, m) and owned(here, p) {
            visit [m];
        }
    }

    can assign with Member entry {
        p = resolve(self.project_id);
        if not isinstance(p, Project) {
            disengage;
        }
        if not [edge here->:OnProject:->p] {
            here +>:OnProject():+> p;
        }
        report {"assigned": True};
        disengage;
    }
}

walker UnassignFromProject {
    has member_id: str,
        project_id: str;

    can start with Root entry {
        m = resolve(self.member_id);
        p = resolve(self.project_id);
        if not isinstance(m, Member) or not isinstance(p, Project) {
            disengage;
        }
        if owned(here, m) and owned(here, p) {
            visit [m];
        }
    }

    can unassign with Member entry {
        p = resolve(self.project_id);
        if not isinstance(p, Project) {
            disengage;
        }
        for e in [edge here->:OnProject:->p] {
            del e;
        }
        report {"unassigned": True};
        disengage;
    }
}
