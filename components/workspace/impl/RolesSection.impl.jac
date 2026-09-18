"""Implementations for the Roles section."""

impl RolesSection.load -> None {
    try {
        rResult = root spawn ListRoles();
        roles = rResult.reports[0] if rResult.reports else [];
        mResult = root spawn ListMembers();
        members = mResult.reports[0] if mResult.reports else [];
        # Which steps a role owns; the count is not needed, so skip the walk
        # over every task.
        sResult = root spawn GetFlowLine(with_counts=False);
        steps = sResult.reports[0] if sResult.reports else [];
    } except Exception as e {
        toast.error("Could not load roles");
    }
    loading = False;
}

impl RolesSection.startAdd -> None {
    editingRole = "";
    newRole = "";
    newBlurb = "";
    adding = True;
}

impl RolesSection.addRole -> None {
    draft = newRole.strip();
    said = newBlurb.strip();
    if not draft or saving {
        return;
    }
    saving = True;
    try {
        # SaveRole is get-or-create by name, so adding a duplicate is a
        # harmless no-op rather than a second row. touch_blurb only when
        # something was typed, or re-adding a name would blank its wording.
        if said {
            root spawn SaveRole(name=draft, blurb=said, touch_blurb=True);
        } else {
            root spawn SaveRole(name=draft);
        }
        forgetWorkspace();
        newRole = "";
        newBlurb = "";
        adding = False;
        await load();
        if onChanged {
            onChanged();
        }
    } except Exception as e {
        toast.error("Could not add that role");
    }
    saving = False;
}

impl RolesSection.startEdit(name: str, blurb: str) -> None {
    adding = False;
    editingRole = name;
    editName = name;
    editBlurb = blurb;
}

impl RolesSection.saveEdit -> None {
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
            toast.error("A role with that name already exists");
        } else {
            forgetWorkspace();
            editingRole = "";
            await load();
            if onChanged {
                onChanged();
            }
        }
    } except Exception as e {
        toast.error("Could not save that role");
    }
    saving = False;
}

impl RolesSection.removeRole -> None {
    name = deleteTarget;
    if not name or busy {
        return;
    }
    busy = True;
    try {
        root spawn DeleteRole(name=name);
        forgetWorkspace();
        deleteTarget = "";
        await load();
        if onChanged {
            onChanged();
        }
        toast.success("Role deleted");
    } except Exception as e {
        toast.error("Could not delete that role");
    }
    busy = False;
}

impl RolesSection.setHolders(role: str, wanted: list[str], undoable: bool) -> None {
    # Only the people whose membership of this role changed are written, and
    # each one keeps every other role they hold.
    before: list[str] = [];
    changes = 0;
    try {
        for m in members {
            if not m.active {
                continue;
            }
            had = role in m.roles;
            if had {
                before.append(m.id);
            }
            wants = m.id in wanted;
            if had == wants {
                continue;
            }
            changes = changes + 1;
            next: list[str] = [
                r
                for r in m.roles
                if r != role
            ];
            if wants {
                next = next + [role];
            }
            root spawn SetMemberRoles(member_id=m.id, roles=next);
        }
        if changes == 0 {
            return;
        }
        forgetWorkspace();
        await load();
        if onChanged {
            onChanged();
        }
        if undoable {
            toast.success(
                role + " updated",
                {
                    "action": {
                        "label": "Undo",
                        "onClick": lambda { setHolders(role, before, False); }
                    }
                }
            );
        }
    } except Exception as e {
        toast.error("Could not change who holds " + role);
    }
}
