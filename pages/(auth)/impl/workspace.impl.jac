"""Implementations for the Workspace page."""

impl WorkspacePage.loadAll -> None {
    try {
        t = spaceRoot();
        mResult = t spawn ListMembers();
        pResult = t spawn ListProjects();
        members = mResult.reports[0] if mResult.reports else [];
        projects = pResult.reports[0] if pResult.reports else [];
        # The member dialog offers the org's managed roles as toggle
        # chips; an org with none (predates roles, or scratch and never
        # added any) falls back to the free-text input.
        t = spaceRoot();
        rResult = t spawn ListRoles();
        roleRows = rResult.reports[0] if rResult.reports else [];
        opts: list[str] = [];
        for r in roleRows {
            opts.append(r.name);
        }
        roleOptions = opts;
    } except Exception as e {
        toast("Failed to load the workspace");
    }
    loading = False;
}

impl WorkspacePage.setField(key: str, value: str) -> None {
    # NOTE: `{**form, key: value}` compiles to a JS object literal with a
    # LITERAL "key" property. Build a copy and subscript it instead.
    updated = {** form};
    updated[key] = value;
    form = updated;
}

impl WorkspacePage.addRole -> None {
    draft = form["roleDraft"].strip();
    if not draft or draft in mRoles {
        return;
    }
    mRoles = mRoles + [draft];
    setField("roleDraft", "");
}

impl WorkspacePage.addTag -> None {
    draft = form["tagDraft"].strip();
    if not draft or draft in mTags {
        return;
    }
    mTags = mTags + [draft];
    setField("tagDraft", "");
}

impl WorkspacePage.toggleRoleOption(role: str) -> None {
    if role in mRoles {
        mRoles = [
            r
            for r in mRoles
            if r != role
        ];
    } else {
        mRoles = mRoles + [role];
    }
}

impl WorkspacePage.removeRole(role: str) -> None {
    mRoles = [
        r
        for r in mRoles
        if r != role
    ];
}

impl WorkspacePage.toggleTag(tag: str) -> None {
    if tag in mTags {
        mTags = [
            t
            for t in mTags
            if t != tag
        ];
    } else {
        mTags = mTags + [tag];
    }
}

impl WorkspacePage.toggleProject(projectId: str) -> None {
    if projectId in mProjects {
        mProjects = [
            p
            for p in mProjects
            if p != projectId
        ];
    } else {
        mProjects = mProjects + [projectId];
    }
}

impl WorkspacePage.openCreate -> None {
    editingId = "";
    form = BLANK_MEMBER;
    mRoles = [];
    mTags = [];
    mProjects = [];
    dialogOpen = True;
}

impl WorkspacePage.openEdit(m: MemberView) -> None {
    editingId = m.id;
    form = {
        "name": m.name,
        "email": m.email,
        "github": m.github_username,
        "roleDraft": ""
    };
    mRoles = m.roles;
    mTags = m.tags;
    mProjects = m.project_ids;
    dialogOpen = True;
}

impl WorkspacePage.saveMember -> None {
    name = form["name"].strip();
    if not name {
        return;
    }
    saving = True;
    # A role still sitting in the draft box counts; losing typed input on
    # save is the setup-wizard bug all over again.
    roles = mRoles;
    draft = form["roleDraft"].strip();
    if draft and draft not in roles {
        roles = roles + [draft];
    }
    try {
        t = spaceRoot();
        result = t spawn SaveMember(
            member_id=editingId,
            name=name,
            roles=roles,
            email=form["email"].strip(),
            github_username=form["github"].strip(),
            tags=mTags
        );
        saved = result.reports[0] if result.reports else None;
        if saved {
            before = saved.project_ids;
            for pid in mProjects {
                if pid not in before {
                    t = spaceRoot();
                    t spawn AssignToProject(member_id=saved.id, project_id=pid);
                }
            }
            for pid in before {
                if pid not in mProjects {
                    t = spaceRoot();
                    t spawn UnassignFromProject(member_id=saved.id, project_id=pid);
                }
            }
        }
        dialogOpen = False;
        await loadAll();
    } except Exception as e {
        toast("Failed to save member");
    }
    saving = False;
}

impl WorkspacePage.archiveMember(memberId: str) -> None {
    try {
        t = spaceRoot();
        t spawn ArchiveMember(member_id=memberId);
        await loadAll();
    } except Exception as e {
        toast("Failed to archive member");
    }
}

impl WorkspacePage.assignTo(memberId: str, projectId: str) -> None {
    if not projectId {
        return;
    }
    try {
        t = spaceRoot();
        t spawn AssignToProject(member_id=memberId, project_id=projectId);
        await loadAll();
    } except Exception as e {
        toast("Failed to assign");
    }
}

impl WorkspacePage.unassignFrom(memberId: str, projectName: str) -> None {
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
        t = spaceRoot();
        t spawn UnassignFromProject(member_id=memberId, project_id=target);
        await loadAll();
    } except Exception as e {
        toast("Failed to unassign");
    }
}


impl WorkspacePage.selectTab(value: str) -> None {
    tab = value;
    # Keep the tab in the URL so it is linkable and survives a reload, but
    # replace rather than push: Back should leave the page, not undo a tab
    # flip. Any OAuth callback params are dropped here too, which is what
    # stops a refresh replaying a burned install nonce.
    w: any = window;
    blank: dict[str, any] = {};
    here = str(w.location.pathname);
    w.history.replaceState(blank, "", here + "?tab=" + value);
}
