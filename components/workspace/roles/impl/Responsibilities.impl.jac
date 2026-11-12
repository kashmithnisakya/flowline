"""Implementations for a role's AI responsibilities."""

impl Responsibilities.nameOf(key: str) -> str {
    for known in AI_RESPONSIBILITIES {
        if known["key"] == key {
            return known["name"];
        }
    }
    return key;
}

# Where it runs and how far it may go, in a few words.
impl Responsibilities.whereOf(r: ResponsibilityView) -> str {
    names: list[str] = [];
    for one in steps {
        if one.id in r.on_steps {
            names.append(one.name);
        }
    }
    place = ("on " + ", ".join(names)) if len(names) > 0 else "on every step it owns";
    reach = "may request changes" if r.mode == "request_changes" else "comments only";
    return place + " · " + reach + ("" if r.enabled else " · off");
}

impl Responsibilities.openNew(key: str) -> None {
    editingId = "";
    fresh = {** BLANK};
    fresh["key"] = key;
    form = fresh;
    picked = [];
    editorOpen = True;
}

impl Responsibilities.openEdit(r: ResponsibilityView) -> None {
    editingId = r.id;
    form = {
        "key": r.key,
        "instructions": r.instructions,
        "mode": r.mode,
        "model": r.model,
        "enabled": "yes" if r.enabled else ""
    };
    picked = r.on_steps;
    editorOpen = True;
}

impl Responsibilities.setField(name: str, value: str) -> None {
    # A computed key does not survive a dict-literal spread: copy, then set.
    updated = {** form};
    updated[name] = value;
    form = updated;
}

impl Responsibilities.toggleStep(stepId: str) -> None {
    if stepId in picked {
        picked = [
            p
            for p in picked
            if p != stepId
        ];
    } else {
        picked = picked + [stepId];
    }
}

impl Responsibilities.save -> None {
    if saving {
        return;
    }
    saving = True;
    try {
        result = root spawn SaveResponsibility(
            responsibility_id=editingId,
            role_id=roleId,
            key=form["key"],
            enabled=form["enabled"] == "yes",
            on_steps=picked,
            instructions=form["instructions"],
            mode=form["mode"],
            model=form["model"]
        );
        answer: any = result.reports[0] if result.reports else None;
        if answer and answer["ok"] {
            editorOpen = False;
            await onChanged();
            toast.success("Saved " + nameOf(form["key"]).lower() + " for " + roleName);
        } else {
            toast.error(answer["message"] if answer else "Could not save that");
        }
    } except Exception as e {
        toast.error("Could not save that");
    }
    saving = False;
}

impl Responsibilities.remove -> None {
    if saving or not editingId {
        return;
    }
    saving = True;
    try {
        root spawn DeleteResponsibility(responsibility_id=editingId);
        editorOpen = False;
        await onChanged();
        toast.success("Removed " + nameOf(form["key"]).lower() + " from " + roleName);
    } except Exception as e {
        toast.error("Could not remove that");
    }
    saving = False;
}

# The line's own switch: a save of the whole responsibility, enabled flipped.
impl Responsibilities.flip(r: ResponsibilityView, wanted: bool) -> None {
    try {
        result = root spawn SaveResponsibility(
            responsibility_id=r.id,
            role_id=roleId,
            key=r.key,
            enabled=wanted,
            on_steps=r.on_steps,
            instructions=r.instructions,
            mode=r.mode,
            model=r.model
        );
        answer: any = result.reports[0] if result.reports else None;
        if answer and answer["ok"] {
            await onChanged();
        } else {
            toast.error("Could not change that");
        }
    } except Exception as e {
        toast.error("Could not change that");
    }
}
