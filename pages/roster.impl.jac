"""Implementations for the Roster page."""

impl RosterPage.loadAll -> None {
    try {
        mResult = root spawn ListMembers();
        rResult = root spawn ListRepos();
        members = mResult.reports[0] if mResult.reports else [];
        repos = rResult.reports[0] if rResult.reports else [];
    } except Exception as e {
        toast("Failed to load roster");
    }
    loading = False;
}

impl RosterPage.openCreate -> None {
    editingId = "";
    fName = "";
    fTeam = "";
    fRole = "";
    fEmail = "";
    fGithub = "";
    fSection = "";
    dialogOpen = True;
}

impl RosterPage.openEdit(m: Member) -> None {
    editingId = jid(m);
    fName = m.name;
    fTeam = m.team;
    fRole = m.role;
    fEmail = m.email;
    fGithub = m.github_username;
    fSection = m.section;
    dialogOpen = True;
}

impl RosterPage.saveMember -> None {
    if not fName.strip() or not fTeam {
        return;
    }
    saving = True;
    # Section only applies to Jac Scale; clear it when the team changed away.
    sec = fSection if fTeam == "Jac Scale" else "";
    try {
        root spawn SaveMember(
            member_id=editingId, name=fName.strip(), team=fTeam,
            role=fRole.strip(), email=fEmail.strip(),
            github_username=fGithub.strip(), section=sec
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
