"""Implementations for the onboarding wizard."""

impl SetupPage.boot -> None {
    # Signup no longer collects a name, so the wizard resumes at whichever
    # step is still unanswered: no organization name means step 1, a named
    # workspace with no project means step 2.
    try {
        profile = await fetchProfile();
        existingOrg = str(profile["org_name"]) if profile["org_name"] else "";
        existingWho = str(profile["full_name"]) if profile["full_name"] else "";
        orgName = existingOrg;
        fullName = existingWho;
        if not existingOrg.strip() {
            step = 1;
            return;
        }
        projResult = root spawn ListProjects();
        existing = projResult.reports[0] if projResult.reports else [];
        if len(existing) == 0 {
            step = 2;
        } else {
            window.location.href = "/board";
        }
    } except Exception as e {
        step = 1;
    }
}

impl SetupPage.saveProfile -> None {
    org = orgName.strip();
    who = fullName.strip();
    if not org or not who {
        return;
    }
    saveError = "";
    busy = True;
    try {
        ok = await patchProfile({"org_name": org, "full_name": who});
        if ok {
            step = 2;
        } else {
            saveError = "Could not save those names. Try again.";
        }
    } except Exception as e {
        saveError = "Could not save those names. Try again.";
    }
    busy = False;
}

impl SetupPage.createProject -> None {
    captured = projectName.strip();
    if not captured {
        return;
    }
    busy = True;
    try {
        root spawn SaveProject(name=captured);
        step = 3;
    } except Exception as e {
        step = 2;
    }
    busy = False;
}


impl SetupPage.addPerson -> None {
    captured = mName.strip();
    capturedRole = mRole.strip();
    if not captured {
        return;
    }
    busy = True;
    try {
        result = root spawn SaveMember(
            name=captured, roles=[capturedRole] if capturedRole else []
        );
        fresh = result.reports[0] if result.reports else None;
        if fresh {
            added = added + [fresh];
        }
        mName = "";
        mRole = "";
    } except Exception as e {
        mName = mName;
    }
    busy = False;
}

impl SetupPage.finish -> None {
    # A name still sitting in the inputs counts; navigating away must not
    # silently discard a typed member.
    if mName.strip() {
        await addPerson();
    }
    # New orgs land on the workflow picker: choosing how work moves is the
    # last piece of setup, and the board reads better once it exists.
    window.location.href = "/workflow";
}
