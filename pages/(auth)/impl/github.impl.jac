"""Implementations for the GitHub page.

Every walker here except GithubStatus answers with one envelope dict, so each
handler reads `payload["ok"]` and surfaces `payload["message"]` rather than
inventing its own wording: only the server knows whether GitHub was
unreachable, unconfigured, or simply said no.
"""

impl GithubPage.boot -> None {
    # GitHub redirects the install round trip back to this page. Finish it
    # before anything reads status, then scrub the params: the nonce is burned
    # server-side on first use, so a replay could only produce an error.
    # URLSearchParams is absent from the checker's DOM typings, so it is
    # reached through an `any` handle on window.
    w: any = window;
    params: any = new(w.URLSearchParams, w.location.search);
    installation = params.get("installation_id") or "";
    state = params.get("state") or "";
    code = params.get("code") or "";
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

impl GithubPage.loadStatus -> None {
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

impl GithubPage.loadWorkspace -> None {
    try {
        rResult = root spawn ListRepos();
        pResult = root spawn ListProjects();
        fetched = rResult.reports[0] if rResult.reports else [];
        repos = fetched;
        projects = pResult.reports[0] if pResult.reports else [];
        # Land on something readable rather than an empty picker. An explicit
        # choice already made is left alone.
        if not repoId and fetched {
            repoId = fetched[0].id;
        }
    } except Exception as e {
        toast("Could not load this workspace's repos");
    }
}

impl GithubPage.startInstall -> None {
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

impl GithubPage.disconnect -> None {
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

impl GithubPage.openPicker -> None {
    pickerOpen = True;
    await searchRepos();
}

impl GithubPage.searchRepos -> None {
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

impl GithubPage.attachRepo(fullName: str) -> None {
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

impl GithubPage.loadIssues(reset: bool) -> None {
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
    blank: dict[str, any] = {};
    try {
        result = root spawn ListRepoIssues(
            repo_id=repoId, state=issueState, page=wanted
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

impl GithubPage.loadPulls(reset: bool) -> None {
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
    blank: dict[str, any] = {};
    try {
        result = root spawn ListRepoPulls(
            repo_id=repoId, state=prState, page=wanted
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

impl GithubPage.toggleIssue(number: int) -> None {
    if number in selected {
        selected = [n for n in selected if n != number];
    } else {
        selected = selected + [number];
    }
}

impl GithubPage.selectRepo(value: str) -> None {
    repoId = value;
    issues = [];
    pulls = [];
    selected = [];
    issuePage = 1;
    prPage = 1;
}

impl GithubPage.importSelected -> None {
    if importing or not selected {
        return;
    }
    importing = True;
    project = importProject if importProject != "none" else "";
    blank: dict[str, any] = {};
    try {
        result = root spawn ImportIssues(
            repo_id=repoId, numbers=selected, project_id=project,
            status=importStatus
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
