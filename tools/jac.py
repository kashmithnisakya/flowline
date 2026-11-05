#!/usr/bin/env python3
"""Run pinned Jac with verified process-review compiler fixes, in isolation.

The installed binary is unchanged. Sources and exact backports are verified
before the binary loads them through its compiler-source handoff.
"""
from __future__ import annotations

import argparse
import errno
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SPEC = ROOT / "tools/jac_toolchain"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(path: Path, expected: str) -> None:
    if not path.is_file() or digest(path) != expected:
        raise RuntimeError(f"Compiler input checksum mismatch: {path}")


def verify_patched_sources(source_root: Path, patches: list[dict[str, str]]) -> None:
    # Several verified backports can touch one source file. The prepared cache
    # must match its final state, while construction checks each intermediate.
    final = {patch["source"]: patch["after_sha256"] for patch in patches}
    for relative, checksum in final.items():
        verify(source_root / relative, checksum)


def verify_prepared_sources(source_root: Path, manifest: dict) -> None:
    verify_patched_sources(source_root, manifest["patches"])
    stubs = source_root / "jaclang/vendor/typeshed/stdlib"
    stamp = stubs / ".typeshed-sha"
    if not (stubs / "typing.pyi").is_file() or not stamp.is_file() or (
        stamp.read_text().strip() != manifest["typeshed"]["commit"]
    ):
        raise RuntimeError(f"Pinned standard-library stubs are missing: {source_root}")


def extract_files(archive_path: Path, destination: Path, prefix: str) -> None:
    with tarfile.open(archive_path) as archive:
        for member in archive:
            if not member.isfile() or not member.name.startswith(prefix):
                continue
            relative = PurePosixPath(member.name[len(prefix):])
            if ".." in relative.parts or relative.is_absolute():
                raise RuntimeError("Invalid compiler archive path")
            if any(part in {"__pycache__", ".jac", "_precompiled"} for part in relative.parts):
                continue
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.extractfile(member) as content:
                target.write_bytes(content.read())


def prepare() -> Path:
    manifest_path = SPEC / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    fingerprint = digest(manifest_path)
    toolchains = ROOT / ".jac/toolchains"
    target = toolchains / f"processes-{manifest['jac_version']}-{fingerprint[:12]}"
    for patch in manifest["patches"]:
        verify(SPEC / patch["file"], patch["sha256"])
    if target.exists():
        verify_prepared_sources(target, manifest)
        return target

    toolchains.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="prepare-", dir=toolchains) as scratch:
        temporary = Path(scratch)
        archive_path = temporary / "source.tar.gz"
        print("Preparing the pinned process-review compiler…", flush=True)
        with urllib.request.urlopen(manifest["archive_url"], timeout=60) as response:
            with archive_path.open("wb") as destination:
                shutil.copyfileobj(response, destination)
        verify(archive_path, manifest["archive_sha256"])
        source = temporary / "source"
        source.mkdir()
        prefix = f"jac-{manifest['source_commit']}/jac/jaclang/"
        extract_files(archive_path, source / "jaclang", prefix)
        # Release source archives omit the generated stdlib stubs. Recreate
        # them using the exact pin and decompressed-tar checksum from Jac.
        stubs = source / "jaclang/vendor/typeshed"
        typeshed = manifest["typeshed"]
        if (stubs / "PIN").read_text().strip() != typeshed["commit"] or (
            stubs / "TARBALL_SHA256"
        ).read_text().strip() != typeshed["tar_sha256"]:
            raise RuntimeError("Jac's standard-library stub pin does not match the manifest")
        stub_archive = temporary / "typeshed.tar.gz"
        url = f"https://codeload.github.com/python/typeshed/tar.gz/{typeshed['commit']}"
        with urllib.request.urlopen(url, timeout=60) as response:
            with stub_archive.open("wb") as destination:
                shutil.copyfileobj(response, destination)
        with gzip.open(stub_archive, "rb") as content:
            checksum = hashlib.sha256()
            for block in iter(lambda: content.read(1024 * 1024), b""):
                checksum.update(block)
        if checksum.hexdigest() != typeshed["tar_sha256"]:
            raise RuntimeError("Standard-library stub archive checksum mismatch")
        extract_files(
            stub_archive, stubs / "stdlib", f"typeshed-{typeshed['commit']}/stdlib/"
        )
        (stubs / "stdlib/.typeshed-sha").write_text(typeshed["commit"] + "\n")
        for patch in manifest["patches"]:
            verify(source / patch["source"], patch["before_sha256"])
            subprocess.run(
                ["patch", "--batch", "--fuzz=0", "-p1", "-i", str(SPEC / patch["file"])],
                cwd=source,
                check=True,
            )
            verify(source / patch["source"], patch["after_sha256"])
        (source / "flowline-toolchain.json").write_text(json.dumps(manifest, indent=2) + "\n")
        try:
            source.rename(target)
        except OSError as exc:
            if exc.errno not in (errno.EEXIST, errno.ENOTEMPTY):
                raise
            # Another invocation may have prepared the same verified inputs.
        verify_prepared_sources(target, manifest)
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare", action="store_true", help="prepare without running Jac")
    parser.add_argument("--github-env", type=Path, help="export the compiler handoff to GitHub Actions")
    options, command = parser.parse_known_args()
    binary = shutil.which("jac")
    if not binary:
        parser.error("Install the exact Jac release from jac.toml first")
    manifest = json.loads((SPEC / "manifest.json").read_text())
    version = subprocess.check_output([binary, "--version"], text=True).strip()
    pin = re.search(r'^jac-version\s*=\s*"==([^\"]+)"', (ROOT / "jac.toml").read_text(), re.M)
    if not pin or pin[1] != manifest["jac_version"] or not re.search(
        rf"\b{re.escape(manifest['jac_version'])}\b", version
    ):
        parser.error(f"The binary, jac.toml and toolchain must agree on Jac {manifest['jac_version']}")
    source = prepare()
    handoff = json.dumps({"compiler_source": str(source)})
    if options.github_env:
        with options.github_env.open("a") as environment:
            environment.write(f"JAC_HANDOFF={handoff}\n")
        return 0
    if options.prepare:
        print(source)
        return 0
    if not command:
        parser.error("Pass a Jac command, for example: python3 tools/jac.py run main.jac")
    if command[0] == "--":
        command = command[1:]
    os.execve(binary, [binary, *command], {**os.environ, "JAC_HANDOFF": handoff})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
