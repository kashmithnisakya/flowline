"""Implementations for the Projects page."""

impl ProjectsPage.loadProjects -> None {
    try {
        result = root spawn ListProjects();
        projects = result.reports[0] if result.reports else [];
    } except Exception as e {
        toast("Failed to load projects");
    }
    loading = False;
}

impl ProjectsPage.openCreate -> None {
    editingId = "";
    fName = "";
    fDescription = "";
    dialogOpen = True;
}

impl ProjectsPage.openEdit(p: Project) -> None {
    editingId = jid(p);
    fName = p.name;
    fDescription = p.description;
    dialogOpen = True;
}

impl ProjectsPage.saveProject -> None {
    if not fName.strip() {
        return;
    }
    saving = True;
    try {
        root spawn SaveProject(
            project_id=editingId, name=fName.strip(), description=fDescription
        );
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
