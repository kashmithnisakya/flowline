#!/usr/bin/env python3
"""Verify that a cached compiler matches the last backport on each source."""
import hashlib
import importlib.util
from concurrent.futures import ThreadPoolExecutor
import gzip
import io
import json
from pathlib import Path
import tarfile
import tempfile
import threading
from unittest.mock import patch

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


def archive(files):
    content = io.BytesIO()
    with tarfile.open(fileobj=content, mode="w") as tar:
        for name, data in files.items():
            member = tarfile.TarInfo(name)
            member.size = len(data)
            tar.addfile(member, io.BytesIO(data))
    return content.getvalue()


with tempfile.TemporaryDirectory() as scratch:
    root = Path(scratch)
    fixture_spec = root / "tools/jac_toolchain"
    fixture_spec.mkdir(parents=True)
    stub_tar = archive({"typeshed-fixture-stubs/stdlib/typing.pyi": b"# pinned stubs\n"})
    stub_sha = hashlib.sha256(stub_tar).hexdigest()
    before, after = "before\n", "after\n"
    source_tar = archive({
        "jac-fixture-source/jac/jaclang/expr.jac": before.encode(),
        "jac-fixture-source/jac/jaclang/vendor/typeshed/PIN": b"fixture-stubs\n",
        "jac-fixture-source/jac/jaclang/vendor/typeshed/TARBALL_SHA256": stub_sha.encode(),
    })
    source_archive = gzip.compress(source_tar)
    fix = "--- a/jaclang/expr.jac\n+++ b/jaclang/expr.jac\n@@ -1 +1 @@\n-before\n+after\n"
    (fixture_spec / "fixture.patch").write_text(fix)
    manifest = {
        "jac_version": "fixture",
        "source_commit": "fixture-source",
        "archive_url": "https://example.invalid/source.tar.gz",
        "archive_sha256": hashlib.sha256(source_archive).hexdigest(),
        "typeshed": {"commit": "fixture-stubs", "tar_sha256": stub_sha},
        "patches": [{
            "file": "fixture.patch", "sha256": checksum(fix),
            "source": "jaclang/expr.jac", "before_sha256": checksum(before),
            "after_sha256": checksum(after),
        }],
    }
    (fixture_spec / "manifest.json").write_text(json.dumps(manifest))
    both_cold = threading.Barrier(2)

    def download(url, timeout):
        assert timeout == 60
        if url == manifest["archive_url"]:
            # Both invocations must observe the cache missing before either
            # can publish. Exercise the real extraction, patch and rename.
            both_cold.wait(timeout=10)
            return io.BytesIO(source_archive)
        assert url.endswith("/fixture-stubs")
        return io.BytesIO(gzip.compress(stub_tar))

    with patch.object(toolchain, "ROOT", root), patch.object(toolchain, "SPEC", fixture_spec), \
            patch.object(toolchain.urllib.request, "urlopen", side_effect=download):
        with ThreadPoolExecutor(max_workers=2) as pool:
            prepared = list(pool.map(lambda _: toolchain.prepare(), range(2)))
        assert prepared[0] == prepared[1] == toolchain.prepare()
        assert (prepared[0] / "jaclang/expr.jac").read_text() == after
        assert (prepared[0] / "jaclang/vendor/typeshed/stdlib/.typeshed-sha").read_text().strip() == "fixture-stubs"
print("ok   concurrent cold preparations publish and reuse one verified compiler")
