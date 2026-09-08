#!/usr/bin/env python3
"""Playwright smoke against a running server: sign up, finish the setup
wizard, apply the flow line template, create a task from the board's
New task button and see its card survive a reload. Every step is a real
click or keystroke, so a dead button fails here. Usage: browser_gate.py [base_url]"""
import re
import sys
import time
import uuid

from playwright.sync_api import expect, sync_playwright

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000").rstrip("/")
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

    step("setup wizard: organization")
    settle(page, "/setup", "Name your workspace")
    act(page, lambda: page.get_by_placeholder("Acme Robotics").fill("CI Org"))
    page.get_by_placeholder("Priya Raman").fill("CI Runner")
    page.get_by_role("button", name="Continue", exact=True).click()

    step("setup wizard: first project")
    expect(page.get_by_text("Create your first project").first).to_be_visible()
    page.get_by_placeholder("Website redesign").fill("CI Project")
    page.get_by_role("button", name="Continue", exact=True).click()

    step("setup wizard: finish")
    expect(page.get_by_text("Add your people").first).to_be_visible()
    page.get_by_role("button", name="Design your flow line", exact=True).click()
    settle(page, "/flowlines", "How does your team move work?")

    step("flow line: apply the template")
    act(page, lambda: page.get_by_role("button", name="Use template", exact=True).click())
    expect(page.get_by_text("Your flow line is in")).to_be_visible()
    page.get_by_role("button", name="Done editing", exact=True).click()

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
    return []


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
