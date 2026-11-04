#!/usr/bin/env python3
"""Headless process/CLI/MCP integration on a disposable test deployment.

Creates test accounts. Run with the agent client and MCP SDK installed:
python tests/smoke/agent_interface_gate.py http://127.0.0.1:8000
"""

import asyncio
import copy
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from flowline_agent.operations import process_example
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

BASE = sys.argv[1].rstrip("/") if len(sys.argv) > 1 else "http://127.0.0.1:8000"
ROOT = Path(__file__).resolve().parents[2]
DOCUMENT = process_example()


def request(path, body, token=""):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(BASE + path, json.dumps(body).encode(), headers)
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as exc:
        return exc.code, json.loads(exc.read())


def walker(name, body=None, token=""):
    status, payload = request("/walker/" + name, body or {}, token)
    assert status == 200, (name, status, payload)
    reports = payload.get("data", payload).get("reports", [])
    assert reports, (name, payload)
    return reports[0]


def account(with_credentials=False):
    tag = uuid.uuid4().hex
    email, password = (
        f"agent-{tag}@flowline-test.invalid",
        "Pw-" + uuid.uuid4().hex + "-Ab7!",
    )
    status, payload = request(
        "/user/register",
        {
            "identities": [{"type": "email", "value": email}],
            "credential": {"type": "password", "password": password},
            "profile": {"org_name": "Agent interface test"},
        },
    )
    assert status in (200, 201), (status, payload)
    status, payload = request(
        "/user/login",
        {
            "identity": {"type": "email", "value": email},
            "credential": {"type": "password", "password": password},
        },
    )
    assert status == 200 and payload["data"]["token"], (status, payload)
    token = payload["data"]["token"]
    return (token, email, password) if with_credentials else token


def domain(value):
    if isinstance(value, dict):
        return {k: domain(v) for k, v in value.items() if not k.startswith("_jac_")}
    if isinstance(value, list):
        return [domain(v) for v in value]
    return value


def run():
    for _ in range(300):
        try:
            with urllib.request.urlopen(BASE, timeout=2) as response:
                if response.status == 200:
                    break
        except (OSError, urllib.error.URLError):
            time.sleep(1)
    else:
        raise AssertionError("Test server did not start")
    for name in (
        "ListProcessDefinitions",
        "GetProcessDefinition",
        "ValidateProcessDefinition",
        "SaveProcessDefinition",
    ):
        status, _ = request(
            "/walker/" + name,
            {"process_id": "missing", "document": DOCUMENT, "request_id": "anonymous"},
        )
        assert status == 401, (name, status)
    owner, email, password = account(with_credentials=True)
    other = account()
    operational = domain(walker("GetFlowLine", token=owner))
    assert walker("ListProcessDefinitions", token=owner)["total"] == 0
    assert walker("ValidateProcessDefinition", {"document": DOCUMENT}, owner)["ok"]
    create = {"document": DOCUMENT, "request_id": "create-concurrently"}
    with ThreadPoolExecutor(2) as pool:
        results = list(
            pool.map(lambda _: walker("SaveProcessDefinition", create, owner), range(2))
        )
    assert all(r["ok"] for r in results), results
    assert len({r["process_id"] for r in results}) == 1
    assert sorted(r["replayed"] for r in results) == [False, True]
    created = results[0]
    pid = created["process_id"]
    assert walker("ListProcessDefinitions", token=owner)["total"] == 1
    altered = {**DOCUMENT, "title": "Another process"}
    assert (
        walker("SaveProcessDefinition", {**create, "document": altered}, owner)["error"]
        == "request_id_reused"
    )
    print(
        "ok   anonymous calls rejected; concurrent creation retries yield one process",
        flush=True,
    )

    current = walker(
        "GetProcessDefinition", {"process_id": pid, "include_history": True}, owner
    )["process"]
    assert current["document"] == DOCUMENT and not current["history"]
    assert (
        walker(
            "SaveProcessDefinition",
            {"document": altered, "process_id": pid, "request_id": "missing-etag"},
            owner,
        )["error"]
        == "conflict"
    )
    update = {
        "document": altered,
        "process_id": pid,
        "request_id": "update-1",
        "expected_etag": current["etag"],
    }
    updated = walker("SaveProcessDefinition", update, owner)
    assert updated["ok"] and updated["revision"] == 2
    replay = walker("SaveProcessDefinition", update, owner)
    assert replay["replayed"] and replay["etag"] == updated["etag"]
    assert (
        walker(
            "SaveProcessDefinition", {**update, "request_id": "stale-update"}, owner
        )["error"]
        == "conflict"
    )
    saved = walker(
        "GetProcessDefinition", {"process_id": pid, "include_history": True}, owner
    )["process"]
    assert saved["id"] == pid and saved["document"]["title"] == altered["title"]
    assert saved["history"][0]["title"] == DOCUMENT["title"]
    assert saved["history"][0]["steps"] == DOCUMENT["steps"]
    assert saved["history"][0]["request_id"] == "update-1"
    with ThreadPoolExecutor(2) as pool:
        races = list(
            pool.map(
                lambda i: walker(
                    "SaveProcessDefinition",
                    {
                        "document": {**DOCUMENT, "title": f"Concurrent edit {i}"},
                        "process_id": pid,
                        "expected_etag": saved["etag"],
                        "request_id": f"race-{i}",
                    },
                    owner,
                ),
                range(2),
            )
        )
    assert sum(r.get("ok", False) for r in races) == 1, races
    assert [r.get("error") for r in races if not r.get("ok")] == ["conflict"], races
    print(
        "ok   updates retain IDs/history, retries replay, and stale/concurrent edits conflict",
        flush=True,
    )

    for name in ("GetProcessDefinition", "SaveProcessDefinition"):
        body = {
            "process_id": pid,
            "document": DOCUMENT,
            "request_id": "foreign",
            "expected_etag": saved["etag"],
        }
        assert walker(name, body, other) == {"ok": False, "error": "not_found"}
        assert walker(name, {**body, "process_id": "malformed"}, other) == {
            "ok": False,
            "error": "not_found",
        }
    assert walker("ListProcessDefinitions", token=other)["total"] == 0
    for field, value in (
        ("id", "intake"),
        ("x", "nan"),
        ("source_url", "javascript:alert(1)"),
        ("source_url", "https://[invalid"),
        ("source_url", "https://@example.test/reference"),
        ("kind", "unknown-kind"),
    ):
        bad = copy.deepcopy(DOCUMENT)
        bad["steps"][1][field] = value
        if field == "source_url":
            bad["steps"][1]["source_label"] = "Reference"
        validation = walker("ValidateProcessDefinition", {"document": bad}, owner)
        assert not validation["ok"] and validation["errors"]
        assert (
            walker(
                "SaveProcessDefinition",
                {"document": bad, "request_id": "invalid-" + field},
                owner,
            )["error"]
            == "invalid_definition"
        )
    bad = copy.deepcopy(DOCUMENT)
    bad["transitions"][0]["target"] = "nonexistent"
    assert not walker("ValidateProcessDefinition", {"document": bad}, owner)["ok"]
    assert not walker(
        "ValidateProcessDefinition", {"document": {**DOCUMENT, "revision": 999}}, owner
    )["ok"]
    assert domain(walker("GetFlowLine", token=owner)) == operational
    print(
        "ok   workspace isolation, invalid graphs/links and operational flow isolation",
        flush=True,
    )

    with tempfile.TemporaryDirectory(prefix="flowline-client-gate-") as tmp:
        env = {
            **os.environ,
            "FLOWLINE_URL": BASE,
            "FLOWLINE_CONFIG": str(Path(tmp) / "credentials.json"),
        }
        env.pop("FLOWLINE_TOKEN", None)
        command = [sys.executable, "-m", "flowline_agent.cli"]

        def cli(*args, expect=0, stdin=None):
            response = subprocess.run(
                [*command, *args],
                input=stdin,
                capture_output=True,
                text=True,
                env=env,
                timeout=60,
                check=False,
            )
            assert response.returncode == expect, (
                args,
                response.stdout,
                response.stderr,
            )
            return json.loads(response.stdout)

        login = cli(
            "login", "--email", email, "--password-stdin", stdin=password + "\n"
        )
        assert login == {"ok": True, "url": BASE, "authenticated": True}
        cli_created = cli(
            "process",
            "create",
            "-",
            "--request-id",
            "cli-create",
            stdin=json.dumps(DOCUMENT),
        )
        cli_process = cli("process", "get", cli_created["process_id"])["process"]
        assert cli_process["document"] == DOCUMENT
        assert cli("process", "export", cli_created["process_id"]) == DOCUMENT
        changed = {**DOCUMENT, "summary": "Edited through the hosted API CLI"}
        assert cli(
            "process", "diff", cli_created["process_id"], "-", stdin=json.dumps(changed)
        )["diff"]
        cli(
            "process",
            "update",
            cli_created["process_id"],
            "-",
            "--etag",
            cli_process["etag"],
            "--request-id",
            "cli-update",
            stdin=json.dumps(changed),
        )
        assert (
            cli(
                "process",
                "update",
                cli_created["process_id"],
                "-",
                "--etag",
                cli_process["etag"],
                "--request-id",
                "cli-stale",
                stdin=json.dumps(changed),
                expect=1,
            )["error"]
            == "conflict"
        )
        project = walker("SaveProject", {"name": "Agent task integration"}, owner)
        project_id = project["_jac_id"]
        projects = cli("projects")["rows"]
        assert any(p["id"] == project_id for p in projects)
        task = cli(
            "task", "create", "--project-id", project_id, "--title", "Headless task"
        )
        assert cli("task", "get", task["id"])["title"] == "Headless task"
        before_move = domain(walker("GetTask", {"task_id": task["id"]}, owner))
        for invalid_status in ("", "Misspelled status"):
            refused = walker(
                "MoveTask", {"task_id": task["id"], "status": invalid_status}, owner
            )
            assert refused.get("refused") == "Unknown task status", refused
            assert (
                domain(walker("GetTask", {"task_id": task["id"]}, owner)) == before_move
            )
        cli("task", "move", task["id"], "--status", "In Progress")
        active_step = walker("SaveStep", {"name": "Active", "kind": "active"}, owner)
        review_step = walker("SaveStep", {"name": "Needs PR", "kind": "handoff"}, owner)
        walker("SetStepRules", {"step_id": review_step["id"], "needs_pr": True}, owner)
        moved = cli("task", "move", task["id"], "--step-id", active_step["id"])
        assert moved["step_id"] == active_step["id"]
        before_refusal = domain(walker("GetTask", {"task_id": task["id"]}, owner))
        refused = cli(
            "task", "move", task["id"], "--step-id", review_step["id"], expect=1
        )
        assert refused["error"] == "transition_refused"
        assert (
            domain(walker("GetTask", {"task_id": task["id"]}, owner)) == before_refusal
        )
        print(
            "ok   CLI process/task operations, invalid status refusal and step entry rules",
            flush=True,
        )

        async def mcp():
            params = StdioServerParameters(
                command=sys.executable,
                args=["-m", "flowline_agent.mcp_server", "--allow-write"],
                env=env,
            )
            async with (
                stdio_client(params) as (read, write),
                ClientSession(read, write) as session,
            ):
                await session.initialize()
                assert "save_process" in {
                    t.name for t in (await session.list_tools()).tools
                }
                result = await session.call_tool(
                    "save_process", {"document": DOCUMENT, "request_id": "mcp-create"}
                )
                assert not result.isError, result
                receipt = result.structuredContent
                result = await session.call_tool(
                    "get_process", {"process_id": receipt["process_id"]}
                )
                assert (
                    not result.isError
                    and result.structuredContent["process"]["document"] == DOCUMENT
                )
                result = await session.call_tool(
                    "save_process",
                    {
                        "document": DOCUMENT,
                        "process_id": receipt["process_id"],
                        "request_id": "mcp-stale",
                        "expected_etag": "stale",
                    },
                )
                assert result.isError and "conflict" in result.content[0].text
                result = await session.call_tool(
                    "create_task",
                    {
                        "project_id": project_id,
                        "title": "MCP task",
                        "step_id": active_step["id"],
                        "notes": "Preserve these notes",
                    },
                )
                assert not result.isError, result
                mcp_task = result.structuredContent
                assert mcp_task["step_id"] == active_step["id"]
                result = await session.call_tool(
                    "get_task", {"task_id": mcp_task["id"]}
                )
                assert (
                    not result.isError
                    and result.structuredContent["notes"] == "Preserve these notes"
                )
                before_refusal = domain(result.structuredContent)
                result = await session.call_tool(
                    "move_task",
                    {"task_id": mcp_task["id"], "step_id": review_step["id"]},
                )
                assert result.isError and "transition_refused" in result.content[0].text
                result = await session.call_tool(
                    "get_task", {"task_id": mcp_task["id"]}
                )
                assert (
                    not result.isError
                    and domain(result.structuredContent) == before_refusal
                )
                result = await session.call_tool(
                    "move_task", {"task_id": mcp_task["id"], "status": "Blocked"}
                )
                assert not result.isError, result
                assert result.structuredContent["status"] == "Blocked"
                assert result.structuredContent["step_id"] == ""

        asyncio.run(mcp())
        print(
            "ok   real MCP process/task operations, conflicts and entry-rule refusals",
            flush=True,
        )
    print("agent interface gate: PASS", flush=True)


if __name__ == "__main__":
    run()
