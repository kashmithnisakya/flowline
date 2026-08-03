"""standup MCP server: a stdio bridge from an MCP client to the walker API.

Run it with `jac run mcp/server.jac`. It is a separate process from the app and
talks to a running standup server over HTTP, so the serve layer stays the
top-level walker spawn and every `owned()` check applies unchanged.

Never `print()` from this process. stdout carries the JSON-RPC stream and any
stray write corrupts it. Diagnostics go to stderr.
"""

import os;
import sys;
import from mcp.server.mcpserver { MCPServer }
import from client { build_client, StandupError }
import from tools {
    use_client,
    check_constants_in_sync,
    standup_whoami,
    list_projects,
    list_members,
    list_tasks,
    list_log_entries,
    get_digest,
    create_task,
    update_task,
    move_task,
    log_activity,
    update_log_entry
}


glob INSTRUCTIONS: str = """standup is a kanban board plus a written daily log for one organization.

Call standup_whoami first. It returns the org's real categories and tags and
the exact board columns, so you never have to guess them.

Every id argument is a jid that must come from a list_* tool in this same
session. Never invent, guess, or hand-edit one. Team members do not have
accounts, so write about them in the third person.""";


glob READ_TOOLS: list[any] = [
    (
        standup_whoami,
        "standup_whoami",
        "Identify the workspace: org name, the exact board columns (statuses), "
        + "priorities, and the org's own categories and tags. Call this first "
        + "so later calls use real vocabulary instead of guesses."
    ),
    (
        list_tasks,
        "list_tasks",
        "Every task on the board, each with its `id`, status, priority, "
        + "assignees and project. Use the `id` for move_task/update_task."
    ),
    (
        list_projects,
        "list_projects",
        "The organization's projects, each with its `id`. Use the `id` for a "
        + "task's project_id."
    ),
    (
        list_members,
        "list_members",
        "The team roster, each member with an `id`. Use the `id` for a task's "
        + "assignee_ids or a log entry's member_id."
    ),
    (
        list_log_entries,
        "list_log_entries",
        "Daily log entries between two dates, inclusive. Dates are YYYY-MM-DD. "
        + "Each entry carries an `id` for update_log_entry."
    ),
    (
        get_digest,
        "get_digest",
        "A computed workspace snapshot for a date range: blocked items, stale "
        + "work, and the review queue, all derived server-side. Prefer this "
        + "over reading every task when answering 'what is blocked' or 'what "
        + "needs review'. Dates are YYYY-MM-DD and default to today."
    )
];


glob WRITE_TOOLS: list[any] = [
    (
        create_task,
        "create_task",
        "Create a task on the board. project_id and assignee_ids must be jids "
        + "from list_projects/list_members. due_date is YYYY-MM-DD."
    ),
    (
        update_task,
        "update_task",
        "Edit an existing task. task_id must come from list_tasks. Every other "
        + "argument is optional and an empty one leaves that field unchanged."
    ),
    (
        move_task,
        "move_task",
        "Move a task to a different board column. task_id must come from "
        + "list_tasks. This is the tool for 'mark it done' or 'put it in review'."
    ),
    (
        log_activity,
        "log_activity",
        "Add an entry to the daily log. date is YYYY-MM-DD and member_id must "
        + "be a jid from list_members, since the log records who did the work."
    ),
    (
        update_log_entry,
        "update_log_entry",
        "Edit an existing daily-log entry. entry_id must come from "
        + "list_log_entries. Empty arguments leave their field unchanged."
    )
];


def register(srv: MCPServer, specs: list[any]) -> None {
    for spec in specs {
        srv.add_tool(spec[0], name=spec[1], description=spec[2]);
    }
}


with entry:__main__ {
    try {
        check_constants_in_sync();
        conn = build_client();
        conn.health_check();
        use_client(conn);
    } except StandupError as e {
        print(f"standup-mcp: {e}", file=sys.stderr);
        sys.exit(1);
    }

    srv = MCPServer("standup", instructions=INSTRUCTIONS, version="0.1.0");
    register(srv, READ_TOOLS);

    # Writes are opt-in. In the GUI the model proposes and a human confirms;
    # over MCP the tool call goes straight through, so the client's own
    # approval prompt is the only gate left. Deletes are not exposed at all.
    if os.environ.get("STANDUP_MCP_WRITE", "") == "1" {
        register(srv, WRITE_TOOLS);
        print("standup-mcp: write tools enabled", file=sys.stderr);
    } else {
        print(
            "standup-mcp: read-only (set STANDUP_MCP_WRITE=1 to enable writes)",
            file=sys.stderr
        );
    }

    srv.run();
}
