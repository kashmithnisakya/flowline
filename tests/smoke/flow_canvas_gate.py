#!/usr/bin/env python3
"""Draw a custom flow, drag across both axes, and read positions after reload.
Usage: flow_canvas_gate.py [base_url]
"""
import math
import sys
import traceback
import uuid

from playwright.sync_api import expect, sync_playwright

from browser_gate import BASE, STEP_TIMEOUT_MS, act, settle, step
from flow_motion_cases import run_motion_checks


def report(page, name: str, body: dict) -> object:
    token = page.evaluate("localStorage.getItem('jac_token')")
    response = page.request.post(
        f"{BASE}/walker/{name}",
        headers={"Authorization": f"Bearer {token}"},
        data=body,
    )
    assert response.ok, f"{name}: {response.status} {response.text()[:300]}"
    payload = response.json()
    data = payload.get("data") or {}
    reports = payload.get("reports") or data.get("reports") or (data.get("result") or {}).get("reports") or []
    assert reports, f"{name} returned no report: {payload}"
    return reports[0]


def run(page) -> None:
    tag = uuid.uuid4().hex[:10]
    step("custom flow: sign up and choose Draw my own")
    page.goto(f"{BASE}/login?mode=signup")
    page.get_by_placeholder("you@company.com").fill(f"canvas-{tag}@flowline-ci.invalid")
    page.get_by_placeholder("••••••••••").fill(f"Pw-{tag}-Xy7!")
    page.get_by_role("button", name="Create workspace", exact=True).click()
    settle(page, "/setup", "Name your workspace")
    act(page, lambda: page.get_by_placeholder("Acme Robotics").fill("Canvas CI"))
    page.get_by_placeholder("Website redesign").fill("Custom flow")
    page.get_by_placeholder("Website redesign").press("Enter")
    page.get_by_role("button", name="Skip for now", exact=True).click()
    page.get_by_role("radio", name="Draw my own").click()
    page.get_by_role("button", name="Open the designer", exact=True).click()
    expect(page.locator('[data-canvas="flow"]')).to_be_visible()
    page.get_by_role("button", name="Add step", exact=True).click()
    page.get_by_role("textbox", name="Step name", exact=True).fill("Start")
    page.get_by_role("button", name="Add to canvas", exact=True).click()
    node = page.locator("[data-step]")
    expect(node).to_have_count(1)
    expect(node).to_be_visible()
    step_id = node.get_attribute("data-step")

    # Refit after each reload, then set an explicit zoom so screen deltas can
    # be checked against canvas coordinates. Test crossing both axes, landing
    # on them, and dragging back from negative coordinates at two zoom levels.
    targets = [(-90.0, -70.0), (110.0, -70.0), (-90.0, 90.0), (110.0, 90.0), (0.0, 0.0)]
    for zoom in (1.0, 0.75):
        for x, y in targets:
            step(f"custom flow: drag to ({x}, {y}) at {zoom * 100:g}%")
            page.locator("[data-zoom]").click()
            if zoom < 1.0:
                page.get_by_role("button", name="Zoom out", exact=True).click()
            expect(page.locator("[data-zoom]")).to_have_attribute("data-zoom", f"{zoom * 100:g}%")
            stored = next(s for s in report(page, "GetFlowLine", {"with_counts": False}) if s["id"] == step_id)
            before = node.bounding_box()
            assert before, "Step has no rendered box"
            dx, dy = (x - stored["x"]) * zoom, (y - stored["y"]) * zoom
            cx, cy = before["x"] + before["width"] / 2, before["y"] + before["height"] / 2
            page.mouse.move(cx, cy)
            page.mouse.down()
            page.mouse.move(cx + dx, cy + dy, steps=12)
            after = node.bounding_box()
            assert after and math.isclose(after["x"], before["x"] + dx, abs_tol=1.0), ("live X", before, after, dx)
            assert math.isclose(after["y"], before["y"] + dy, abs_tol=1.0), ("live Y", before, after, dy)
            with page.expect_response(lambda r: r.request.method == "POST" and r.url.endswith("/walker/MoveStep")) as saved:
                page.mouse.up()
            assert saved.value.ok, saved.value.text()
            # A fresh request bypasses the browser's reader cache, and a hard
            # reload proves the box is still rendered at the saved position.
            page.reload()
            expect(node).to_be_visible()
            stored = next(s for s in report(page, "GetFlowLine", {"with_counts": False}) if s["id"] == step_id)
            assert math.isclose(stored["x"], x, abs_tol=0.1), stored
            assert math.isclose(stored["y"], y, abs_tol=0.1), stored
            node.click()
            expect(page.get_by_role("textbox", name="Step name", exact=True)).to_have_value("Start")

    step("custom flow: creating and moving a step retain signed coordinates")
    probe = report(page, "SaveStep", {"name": "Coordinate probe", "x": -20000.0, "y": 20000.0})
    assert (probe["x"], probe["y"]) == (-20000.0, 20000.0), probe
    probe = report(page, "MoveStep", {"step_id": probe["id"], "x": 20000.0, "y": -20000.0})
    assert (probe["x"], probe["y"]) == (20000.0, -20000.0), probe
    step("custom flow: out-of-range coordinates stop at the nearest boundary")
    probe = report(page, "MoveStep", {"step_id": probe["id"], "x": -20001.0, "y": 20001.0})
    assert (probe["x"], probe["y"]) == (-20000.0, 20000.0), probe


def main() -> int:
    errors: list[str] = []
    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        page = browser.new_page(viewport={"width": 1440, "height": 1000})
        page.set_default_timeout(STEP_TIMEOUT_MS)
        page.on("pageerror", lambda error: errors.append(str(error)))
        try:
            run(page)
            run_motion_checks(page, report)
            assert not errors, errors
        except Exception as exc:
            traceback.print_exc()
            page.screenshot(path="browser_gate_failure.png", full_page=True)
            print(f"flow canvas gate: FAIL {exc}", flush=True)
            print(f"url at failure: {page.url}", flush=True)
            for error in errors:
                print(f"page error: {error}", flush=True)
            return 1
        finally:
            browser.close()
    print("flow canvas gate: PASS", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
