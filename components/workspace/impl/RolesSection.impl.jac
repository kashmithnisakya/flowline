"""Implementations for the Roles section."""

impl RolesSection.load -> None {
    try {
        rResult = root spawn ListRoles();
        roles = rResult.reports[0] if rResult.reports else [];
        mResult = root spawn ListMembers();
        members = mResult.reports[0] if mResult.reports else [];
    } except Exception as e {
        toast("Could not load roles");
    }
    loading = False;
}

impl RolesSection.addRole -> None {
    # Both drafts read before the walker call: a `has` read after an await is
    # a stale render-time snapshot.
    draft = newRole.strip();
    said = newBlurb.strip();
    if not draft or saving {
        return;
    }
    saving = True;
    try {
        # SaveRole is get-or-create by name, so adding a duplicate is a
        # harmless no-op rather than a second card. touch_blurb only when
        # something was typed, or re-adding a name would blank its wording.
        if said {
            root spawn SaveRole(name=draft, blurb=said, touch_blurb=True);
        } else {
            root spawn SaveRole(name=draft);
        }
        newRole = "";
        newBlurb = "";
        await load();
        if onChanged {
            onChanged();
        }
    } except Exception as e {
        toast("Could not add that role");
    }
    saving = False;
}

impl RolesSection.startEdit(name: str, blurb: str) -> None {
    editingRole = name;
    editName = name;
    editBlurb = blurb;
    confirmDelete = "";
}

impl RolesSection.saveEdit -> None {
    # Read the drafts before the walker call; a `has` read after an await
    # is a stale render-time snapshot.
    was = editingRole;
    wanted = editName.strip();
    said = editBlurb.strip();
    if not was or not wanted or saving {
        return;
    }
    saving = True;
    try {
        result = root spawn SaveRole(
            name=was, new_name=wanted, blurb=said, touch_blurb=True
        );
        resp = result.reports[0] if result.reports else None;
        if resp and not resp["ok"] {
            toast("A role with that name already exists");
        } else {
            editingRole = "";
            await load();
            if onChanged {
                onChanged();
            }
        }
    } except Exception as e {
        toast("Could not save that role");
    }
    saving = False;
}

impl RolesSection.deleteRole(name: str) -> None {
    if saving {
        return;
    }
    saving = True;
    try {
        root spawn DeleteRole(name=name);
        confirmDelete = "";
        await load();
        if onChanged {
            onChanged();
        }
    } except Exception as e {
        toast("Could not delete that role");
    }
    saving = False;
}
