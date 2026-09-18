"""Implementations for the Roles section."""

impl RolesSection.refresh -> None {
    # After a write here: drop the cached view and let the page reload its
    # lists, so the section and the page never disagree.
    forgetWorkspace();
    if onChanged {
        await onChanged();
    }
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
        newRole = "";
        newBlurb = "";
        adding = False;
        await refresh();
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
            editingRole = "";
            await refresh();
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
        deleteTarget = "";
        await refresh();
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
        await refresh();
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
