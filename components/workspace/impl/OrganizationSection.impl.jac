"""Implementations for the Organization section."""

impl OrganizationSection.load -> None {
    try {
        profile = await fetchProfile();
        orgName = str(profile["org_name"]) if profile["org_name"] else "";
        fullName = str(profile["full_name"]) if profile["full_name"] else "";
    } except Exception as e {
        toast("Could not load your organization details");
    }
    loading = False;
}

impl OrganizationSection.save -> None {
    org = orgName.strip();
    who = fullName.strip();
    if not org or not who {
        return;
    }
    saving = True;
    try {
        ok = await patchProfile({"org_name": org, "full_name": who});
        if ok {
            # The name in the nav is read once when the shell mounts, so a
            # rename only shows there after a reload. Say so rather than
            # letting the header silently disagree with this form.
            toast("Saved. The name in the header updates on your next reload.");
        } else {
            toast("Could not save those changes");
        }
    } except Exception as e {
        toast("Could not save those changes");
    }
    saving = False;
}
