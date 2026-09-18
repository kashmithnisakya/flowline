"""Implementations for the GitHub page. Every walker except GithubStatus
answers one envelope dict, so handlers read `payload["ok"]` and surface
`payload["message"]`: only the server knows why GitHub said no.
"""

impl GithubSection.boot -> None {
    # Finish GitHub's install round trip before anything reads status. The
    # params are consumed once, before the first await: both mounts of the
    # page read the URL, and the nonce and the OAuth code are single-use.
    # URLSearchParams is missing from the checker's DOM typings: `any` handle.
    w: any = window;
    params: any = new(w.URLSearchParams, w.location.search);
    installation = params.get("installation_id") or "";
    state = params.get("state") or "";
    code = params.get("code") or "";
    # Deep links restore the triage view before any data loads: the repo,
    # the tab, and a committed search all round-trip through the URL.
    wantRepo = params.get("repo") or "";
    wantTab = params.get("tab") or "";
    wantQuery = params.get("q") or "";
    if wantRepo {
        repoId = wantRepo;
    }
    if wantTab in ["issues", "pulls"] {
        tab = wantTab;
    }
    if wantQuery {
        searchQuery = wantQuery;
        searchDraft = wantQuery;
    }
    if installation and state and not INSTALL_ONCE["pending"] {
        blank: dict[str, any] = {};
        window.history.replaceState(blank, "", window.location.pathname);
        installId = 0;
        try {
            installId = int(installation);
        } except Exception as e {
            installId = 0;
        }
        INSTALL_ONCE["pending"] = finishInstall(code, installId, state);
    }
    if INSTALL_ONCE["pending"] {
        await INSTALL_ONCE["pending"];
    }
    await loadStatus();
    await loadWorkspace();
    loading = False;
}

impl GithubSection.finishInstall(code: str, installId: int, state: str) -> None {
    # One server call per redirect; the page's other mount awaits this same
    # promise, so both read the connection only after it exists.
    blank: dict[str, any] = {};
    try {
        result = root spawn CompleteGithubInstall(
            code=code, installation_id=installId, state=state
        );
        payload = result.reports[0] if result.reports else blank;
        if payload["ok"] {
            toast.success("GitHub connected");
        } else {
            toast.error(payload["message"] or "That install could not be finished.");
        }
    } except Exception as e {
        toast.error("Could not finish the GitHub install");
    }
}

impl GithubSection.loadStatus -> None {
    try {
        result = root spawn GithubStatus();
        view = result.reports[0] if result.reports else None;
        if view {
            conn = view;
            configGaps = view.missing_config;
            try {
                localStorage.setItem(GITHUB_KEY, "1" if view.connected else "0");
            } except Exception as e {
                configGaps = configGaps;
            }
        }
    } except Exception as e {
        toast.error("Could not read the GitHub connection");
    }
}

impl GithubSection.loadWorkspace -> None {
    try {
        rResult = root spawn ListRepos();
        pResult = root spawn ListProjects();
        sResult = root spawn GetFlowLine();
        fetched = rResult.reports[0] if rResult.reports else [];
        repos = fetched;
        fetchedProjects: list[Project] = pResult.reports[0] if pResult.reports else [];
        projects = fetchedProjects;
        # One active project is no real choice: preselect it so a fresh
        # workspace never attaches its first repo to "No project".
        actives: list[Project] = [
            p
            for p in fetchedProjects
            if p.active
        ];
        if not pickerProject and len(actives) == 1 {
            pickerProject = jid(actives[0]);
        }
        # The "as" picker offers the org's own flow line steps; imports land on
        # the start step by default (where new work lands). An org with no
        # flow line keeps the legacy status list instead.
        stepRows: list[StepView] = sResult.reports[0] if sResult.reports else [];
        steps = stepRows;
        if not importStep and len(stepRows) > 0 {
            landing = stepRows[0].id;
            for s in stepRows {
                if s.kind == "start" {
                    landing = s.id;
                    break;
                }
            }
            importStep = landing;
        }
        # Land on something readable rather than an empty picker. An explicit
        # choice already made is left alone.
        if not repoId and fetched {
            repoId = fetched[0].id;
        }
    } except Exception as e {
        toast.error("Could not load this workspace's repositories");
    }
}

impl GithubSection.startInstall -> None {
    if starting {
        return;
    }
    starting = True;
    blank: dict[str, any] = {};
    try {
        result = root spawn StartGithubInstall();
        payload = result.reports[0] if result.reports else blank;
        if payload["ok"] and payload["url"] {
            # A full-page hop to github.com; this tab does not come back until
            # GitHub redirects, so `starting` is deliberately left set.
            window.location.href = payload["url"];
            return;
        }
        gaps = payload["missing"] or [];
        configGaps = gaps;
        if not gaps {
            toast.error(payload["message"] or "Could not start the GitHub install");
        }
    } except Exception as e {
        toast.error("Could not start the GitHub install");
    }
    starting = False;
}

impl GithubSection.disconnect -> None {
    if disconnecting {
        return;
    }
    disconnecting = True;
    try {
        root spawn DisconnectGithub();
        confirmDisconnect = False;
        repoId = "";
        issues = [];
        pulls = [];
        selected = [];
        pickerRows = [];
        await loadStatus();
        toast.success("Disconnected from GitHub");
    } except Exception as e {
        toast.error("Could not disconnect from GitHub");
    }
    disconnecting = False;
}

impl GithubSection.syncNow -> None {
    await runSync(False);
}

impl GithubSection.resyncAll -> None {
    await runSync(True);
}

impl GithubSection.runSync(full: bool) -> None {
    # The same bounded loop the board runs, driven by hand: each increment is
    # capped server-side, so this asks for the next one until it says done.
    # A history pass resets the cursors on its first round only.
    if syncing {
        return;
    }
    syncing = True;
    linked = 0;
    added = 0;
    moved = 0;
    failure = "";
    try {
        rounds = 0;
        more = True;
        while more and rounds < SYNC_ROUNDS {
            rounds = rounds + 1;
            result = root spawn SyncGithub(full=(full and rounds == 1));
            payload = result.reports[0] if result.reports else None;
            if not payload or not payload["ok"] {
                failure = str(payload["message"]) if payload else "Sync failed";
                break;
            }
            linked = int(payload["linked"] or 0);
            added = added + int(payload["auto_added"] or 0);
            moved = moved + int(payload["auto_done"] or 0);
            failure = str(payload["failure"] or "");
            more = bool(payload["has_more"]) and not failure;
        }
        await loadStatus();
        rResult = root spawn ListRepos();
        repos = rResult.reports[0] if rResult.reports else repos;
        if tab == "issues" {
            await loadIssues(True);
        } else {
            await loadPulls(True);
        }
        if failure {
            toast.error(failure);
        } else {
            msg: str = "Synced " + str(linked) + " tasks";
            if added > 0 {
                msg = msg + " · " + str(added) + " issues added";
            }
            if moved > 0 {
                msg = msg + " · " + str(moved) + " moved to Done";
            }
            toast.success(msg);
        }
        # The board is a separate tree; without this it would not show what
        # the sync just changed until its next poll.
        w: any = window;
        w.dispatchEvent(new(w.CustomEvent, "flowline:refresh"));
    } except Exception as e {
        toast.error("Could not sync with GitHub");
    }
    syncing = False;
}

impl GithubSection.openPicker -> None {
    pickerOpen = True;
    await searchRepos();
}

impl GithubSection.searchRepos -> None {
    pickerLoading = True;
    blank: dict[str, any] = {};
    try {
        needle = pickerQuery.strip();
        pickerRef.current = needle;
        result = root spawn ListGithubRepos(query=needle, page=1);
        payload = result.reports[0] if result.reports else blank;
        if payload["ok"] {
            pickerRows = payload["rows"] or [];
            pickerPage = 1;
            pickerMore = bool(payload["has_more"]);
        } else {
            pickerRows = [];
            pickerMore = False;
            toast.error(
                payload["message"] or "GitHub would not list your repositories"
            );
        }
    } except Exception as e {
        toast.error("Could not reach GitHub");
    }
    pickerLoading = False;
}

impl GithubSection.moreRepos -> None {
    # The query and page are read before the await; a page filtered by
    # name can come back short or empty and still have more behind it.
    if pickerLoadingMore {
        return;
    }
    wanted = pickerPage + 1;
    needle = pickerQuery.strip();
    have = [r for r in pickerRows];
    pickerLoadingMore = True;
    blank: dict[str, any] = {};
    try {
        result = root spawn ListGithubRepos(query=needle, page=wanted);
        payload = result.reports[0] if result.reports else blank;
        if payload["ok"] and pickerRef.current == needle {
            # Sort the merged list: each page arrives sorted on its own, so
            # concatenating them would interleave two alphabets.
            merged = have + (payload["rows"] or []);
            merged.sort(key=lambda (r: GhRepoRow) { r.full_name; });
            pickerRows = merged;
            pickerPage = wanted;
            pickerMore = bool(payload["has_more"]);
        } else {
            toast.error(
                payload["message"] or "GitHub would not list your repositories"
            );
        }
    } except Exception as e {
        toast.error("Could not reach GitHub");
    }
    pickerLoadingMore = False;
}

impl GithubSection.toggleAutoSync(rid: str, enabled: bool) -> None {
    try {
        result = root spawn SetRepoAutoSync(repo_id=rid, enabled=enabled);
        payload = result.reports[0] if result.reports else None;
        if payload and payload["ok"] {
            rResult = root spawn ListRepos();
            repos = rResult.reports[0] if rResult.reports else [];
            toast.success(
                "Importing issues on. This repository's existing issues arrive on the next sync."
                    if enabled
                    else "Importing issues turned off"
            );
        } else {
            toast.error("Could not update that repository");
        }
    } except Exception as e {
        toast.error("Could not update that repository");
    }
}

impl GithubSection.toggleAutoDone(rid: str, enabled: bool) -> None {
    try {
        result = root spawn SetRepoAutoDone(repo_id=rid, enabled=enabled);
        payload = result.reports[0] if result.reports else None;
        if payload and payload["ok"] {
            rResult = root spawn ListRepos();
            repos = rResult.reports[0] if rResult.reports else [];
            toast.success(
                "Merged pull requests and closed issues will move their cards to Done"
                    if enabled
                    else "Moving cards to Done turned off"
            );
        } else {
            toast.error("Could not update that repository");
        }
    } except Exception as e {
        toast.error("Could not update that repository");
    }
}

impl GithubSection.toggleAutoClose(rid: str, enabled: bool) -> None {
    try {
        result = root spawn SetRepoAutoClose(repo_id=rid, enabled=enabled);
        payload = result.reports[0] if result.reports else None;
        if payload and payload["ok"] {
            rResult = root spawn ListRepos();
            repos = rResult.reports[0] if rResult.reports else [];
            toast.success(
                "Cards reaching Done will close their GitHub issue, and reopen it when moved back"
                    if enabled
                    else "Closing issues from Flowline turned off"
            );
        } else {
            toast.error("Could not update that repository");
        }
    } except Exception as e {
        toast.error("Could not update that repository");
    }
}

impl GithubSection.attachRepo(fullName: str) -> None {
    if attaching {
        return;
    }
    project = pickerProject;
    if not project {
        toast.error("Pick the project its issues land in first");
        return;
    }
    attaching = fullName;
    try {
        result = root spawn AddRepo(full_name=fullName, project_id=project);
        added = result.reports[0] if result.reports else None;
        await loadWorkspace();
        await searchRepos();
        # Land on the repository that was just added, so the panes show it
        # when the dialog closes.
        if added {
            selectRepo(added.id);
        }
        toast.success("Added " + fullName);
    } except Exception as e {
        toast.error("Could not add " + fullName);
    }
    attaching = "";
}

impl GithubSection.loadIssues(reset: bool) -> None {
    if not repoId {
        return;
    }
    wanted = 1;
    if reset {
        issueLoading = True;
    } else {
        issueMore = True;
        wanted = issuePage + 1;
    }
    # Read the rows once, here. Reading `issues` back after the walker call
    # would hand us the render-time snapshot and silently drop this page.
    base: list[GhIssueRow] = issues;
    if reset {
        base = [];
    }
    q = searchQuery.strip();
    blank: dict[str, any] = {};
    try {
        result = (
            root spawn SearchRepoItems(
                repo_id=repoId, kind="issues", query=q, state=issueState, page=wanted
            )
        )
            if q
            else (
                root spawn ListRepoIssues(repo_id=repoId, state=issueState, page=wanted)
            );
        payload = result.reports[0] if result.reports else blank;
        if payload["ok"] {
            issues = base + (payload["rows"] or []);
            issuePage = payload["page"] or wanted;
            issueHasMore = bool(payload["has_more"]);
            if reset {
                selected = [];
            }
        } else {
            toast.error(payload["message"] or "GitHub would not list those issues");
        }
    } except Exception as e {
        toast.error("Could not load issues");
    }
    issueLoading = False;
    issueMore = False;
}

impl GithubSection.loadPulls(reset: bool) -> None {
    if not repoId {
        return;
    }
    wanted = 1;
    if reset {
        prLoading = True;
    } else {
        prMore = True;
        wanted = prPage + 1;
    }
    base: list[GhPrRow] = pulls;
    if reset {
        base = [];
    }
    q = searchQuery.strip();
    blank: dict[str, any] = {};
    try {
        result = (
            root spawn SearchRepoItems(
                repo_id=repoId, kind="pulls", query=q, state=prState, page=wanted
            )
        )
            if q
            else (root spawn ListRepoPulls(repo_id=repoId, state=prState, page=wanted));
        payload = result.reports[0] if result.reports else blank;
        if payload["ok"] {
            pulls = base + (payload["rows"] or []);
            prPage = payload["page"] or wanted;
            prHasMore = bool(payload["has_more"]);
        } else {
            toast.error(
                payload["message"] or "GitHub would not list those pull requests"
            );
        }
    } except Exception as e {
        toast.error("Could not load pull requests");
    }
    prLoading = False;
    prMore = False;
}

impl GithubSection.toggleIssue(number: int) -> None {
    if number in selected {
        selected = [
            n
            for n in selected
            if n != number
        ];
    } else {
        selected = selected + [number];
    }
}

impl GithubSection.selectRepo(value: str) -> None {
    repoId = value;
    issues = [];
    pulls = [];
    selected = [];
    issuePage = 1;
    prPage = 1;
    importProject = "none";
}

impl GithubSection.runSearch -> None {
    # Only commit the query; the dependent effect owns the fetch. Calling a
    # loader here would read the pre-commit searchQuery snapshot and search
    # for the previous term.
    searchQuery = searchDraft.strip();
}

impl GithubSection.clearSearch -> None {
    searchDraft = "";
    searchQuery = "";
}

impl GithubSection.importSelected -> None {
    if importing or not selected {
        return;
    }
    importing = True;
    blank: dict[str, any] = {};
    try {
        # An explicit pick (repo attached without a project) wins; empty
        # project_id makes ImportIssues inherit the repo's own project.
        project = importProject if importProject != "none" else "";
        result = root spawn ImportIssues(
            repo_id=repoId,
            numbers=selected,
            project_id=project,
            status=importStatus,
            step_id=importStep
        );
        payload = result.reports[0] if result.reports else blank;
        if payload["ok"] {
            made = len(payload["imported"] or []);
            skipped = len(payload["skipped"] or []);
            failed = len(payload["failed"] or []);
            note = str(made) + " imported";
            if skipped {
                note = note + ", " + str(skipped) + " already on the board";
            }
            if failed {
                note = note + ", " + str(failed) + " GitHub would not return";
            }
            toast.success(note);
            selected = [];
            await loadIssues(True);
            # The board is a separate tree; without this it would not show the
            # new cards until its next poll.
            w: any = window;
            w.dispatchEvent(new(w.CustomEvent, "flowline:refresh"));
        } else {
            toast.error(payload["message"] or "Could not import those issues");
        }
    } except Exception as e {
        toast.error("Could not import those issues");
    }
    importing = False;
}
