"""Implementations for the Projects section."""

impl ProjectsSection.refresh -> None {
    # After a write here: drop the cached view and let the page reload its
    # lists, so the section and the page never disagree.
    forgetWorkspace();
    if onChanged {
        await onChanged();
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
        await refresh();
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
        await refresh();
        toast.success("Project archived");
    } except Exception as e {
        toast.error("Could not archive that project");
    }
    busy = False;
}


impl ProjectsSection.removeRepo(repoId: str) -> None {
    try {
        root spawn RemoveRepo(repo_id=repoId);
        await refresh();
    } except Exception as e {
        toast.error("Could not remove that repository");
    }
}
