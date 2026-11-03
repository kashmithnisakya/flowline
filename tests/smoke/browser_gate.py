#!/usr/bin/env python3
"""Playwright smoke against a running server: sign up, finish the three-step
setup wizard on the Simple template, land on the board with the create dialog
open, create a task from the board's New task button and see its card survive
a reload, check the runtime reads the served effects table, reads /user/me
once and mounts the pages after the board on the cached workspace until a
roster write drops it, turn on AI on its page and give a role code review,
check a proposal from Ask is drawn dashed until it is applied, then land
on GitHub's install redirect and check the page finishes it with exactly one
callback. Every step is a real click or keystroke, so a dead button fails here.
Usage: browser_gate.py [base_url] [stub_url]"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request
import uuid

from playwright.sync_api import expect, sync_playwright

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000").rstrip("/")
STUB = (sys.argv[2] if len(sys.argv) > 2 else "http://127.0.0.1:8099").rstrip("/")
INSTALLATION = 4242
STEP_TIMEOUT_MS = 45_000


def step(name: str) -> None:
    print(f"step  {name}", flush=True)


def settle(page, url_tail: str, title: str) -> None:
    # A hard navigation can fire more than once (an app page mounts twice on
    # a full load and repeats its redirect), which aborts the earlier document.
    # Act only on a document that survives a quiet moment.
    # page.url is a plain property: wait_for_url tracks a navigation and
    # raises ERR_ABORTED when the app's repeated redirect cancels it.
    deadline = time.time() + STEP_TIMEOUT_MS / 1000
    while not re.search(url_tail + "$", page.url):
        if time.time() > deadline:
            raise TimeoutError(f"still on {page.url}, expected {url_tail}")
        page.wait_for_timeout(250)
    for _ in range(20):
        token = uuid.uuid4().hex
        try:
            page.evaluate("t => { window.__gate_token = t; }", token)
            page.wait_for_timeout(1500)
            if page.evaluate("() => window.__gate_token") == token:
                break
        except Exception:
            page.wait_for_timeout(500)
    expect(page.get_by_text(title).filter(visible=True).first).to_be_visible()


TRANSIENT = ("ERR_ABORTED", "detached", "context was destroyed", "navigating")


def act(page, fn, tries: int = 3):
    # Retry an action the page replaced out from under us.
    for attempt in range(tries):
        try:
            return fn()
        except Exception as exc:
            if attempt == tries - 1 or not any(k in str(exc) for k in TRANSIENT):
                raise
            page.wait_for_timeout(1500)


def run(page, tag: str) -> list[str]:
    email = f"ui-{tag}@flowline-ci.invalid"
    password = f"Pw-{tag}-Xy7!"
    title = f"UI task {tag}"

    step("sign up")
    page.goto(f"{BASE}/login?mode=signup")
    expect(page.get_by_role("heading", name="Start your first flow line.")).to_be_visible()
    page.get_by_placeholder("you@company.com").fill(email)
    page.get_by_placeholder("••••••••••").fill(password)
    page.get_by_role("button", name="Create workspace", exact=True).click()

    step("setup wizard: workspace and first project, Enter submits")
    settle(page, "/setup", "Name your workspace")
    act(page, lambda: page.get_by_placeholder("Acme Robotics").fill("CI Org"))
    expect(page.get_by_text("Your name", exact=True)).to_have_count(0)
    page.get_by_placeholder("Website redesign").fill("CI Project")
    page.get_by_placeholder("Website redesign").press("Enter")

    step("setup wizard: add a person by first and last name")
    expect(page.get_by_role("heading", name="Who works on CI Project?")).to_be_visible()
    page.get_by_placeholder("First name").fill("Priya")
    page.get_by_placeholder("Last name").fill("Raman")
    page.get_by_role("button", name="Add", exact=True).click()
    expect(page.get_by_text("Priya Raman", exact=True)).to_be_visible()
    page.get_by_role("button", name="Continue", exact=True).click()

    step("setup wizard: how work moves, Simple preselected")
    expect(page.get_by_role("heading", name="How does work move?")).to_be_visible()
    expect(page.get_by_role("radio", name="Simple")).to_have_attribute("aria-checked", "true")
    page.get_by_role("button", name="Open the board", exact=True).click()

    step("board: opens with the create dialog on the template's steps")
    settle(page, "/board", "Board")
    dialog = page.locator("[data-new-task]")
    expect(dialog).to_be_visible()
    dialog.get_by_role("button", name="Cancel", exact=True).click()
    expect(dialog).to_be_hidden()
    columns = ["To do", "Doing", "Review", "Done"]
    for column in columns:
        expect(page.get_by_text(column, exact=True).filter(visible=True).first).to_be_visible()
    # Visible text alone could match a word elsewhere on the page, so the
    # flow line the wizard applied is checked exactly as well.
    steps = page.evaluate(
        """async (base) => {
            const r = await fetch(base + "/walker/GetFlowLine", {
                method: "POST",
                headers: {"Content-Type": "application/json",
                          "Authorization": "Bearer " + localStorage.getItem("jac_token")},
                body: JSON.stringify({with_counts: false}),
            });
            const d = await r.json();
            const reports = d.reports || (d.data && (d.data.reports
                || (d.data.result && d.data.result.reports))) || [];
            return (reports[0] || []).map((s) => [s.name, s.kind]);
        }""",
        BASE,
    )
    expected = [[n, k] for n, k in zip(columns, ["start", "active", "handoff", "done"])]
    assert steps == expected, f"setup applied {steps}, expected {expected}"

    step("board: open via the project's tabs")
    page.get_by_role("link", name="Board", exact=True).click()
    settle(page, "/board", "Board")

    step("board: create a task")
    act(page, lambda: page.get_by_role("button", name="New task", exact=True).click())
    dialog = page.locator("[data-new-task]")
    expect(dialog).to_be_visible()
    title_input = dialog.locator("[data-task-title]")
    title_input.click()
    title_input.press_sequentially(title)
    expect(dialog.get_by_role("button", name="Create task", exact=True)).to_be_enabled()
    dialog.get_by_role("button", name="Create task", exact=True).click()
    expect(dialog).to_be_hidden()

    step("board: the task row renders and survives a reload")
    card = page.get_by_role("button", name=title)
    expect(card).to_be_visible()
    page.reload()
    expect(page.get_by_role("button", name=title)).to_be_visible()

    step("board: the row opens the sheet, and Save shows only after an edit")
    page.get_by_role("button", name=title).first.click()
    dialog = page.locator("[data-task-sheet]")
    expect(dialog.get_by_label("Title", exact=True)).to_have_value(title)
    expect(dialog.get_by_role("button", name="Save", exact=True)).to_have_count(0)
    dialog.get_by_label("Title", exact=True).press_sequentially(" edited")
    expect(dialog.get_by_role("button", name="Save", exact=True)).to_be_visible()
    dialog.get_by_label("Title", exact=True).fill(title)
    expect(dialog.get_by_role("button", name="Save", exact=True)).to_have_count(0)
    dialog.get_by_role("button", name="Close", exact=True).click()
    expect(dialog).to_be_hidden()

    step("flow line, roadmap and overview pages render")
    page.get_by_role("link", name="Flow line", exact=True).click()
    settle(page, "/flowlines", "Flow line")
    page.get_by_role("link", name="Roadmap", exact=True).click()
    roadmap_open(page)
    page.get_by_role("link", name="Overview", exact=True).click()
    expect(page.get_by_role("heading", name="Overview", exact=True)).to_be_visible()

    read_cache_once(page)
    page_scroll_once(page)
    ai_switch_once(page)
    ai_responsibility_once(page)
    ask_proposal_once(page)
    github_install_once(page)
    ai_run_once(page)
    return []


def roadmap_open(page) -> None:
    # The roadmap has no title of its own: its project tab says where we are.
    expect(page.get_by_role("link", name="Roadmap", exact=True)).to_have_attribute("aria-current", "page")


def ai_switch_once(page) -> None:
    # The AI page's switch: off in a new workspace, beside what it sends, and
    # turning it on asks first and survives a reload.
    step("ai: the switch starts off beside what it sends")
    page.goto(f"{BASE}/ai")
    switch = page.get_by_role("switch", name="AI responsibilities")
    expect(switch).to_have_attribute("aria-checked", "false")
    expect(page.get_by_text("The task's title and the first line of its notes.", exact=True)).to_be_visible()

    step("ai: turning it on asks first, and an answer of no keeps it off")
    switch.click()
    dialog = page.locator("[role=dialog][data-state=open]")
    expect(dialog.get_by_text("Turn on AI responsibilities?", exact=True)).to_be_visible()
    dialog.get_by_role("button", name="Keep it off", exact=True).click()
    expect(dialog).to_be_hidden()
    expect(switch).to_have_attribute("aria-checked", "false")

    step("ai: turning it on is kept across a reload")
    switch.click()
    dialog = page.locator("[role=dialog][data-state=open]")
    dialog.get_by_role("button", name="Turn on", exact=True).click()
    expect(page.get_by_text("AI responsibilities turned on", exact=True)).to_be_visible()
    expect(switch).to_have_attribute("aria-checked", "true")
    page.reload()
    switch = page.get_by_role("switch", name="AI responsibilities")
    expect(switch).to_have_attribute("aria-checked", "true")
    expect(page.get_by_text(re.compile(r"^On since "))).to_be_visible()


def ai_responsibility_once(page) -> None:
    # A role made in Workspace gets code review on the AI page, with its own
    # instructions and mode, and both read back after a reload.
    step("ai: add a role, then give it AI code review")
    page.goto(f"{BASE}/workspace?tab=roles")
    page.get_by_role("button", name="Add role", exact=True).first.click()
    page.get_by_placeholder("Role name").fill("Reviewer")
    page.get_by_role("button", name="Add role", exact=True).last.click()
    expect(page.get_by_role("link", name="Add AI to Reviewer", exact=True)).to_be_visible()
    page.get_by_role("link", name="Add AI to Reviewer", exact=True).click()
    expect(page.get_by_role("heading", name="AI", exact=True)).to_be_visible()
    page.get_by_role("button", name="AI code review", exact=True).click()
    dialog = page.locator("[role=dialog][data-state=open]")
    expect(dialog.get_by_text("Code review for Reviewer", exact=True)).to_be_visible()
    dialog.get_by_role("button", name="Request changes", exact=True).click()
    dialog.get_by_label("Instructions").fill("Check error handling.")
    dialog.get_by_role("button", name="Save", exact=True).click()
    expect(dialog).to_be_hidden()

    step("ai: the responsibility reads back after a reload")
    page.reload()
    line = page.get_by_role("button", name=re.compile(r"^AI code review · .*may request changes"))
    expect(line).to_be_visible()
    line.click()
    dialog = page.locator("[role=dialog][data-state=open]")
    expect(dialog.get_by_label("Instructions")).to_have_value("Check error handling.")
    expect(dialog.get_by_role("button", name="Request changes", exact=True)).to_have_attribute("aria-pressed", "true")
    dialog.get_by_role("button", name="Cancel", exact=True).click()
    expect(dialog).to_be_hidden()


def ask_proposal_once(page) -> None:
    # Ask's one input, with the model's answer stood in: CI has no model, and
    # what is under test is what the client does with a proposal. It is drawn
    # dashed on the board, nothing is saved, and Apply creates it.
    title = "Proposed by the gate"
    reply = {"kind": "change", "text": "", "proposal": {
        "kind": "create_task", "title": title, "project": "", "assignee": "", "status": "",
        "priority": "", "category": "", "due_date": "", "note": "", "confidence": "high"}}

    def answer(route) -> None:
        route.fulfill(status=200, content_type="application/json",
                      body=json.dumps({"ok": True, "data": {"result": {}, "reports": [reply]}}))

    step("ask: one input, and a change comes back as a dashed row on the board")
    page.route("**/walker/AskOrPropose", answer)
    page.goto(f"{BASE}/board")
    settle(page, "/board", "Board")
    page.get_by_role("button", name=re.compile(r"^Ask")).first.click()
    composer = page.get_by_label("Ask, or describe a change", exact=True)
    composer.fill("Add a task for the gate")
    composer.press("Enter")
    card = page.locator("[data-proposal-card=pending]")
    expect(card.get_by_text(title, exact=True)).to_be_visible()
    row = page.locator("[data-proposal]")
    expect(row.get_by_text(title, exact=True)).to_be_visible()
    # The gate's window is 1280 wide, where docked Ask leaves the board the least
    # room: the columns give way so the title still reads in full.
    assert row.get_by_text(title, exact=True).evaluate("e => e.scrollWidth <= e.clientWidth"), "docked Ask squeezed the title"
    heads = page.locator("[data-board-heads]")
    expect(heads.get_by_text("Due", exact=True)).to_be_visible()
    expect(heads.get_by_text("GitHub", exact=True)).to_be_hidden()
    assert api(page, "ListTasks", {"scope": "all", "q": title}).get("total") == 0, "a proposal saved a task"

    step("ask: Apply makes it a real task and the dashed row goes")
    card.get_by_role("button", name="Apply", exact=True).click()
    expect(page.locator("[data-proposal-card=applied]")).to_be_visible()
    expect(row).to_have_count(0)
    expect(page.get_by_role("button", name=title)).to_be_visible()
    page.unroute("**/walker/AskOrPropose")
    page.get_by_role("button", name="Close Ask", exact=True).click()


def read_cache_once(page) -> None:
    # The runtime caches a pure reader for 60 s through the effects table the
    # shell serves in __jac_init__. A client-imported module that owns a
    # server def:pub registers a partial table at load, which shadows the
    # served one and sends every walker down the writer path (issue #224):
    # so the table is empty before the first spawn and the served size after.
    step("cache: no module registers an effects table before the first spawn")
    page.goto(f"{BASE}/")
    expect(page.get_by_role("heading").first).to_be_visible()
    early = page.evaluate("() => Object.keys(globalThis.__jacEndpointEffects__ || {}).length")
    assert early == 0, f"a client module registered {early} effects rows at load"

    step("cache: after the board's first spawn the runtime holds the served table")
    hits: list[str] = []
    page.on("request", lambda r: hits.append(r.url)
            if r.url.endswith("/walker/GetWorkspace") or r.url.endswith("/user/me") else None)
    page.goto(f"{BASE}/board")
    settle(page, "/board", "Board")
    served = page.evaluate(
        """() => Object.keys(JSON.parse(document.getElementById("__jac_init__").textContent)
                 .endpointEffects || {}).length"""
    )
    used = page.evaluate("() => Object.keys(globalThis.__jacEndpointEffects__ || {}).length")
    assert served > 20 and used == served, f"runtime holds {used} effects rows, the shell serves {served}"

    # The board's snapshot primes the app's workspace cache (lib/workspace),
    # so the pages after it mount on it without a request.
    step("cache: board, flow line, roadmap, board make no GetWorkspace and one /user/me")
    page.get_by_role("link", name="Flow line", exact=True).click()
    settle(page, "/flowlines", "Flow line")
    page.get_by_role("link", name="Roadmap", exact=True).click()
    roadmap_open(page)
    page.get_by_role("link", name="Board", exact=True).click()
    settle(page, "/board", "Board")
    page.wait_for_timeout(1500)
    workspace = [u for u in hits if u.endswith("/walker/GetWorkspace")]
    me = [u for u in hits if u.endswith("/user/me")]
    assert not workspace, f"GetWorkspace was requested {len(workspace)} times, expected none"
    assert len(me) == 1, f"/user/me was requested {len(me)} times, expected 1"

    # The workspace page loads its lists once and the sections render from
    # props, so a jump between sections is a scroll, not a request (issue #228).
    step("cache: jumping between the workspace's sections makes no request")
    calls: list[str] = []
    page.on("request", lambda r: calls.append(r.url) if "/walker/" in r.url or "/user/" in r.url else None)
    page.get_by_role("link", name="Workspace", exact=True).click()
    expect(page.get_by_role("heading", name="Organization", exact=True)).to_be_visible()
    page.wait_for_timeout(1000)
    del calls[:]
    for tab, marker in (("people", "Add person"), ("projects", "New project"), ("roles", "Add role"),
                        ("preferences", "Preferences"), ("organization", "Organization")):
        page.locator(f'a[href="/workspace?tab={tab}"]').first.click()
        expect(page.get_by_text(marker, exact=True).first).to_be_visible()
    page.wait_for_timeout(1000)
    assert not calls, f"tab switches made {len(calls)} requests: {calls}"

    # A roster write drops the cache: the page's own refetch is the one request,
    # and the overview then mounts on it.
    step("cache: a People save then the overview makes exactly one GetWorkspace")
    page.locator('a[href="/workspace?tab=people"]').first.click()
    expect(page.get_by_role("button", name="Add person", exact=True).first).to_be_visible()
    page.wait_for_timeout(1000)
    del hits[:]
    page.get_by_role("button", name="Add person", exact=True).first.click()
    dialog = page.locator("[role=dialog][data-state=open]")
    expect(dialog).to_be_visible()
    dialog.get_by_placeholder("First name").fill("Cache")
    dialog.get_by_placeholder("Last name").fill("Probe")
    dialog.get_by_role("button", name="Add person", exact=True).click()
    expect(dialog).to_be_hidden()
    expect(page.get_by_text("Cache Probe", exact=True).first).to_be_visible()
    page.get_by_role("link", name="Overview", exact=True).click()
    expect(page.get_by_role("heading", name="Overview", exact=True)).to_be_visible()
    page.wait_for_timeout(1500)
    workspace = [u for u in hits if u.endswith("/walker/GetWorkspace")]
    assert len(workspace) == 1, f"GetWorkspace was requested {len(workspace)} times after the save, expected 1"
    assert not [u for u in hits if u.endswith("/user/me")], "/user/me was requested again after the first load"


def page_scroll_once(page) -> None:
    # A page change opens at the top rather than keeping the last page's scroll;
    # a link to a section on the new page still lands on that section.
    def scrolled_overview() -> None:
        page.goto(f"{BASE}/overview")
        settle(page, "/overview", "Overview")
        page.evaluate("window.scrollTo({top: 400, behavior: 'instant'})")
        page.wait_for_function("window.scrollY > 100")

    step("scroll: a new page opens at its top")
    scrolled_overview()
    page.get_by_role("link", name="Workspace", exact=True).filter(visible=True).first.click()
    expect(page.get_by_role("heading", name="Workspace", exact=True).filter(visible=True).first).to_be_visible()
    page.wait_for_timeout(400)
    assert page.evaluate("window.scrollY") == 0, "the new page kept the last page's scroll"

    step("scroll: a link to a section still lands on it")
    scrolled_overview()
    page.get_by_role("button", name="New project", exact=True).filter(visible=True).first.click()
    page.wait_for_function("window.location.search.includes('tab=projects') && window.scrollY > 100")


def github_install_once(page) -> None:
    # GitHub redirects back once, with a single-use code. The page mounts
    # twice on that load (see CLAUDE.md), and issue #187 was the second mount
    # firing the callback again: the two calls raced and left the connection
    # blank. So the assertion is the request count, not only the end state.
    step("github: the stub owns one installation")
    body = json.dumps({"installations": [INSTALLATION], "repos": {}}).encode()
    req = urllib.request.Request(f"{STUB}/_stub/reset", data=body, method="POST",
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        assert resp.status == 200, f"stub reset {resp.status}"

    step("github: start the install to get this workspace's nonce")
    url = page.evaluate(
        """async (base) => {
            const r = await fetch(base + "/walker/StartGithubInstall", {
                method: "POST",
                headers: {"Content-Type": "application/json",
                          "Authorization": "Bearer " + localStorage.getItem("jac_token")},
                body: "{}",
            });
            const d = await r.json();
            const reports = (d.data && d.data.reports) || d.reports || [];
            return (reports[0] && reports[0].url) || JSON.stringify(reports[0] || d);
        }""",
        BASE,
    )
    # A dumped payload holds the URL as text, so parsing it would yield a garbage state.
    state = ""
    if url.startswith("http"):
        state = urllib.parse.parse_qs(urllib.parse.urlparse(url).query).get("state", [""])[0]
    assert state, f"StartGithubInstall gave no install URL: {url[:200]}"

    step("github: land on the redirect and finish the install once")
    callbacks: list[str] = []
    answers: list[str] = []
    page.on("request", lambda r: callbacks.append(r.url) if r.url.endswith("/walker/CompleteGithubInstall") else None)

    def record(resp) -> None:
        if resp.url.endswith("/walker/CompleteGithubInstall"):
            try:
                answers.append(f"{resp.status} {resp.text()[:1500]}")
            except Exception as exc:  # the document may be gone
                answers.append(f"{resp.status} <body unreadable: {exc}>")

    page.on("response", record)
    page.goto(f"{BASE}/github?code=stub-code&installation_id={INSTALLATION}"
              f"&setup_action=install&state={state}&tab=github")
    # The install lands on /github, which renders the Workspace's GitHub
    # section and moves the address to /workspace?tab=github once it is done.
    settle(page, r"/(github|workspace\?tab=github)", "GitHub")
    try:
        expect(page.get_by_text("@stub-org", exact=True)).to_be_visible()
        expect(page.get_by_role("button", name="Disconnect", exact=True)).to_be_visible()
    except AssertionError as exc:
        # The server's answer says which check the callback tripped.
        raise AssertionError(f"install did not finish; callback answers: {answers}") from exc
    page.wait_for_timeout(1500)
    assert len(callbacks) == 1, f"CompleteGithubInstall was called {len(callbacks)} times, expected exactly 1"

    # The GitHub poll runs on the server's schedule: a board open with a
    # connected workspace spawns no SyncGithub, and drains the webhook queue
    # only on its timers (none inside the first seconds of a quiet one).
    step("github: a board open makes no sync call")
    syncs: list[str] = []
    page.on("request", lambda r: syncs.append(r.url)
            if r.url.endswith("/walker/SyncGithub") or r.url.endswith("/walker/DrainGithubEvents") else None)
    page.goto(f"{BASE}/board")
    settle(page, "/board", "Board")
    page.wait_for_timeout(3000)
    assert not syncs, f"the board open called {syncs}"


def api(page, name: str, body: dict):
    """A walker call as the signed-in browser makes it; the first report."""
    return page.evaluate(
        """async ([base, name, body]) => {
            const r = await fetch(base + "/walker/" + name, {
                method: "POST",
                headers: {"Content-Type": "application/json",
                          "Authorization": "Bearer " + localStorage.getItem("jac_token")},
                body: JSON.stringify(body),
            });
            const d = await r.json();
            const reports = (d.data && d.data.reports) || d.reports || [];
            return reports[0];
        }""",
        [BASE, name, body],
    )


def ai_run_once(page) -> None:
    # The task sheet's AI reviews: Reviewer (given code review above) owns
    # Review, a task with a linked PR lands there, and the sheet follows the
    # run from the queue to the review on its own (the runner's fake model).
    step("ai: Review is the Reviewer's, and a task with a PR lands there")
    repo = "stub-org/ai-repo"
    body = json.dumps({"pulls": [{"repo": repo, "number": 5, "head_sha": "sha-5"}]}).encode()
    req = urllib.request.Request(f"{STUB}/_stub/pulls", data=body, method="POST",
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        assert resp.status == 200, f"stub pulls {resp.status}"
    steps = {st["name"]: st for st in api(page, "GetFlowLine", {"with_counts": False})}
    api(page, "SaveStep", {"step_id": steps["Review"]["id"], "owner": "Reviewer"})
    first = (api(page, "ListProjects", {}) or [{}])[0]
    project_id = first.get("id") or first.get("_jac_id", "")
    made = api(page, "CreateTask", {"title": "Reviewed by AI", "project_id": project_id,
                                    "step_id": steps["Doing"]["id"]})
    fields = {k: made.get(k, "") for k in ("title", "category", "priority", "status", "step_id", "due_date",
                                           "start_date", "notes", "issue_link", "reviewer_id", "review_due",
                                           "project_id")}
    fields.update({"task_id": made["id"], "tags": [], "estimate": 0.0, "assignee_ids": [],
                   "pr_link": f"https://github.com/{repo}/pull/5"})
    api(page, "UpdateTask", fields)
    landed = api(page, "MoveTask", {"task_id": made["id"], "step_id": steps["Review"]["id"]})
    assert landed.get("ai_state") == "queued", f"the move reported {landed.get('ai_state')!r}, expected 'queued'"

    step("ai: the flow line marks Review, the sheet shows the run reviewed")
    page.goto(f"{BASE}/flowlines")
    settle(page, "/flowlines", "Flow line")
    expect(page.locator(f"[data-step='{steps['Review']['id']}'] [data-step-ai]")).to_be_visible()
    page.goto(f"{BASE}/board?task={made['id']}")
    settle(page, "/board", "Board")
    runs = page.get_by_role("region", name="AI reviews")
    expect(runs).to_be_visible()
    expect(runs.get_by_text("Commented", exact=True)).to_be_visible(timeout=90_000)
    expect(runs.get_by_role("link", name="View on GitHub")).to_be_visible()
    # The settled run refetches the task, so the row's chip settles with it.
    row = page.locator(f"[data-task-row='{made['id']}']")
    expect(row.locator(".ai-chip").filter(visible=True)).to_have_text("Reviewed", timeout=15_000)

    step("ai: the AI page lists the run with its task")
    page.goto(f"{BASE}/ai")
    expect(page.get_by_role("link", name="Reviewed by AI", exact=True)).to_be_visible()
    expect(page.get_by_text("Commented", exact=True)).to_be_visible()


def main() -> int:
    tag = uuid.uuid4().hex[:8]
    page_errors: list[str] = []
    console_errors: list[str] = []
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        context = browser.new_context(viewport={"width": 1280, "height": 900})
        page = context.new_page()
        page.set_default_timeout(STEP_TIMEOUT_MS)
        page.on("pageerror", lambda err: page_errors.append(str(err)))
        page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)
        try:
            run(page, tag)
        except Exception as exc:  # report the step, keep the screenshot
            page.screenshot(path="browser_gate_failure.png", full_page=True)
            print(f"FAIL {exc}")
            print(f"url at failure: {page.url}")
            for line in page_errors:
                print(f"page error: {line}")
            return 1
        finally:
            browser.close()
    for line in page_errors:
        print(f"page error: {line}")
    if page_errors:
        print("browser gate: FAIL (uncaught page errors)")
        return 1
    if console_errors:
        print(f"note: {len(console_errors)} console error line(s), first: {console_errors[0][:200]}")
    print("browser gate: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
