#!/usr/bin/env python3
"""Assert a `jac scale deploy --dry-run --show-yaml` transcript would ship a
client bundle, more than one worker per app pod, and a gateway HPA with its own
ceiling. flowline-dev went API-only on 2026-09-08 because the deploy skipped
the client build, and ran four gateway pods on 2026-09-14 because the gateway
inherited the app's replica bounds; `jac run` never shows either, only this
transcript does. Usage: deploy_gate.py manifests.yaml"""
import re
import sys

SKIPPED = "skipping the client build"
WOULD_BUILD = "skipped the host client bundle build"
APP_DEPLOYMENT = "flowline-deployment"
GATEWAY_HPA = "gateway-hpa"
GATEWAY_MAX = 2


def worker_values(text: str) -> dict[str, str]:
    # Map each Deployment name to its JAC_SERVE_WORKERS value.
    found: dict[str, str] = {}
    name = ""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.startswith("kind: "):
            name = ""
        elif line.startswith("  name: ") and not name:
            name = line.split(":", 1)[1].strip()
        elif line.strip() == "- name: JAC_SERVE_WORKERS" and i + 1 < len(lines):
            value = lines[i + 1].split(":", 1)[1].strip().strip("'\"")
            found[name] = value
    return found


def hpa_bounds(text: str) -> dict[str, tuple[int, int]]:
    # Map each HorizontalPodAutoscaler name to (minReplicas, maxReplicas).
    found: dict[str, tuple[int, int]] = {}
    name = ""
    is_hpa = False
    lo = hi = 0
    for line in text.splitlines():
        if line.startswith("kind: "):
            if is_hpa and name:
                found[name] = (lo, hi)
            is_hpa = line.strip() == "kind: HorizontalPodAutoscaler"
            name = ""
            lo = hi = 0
        elif line.startswith("  name: ") and not name:
            name = line.split(":", 1)[1].strip()
        elif line.startswith("  minReplicas:"):
            lo = int(line.split(":", 1)[1])
        elif line.startswith("  maxReplicas:"):
            hi = int(line.split(":", 1)[1])
    if is_hpa and name:
        found[name] = (lo, hi)
    return found


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: deploy_gate.py <manifests.yaml>")
        return 2
    text = open(sys.argv[1], encoding="utf-8").read()
    failures: list[str] = []

    if SKIPPED in text:
        failures.append(
            "the deploy would skip the client bundle build; pods would serve "
            "the API only and / would be a JSON 404 (is the app declared "
            "under [apps.<name>] instead of [project]?)"
        )
    if WOULD_BUILD not in text:
        failures.append(f"transcript never says '{WOULD_BUILD}'")

    fleet = re.search(r'"app": "flowline", "client": (true|false)', text)
    if fleet is None:
        failures.append("no JAC_SV_FLEET member named flowline in the manifests")
    elif fleet.group(1) != "true":
        failures.append("the flowline fleet member has client: false")

    workers = worker_values(text)
    value = workers.get(APP_DEPLOYMENT)
    if value is None:
        failures.append(f"{APP_DEPLOYMENT} has no JAC_SERVE_WORKERS env")
    elif value != "auto" and not (value.isdigit() and int(value) >= 2):
        failures.append(
            f"{APP_DEPLOYMENT} would run JAC_SERVE_WORKERS={value}; expected "
            "'auto' or at least 2 (see [serve.workers] in jac.toml)"
        )

    hpas = hpa_bounds(text)
    bounds = hpas.get(GATEWAY_HPA)
    if bounds is None:
        failures.append(f"no {GATEWAY_HPA} in the manifests")
    elif bounds[1] > GATEWAY_MAX:
        failures.append(
            f"{GATEWAY_HPA} would scale to {bounds[1]} pods; the gateway only "
            f"proxies, so keep [scale.gateway.hpa] max at {GATEWAY_MAX} or "
            "below (without that table it inherits [scale.kubernetes] bounds)"
        )

    print(f"client build: {'would build' if WOULD_BUILD in text else 'SKIPPED'}")
    for dep, val in sorted(workers.items()):
        print(f"{dep}: JAC_SERVE_WORKERS={val}")
    for hpa, (lo, hi) in sorted(hpas.items()):
        print(f"{hpa}: replicas {lo} -> {hi}")
    for f in failures:
        print(f"FAIL {f}")
    print("deploy gate: " + ("PASS" if not failures else "FAIL"))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
