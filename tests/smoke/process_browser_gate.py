#!/usr/bin/env python3
"""Neutral catalog review journeys in an isolated Chromium test context.
Never drives a user's browser profile or installs personal definitions.
"""
from pathlib import Path
import copy
import json
import re
import sys
from playwright.sync_api import expect, sync_playwright
import process_gate as api

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000").rstrip("/")
OUT = Path(".jac/process-review")
FIXTURE = Path(__file__).resolve().parents[1] / "fixtures/process_catalog.json"

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
    expect(page.locator(".process-map [data-step] .num, .process-step-list .num")).to_have_count(0)


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
        browser = pw.chromium.launch()
        page = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(BASE + "/login")
        page.evaluate("token => localStorage.setItem('jac_token', token)", token)
        page.goto(BASE + "/processes")
        expect(page.get_by_role("heading", name="No processes yet", exact=True)).to_be_visible()
        page.screenshot(path=str(OUT / "empty.png"))
        expect(page.get_by_role("button", name="Import process catalog", exact=True)).to_be_enabled()
        page.get_by_label("Choose process catalog", exact=True).set_input_files(str(FIXTURE))
        expect(page.get_by_role("heading", name="Sample group", exact=True)).to_be_visible()
        expect(page.get_by_text("Review only. This library does not execute process steps.", exact=True)).to_be_visible()
        expect(page.locator('.process-map [data-step]')).to_have_count(3)
        expect(page.locator('[data-step="node-d"]')).to_have_count(0)
        page.get_by_role("button", name="All paths", exact=True).click()
        expect(page.locator('.process-map [data-step]')).to_have_count(4)
        layout(page)
        page.screenshot(path=str(OUT / "catalog-current.png"), full_page=True)
        page.get_by_role("button", name="Compare versions", exact=True).click()
        expect(page.locator('.process-diagram-panel')).to_have_count(2)
        page.get_by_role("button", name="List", exact=True).click()
        expect(page.locator('.process-step-list')).to_have_count(2)
        page.get_by_label("Choose process catalog", exact=True).set_input_files({
            "name": "invalid.json", "mimeType": "application/json", "buffer": b"{",
        })
        expect(page.get_by_role("alert")).to_contain_text("Choose valid JSON")
        expect(page.locator('.process-step-list')).to_have_count(2)
        print("ok   arbitrary catalog family, explicit import, branch paths and comparison", flush=True)
        page.get_by_role("button", name="Proposed", exact=True).click()
        inspector = jump(page, "Second step")
        note = "Keep this draft through changes of view."
        page.get_by_label("Review note", exact=True).fill(note)
        imports = []
        page.on("request", lambda request: imports.append(request) if request.url.endswith("/walker/ImportProcessCatalog") else None)
        page.get_by_label("Choose process catalog", exact=True).set_input_files(str(FIXTURE))
        expect(page.get_by_role("alert")).to_contain_text("Save or discard")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(note)
        assert imports == [], "Import must not start while a note has unsaved changes"
        jump(page, "First step")
        jump(page, "Second step")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(note)
        page.get_by_role("button", name="Current", exact=True).click()
        jump(page, "Second step")
        expect(page.get_by_label("Review note", exact=True)).to_have_value("")
        page.get_by_role("button", name="Proposed", exact=True).click()
        jump(page, "Second step")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(note)
        options(page, "Configuration")
        expect(page.get_by_text("Sample setting", exact=True)).to_be_visible()
        page.get_by_role("button", name="Back to flow", exact=True).click()
        jump(page, "Second step")
        page.get_by_role("button", name="Save note", exact=True).click()
        expect(page.get_by_text("Saved to this workspace", exact=True)).to_be_visible()
        page.reload()
        jump(page, "Second step")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(note)
        print("ok   drafts survive step/version/section changes and saved notes survive reload", flush=True)

        upgraded = [json.loads(FIXTURE.read_text())[1]]
        upgraded[0]["steps"][1].update(source_url="https://example.invalid/source", related_url="https://example.invalid/related", related_label="  ")
        for revision, width in ((2, 1440), (3, 390)):
            upgraded[0]["revision"] = revision
            close_details(page)
            page.set_viewport_size({"width": width, "height": 1000})
            jump(page, "Second step")
            held_imports = []
            page.route("**/walker/ImportProcessCatalog", lambda route: held_imports.append(route))
            page.get_by_label("Choose process catalog", exact=True).set_input_files({
                "name": "upgrade.json", "mimeType": "application/json", "buffer": json.dumps(upgraded).encode(),
            })
            for _ in range(250):
                if held_imports:
                    break
                page.wait_for_timeout(20)
            assert len(held_imports) == 1, "The controlled catalog import must be pending"
            expect(page.get_by_label("Review note", exact=True)).to_be_disabled()
            expect(page.get_by_role("button", name="Save note", exact=True)).to_be_disabled()
            expect(page.get_by_label("Choose process catalog", exact=True)).to_be_disabled()
            # A second change event must not start another import, even if
            # programmatically dispatched on the disabled file input.
            page.get_by_label("Choose process catalog", exact=True).dispatch_event("change")
            assert len(held_imports) == 1, "A duplicate import was submitted while the first was pending"
            page.screenshot(path=str(OUT / f"import-busy-{width}.png"))
            held_imports[0].fulfill(response=held_imports[0].fetch())
            page.unroute("**/walker/ImportProcessCatalog")
            expect(page.get_by_role("complementary", name="Step details", exact=True)).to_have_count(0)
            jump(page, "Second step")
            expect(page.get_by_label("Review note", exact=True)).to_have_value(note)
            expect(page.get_by_label("Review note", exact=True)).to_be_enabled()
            for url in ("https://example.invalid/source", "https://example.invalid/related"):
                expect(page.get_by_role("link", name=url, exact=True)).to_have_attribute("href", url)
        page.set_viewport_size({"width": 1440, "height": 1000})
        page.get_by_label("Choose process catalog", exact=True).set_input_files({
            "name": "invalid.json", "mimeType": "application/json", "buffer": b"{",
        })
        expect(page.get_by_role("alert")).to_contain_text("Choose valid JSON")
        expect(page.get_by_label("Review note", exact=True)).to_be_enabled()
        expect(page.get_by_label("Review note", exact=True)).to_have_value(note)
        imports.clear()
        print("ok   imports pause note editing and duplicate submission on desktop/phone; unlabeled URLs remain visible", flush=True)

        held_saves = []
        page.route("**/walker/SaveProcessNote", lambda route: held_saves.append(route))
        page.get_by_label("Review note", exact=True).fill("Earlier submitted note")
        page.get_by_role("button", name="Save note", exact=True).click()
        jump(page, "First step")
        jump(page, "Second step")
        newer_draft = "Newer draft written while the earlier save is in flight"
        page.get_by_label("Review note", exact=True).fill(newer_draft)
        assert len(held_saves) == 1
        page.get_by_label("Choose process catalog", exact=True).set_input_files(str(FIXTURE))
        expect(page.get_by_role("alert")).to_contain_text("Save or discard")
        assert imports == [], "Import must not start while a note save is pending"
        with page.expect_response(re.compile(r"/walker/ListProcesses$")):
            held_saves[0].fulfill(response=held_saves[0].fetch())
        page.unroute("**/walker/SaveProcessNote")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(newer_draft)
        print("ok   an earlier in-flight save cannot overwrite a newer draft", flush=True)

        for case, navigate, fail_earlier in (("remount", False, False), ("navigation", True, False), ("failed predecessor", False, True)):
            held_saves, sent_notes = [], []
            older_note = "Earlier save held across " + case
            newer_note = "Later accepted save survives " + case
            def hold_older_save(route):
                submitted = route.request.post_data_json["note"]
                sent_notes.append(submitted)
                if submitted == older_note:
                    held_saves.append(route)
                else:
                    route.continue_()
            page.route("**/walker/SaveProcessNote", hold_older_save)
            page.get_by_label("Review note", exact=True).fill(older_note)
            page.get_by_role("button", name="Save note", exact=True).click()
            if navigate:
                sidebar = page.get_by_role("complementary", name="Navigation", exact=True)
                sidebar.get_by_role("link", name="Overview", exact=True).click()
                expect(page).to_have_url(re.compile(r"/overview$"))
                sidebar.get_by_role("link", name="Processes", exact=True).click()
                page.get_by_role("button", name="Sample group", exact=True).click()
                page.get_by_role("button", name="Proposed", exact=True).click()
            else:
                jump(page, "First step")
            jump(page, "Second step")
            page.get_by_label("Review note", exact=True).fill(newer_note)
            page.get_by_role("button", name="Save note", exact=True).click()
            expect(page.get_by_role("button", name="Saving…", exact=True)).to_be_visible()
            assert sent_notes == [older_note], "A later save reached the server before the earlier write settled"
            with page.expect_response(lambda response: response.url.endswith("/walker/SaveProcessNote") and response.request.post_data_json["note"] == newer_note):
                if fail_earlier:
                    held_saves[0].abort()
                else:
                    held_saves[0].fulfill(response=held_saves[0].fetch())
            expect(page.get_by_text("Saved to this workspace", exact=True)).to_be_visible()
            page.unroute("**/walker/SaveProcessNote")
            page.reload()
            jump(page, "Second step")
            expect(page.get_by_label("Review note", exact=True)).to_have_value(newer_note)
            saved = next(f for f in api.walker("ListProcesses", token=token) if f["template_key"] == "sample-proposed")
            assert saved["review_notes"]["node-b"] == newer_note
        print("ok   accepted note saves stay ordered through remounts, page changes and predecessor failures", flush=True)

        held_reads, held_later = [], []
        newest_note = "Latest saved note must outlive a stale refresh"
        def hold_old_refresh(route):
            if not held_reads:
                held_reads.append((route, route.fetch()))
            else:
                route.continue_()
        def hold_later_write(route):
            if route.request.post_data_json["note"] == newest_note:
                held_later.append(route)
            else:
                route.continue_()
        page.route("**/walker/ListProcesses", hold_old_refresh)
        page.route("**/walker/SaveProcessNote", hold_later_write)
        page.get_by_label("Review note", exact=True).fill("Older saved note before the held refresh")
        page.get_by_role("button", name="Save note", exact=True).click()
        jump(page, "First step")
        jump(page, "Second step")
        page.get_by_label("Review note", exact=True).fill(newest_note)
        page.get_by_role("button", name="Save note", exact=True).click()
        for _ in range(250):
            if held_reads and held_later:
                break
            page.wait_for_timeout(20)
        assert held_reads and held_later, "Both controlled requests must be pending"
        held_later[0].fulfill(response=held_later[0].fetch())
        expect(page.get_by_text("Saved to this workspace", exact=True)).to_be_visible()
        held_reads[0][0].fulfill(response=held_reads[0][1])
        page.unroute("**/walker/ListProcesses")
        page.unroute("**/walker/SaveProcessNote")
        close_details(page)
        inspector = jump(page, "Second step")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(newest_note)
        expect(inspector.get_by_role("status")).not_to_contain_text("Unsaved changes")
        print("ok   a delayed older refresh cannot replace the latest confirmed note", flush=True)

        page.route("**/walker/SaveProcessNote", lambda route: route.abort())
        retry_note = "A failed save must keep this review input."
        page.get_by_label("Review note", exact=True).fill(retry_note)
        page.get_by_role("button", name="Save note", exact=True).click()
        expect(page.get_by_role("complementary", name="Step details").get_by_role("alert")).to_contain_text("Your note is still here")
        expect(page.get_by_label("Review note", exact=True)).to_have_value(retry_note)
        page.unroute("**/walker/SaveProcessNote")
        page.get_by_role("button", name="Try again", exact=True).click()
        expect(page.get_by_text("Saved to this workspace", exact=True)).to_be_visible()
        close_details(page)
        print("ok   failed saves retain input and retry succeeds", flush=True)

        jump(page, "Alternate step")
        page.get_by_role("button", name="Second step →", exact=True).click()
        inspector = page.get_by_role("complementary", name="Step details")
        expect(inspector.get_by_role("heading", name="Second step", exact=True)).to_be_visible()
        close_details(page)
        options(page, "Policies")
        expect(page.get_by_text("Sample policy", exact=True)).to_be_visible()
        page.get_by_role("button", name="Back to flow", exact=True).click()
        page.get_by_role("button", name="Compare versions", exact=True).click()
        page.set_viewport_size({"width": 878, "height": 988})
        expect(page.locator('.process-step-list')).to_have_count(2)
        layout(page)
        page.screenshot(path=str(OUT / "compare-intermediate.png"), full_page=True)
        page.set_viewport_size({"width": 390, "height": 844})
        layout(page)
        for steps in page.locator('.process-step-list').all():
            assert steps.evaluate("el => el.scrollHeight <= el.clientHeight + 1")
        page.evaluate("window.scrollTo(0, document.documentElement.scrollHeight)")
        footer = page.locator('.process-workspace > footer').bounding_box()
        navigation = page.get_by_role("navigation", name="Pages", exact=True).bounding_box()
        assert footer["y"] + footer["height"] <= navigation["y"]
        page.screenshot(path=str(OUT / "phone-bottom.png"))
        page.get_by_role("button", name="Proposed", exact=True).click()
        jump(page, "Second step")
        dialog = page.get_by_role("dialog", name="Step details", exact=True)
        expect(dialog).to_have_css("opacity", "1")
        page.screenshot(path=str(OUT / "details-mobile.png"))
        close_details(page)
        expect(page.get_by_role("combobox", name="Jump to step", exact=True)).to_be_focused()
        print("ok   intermediate/phone layouts and contextual inspection", flush=True)
        page.set_viewport_size({"width": 1440, "height": 1000})
        page.evaluate("localStorage.setItem('flowline-theme','dark')")
        page.goto(BASE + "/processes?version=proposed")
        expect(page.locator('html')).to_have_class(re.compile('dark'))
        layout(page)
        page.emulate_media(reduced_motion="reduce")
        region = page.get_by_role("region", name="Sample process · Proposed diagram", exact=True)
        node = region.locator('[data-step="node-a"]')
        top = node.bounding_box()["y"]
        region.press("ArrowDown")
        page.wait_for_function("previous => document.querySelector('.process-map [data-step=\"node-a\"]').getBoundingClientRect().y < previous - 40", arg=top)
        region.press("f")
        page.screenshot(path=str(OUT / "catalog-dark.png"), full_page=True)
        page.route("**/walker/ListProcesses", lambda route: route.abort())
        page.goto(BASE + "/processes")
        expect(page.get_by_role("alert")).to_contain_text("Could not load")
        expect(page.get_by_role("button", name="Import process catalog", exact=True)).to_have_count(0)
        page.unroute("**/walker/ListProcesses")
        page.get_by_role("button", name="Try again", exact=True).click()
        expect(page.locator('.process-diagram-panel')).to_have_count(1)

        for axis in ("x", "y"):
            tiny = copy.deepcopy(json.loads(FIXTURE.read_text())[0])
            tiny.update(template_key="tiny-" + axis, family="Tiny " + axis, title="Tiny " + axis, transitions=[])
            tiny["steps"] = [
                {"id": f"tiny-{i}", "title": f"Point {i}", "x": 0, "y": 0, axis: value,
                 "stage": "Group boundary" if i == 2 else ""}
                for i, value in enumerate((-20000, 0, 5e-324, 1, 20000))
            ]
            assert api.walker("ImportProcessCatalog", {"definitions": [tiny]}, token)["ok"]
            page.goto(BASE + "/processes?family=Tiny%20" + axis)
            expect(page.locator('.process-map [data-step]')).to_have_count(5)
            for paths in ("Main path", "All paths"):
                page.get_by_role("button", name=paths, exact=True).click()
                for zoom_case in ("fit", "actual", "enlarged"):
                    if zoom_case == "actual":
                        page.get_by_title("Zoom to 100%", exact=True).click()
                    elif zoom_case == "enlarged":
                        page.get_by_role("button", name="Zoom in", exact=True).click()
                    layout(page)
                    assert page.locator('.process-map [data-step]').evaluate_all("""nodes => nodes.every(n =>
                        ['left','top','width','height'].every(k => n.style[k] !== '' && Number.isFinite(parseFloat(n.style[k]))))"""), "Nonfinite imported coordinates reached the rendered diagram"
            jump(page, "Point 2")
            close_details(page)
            page.screenshot(path=str(OUT / f"tiny-{axis}.png"))
        print("ok   subnormal coordinate gaps render finite, nonoverlapping nodes in main/all-path views", flush=True)

        api.walker("ApplyTemplate", {"template_key": "simple"}, token)
        page.goto(BASE + "/flowlines")
        expect(page.locator('[data-canvas="flow"]')).to_have_count(1)
        expect(page.get_by_text("0 tasks", exact=True).first).to_be_visible()
        assert errors == [], errors
        print("ok   theme, keyboard, retry and unchanged operational task counts", flush=True)
        browser.close()

if __name__ == "__main__":
    run()
