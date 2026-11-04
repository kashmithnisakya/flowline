#!/usr/bin/env python3
"""Exercise persisted storyboards on a running server, including isolation.
Usage: python tests/smoke/process_gate.py [http://localhost:8000]
Creates disposable local test workspaces; uses only the standard library.
"""
import copy
import json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
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


def domain(value):
    if isinstance(value, dict):
        return {k: domain(v) for k, v in value.items() if not k.startswith("_jac_")}
    if isinstance(value, list):
        return [domain(v) for v in value]
    return value


def run():
    for name in ("ListProcesses", "ImportProcessCatalog", "SaveProcessNote"):
        status, _ = request("/walker/" + name, {"process_id": "x", "step_id": "x"})
        assert status == 401, (name, status)
    print("ok   all process endpoints reject anonymous calls", flush=True)
    values = json.loads((Path(__file__).resolve().parents[1] / "fixtures/process_catalog.json").read_text())
    owner, other = account(), account()
    assert walker("ListProcesses", token=owner) == []
    assert walker("ImportProcessCatalog", token=owner) == {"ok": False, "error": "invalid_catalog"}
    assert walker("ListProcesses", token=owner) == []
    walker("ApplyTemplate", {"template_key": "simple"}, owner)
    before = domain(walker("GetFlowLine", token=owner))
    assert walker("ImportProcessCatalog", {"definitions": values}, owner) == {"ok": True, "added": 2, "updated": 0}
    flows = {p["template_key"]: p for p in walker("ListProcesses", token=owner)}
    assert set(flows) == {"sample-current", "sample-proposed"}
    assert all(p["family"] == "Sample group" for p in flows.values())
    assert walker("ImportProcessCatalog", {"definitions": values}, owner) == {"ok": True, "added": 0, "updated": 0}
    assert domain(walker("GetFlowLine", token=owner)) == before
    assert walker("ListProcesses", token=other) == [], "Imports must not publish a shared catalog"
    print("ok   user-supplied imports are idempotent, workspace-owned and separate from tasks", flush=True)

    process_id = flows["sample-current"]["id"]
    body = {"process_id": process_id, "step_id": "node-b", "note": "  Saved sample note  "}
    assert walker("SaveProcessNote", body, owner)["ok"]
    retired = {**body, "step_id": "node-d", "note": "Keep this earlier-step note"}
    assert walker("SaveProcessNote", retired, owner)["ok"]
    assert walker("SaveProcessNote", {**body, "step_id": "missing"}, owner)["error"] == "unknown_step"
    assert walker("SaveProcessNote", {**body, "note": "x" * 6001}, owner)["error"] == "note_too_long"
    assert walker("SaveProcessNote", {**body, "process_id": "malformed"}, owner)["error"] == "not_found"
    assert walker("SaveProcessNote", body, other) == {"ok": False, "error": "not_found"}
    assert walker("ImportProcessCatalog", {"definitions": values}, other)["added"] == 2
    other_before = domain(walker("ListProcesses", token=other))
    saved = {p["template_key"]: p for p in walker("ListProcesses", token=owner)}
    assert saved["sample-current"]["review_notes"]["node-b"] == "Saved sample note"
    assert not {p["id"] for p in other_before}.intersection(p["id"] for p in saved.values())
    print("ok   notes persist, invalid writes fail and workspaces remain isolated", flush=True)

    invalid = [[], values + [{"template_key": "incomplete"}]]
    for field, value in (("revision", True), ("variant", "unsupported"), ("summary", "x" * 1048577)):
        bad = copy.deepcopy(values); bad[0][field] = value; invalid.append(bad)
    for field, value in (("x", True), ("x", "NaN"), ("x", "Infinity"), ("x", 20001), ("source_url", "javascript:alert(1)")):
        bad = copy.deepcopy(values); bad[0]["steps"][0][field] = value; invalid.append(bad)
    bad = copy.deepcopy(values); bad[0]["steps"].append(copy.deepcopy(bad[0]["steps"][0])); invalid.append(bad)
    bad = copy.deepcopy(values); bad[0]["transitions"][0]["target"] = "missing"; invalid.append(bad)
    invalid.append(values + [copy.deepcopy(values[0])])
    bad = copy.deepcopy(values); bad[1]["variant"] = "current"; invalid.append(bad)
    empty_owner = account()
    for bad in invalid:
        assert walker("ImportProcessCatalog", {"definitions": bad}, empty_owner) == {"ok": False, "error": "invalid_catalog"}
        assert walker("ImportProcessCatalog", {"definitions": bad}, owner) == {"ok": False, "error": "invalid_catalog"}
        assert walker("ListProcesses", token=empty_owner) == []
        assert domain(walker("ListProcesses", token=owner)) == domain(list(saved.values()))
    print("ok   malformed catalogs fail before writes, including invalid graph IDs, coordinates and links", flush=True)
    renamed = copy.deepcopy(values); renamed[0]["template_key"] = "sample-renamed"
    assert walker("ImportProcessCatalog", {"definitions": renamed}, owner) == {"ok": False, "error": "catalog_conflict"}
    collision = [copy.deepcopy(values[1])]; collision[0].update(variant="current", revision=2)
    assert walker("ImportProcessCatalog", {"definitions": collision}, owner) == {"ok": False, "error": "catalog_conflict"}
    assert domain(walker("ListProcesses", token=owner)) == domain(list(saved.values()))
    print("ok   conflicting keys or group/variant updates fail without partial writes", flush=True)
    updated = copy.deepcopy(values)
    for item in updated:
        item["revision"] = 2
        item["title"] += " updated"
        item["steps"] = [step for step in item["steps"] if step["id"] != "node-d"]
        item["transitions"] = [link for link in item["transitions"] if "node-d" not in (link["source"], link["target"])]
    assert walker("ImportProcessCatalog", {"definitions": updated}, owner) == {"ok": True, "added": 0, "updated": 2}
    after = {p["template_key"]: p for p in walker("ListProcesses", token=owner)}
    for key, old in saved.items():
        new = after[key]
        assert new["id"] == old["id"] and new["review_notes"] == old["review_notes"]
        assert new["revision"] == 2 and len(new["history"]) == 1
        for field in ("revision", "title", "summary", "steps", "transitions", "policies", "configuration", "review_notes", "updated_at"):
            assert domain(new["history"][0][field]) == domain(old[field]), field
    assert after["sample-current"]["history"][0]["review_notes"]["node-d"] == retired["note"]
    for definitions in (updated, values):
        assert walker("ImportProcessCatalog", {"definitions": definitions}, owner) == {"ok": True, "added": 0, "updated": 0}
    assert domain(walker("ListProcesses", token=other)) == other_before
    assert domain(walker("GetFlowLine", token=owner)) == before
    print("ok   higher revisions retain IDs, notes and retired-step history without downgrades or unrelated writes", flush=True)
    concurrent_owner = account()
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: walker("ImportProcessCatalog", {"definitions": values}, concurrent_owner), range(2)))
    assert sorted(result["added"] for result in results) == [0, 2], results
    assert len(walker("ListProcesses", token=concurrent_owner)) == 2
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: walker("ImportProcessCatalog", {"definitions": updated}, concurrent_owner), range(2)))
    assert sorted(result["updated"] for result in results) == [0, 2], results
    concurrent = walker("ListProcesses", token=concurrent_owner)
    assert len(concurrent) == 2 and all(len(p["history"]) == 1 for p in concurrent)
    target = next(p for p in concurrent if p["template_key"] == "sample-current")
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda step: walker("SaveProcessNote", {
            "process_id": target["id"], "step_id": step, "note": "Saved " + step,
        }, concurrent_owner), ("node-a", "node-b")))
    assert all(result["ok"] for result in results), results
    target = next(p for p in walker("ListProcesses", token=concurrent_owner) if p["id"] == target["id"])
    assert target["review_notes"] == {"node-a": "Saved node-a", "node-b": "Saved node-b"}
    print("ok   concurrent imports, upgrades and note writes retain one consistent workspace", flush=True)

if __name__ == "__main__":
    run()
