"""Implementations for the Projects page."""

impl ProjectsPage.loadProjects -> None {
    try {
        result = root spawn ListProjects();
        rResult = root spawn ListRepos();
        projects = result.reports[0] if result.reports else [];
        repos = rResult.reports[0] if rResult.reports else [];
    } except Exception as e {
        toast("Failed to load projects");
    }
    loading = False;
}

impl ProjectsPage.openCreate -> None {
    editingId = "";
    fName = "";
    fDescription = "";
    fRepoDraft = "";
    dialogOpen = True;
}

impl ProjectsPage.openEdit(p: Project) -> None {
    editingId = jid(p);
    fName = p.name;
    fDescription = p.description;
    fRepoDraft = "";
    dialogOpen = True;
}

impl ProjectsPage.saveProject -> None {
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
                toast("Saved, but the repo link did not look like a GitHub repo.");
            }
        }
        fRepoDraft = "";
        dialogOpen = False;
        await loadProjects();
    } except Exception as e {
        toast("Failed to save project");
    }
    saving = False;
}

impl ProjectsPage.archiveProject(projectId: str) -> None {
    try {
        root spawn ArchiveProject(project_id=projectId);
        await loadProjects();
    } except Exception as e {
        toast("Failed to archive project");
    }
}


impl ProjectsPage.removeRepo(repoId: str) -> None {
    try {
        root spawn RemoveRepo(repo_id=repoId);
        await loadProjects();
    } except Exception as e {
        toast("Failed to remove repo");
    }
}
