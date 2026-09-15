"""Implementations for the setup wizard."""

impl SetupPage.boot -> None {
    # Resume at the first open step: no name or no project is step 1; a
    # project with no flow line is step 2, or 3 once people exist; a flow
    # line means setup is done.
    try {
        profile = await fetchProfile();
        existingOrg = str(profile["org_name"]) if profile["org_name"] else "";
        orgName = existingOrg;
        savedOrg = existingOrg;
        projResult = root spawn ListProjects();
        existing = projResult.reports[0] if projResult.reports else [];
        if len(existing) > 0 {
            first = existing[0];
            projectName = first.name;
            savedProject = first.name;
            projectId = jid(first);
        }
        if not existingOrg.strip() or len(existing) == 0 {
            step = 1;
            return;
        }
        flowResult = root spawn GetFlowLine(with_counts=False);
        steps = flowResult.reports[0] if flowResult.reports else [];
        if len(steps) > 0 {
            navigate("/board");
            return;
        }
        roster = root spawn ListMembers();
        members = roster.reports[0] if roster.reports else [];
        added = members;
        step = 3 if len(members) > 0 else 2;
    } except Exception as e {
        step = 1;
    }
}

impl SetupPage.saveWorkspace(e: FormEvent) -> None {
    e.preventDefault();
    if busy {
        return;
    }
    org = orgName.strip();
    project = projectName.strip();
    orgError = "" if org else "Enter a team or company name.";
    projectError = "" if project else "Name your first project, like Website redesign.";
    if orgError or projectError {
        doc: any = document;
        target: any = doc.getElementById("setup-org" if orgError else "setup-project");
        if target {
            target.focus();
        }
        return;
    }
    saveError = "";
    busy = True;
    try {
        if org != savedOrg {
            ok = await patchProfile({"org_name": org});
            if not ok {
                saveError = "Could not save the workspace name. Try again.";
                busy = False;
                return;
            }
            savedOrg = org;
            # The app header shows the name; tell it without a reload.
            w: any = window;
            w.dispatchEvent(
                new(w.CustomEvent, "flowline:org-renamed", {"detail": {"name": org}})
            );
        }
        if not projectId or project != savedProject {
            result = root spawn SaveProject(project_id=projectId, name=project);
            made = result.reports[0] if result.reports else None;
            if not made {
                saveError = "Could not create the project. Try again.";
                busy = False;
                return;
            }
            projectId = jid(made);
            savedProject = project;
        }
        step = 2;
    } except Exception as ex {
        saveError = "Could not save that. Try again.";
    }
    busy = False;
}

impl SetupPage.addPerson -> bool {
    first = mFirst.strip();
    if not first {
        firstError = "Enter a first name to add someone.";
        doc: any = document;
        target: any = doc.getElementById("setup-first");
        if target {
            target.focus();
        }
        return False;
    }
    role = mRole.strip();
    saveError = "";
    busy = True;
    ok = False;
    try {
        result = root spawn SaveMember(
            first_name=first, last_name=mLast.strip(), roles=[role] if role else []
        );
        fresh = result.reports[0] if result.reports else None;
        if fresh {
            # The question was who works on this project, so put them on it.
            if projectId {
                root spawn AssignToProject(member_id=fresh.id, project_id=projectId);
            }
            added = added + [fresh];
            mFirst = "";
            mLast = "";
            mRole = "";
            ok = True;
        } else {
            saveError = "Could not add that person. Try again.";
        }
    } except Exception as ex {
        saveError = "Could not add that person. Try again.";
    }
    busy = False;
    if ok {
        doc: any = document;
        target: any = doc.getElementById("setup-first");
        if target {
            target.focus();
        }
    }
    return ok;
}

impl SetupPage.submitPerson(e: FormEvent) -> None {
    e.preventDefault();
    if busy {
        return;
    }
    await addPerson();
}

impl SetupPage.continuePeople -> None {
    # A name still in the fields counts: moving on must not drop it.
    if mFirst.strip() {
        ok = await addPerson();
        if not ok {
            return;
        }
    }
    firstError = "";
    saveError = "";
    step = 3;
}

impl SetupPage.skipPeople -> None {
    mFirst = "";
    mLast = "";
    mRole = "";
    firstError = "";
    saveError = "";
    step = 3;
}

impl SetupPage.pickTemplate(key: str) -> None {
    choice = key;
    saveError = "";
}

impl SetupPage.radioKey(e: KeyboardEvent, index: int, keys: list[str]) -> None {
    # Radio group keys: arrows move and select, Enter also opens the board.
    count = len(keys);
    next = -1;
    if e.key == "ArrowDown" or e.key == "ArrowRight" {
        next = (index + 1) % count;
    } elif e.key == "ArrowUp" or e.key == "ArrowLeft" {
        next = (index - 1 + count) % count;
    } elif e.key == "Home" {
        next = 0;
    } elif e.key == "End" {
        next = count - 1;
    } elif e.key == "Enter" {
        e.preventDefault();
        choice = keys[index];
        finish();
        return;
    }
    if next >= 0 {
        e.preventDefault();
        choice = keys[next];
        doc: any = document;
        target: any = doc.getElementById("tpl-" + keys[next]);
        if target {
            target.focus();
        }
    }
}

impl SetupPage.submitFinish(e: FormEvent) -> None {
    e.preventDefault();
    await finish();
}

impl SetupPage.finish -> None {
    if busy {
        return;
    }
    if choice == SCRATCH {
        navigate("/flowlines");
        return;
    }
    saveError = "";
    busy = True;
    try {
        # A flow line that already exists comes back unchanged, so a second
        # click (or a resumed setup) still lands on the same board.
        result = root spawn ApplyTemplate(template_key=choice);
        fresh = result.reports[0] if result.reports else [];
        if len(fresh) > 0 {
            navigate("/board?new=1");
            return;
        }
        saveError = "That starting point could not be set up. Try again.";
    } except Exception as ex {
        saveError = "Could not set up the board. Try again.";
    }
    busy = False;
}
