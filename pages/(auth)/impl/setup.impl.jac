"""Implementations for the onboarding wizard."""

impl SetupPage.boot -> None {
    # Resume where the PM left off: no org -> step 1; org but no project ->
    # step 2; both -> setup is done, go to the board.
    try {
        me = root spawn GetMe();
        if not me.reports {
            step = 1;
            return;
        }
        projResult = root spawn ListProjects();
        existing = projResult.reports[0] if projResult.reports else [];
        if len(existing) == 0 {
            step = 2;
        } else {
            window.location.href = "/";
        }
    } except Exception as e {
        step = 1;
    }
}

impl SetupPage.createOrg -> None {
    captured = orgName.strip();
    if not captured {
        return;
    }
    busy = True;
    try {
        root spawn CreateOrganization(name=captured);
        step = 2;
    } except Exception as e {
        step = 1;
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
        result = root spawn SaveMember(name=captured, role=capturedRole);
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
