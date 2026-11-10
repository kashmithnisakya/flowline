#!/usr/bin/env python3
"""Exercise the shared contract when the process library and authoring coexist.

Run on a disposable two-worker deployment with both sets of endpoints:
python tests/smoke/process_authoring_library_gate.py http://127.0.0.1:8000
"""

import copy
from concurrent.futures import ThreadPoolExecutor

from agent_interface_gate import DOCUMENT, account, domain, walker


def read(process_id, token):
    return domain(
        walker(
            "GetProcessDefinition",
            {"process_id": process_id, "include_history": True},
            token,
        )["process"]
    )


def run():
    owner = account()
    source = copy.deepcopy(DOCUMENT)
    source.update(
        template_key="library-agent-bridge", family="Sample group", revision=1
    )
    step = source["steps"][0]
    previous_id = step["id"]
    step_id = "1." + "a" * 78
    step.update(
        id=step_id,
        path="branch",
        short_title="Intake",
        source_url="https://example.test/reference",
        source_label="",
    )
    for link in source["transitions"]:
        for endpoint in ("source", "target"):
            if link[endpoint] == previous_id:
                link[endpoint] = step_id
    source["policies"] = [
        {"title": "Review", "detail": "Keep the rationale", "status": "Defined"}
    ]
    assert walker("ImportProcessCatalog", {"definitions": [source]}, owner) == {
        "ok": True,
        "added": 1,
        "updated": 0,
    }
    library = domain(walker("ListProcesses", token=owner))[0]
    original = read(library["id"], owner)
    document = original["document"]
    assert document == {key: library[key] for key in DOCUMENT}
    assert document["steps"][0]["id"] == step_id
    assert document["steps"][0]["path"] == "branch"
    assert document["steps"][0]["short_title"] == "Intake"
    assert document["steps"][0]["source_label"] == ""
    assert document["policies"] == source["policies"]
    assert walker("ValidateProcessDefinition", {"document": document}, owner)["ok"]
    assert walker(
        "SaveProcessDefinition", {"document": document, "request_id": "occupied"}, owner
    ) == {"ok": False, "error": "family_variant_conflict"}
    assert walker(
        "SaveProcessDefinition",
        {
            "document": document,
            "process_id": library["id"],
            "expected_etag": original["etag"],
            "request_id": "managed-edit",
        },
        owner,
    ) == {"ok": False, "error": "template_requires_copy"}
    print(
        "ok   library exports validate with branch/link/policy metadata intact",
        flush=True,
    )

    custom_document = {**document, "family": "Independent sample group"}
    create = {"document": custom_document, "request_id": "independent-copy"}
    created = walker("SaveProcessDefinition", create, owner)
    assert created["ok"]
    process_id = created["process_id"]
    saved = read(process_id, owner)
    assert saved["document"] == custom_document and not saved["history"]
    assert walker(
        "SaveProcessNote",
        {"process_id": process_id, "step_id": step_id, "note": "Keep this rationale"},
        owner,
    )["ok"]
    changed = {**custom_document, "summary": "Edited after a review note"}
    update = {
        "document": changed,
        "process_id": process_id,
        "expected_etag": saved["etag"],
        "request_id": "stale-after-note",
    }
    assert walker("SaveProcessDefinition", update, owner)["error"] == "conflict"
    noted = read(process_id, owner)
    assert noted["etag"] != saved["etag"]
    assert walker(
        "SaveProcessDefinition",
        {**update, "expected_etag": noted["etag"], "request_id": "edit-after-note"},
        owner,
    )["ok"]
    edited = read(process_id, owner)
    assert edited["document"] == changed and edited["revision"] == 2
    assert edited["review_notes"] == {step_id: "Keep this rationale"}
    assert len(edited["history"]) == 1
    assert edited["history"][0]["review_notes"] == edited["review_notes"]
    replay = walker("SaveProcessDefinition", create, owner)
    assert replay == {**created, "replayed": True}
    assert read(process_id, owner) == edited
    assert walker(
        "SaveProcessDefinition",
        {
            "document": document,
            "process_id": process_id,
            "expected_etag": edited["etag"],
            "request_id": "colliding-edit",
        },
        owner,
    ) == {"ok": False, "error": "family_variant_conflict"}
    assert read(process_id, owner) == edited
    print(
        "ok   authored copies preserve metadata, review notes, history and retry receipts",
        flush=True,
    )

    upgraded = {**source, "revision": 2, "summary": "Library revision two"}
    assert walker("ImportProcessCatalog", {"definitions": [upgraded]}, owner) == {
        "ok": True,
        "added": 0,
        "updated": 1,
    }
    assert read(process_id, owner) == edited
    managed = read(library["id"], owner)
    assert managed["revision"] == 2 and len(managed["history"]) == 1
    assert managed["document"]["summary"] == upgraded["summary"]
    assert walker("ImportProcessCatalog", {"definitions": [upgraded]}, owner) == {
        "ok": True,
        "added": 0,
        "updated": 0,
    }
    assert walker("ListProcessDefinitions", token=owner)["total"] == 2
    print(
        "ok   authoring does not block idempotent catalog imports or managed upgrades",
        flush=True,
    )

    racing_owner = account()
    with ThreadPoolExecutor(2) as pool:
        results = list(
            pool.map(
                lambda call: walker(*call),
                [
                    ("ImportProcessCatalog", {"definitions": [source]}, racing_owner),
                    (
                        "SaveProcessDefinition",
                        {"document": document, "request_id": "race"},
                        racing_owner,
                    ),
                ],
            )
        )
    assert sum(result.get("ok", False) for result in results) == 1, results
    assert {result["error"] for result in results if not result.get("ok")} <= {
        "catalog_conflict",
        "family_variant_conflict",
    }, results
    assert walker("ListProcessDefinitions", token=racing_owner)["total"] == 1
    assert len(walker("ListProcesses", token=racing_owner)) == 1
    print(
        "ok   concurrent import/authoring cannot occupy the same family/variant twice",
        flush=True,
    )
    print("process library/authoring gate: PASS", flush=True)


if __name__ == "__main__":
    run()
