"""Implementations for the Workspace page."""

impl RosterPage.loadAll -> None {
    try {
        mResult = root spawn ListMembers();
        pResult = root spawn ListProjects();
        vResult = root spawn ListVocab();
        members = mResult.reports[0] if mResult.reports else [];
        projects = pResult.reports[0] if pResult.reports else [];
        vocab = vResult.reports[0] if vResult.reports else [];
    } except Exception as e {
        toast("Failed to load the workspace");
    }
    loading = False;
}

impl RosterPage.setField(key: str, value: str) -> None {
    # NOTE: `{**form, key: value}` compiles to a JS object literal with a
    # LITERAL "key" property. Build a copy and subscript it instead.
    updated = {**form};
    updated[key] = value;
    form = updated;
}

impl RosterPage.addRole -> None {
    draft = form["roleDraft"].strip();
    if not draft or draft in mRoles {
        return;
    }
    mRoles = mRoles + [draft];
    setField("roleDraft", "");
}

impl RosterPage.removeRole(role: str) -> None {
    mRoles = [r for r in mRoles if r != role];
}

impl RosterPage.toggleTag(tag: str) -> None {
    if tag in mTags {
        mTags = [t for t in mTags if t != tag];
    } else {
        mTags = mTags + [tag];
    }
}

impl RosterPage.toggleProject(projectId: str) -> None {
    if projectId in mProjects {
        mProjects = [p for p in mProjects if p != projectId];
    } else {
        mProjects = mProjects + [projectId];
    }
}

impl RosterPage.openCreate -> None {
    editingId = "";
    form = BLANK_MEMBER;
    mRoles = [];
    mTags = [];
    mProjects = [];
    dialogOpen = True;
}

impl RosterPage.openEdit(m: MemberView) -> None {
    editingId = m.id;
    form = {
        "name": m.name, "email": m.email,
        "github": m.github_username, "roleDraft": ""
    };
    mRoles = m.roles;
    mTags = m.tags;
    mProjects = m.project_ids;
    dialogOpen = True;
}

impl RosterPage.saveMember -> None {
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
        result = root spawn SaveMember(
            member_id=editingId, name=name, roles=roles,
            email=form["email"].strip(), github_username=form["github"].strip(),
            tags=mTags
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

impl RosterPage.addVocab(kind: str) -> None {
    value = newCategory.strip() if kind == "category" else newTag.strip();
    if not value {
        return;
    }
    try {
        root spawn AddVocab(kind=kind, value=value);
        if kind == "category" {
            newCategory = "";
        } else {
            newTag = "";
        }
        await loadAll();
    } except Exception as e {
        toast("Failed to add the term");
    }
}

impl RosterPage.removeVocab(termId: str) -> None {
    try {
        root spawn RemoveVocab(term_id=termId);
        await loadAll();
    } except Exception as e {
        toast("Failed to remove the term");
    }
}
