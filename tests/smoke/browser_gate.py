#!/usr/bin/env python3
"""Playwright smoke against a running server: sign up, finish the three-step
setup wizard on the Simple template, land on the board with the create dialog
open, create a task from the board's New task button and see its card survive
a reload, check the runtime reads the served effects table, reads /user/me
once and mounts the pages after the board on the cached workspace until a
roster write drops it, then land
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
    expect(page.get_by_text(title).first).to_be_visible()


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
    password = f"Ui-{tag}-Xy7!"
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

    step("board: opens with the create dialog on the template's columns")
    settle(page, "/board", "Board")
    dialog = page.locator("[role=dialog][data-state=open]")
    expect(dialog).to_be_visible()
    expect(dialog.get_by_text("New task", exact=True)).to_be_visible()
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

    step("board: open via the nav")
    page.get_by_role("link", name="Board", exact=True).click()
    settle(page, "/board", "Board")

    step("board: create a task")
    act(page, lambda: page.get_by_role("button", name="New task", exact=True).click())
    dialog = page.locator("[role=dialog][data-state=open]")
    expect(dialog).to_be_visible()
    expect(dialog.get_by_text("New task", exact=True)).to_be_visible()
    title_input = dialog.locator("input[data-slot=input]").first
    title_input.click()
    title_input.press_sequentially(title)
    expect(dialog.get_by_role("button", name="Save", exact=True)).to_be_enabled()
    dialog.get_by_role("button", name="Save", exact=True).click()
    expect(dialog).to_be_hidden()

    step("board: the card renders and survives a reload")
    card = page.get_by_role("button", name=title)
    expect(card).to_be_visible()
    page.reload()
    expect(page.get_by_role("button", name=title)).to_be_visible()

    step("board: the card opens the dialog")
    page.get_by_role("button", name=title).first.click()
    dialog = page.locator("[role=dialog][data-state=open]")
    expect(dialog.get_by_text("Edit task", exact=True)).to_be_visible()
    dialog.get_by_role("button", name="Cancel", exact=True).click()
    expect(dialog).to_be_hidden()

    step("overview and log pages render")
    page.get_by_role("link", name="Overview", exact=True).click()
    expect(page.get_by_role("heading", name="Overview", exact=True)).to_be_visible()
    page.get_by_role("link", name="Log", exact=True).click()
    expect(page.get_by_role("heading", name="Log", exact=True)).to_be_visible()

    read_cache_once(page)
    github_install_once(page)
    return []


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
    step("cache: board, tasks, roadmap, board make no GetWorkspace and one /user/me")
    page.get_by_role("link", name="Tasks", exact=True).click()
    expect(page.get_by_role("heading", name="Tasks", exact=True)).to_be_visible()
    page.get_by_role("link", name="Roadmap", exact=True).click()
    expect(page.get_by_role("heading", name="Roadmap", exact=True)).to_be_visible()
    page.get_by_role("link", name="Board", exact=True).click()
    settle(page, "/board", "Board")
    page.wait_for_timeout(1500)
    workspace = [u for u in hits if u.endswith("/walker/GetWorkspace")]
    me = [u for u in hits if u.endswith("/user/me")]
    assert not workspace, f"GetWorkspace was requested {len(workspace)} times, expected none"
    assert len(me) == 1, f"/user/me was requested {len(me)} times, expected 1"

    # A roster write drops the cache: the People tab's own refetch is the one
    # request, and /tasks then mounts on it.
    step("cache: a People-tab save then tasks makes exactly one GetWorkspace")
    page.get_by_role("link", name="Workspace", exact=True).click()
    expect(page.get_by_role("heading", name="Organization", exact=True)).to_be_visible()
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
    page.get_by_role("link", name="Tasks", exact=True).click()
    expect(page.get_by_role("heading", name="Tasks", exact=True)).to_be_visible()
    page.wait_for_timeout(1500)
    workspace = [u for u in hits if u.endswith("/walker/GetWorkspace")]
    assert len(workspace) == 1, f"GetWorkspace was requested {len(workspace)} times after the save, expected 1"
    assert not [u for u in hits if u.endswith("/user/me")], "/user/me was requested again after the first load"


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
    settle(page, "/github", "GitHub")
    try:
        expect(page.get_by_text("@stub-org", exact=True)).to_be_visible()
        expect(page.get_by_role("button", name="Disconnect", exact=True)).to_be_visible()
    except AssertionError as exc:
        # The server's answer says which check the callback tripped.
        raise AssertionError(f"install did not finish; callback answers: {answers}") from exc
    page.wait_for_timeout(1500)
    assert len(callbacks) == 1, f"CompleteGithubInstall was called {len(callbacks)} times, expected exactly 1"


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
