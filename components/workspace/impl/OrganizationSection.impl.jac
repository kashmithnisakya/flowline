"""Implementations for the Organization section."""

impl OrganizationSection.load -> None {
    try {
        profile = await fetchProfile();
        name = str(profile["org_name"]) if profile["org_name"] else "";
        saved = name;
        draft = name;
    } except Exception as e {
        toast.error("Could not load your organization details");
    }
    loading = False;
}

impl OrganizationSection.save -> None {
    org = draft.strip();
    if not org or org == saved or saving {
        return;
    }
    saving = True;
    try {
        ok = await patchProfile({"org_name": org});
        if ok {
            saved = org;
            # The top bar reads the name once, when the shell mounts. Tell it
            # instead of asking the person to reload (contract C3).
            w: any = window;
            w.dispatchEvent(
                new(w.CustomEvent, "flowline:org-renamed", {"detail": {"name": org}})
            );
            if onRenamed {
                onRenamed(org);
            }
            toast.success("Organization renamed");
        } else {
            toast.error("Could not save that name");
        }
    } except Exception as e {
        toast.error("Could not save that name");
    }
    saving = False;
}
