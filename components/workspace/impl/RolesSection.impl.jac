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

impl RolesSection.toggleRole(memberId: str, role: str) -> None {
    if saving {
        return;
    }
    current: list[str] = [];
    for m in members {
        if m.id == memberId {
            current = m.roles;
        }
    }
    updated: list[str] = [];
    if role in current {
        updated = [
            r
            for r in current
            if r != role
        ];
    } else {
        updated = current + [role];
    }
    saving = True;
    try {
        result = root spawn SetMemberRoles(member_id=memberId, roles=updated);
        fresh = result.reports[0] if result.reports else None;
        if fresh {
            # Rebind rather than mutate: swap the reported view in so the
            # chips flip without a full reload.
            swapped: list[MemberView] = [];
            for m in members {
                if m.id == memberId {
                    swapped.append(fresh);
                } else {
                    swapped.append(m);
                }
            }
            members = swapped;
            # The People tab and member dialog render roles too; let the
            # host page refresh.
            if onChanged {
                onChanged();
            }
        }
    } except Exception as e {
        toast("Could not update roles");
    }
    saving = False;
}

impl RolesSection.addRole -> None {
    draft = newRole.strip();
    if not draft or saving {
        return;
    }
    saving = True;
    try {
        # SaveRole is get-or-create by name, so adding a duplicate is a
        # harmless no-op rather than a second card.
        root spawn SaveRole(name=draft);
        newRole = "";
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
