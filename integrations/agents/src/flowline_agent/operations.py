"""Curated operations shared by the CLI and MCP adapters."""

from __future__ import annotations

import difflib
import json
from importlib.resources import files
from typing import Literal, get_args

from .client import FlowlineClient, FlowlineError

TaskStatus = Literal[
    "Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"
]
TASK_STATUSES = get_args(TaskStatus)


def process_example() -> dict:
    return json.loads(
        files("flowline_agent")
        .joinpath("process-example.json")
        .read_text(encoding="utf-8")
    )


def process_list(client: FlowlineClient, page: int = 1, page_size: int = 25) -> dict:
    return client.walker(
        "ListProcessDefinitions", {"page": page, "page_size": page_size}
    )


def process_get(
    client: FlowlineClient, process_id: str, include_history: bool = False
) -> dict:
    return client.walker(
        "GetProcessDefinition",
        {"process_id": process_id, "include_history": include_history},
    )


def process_validate(client: FlowlineClient, document: dict) -> dict:
    # Validation failure is useful data rather than a protocol failure.
    try:
        return client.walker("ValidateProcessDefinition", {"document": document})
    except FlowlineError as exc:
        if isinstance(exc.details, dict) and "errors" in exc.details:
            return exc.details
        raise


def process_save(
    client: FlowlineClient,
    document: dict,
    request_id: str,
    process_id: str = "",
    expected_etag: str = "",
) -> dict:
    return client.walker(
        "SaveProcessDefinition",
        {
            "document": document,
            "request_id": request_id,
            "process_id": process_id,
            "expected_etag": expected_etag,
        },
    )


def process_diff(client: FlowlineClient, process_id: str, document: dict) -> dict:
    current = process_get(client, process_id)["process"]
    before = json.dumps(current["document"], indent=2, sort_keys=True).splitlines(
        keepends=True
    )
    after = json.dumps(document, indent=2, sort_keys=True).splitlines(keepends=True)
    return {
        "ok": True,
        "process_id": process_id,
        "expected_etag": current["etag"],
        "diff": "".join(
            difflib.unified_diff(before, after, fromfile="saved", tofile="proposed")
        ),
    }


def tasks_list(
    client: FlowlineClient, page: int = 1, page_size: int = 25, project_id: str = ""
) -> dict:
    return client.walker(
        "ListTasks",
        {
            "scope": "all",
            "page": page,
            "page_size": page_size,
            "project_id": project_id,
        },
    )


def task_get(client: FlowlineClient, task_id: str) -> dict:
    return client.walker("GetTask", {"task_id": task_id})


def task_create(
    client: FlowlineClient,
    title: str,
    project_id: str,
    notes: str = "",
    step_id: str = "",
) -> dict:
    return client.walker(
        "CreateTask",
        {"title": title, "project_id": project_id, "notes": notes, "step_id": step_id},
    )


def task_move(
    client: FlowlineClient, task_id: str, step_id: str = "", status: str = ""
) -> dict:
    if bool(step_id) == bool(status):
        raise FlowlineError(
            "invalid_transition", "Provide exactly one of step_id or status"
        )
    if status and status not in TASK_STATUSES:
        raise FlowlineError(
            "invalid_transition", "Status must be one of: " + ", ".join(TASK_STATUSES)
        )
    return client.walker(
        "MoveTask", {"task_id": task_id, "step_id": step_id, "status": status}
    )
