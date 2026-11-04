#!/usr/bin/env python3
"""Check the neutral test fixture and the absence of a bundled process catalog."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def run():
    records = json.loads((ROOT / "tests/fixtures/process_catalog.json").read_text())
    assert len(records) == 2
    keys, versions = set(), set()
    for record in records:
        assert record["template_key"] not in keys
        keys.add(record["template_key"])
        pair = record["family"], record["variant"]
        assert pair not in versions
        versions.add(pair)
        ids = [s["id"] for s in record["steps"]]
        assert len(ids) == len(set(ids))
        for edge in record["transitions"]:
            assert edge["source"] in ids and edge["target"] in ids
            assert edge["kind"] in ("forward", "return")
    production = ROOT / "services/processes"
    assert not list(production.glob("*templates*.jac")), "Process data must remain external"
    assert "validate_catalog" in (production / "catalog.jac").read_text()
    assert ".flowline-local/" in (ROOT / ".gitignore").read_text()
    print("ok   neutral process fixtures and external-only production catalog")

if __name__ == "__main__":
    run()
