"""Implementations for the GitHub page. Every walker except GithubStatus
answers one envelope dict, so handlers read `payload["ok"]` and surface
`payload["message"]`: only the server knows why GitHub said no.
"""

impl GithubSection.boot -> None {
    # Finish GitHub's install round trip before anything reads status, then
    # scrub the params: the nonce burns on first use, so a replay only errors.
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
    if installation and state {
        installId = 0;
        try {
            installId = int(installation);
        } except Exception as e {
            installId = 0;
        }
        blank: dict[str, any] = {};
        try {
            result = root spawn CompleteGithubInstall(
                code=code, installation_id=installId, state=state
            );
            payload = result.reports[0] if result.reports else blank;
            window.history.replaceState(blank, "", window.location.pathname);
            if payload["ok"] {
                toast("GitHub connected");
            } else {
                toast(payload["message"] or "That install could not be finished.");
            }
        } except Exception as e {
            window.history.replaceState(blank, "", window.location.pathname);
            toast("Could not finish the GitHub install");
        }
    }
    await loadStatus();
    await loadWorkspace();
    loading = False;
}

impl GithubSection.loadStatus -> None {
    try {
        result = root spawn GithubStatus();
        view = result.reports[0] if result.reports else None;
        if view {
            conn = view;
            configGaps = view.missing_config;
        }
    } except Exception as e {
        toast("Could not read the GitHub connection");
    }
}

impl GithubSection.loadWorkspace -> None {
    try {
        rResult = root spawn ListRepos();
        pResult = root spawn ListProjects();
        sResult = root spawn GetWorkflow();
        fetched = rResult.reports[0] if rResult.reports else [];
        repos = fetched;
        projects = pResult.reports[0] if pResult.reports else [];
        # The "as" picker offers the org's own workflow steps; imports land on
        # the start step by default (where new work lands). An org with no
        # workflow keeps the legacy status list instead.
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
        toast("Could not load this workspace's repos");
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
            toast(payload["message"] or "Could not start the GitHub install");
        }
    } except Exception as e {
        toast("Could not start the GitHub install");
    }
    starting = False;
}

impl GithubSection.disconnect -> None {
    # Two clicks, no dialog: the first arms the button and reveals what is and
    # is not lost, the second does it.
    if not confirmDisconnect {
        confirmDisconnect = True;
        return;
    }
    confirmDisconnect = False;
    try {
        root spawn DisconnectGithub();
        repoId = "";
        issues = [];
        pulls = [];
        selected = [];
        pickerRows = [];
        await loadStatus();
        toast("Disconnected from GitHub");
    } except Exception as e {
        toast("Could not disconnect from GitHub");
    }
}

impl GithubSection.openPicker -> None {
    pickerOpen = True;
    await searchRepos();
}

impl GithubSection.searchRepos -> None {
    pickerLoading = True;
    blank: dict[str, any] = {};
    try {
        result = root spawn ListGithubRepos(query=pickerQuery.strip());
        payload = result.reports[0] if result.reports else blank;
        if payload["ok"] {
            pickerRows = payload["rows"] or [];
        } else {
            pickerRows = [];
            toast(payload["message"] or "GitHub would not list your repositories");
        }
    } except Exception as e {
        toast("Could not reach GitHub");
    }
    pickerLoading = False;
}

impl GithubSection.attachRepo(fullName: str) -> None {
    if attaching {
        return;
    }
    attaching = fullName;
    project = pickerProject if pickerProject != "none" else "";
    try {
        root spawn AddRepo(full_name=fullName, project_id=project);
        await loadWorkspace();
        await searchRepos();
        toast("Attached " + fullName);
    } except Exception as e {
        toast("Could not attach " + fullName);
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
                repo_id=repoId, kind="issues", query=q,
                state=issueState, page=wanted
            )
        ) if q else (
            root spawn ListRepoIssues(
                repo_id=repoId, state=issueState, page=wanted
            )
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
            toast(payload["message"] or "GitHub would not list those issues");
        }
    } except Exception as e {
        toast("Could not load issues");
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
                repo_id=repoId, kind="pulls", query=q,
                state=prState, page=wanted
            )
        ) if q else (
            root spawn ListRepoPulls(
                repo_id=repoId, state=prState, page=wanted
            )
        );
        payload = result.reports[0] if result.reports else blank;
        if payload["ok"] {
            pulls = base + (payload["rows"] or []);
            prPage = payload["page"] or wanted;
            prHasMore = bool(payload["has_more"]);
        } else {
            toast(payload["message"] or "GitHub would not list those pull requests");
        }
    } except Exception as e {
        toast("Could not load pull requests");
    }
    prLoading = False;
    prMore = False;
}

impl GithubSection.toggleIssue(number: int) -> None {
    if number in selected {
        selected = [n for n in selected if n != number];
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
    project = importProject if importProject != "none" else "";
    blank: dict[str, any] = {};
    try {
        result = root spawn ImportIssues(
            repo_id=repoId, numbers=selected, project_id=project,
            status=importStatus, step_id=importStep
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
            toast(note);
            selected = [];
            await loadIssues(True);
            # The board is a separate tree; without this it would not show the
            # new cards until its next poll.
            w: any = window;
            w.dispatchEvent(new(w.CustomEvent, "standup:refresh"));
        } else {
            toast(payload["message"] or "Could not import those issues");
        }
    } except Exception as e {
        toast("Could not import those issues");
    }
    importing = False;
}
