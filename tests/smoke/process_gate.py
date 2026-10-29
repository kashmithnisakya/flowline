#!/usr/bin/env python3
"""Exercise persisted storyboards on a running server, including isolation.
Usage: python tests/smoke/process_gate.py [http://localhost:8000]
Creates disposable local test workspaces; uses only the standard library.
"""
import json
import sys
import urllib.error
import urllib.request
import uuid

BASE = (sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000").rstrip("/")


def request(path, body, token=""):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(BASE + path, json.dumps(body).encode(), headers)
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            return resp.status, json.load(resp)
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read())


def find_token(value):
    if isinstance(value, dict):
        for key in ("token", "access_token"):
            if value.get(key):
                return value[key]
        for child in value.values():
            result = find_token(child)
            if result:
                return result
    return ""


def account():
    tag = uuid.uuid4().hex[:10]
    email, password = f"process-{tag}@flowline-ci.invalid", f"Pw-{uuid.uuid4().hex}-Ab7!"
    status, _ = request("/user/register", {
        "identities": [{"type": "email", "value": email}],
        "credential": {"type": "password", "password": password},
        "profile": {"org_name": "Process gate"},
    })
    assert status in (200, 201), status
    status, payload = request("/user/login", {
        "identity": {"type": "email", "value": email},
        "credential": {"type": "password", "password": password},
    })
    token = find_token(payload)
    assert status == 200 and token, (status, payload)
    return token


def walker(name, body=None, token=""):
    status, payload = request("/walker/" + name, body or {}, token)
    assert status == 200, (name, status, payload)
    data = payload.get("data", payload)
    return data.get("reports", [])[0]


def reaches(flow, start, target, forward_only=False, excluding=()):
    pending, seen = [start], set()
    while pending:
        key = pending.pop()
        if key == target:
            return True
        if key in seen or key in excluding:
            continue
        seen.add(key)
        pending.extend(t["target"] for t in flow["transitions"]
                       if t["source"] == key and (not forward_only or t["kind"] == "forward"))
    return False


def run():
    for name in ("ListProcesses", "InstallProcessExamples", "SaveProcessNote"):
        status, _ = request("/walker/" + name, {"process_id": "x", "step_id": "x"})
        assert status == 401, (name, status)
    print("ok   all process endpoints reject anonymous calls")

    owner, other = account(), account()
    assert walker("ListProcesses", token=owner) == []
    walker("ApplyTemplate", {"template_key": "simple"}, owner)
    before = walker("GetFlowLine", token=owner)
    assert walker("InstallProcessExamples", token=owner) == {"ok": True, "added": 4}
    flows = walker("ListProcesses", token=owner)
    assert {f["template_key"] for f in flows} == {
        "react-current", "react-proposed", "bau-current", "bau-proposed"}
    assert len(flows) == 4
    assert [{k: v for k, v in s.items() if not k.startswith("_jac_")}
            for s in walker("GetFlowLine", token=owner)] == [
                {k: v for k, v in s.items() if not k.startswith("_jac_")} for s in before]
    assert walker("InstallProcessExamples", token=owner)["added"] == 0
    assert [f["id"] for f in walker("ListProcesses", token=owner)] == [f["id"] for f in flows]
    print("ok   four persistent definitions; repeat install preserves IDs and operational flow")

    for flow in flows:
        steps = {s["id"]: s for s in flow["steps"]}
        assert len(steps) == len(flow["steps"])
        for arrow in flow["transitions"]:
            assert arrow["source"] in steps and arrow["target"] in steps, arrow
        assert all(reaches(flow, key, "production") for key in steps), flow["template_key"]
        assert reaches(flow, "qa", "merge", True)
        assert reaches(flow, "merge", "uat", True)
        assert not reaches(flow, "intake", "uat", True, excluding={"merge"})
        assert steps["final"]["owner"] == "PR owner"
        assert all(s["status"] in {"Manual", "Planned", "Placeholder"} for s in steps.values())
        assert all(c["status"] == "To configure" for c in flow["configuration"])
        assert flow["review_notes"] == {}
        if flow["variant"] == "current":
            assert steps["story_approval"]["owner"] == "QA staff in Spark"
            assert reaches(flow, "story_approval", "dev", True)
            assert not reaches(flow, "intake", "dev", True, excluding={"story_approval"})
        else:
            assert "story_approval" not in steps
            assert reaches(flow, "approval", "stories", True)
            assert reaches(flow, "stories", "dev", True)
            assert "read-only" in steps["review"]["detail"].lower()
            assert any(t["source"] == "resume" and t["target"] == "dev"
                       for t in flow["transitions"]), "Implementation checkpoint must return to implementation"
            assert not reaches(flow, "intake", "dev", True, excluding={"approval"})
            assert not reaches(flow, "intake", "dev", True, excluding={"stories"})
            if flow["family"] == "bau":
                assert "design_approval" not in steps
                assert "design" in steps["approval"]["title"].lower()
        assert reaches(flow, "uat", "fix_story", True)
    print("ok   all four graphs are connected; approval order, QA, merge, UAT and repair semantics")

    process_id = flows[0]["id"]
    body = {"process_id": process_id, "step_id": "intake", "note": "  Review persisted note  "}
    assert walker("SaveProcessNote", body, owner)["ok"]
    saved = walker("ListProcesses", token=owner)[0]
    assert saved["review_notes"]["intake"] == "Review persisted note"
    assert saved["revision"] == flows[0]["revision"]
    assert walker("InstallProcessExamples", token=owner)["added"] == 0
    assert walker("ListProcesses", token=owner)[0]["review_notes"] == saved["review_notes"]
    assert walker("SaveProcessNote", {**body, "step_id": "missing"}, owner)["error"] == "unknown_step"
    assert walker("SaveProcessNote", {**body, "note": "x" * 6001}, owner)["error"] == "note_too_long"
    assert walker("SaveProcessNote", {**body, "process_id": "malformed"}, owner)["error"] == "not_found"
    print("ok   notes persist; installation is non-destructive; invalid IDs and lengths are rejected")

    assert walker("ListProcesses", token=other) == []
    assert walker("SaveProcessNote", body, other) == {"ok": False, "error": "not_found"}
    assert walker("InstallProcessExamples", token=other)["added"] == 4
    foreign_ids = {f["id"] for f in walker("ListProcesses", token=other)}
    assert not foreign_ids.intersection(f["id"] for f in flows)
    assert walker("ListProcesses", token=owner)[0]["review_notes"] == saved["review_notes"]
    print("ok   workspace isolation for definitions, notes and install")


if __name__ == "__main__":
    run()
