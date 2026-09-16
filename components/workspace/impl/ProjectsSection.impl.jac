"""Implementations for the Projects section."""

impl ProjectsSection.loadProjects -> None {
    try {
        result = root spawn ListProjects();
        rResult = root spawn ListRepos();
        projects = result.reports[0] if result.reports else [];
        repos = rResult.reports[0] if rResult.reports else [];
    } except Exception as e {
        toast.error("Could not load projects");
    }
    loading = False;
    await loadCounts();
}

impl ProjectsSection.loadCounts -> None {
    # Open work per project, counted server-side over the whole history: the
    # rows need a number, not the tasks.
    try {
        result = root spawn TaskCounts();
        totals: TaskTotals | None = result.reports[0] if result.reports else None;
        if totals {
            tallies: dict[str, int] = {};
            for t in totals.projects {
                tallies[t.project_id] = t.total - t.done;
            }
            openCounts = tallies;
            countsReady = True;
        }
    } except Exception as e {
        countsReady = False;
    }
}

impl ProjectsSection.openCreate -> None {
    editingId = "";
    fName = "";
    fDescription = "";
    fRepoDraft = "";
    dialogOpen = True;
}

impl ProjectsSection.openEdit(p: Project) -> None {
    editingId = jid(p);
    fName = p.name;
    fDescription = p.description;
    fRepoDraft = "";
    dialogOpen = True;
}

impl ProjectsSection.askArchive(p: Project) -> None {
    archiveId = jid(p);
    archiveName = p.name;
}

impl ProjectsSection.saveProject -> None {
    if not fName.strip() {
        return;
    }
    saving = True;
    try {
        result = root spawn SaveProject(
            project_id=editingId, name=fName.strip(), description=fDescription
        );
        saved = result.reports[0] if result.reports else None;
        draft = normalizeRepoInput(fRepoDraft);
        if saved and fRepoDraft.strip() {
            if draft {
                root spawn AddRepo(full_name=draft, project_id=jid(saved));
            } else {
                toast.error("That did not look like a GitHub repository");
            }
        }
        fRepoDraft = "";
        dialogOpen = False;
        await loadProjects();
        if onChanged {
            onChanged();
        }
    } except Exception as e {
        toast.error("Could not save that project");
    }
    saving = False;
}

impl ProjectsSection.archiveProject -> None {
    target = archiveId;
    if not target or busy {
        return;
    }
    busy = True;
    try {
        root spawn ArchiveProject(project_id=target);
        archiveId = "";
        await loadProjects();
        if onChanged {
            onChanged();
        }
        toast.success("Project archived");
    } except Exception as e {
        toast.error("Could not archive that project");
    }
    busy = False;
}


impl ProjectsSection.removeRepo(repoId: str) -> None {
    try {
        root spawn RemoveRepo(repo_id=repoId);
        await loadProjects();
    } except Exception as e {
        toast.error("Could not remove that repository");
    }
}
