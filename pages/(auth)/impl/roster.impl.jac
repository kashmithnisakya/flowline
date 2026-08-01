"""Implementations for the People page."""

impl RosterPage.loadAll -> None {
    try {
        mResult = root spawn ListMembers();
        pResult = root spawn ListProjects();
        rResult = root spawn ListRepos();
        members = mResult.reports[0] if mResult.reports else [];
        projects = pResult.reports[0] if pResult.reports else [];
        repos = rResult.reports[0] if rResult.reports else [];
    } except Exception as e {
        toast("Failed to load people");
    }
    loading = False;
}

impl RosterPage.setField(key: str, value: str) -> None {
    # NOTE: `{**form, key: value}` compiles to a JS object literal with a
    # LITERAL "key" property — the variable is ignored and the real field
    # never updates (inputs appear frozen). Build a copy and subscript it.
    updated = {**form};
    updated[key] = value;
    form = updated;
}

impl RosterPage.openCreate -> None {
    editingId = "";
    form = BLANK_MEMBER;
    dialogOpen = True;
}

impl RosterPage.openEdit(m: MemberView) -> None {
    editingId = m.id;
    form = {
        "name": m.name, "role": m.role, "email": m.email,
        "github": m.github_username, "section": m.section
    };
    dialogOpen = True;
}

impl RosterPage.saveMember -> None {
    name = form["name"].strip();
    if not name {
        return;
    }
    saving = True;
    try {
        root spawn SaveMember(
            member_id=editingId, name=name, role=form["role"].strip(),
            email=form["email"].strip(), github_username=form["github"].strip(),
            section=form["section"]
        );
        dialogOpen = False;
        await loadAll();
    } except Exception as e {
        toast("Failed to save member");
    }
    saving = False;
}

impl RosterPage.archiveMember(memberId: str) -> None {
    try {
        root spawn ArchiveMember(member_id=memberId);
        await loadAll();
    } except Exception as e {
        toast("Failed to archive member");
    }
}

impl RosterPage.assignTo(memberId: str, projectId: str) -> None {
    if not projectId {
        return;
    }
    try {
        root spawn AssignToProject(member_id=memberId, project_id=projectId);
        await loadAll();
    } except Exception as e {
        toast("Failed to assign");
    }
}

impl RosterPage.unassignFrom(memberId: str, projectName: str) -> None {
    # The badge carries the project NAME; resolve it to a jid via the
    # loaded projects list.
    target = "";
    for p in projects {
        if p.name == projectName {
            target = jid(p);
        }
    }
    if not target {
        return;
    }
    try {
        root spawn UnassignFromProject(member_id=memberId, project_id=target);
        await loadAll();
    } except Exception as e {
        toast("Failed to unassign");
    }
}

impl RosterPage.addRepo -> None {
    captured = newRepo.strip();
    if not captured {
        return;
    }
    try {
        root spawn AddRepo(full_name=captured);
        newRepo = "";
        await loadAll();
    } except Exception as e {
        toast("Failed to add repo");
    }
}

impl RosterPage.removeRepo(repoId: str) -> None {
    try {
        root spawn RemoveRepo(repo_id=repoId);
        await loadAll();
    } except Exception as e {
        toast("Failed to remove repo");
    }
}
