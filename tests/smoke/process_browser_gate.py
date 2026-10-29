#!/usr/bin/env python3
"""Process review journeys, native presentation and draft preservation in Chrome.
Usage: python tests/smoke/process_browser_gate.py [http://localhost:8000]
Creates an isolated local test workspace; never drives a user's browser profile.
"""
from pathlib import Path
import re
import sys

from playwright.sync_api import expect, sync_playwright
import process_gate as api

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000").rstrip("/")
OUT = Path(".jac/process-review")


def layout(page):
    assert page.evaluate("document.documentElement.scrollWidth <= window.innerWidth"), "Document overflows"
    collisions = page.locator(".process-map").evaluate_all("""maps => maps.flatMap(map => {
        const nodes = [...map.querySelectorAll('[data-step]')];
        return nodes.flatMap((a, i) => nodes.slice(i + 1).filter(b => {
            const r = a.getBoundingClientRect(), s = b.getBoundingClientRect();
            return Math.min(r.right,s.right)-Math.max(r.left,s.left)>1 &&
                Math.min(r.bottom,s.bottom)-Math.max(r.top,s.top)>1;
        }).map(b => [a.textContent,b.textContent]));
    })""")
    assert collisions == [], collisions
    expect(page.locator("h1.page-title")).to_have_css("font-size", "20px")
    expect(page.locator("h1.page-title")).to_have_css("font-weight", "600")
    expect(page.get_by_text(re.compile(r"^0 open$"))).to_have_count(0)


def jump(page, title):
    page.get_by_role("combobox", name="Jump to step", exact=True).click()
    page.get_by_role("option", name=title, exact=True).click()
    inspector = page.get_by_role("complementary", name="Step details", exact=True)
    expect(inspector.get_by_role("heading", name=title, exact=True)).to_be_visible()
    return inspector


def close_details(page):
    page.get_by_role("button", name="Close step details", exact=True).click()
    expect(page.get_by_role("complementary", name="Step details")).to_have_count(0)


def options(page, item):
    page.get_by_role("button", name="Review options", exact=True).click()
    page.get_by_role("menuitem", name=item, exact=True).click()


def run():
    api.BASE = BASE
    token = api.account()
    OUT.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as pw:
        browser = pw.chromium.launch(channel="chrome")
        page = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(BASE + "/login")
        page.evaluate("token => localStorage.setItem('jac_token', token)", token)
        page.goto(BASE + "/processes")
        page.get_by_role("button", name="Add the four example flows", exact=True).click()
        expect(page.get_by_role("heading", name="React migration process", exact=True)).to_be_visible()
        expect(page.get_by_text("Review only. Agents, QA execution, timers and integrations are unfinished.", exact=True)).to_be_visible()
        expect(page.get_by_role("complementary", name="Step details")).to_have_count(0)
        print("ok   examples install; native header and honest review-only state", flush=True)

        for family, title in (("react", "React migration process"), ("bau", "BAU process")):
            for version in ("current", "proposed"):
                page.goto(f"{BASE}/processes?family={family}&version={version}")
                expect(page.get_by_role("heading", name=title, exact=True)).to_be_visible()
                inspector = jump(page, "QA + BAU regression")
                expect(inspector).to_contain_text("48–96-hour")
                expect(inspector).to_contain_text("Retries never reset")
                close_details(page)
                expect(page.get_by_role("combobox", name="Jump to step", exact=True)).to_be_focused()
                layout(page)
                page.screenshot(path=str(OUT / f"{family}-{version}.png"), full_page=True)
        print("ok   four direct links, QA semantics, node geometry and focus return", flush=True)

        page.get_by_role("button", name="Compare versions", exact=True).click()
        expect(page.locator(".process-diagram-panel")).to_have_count(2)
        expect(page.locator('[data-canvas="flow"]')).to_have_count(2)
        expect(page.get_by_role("group", name="Zoom", exact=True)).to_have_count(1)
        zoom = page.locator("[data-zoom]")
        before_zoom = zoom.get_attribute("data-zoom")
        page.get_by_role("button", name="Zoom in", exact=True).click()
        expect(zoom).not_to_have_attribute("data-zoom", before_zoom)
        fonts = page.locator(".process-map [data-step]").evaluate_all("nodes => nodes.map(n => parseFloat(getComputedStyle(n.querySelector('span span span')).fontSize))")
        assert fonts and all(size >= 12 for size in fonts), fonts
        page.get_by_role("combobox", name="Jump to step", exact=True).click()
        page.get_by_role("group", name="Proposed", exact=True).get_by_role("option", name="QA + BAU regression", exact=True).click()
        for diagram in page.locator(".process-map").all():
            viewport = diagram.bounding_box()
            qa = diagram.locator('[data-step="qa"]').bounding_box()
            assert viewport["y"] <= qa["y"] < viewport["y"] + viewport["height"], (viewport, qa)
        close_details(page)
        page.get_by_role("button", name="Fit", exact=True).click()
        layout(page)
        page.screenshot(path=str(OUT / "compare-desktop.png"), full_page=True)
        page.get_by_role("button", name="List", exact=True).click()
        expect(page.locator(".process-step-list")).to_have_count(2)
        print("ok   native comparison shares zoom and readable labels; list view works", flush=True)

        page.get_by_role("button", name="Proposed", exact=True).click()
        inspector = jump(page, "QA + BAU regression")
        note = "Keep this draft while changing step, version, family and section."
        page.get_by_label("Review note", exact=True).fill(note)
        jump(page, "Generate + validate stories")
        jump(page, "QA + BAU regression")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(note)
        page.get_by_role("button", name="Current", exact=True).click()
        jump(page, "QA + BAU regression")
        expect(page.get_by_label("Review note", exact=True)).to_have_value("")
        page.get_by_role("button", name="Proposed", exact=True).click()
        jump(page, "QA + BAU regression")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(note)
        page.get_by_role("button", name="React migration", exact=True).click()
        page.get_by_role("button", name="BAU", exact=True).click()
        jump(page, "QA + BAU regression")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(note)
        options(page, "To configure")
        expect(page.get_by_text("Test-data provision", exact=True)).to_be_visible()
        expect(page.get_by_role("complementary", name="Step details")).to_have_count(0)
        page.get_by_role("button", name="Back to flow", exact=True).click()
        jump(page, "QA + BAU regression")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(note)
        page.get_by_role("button", name="Save note", exact=True).click()
        expect(page.get_by_text("Saved to this workspace", exact=True)).to_be_visible()
        page.reload()
        jump(page, "QA + BAU regression")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(note)
        saved = [f for f in api.walker("ListProcesses", token=token) if f["template_key"] == "bau-proposed"][0]
        assert saved["review_notes"]["qa"] == note
        print("ok   drafts survive navigation; saved notes survive reload and server readback", flush=True)

        held_saves = []
        page.route("**/walker/SaveProcessNote", lambda route: held_saves.append(route))
        page.get_by_label("Review note", exact=True).fill("Earlier submitted note")
        page.get_by_role("button", name="Save note", exact=True).click()
        jump(page, "Generate + validate stories")
        jump(page, "QA + BAU regression")
        newer_draft = "Newer draft written while the earlier save is in flight"
        page.get_by_label("Review note", exact=True).fill(newer_draft)
        assert len(held_saves) == 1
        with page.expect_response(re.compile(r"/walker/ListProcesses$")):
            held_saves[0].fulfill(response=held_saves[0].fetch())
        page.unroute("**/walker/SaveProcessNote")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(newer_draft)
        print("ok   an earlier in-flight save cannot overwrite a newer draft", flush=True)

        page.route("**/walker/SaveProcessNote", lambda route: route.abort())
        retry_note = "A failed save must keep this review input."
        page.get_by_label("Review note", exact=True).fill(retry_note)
        page.get_by_role("button", name="Save note", exact=True).click()
        expect(page.get_by_role("alert")).to_contain_text("Your note is still here")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(retry_note)
        page.unroute("**/walker/SaveProcessNote")
        page.get_by_role("button", name="Try again", exact=True).click()
        expect(page.get_by_text("Saved to this workspace", exact=True)).to_be_visible()
        close_details(page)
        print("ok   failed saves retain input and retry succeeds", flush=True)

        jump(page, "Business-user UAT")
        page.get_by_role("button", name="Create linked fix story →", exact=True).click()
        expect(page.get_by_role("complementary", name="Step details")).to_contain_text("Use a new PR")
        close_details(page)
        options(page, "Shared QA & rules")
        expect(page.get_by_text("Independent code review", exact=True)).to_be_visible()
        expect(page.get_by_label("Process requirements")).to_contain_text("failed-then-passing")
        options(page, "To configure")
        expect(page.get_by_label("Process requirements")).to_contain_text("Chrome is required")
        expect(page.get_by_label("Process requirements")).to_contain_text("Numeric values are unset")
        print("ok   UAT rework and requirements retain their agreed semantics", flush=True)

        page.set_viewport_size({"width": 878, "height": 988})
        page.goto(BASE + "/processes?family=react&version=current&compare=1")
        expect(page.locator(".process-step-list")).to_have_count(2)
        expect(page.locator('[data-canvas="flow"]')).to_have_count(0)
        layout(page)
        footer = page.locator(".process-workspace > footer").bounding_box()
        navigation = page.get_by_role("navigation", name="Pages", exact=True).bounding_box()
        assert footer["y"] + footer["height"] <= navigation["y"], "Process footer sits behind the bottom navigation"
        page.screenshot(path=str(OUT / "compare-intermediate.png"), full_page=True)
        page.set_viewport_size({"width": 390, "height": 844})
        layout(page)
        for steps in page.locator(".process-step-list").all():
            assert steps.evaluate("el => el.scrollHeight <= el.clientHeight + 1"), "Phone list traps rows inside a nested scroller"
        page.screenshot(path=str(OUT / "compare-mobile.png"), full_page=True)
        page.get_by_role("button", name="Proposed", exact=True).click()
        inspector = jump(page, "QA + BAU regression")
        dialog = page.get_by_role("dialog", name="Step details", exact=True)
        expect(dialog).to_have_css("opacity", "1")
        expect(page.locator('[data-slot="select-content"]')).to_have_count(0)
        expect(inspector).to_contain_text("Planned")
        page.screenshot(path=str(OUT / "details-mobile.png"), full_page=False)
        close_details(page)
        expect(page.get_by_role("combobox", name="Jump to step", exact=True)).to_be_focused()
        print("ok   intermediate comparison fallback, phone layout and native detail sheet", flush=True)

        page.set_viewport_size({"width": 1440, "height": 1000})
        page.evaluate("localStorage.setItem('flowline-theme','dark')")
        page.goto(BASE + "/processes?family=react&version=proposed")
        expect(page.locator("html")).to_have_class(re.compile("dark"))
        layout(page)
        page.emulate_media(reduced_motion="reduce")
        duration = page.locator(".process-map [data-step]").first.evaluate("el => getComputedStyle(el).transitionDuration")
        assert all(float(value.strip().removesuffix("s")) <= .00002 for value in duration.split(",")), duration
        page.screenshot(path=str(OUT / "proposed-dark.png"), full_page=True)
        region = page.get_by_role("region", name="React migration process · Proposed diagram", exact=True)
        node = region.locator('[data-step="intake"]')
        top = node.bounding_box()["y"]
        region.press("ArrowDown")
        page.wait_for_function("previous => document.querySelector('.process-map [data-step=intake]').getBoundingClientRect().y < previous - 40", arg=top)
        region.press("f")
        page.get_by_role("button", name="List", exact=True).click()
        row = page.locator(".process-step-list button").first
        row.hover()
        color = row.evaluate("el => getComputedStyle(el).backgroundColor")
        accent = page.evaluate("getComputedStyle(document.documentElement).getPropertyValue('--accent').trim()")
        assert color not in ("rgb(240, 122, 58)", "rgb(191, 63, 11)"), (color, accent)
        print("ok   dark theme, keyboard panning and neutral row hover", flush=True)

        page.route("**/walker/ListProcesses", lambda route: route.abort())
        page.goto(BASE + "/processes")
        expect(page.get_by_role("alert")).to_contain_text("Could not load")
        expect(page.get_by_role("button", name="Add the four example flows", exact=True)).to_have_count(0)
        page.unroute("**/walker/ListProcesses")
        page.get_by_role("button", name="Try again", exact=True).click()
        expect(page.locator(".process-diagram-panel")).to_have_count(1)
        assert errors == [], errors
        print("ok   first-load errors stay errors, retry recovers and no browser exceptions", flush=True)
        api.walker("ApplyTemplate", {"template_key": "simple"}, token)
        page.goto(BASE + "/flowlines")
        expect(page.locator('[data-canvas="flow"]')).to_have_count(1)
        expect(page.get_by_text("0 open", exact=True).first).to_be_visible()
        assert errors == [], errors
        print("ok   operational flow canvas keeps its normal task counts", flush=True)
        browser.close()


if __name__ == "__main__":
    run()
