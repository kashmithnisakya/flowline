"""Implementations for the Workspace page."""

impl WorkspacePage.loadAll -> None {
    try {
        mResult = root spawn ListMembers();
        pResult = root spawn ListProjects();
        members = mResult.reports[0] if mResult.reports else [];
        projects = pResult.reports[0] if pResult.reports else [];
        # The org's managed roles drive the row menus and the member dialog;
        # a workspace with none falls back to free text in the dialog.
        rResult = root spawn ListRoles();
        roles = rResult.reports[0] if rResult.reports else [];
        orgName = await fetchOrgName();
    } except Exception as e {
        toast.error("Could not load the workspace");
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
    # A row saved before names were split shows its display name as the
    # first name until it is saved again.
    first = m.first_name;
    last = m.last_name;
    if not first and not last {
        bits = m.name.strip().split(" ");
        first = bits[0];
        last = " ".join(bits[1:]);
    }
    form = {
        "first_name": first,
        "last_name": last,
        "email": m.email,
        "github": m.github_username,
        "color": m.color,
        "roleDraft": "",
        "tagDraft": ""
    };
    mRoles = m.roles;
    mTags = m.tags;
    mProjects = m.project_ids;
    dialogOpen = True;
}

impl WorkspacePage.askArchive(m: MemberView) -> None {
    archiveId = m.id;
    archiveName = m.name;
}

impl WorkspacePage.saveMember -> None {
    first = form["first_name"].strip();
    if not first {
        return;
    }
    saving = True;
    # A role still sitting in the draft box counts; losing typed input on
    # save is the setup-wizard bug all over again.
    roleList = mRoles;
    draft = form["roleDraft"].strip();
    if draft and draft not in roleList {
        roleList = roleList + [draft];
    }
    try {
        result = root spawn SaveMember(
            member_id=editingId,
            first_name=first,
            last_name=form["last_name"].strip(),
            roles=roleList,
            email=form["email"].strip(),
            github_username=form["github"].strip(),
            tags=mTags,
            color=form["color"]
        );
        saved = result.reports[0] if result.reports else None;
        if saved {
            before = saved.project_ids;
            for pid in mProjects {
                if pid not in before {
                    root spawn AssignToProject(member_id=saved.id, project_id=pid);
                }
            }
            for pid in before {
                if pid not in mProjects {
                    root spawn UnassignFromProject(member_id=saved.id, project_id=pid);
                }
            }
        }
        dialogOpen = False;
        await loadAll();
    } except Exception as e {
        toast.error("Could not save that person");
    }
    saving = False;
}

impl WorkspacePage.archiveMember -> None {
    target = archiveId;
    name = archiveName;
    if not target or archiving {
        return;
    }
    archiving = True;
    try {
        root spawn ArchiveMember(member_id=target);
        archiveId = "";
        await loadAll();
        toast.success(name + " archived");
    } except Exception as e {
        toast.error("Could not archive that person");
    }
    archiving = False;
}

impl WorkspacePage.applyRoles(memberId: str, next: list[str], undoable: bool) -> None {
    # SetMemberRoles overwrites only the roles and answers with the saved row,
    # so one call updates the table without reloading the roster.
    was: list[str] = [];
    who = "";
    for m in members {
        if m.id == memberId {
            was = m.roles;
            who = m.name;
        }
    }
    try {
        result = root spawn SetMemberRoles(member_id=memberId, roles=next);
        saved = result.reports[0] if result.reports else None;
        if saved {
            members = [saved if m.id == memberId else m for m in members];
        }
        # A role typed on this member may be new to the workspace.
        rResult = root spawn ListRoles();
        roles = rResult.reports[0] if rResult.reports else roles;
        if undoable {
            toast.success(
                "Roles saved for " + who,
                {
                    "action": {
                        "label": "Undo",
                        "onClick": lambda { applyRoles(memberId, was, False); }
                    }
                }
            );
        }
    } except Exception as e {
        toast.error("Could not save those roles");
    }
}

impl WorkspacePage.applyProjects(
    memberId: str, next: list[str], undoable: bool
) -> None {
    # Only the differences are written: a project the menu never listed (an
    # archived one someone is still on) is left exactly as it was.
    was: list[str] = [];
    who = "";
    for m in members {
        if m.id == memberId {
            was = m.project_ids;
            who = m.name;
        }
    }
    try {
        for pid in next {
            if pid not in was {
                root spawn AssignToProject(member_id=memberId, project_id=pid);
            }
        }
        for pid in was {
            if pid not in next {
                root spawn UnassignFromProject(member_id=memberId, project_id=pid);
            }
        }
        mResult = root spawn ListMembers();
        members = mResult.reports[0] if mResult.reports else members;
        if undoable {
            toast.success(
                "Projects saved for " + who,
                {
                    "action": {
                        "label": "Undo",
                        "onClick": lambda { applyProjects(memberId, was, False); }
                    }
                }
            );
        }
    } except Exception as e {
        toast.error("Could not save those projects");
    }
}

impl WorkspacePage.selectTab(value: str) -> None {
    tab = value;
    query = "";
    # Keep the section in the URL so it is linkable and survives a reload, but
    # replace rather than push: Back should leave the page, not undo a tab
    # flip. Any OAuth callback params are dropped here too, which is what
    # stops a refresh replaying a burned install nonce.
    w: any = window;
    blank: dict[str, any] = {};
    here = str(w.location.pathname);
    w.history.replaceState(blank, "", here + "?tab=" + value);
}
