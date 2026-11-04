#!/usr/bin/env python3
"""Verify that a cached compiler matches the last backport on each source."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("flowline_jac_toolchain", ROOT / "tools/jac.py")
toolchain = importlib.util.module_from_spec(spec)
spec.loader.exec_module(toolchain)


def checksum(text):
    return hashlib.sha256(text.encode()).hexdigest()


with tempfile.TemporaryDirectory() as scratch:
    source = Path(scratch)
    (source / "expr.jac").write_text("second verified backport")
    (source / "sort.jac").write_text("independent backport")
    patches = [
        {"source": "expr.jac", "after_sha256": checksum("first verified backport")},
        {"source": "sort.jac", "after_sha256": checksum("independent backport")},
        {"source": "expr.jac", "after_sha256": checksum("second verified backport")},
    ]
    toolchain.verify_patched_sources(source, patches)
    for bad_source, invalid_content in (
        ("expr.jac", "first verified backport"),
        ("sort.jac", "changed outside the verified backports"),
    ):
        target = source / bad_source
        original = target.read_text()
        target.write_text(invalid_content)
        try:
            toolchain.verify_patched_sources(source, patches)
        except RuntimeError:
            pass
        else:
            raise AssertionError("Accepted an incomplete or modified compiler source")
        finally:
            target.write_text(original)
print("ok   final backport state is required for each cached compiler source")
