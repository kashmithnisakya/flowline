"""The MCP tool surface over the standup walker API.

Eleven tools, not the full 29 walkers: agents choose badly among many
near-identical tools. Deletes and structural org edits (projects, members,
repos, vocab) are deliberately absent, and so are the assistant walkers, since
the MCP client already has a model of its own and `get_digest` hands it the
same snapshot those walkers reason over.

Every argument that names a node takes a jid obtained from a `list_*` tool.
Nothing here resolves a name to a jid, because that would put identity
resolution on this side of the walker boundary where `owned()` cannot see it.

Status and priority are `Literal` types on purpose: the SDK turns them into a
JSON Schema `enum` and pydantic rejects a bad value before the walker is ever
called, so a hallucinated column cannot reach the board.
"""

import from constants { STATUSES, PRIORITIES }
import from client { StandupClient, StandupError }


# The tool functions are module-level so their signatures introspect cleanly
# for schema generation. They reach the client through this holder rather than
# a rebound global, which Jac has no syntax for inside a `def`.
obj ClientHolder {
    has client: StandupClient | None = None;
}


glob HOLDER = ClientHolder();


def use_client(c: StandupClient) {
    HOLDER.client = c;
}


def api -> StandupClient {
    c = HOLDER.client;
    if c is None {
        raise StandupError("MCP client not initialised");
    }
    return c;
}


# `constants.jac` is the single source of truth, but a Literal annotation has
# to be written out literally. Fail at startup if the two drift apart rather
# than silently shipping a stale enum to the model.
def check_constants_in_sync {
    expected = ["Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"];
    if list(STATUSES) != expected {
        raise StandupError(
            f"STATUSES changed in constants.jac ({STATUSES}) but the Literal "
            + f"types in mcp_server/tools.jac still say {expected}. Update both."
        );
    }
    if list(PRIORITIES) != ["High", "Medium", "Low"] {
        raise StandupError(
            f"PRIORITIES changed in constants.jac ({PRIORITIES}) but the "
            + "Literal types in mcp_server/tools.jac did not. Update both."
        );
    }
}


# List walkers carry `has results` and report the whole list in one shot, so
# `reports` arrives as [[row, row, ...]]. Flatten that one level.
def rows(reports: list[any]) -> list[any] {
    if not reports {
        return [];
    }
    head = reports[0];
    return head if isinstance(head, list) else reports;
}


# Guarantee every row carries an `id` the write tools can accept.
#
# The two row shapes differ. TaskView and MemberView are `obj` views that
# declare `id` outright. Raw nodes (LogEntry, Project) serialize with the
# runtime's own envelope instead: `_jac_id` alongside `_jac_type` and
# `_jac_archetype`. Without this, update_log_entry has no id to take and the
# model starts inventing them.
#
# The `_jac_*` keys are serialization detail, not domain data, so they are
# dropped once the id has been lifted out. Tool output is prompt context and
# every wasted key is wasted budget.
def with_ids(raw: list[any]) -> list[dict[str, any]] {
    out: list[dict[str, any]] = [];
    for r in raw {
        if not isinstance(r, dict) {
            continue;
        }
        row = dict(r);
        if "id" not in row or not row["id"] {
            for k in ["_jac_id", "jid", "__jid__"] {
                if k in row and row[k] {
                    row["id"] = row[k];
                    break;
                }
            }
        }
        for k in ["_jac_id", "_jac_type", "_jac_archetype"] {
            if k in row {
                del row[k];
            }
        }
        out.append(row);
    }
    return out;
}


# ------------------------------------------------------------------ read tools

def standup_whoami -> dict[str, any] {
    c = api();
    profile = c.get_profile();
    vocab = rows(c.call_walker("ListVocab"));
    categories: list[str] = [];
    tags: list[str] = [];
    for term in vocab {
        if not isinstance(term, dict) {
            continue;
        }
        kind = term["kind"] if "kind" in term else "";
        value = term["value"] if "value" in term else "";
        if kind == "category" and value {
            categories.append(str(value));
        } elif kind == "tag" and value {
            tags.append(str(value));
        }
    }
    return {
        "org_name": profile["org_name"] if "org_name" in profile else "",
        "full_name": profile["full_name"] if "full_name" in profile else "",
        "statuses": list(STATUSES),
        "priorities": list(PRIORITIES),
        "categories": categories,
        "tags": tags,
        "server": c.base_url
    };
}


def list_projects -> list[dict[str, any]] {
    return with_ids(rows(api().call_walker("ListProjects")));
}


def list_members -> list[dict[str, any]] {
    return with_ids(rows(api().call_walker("ListMembers")));
}


def list_tasks -> list[dict[str, any]] {
    return with_ids(rows(api().call_walker("ListTasks")));
}


def list_log_entries(from_date: str, to_date: str) -> list[dict[str, any]] {
    return with_ids(
        rows(
            api().call_walker(
                "ListLogEntries", {"from_date": from_date, "to_date": to_date}
            )
        )
    );
}


def get_digest(from_date: str = "", to_date: str = "") -> dict[str, any] {
    out = api().call_walker(
        "Digest", {"from_date": from_date, "to_date": to_date}
    );
    if out and isinstance(out[0], dict) {
        return out[0];
    }
    return {};
}


# ----------------------------------------------------------------- write tools

def create_task(
    title: str,
    status: Literal[
        "Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"
    ] = "Backlog",
    priority: Literal["High", "Medium", "Low"] = "Medium",
    category: str = "",
    due_date: str = "",
    notes: str = "",
    issue_link: str = "",
    project_id: str = "",
    # `= []` rather than `| None`: it keeps the generated schema a plain array
    # with an empty default instead of an anyOf-with-null the model has to
    # reason about. Nothing here mutates it.
    assignee_ids: list[str] = []
) -> dict[str, any] {
    out = api().call_walker(
        "CreateTask",
        {
            "title": title,
            "status": status,
            "priority": priority,
            "category": category,
            "due_date": due_date,
            "notes": notes,
            "issue_link": issue_link,
            "project_id": project_id,
            "assignee_ids": assignee_ids
        }
    );
    if out and isinstance(out[0], dict) {
        return with_ids([out[0]])[0];
    }
    raise StandupError("CreateTask returned nothing");
}


def update_task(
    task_id: str,
    title: str = "",
    status: Literal[
        "", "Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"
    ] = "",
    priority: Literal["", "High", "Medium", "Low"] = "",
    category: str = "",
    due_date: str = "",
    notes: str = "",
    issue_link: str = "",
    pr_link: str = "",
    project_id: str = "",
    assignee_ids: list[str] = []
) -> dict[str, any] {
    out = api().call_walker(
        "UpdateTask",
        {
            "task_id": task_id,
            "title": title,
            "status": status,
            "priority": priority,
            "category": category,
            "due_date": due_date,
            "notes": notes,
            "issue_link": issue_link,
            "pr_link": pr_link,
            "project_id": project_id,
            "assignee_ids": assignee_ids
        }
    );
    if out and isinstance(out[0], dict) {
        return with_ids([out[0]])[0];
    }
    raise StandupError(
        f"UpdateTask changed nothing for {task_id}. The id may be wrong or "
        + "belong to another account."
    );
}


def move_task(
    task_id: str,
    status: Literal[
        "Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"
    ]
) -> dict[str, any] {
    out = api().call_walker("MoveTask", {"task_id": task_id, "status": status});
    if out and isinstance(out[0], dict) {
        return with_ids([out[0]])[0];
    }
    raise StandupError(
        f"MoveTask changed nothing for {task_id}. The id may be wrong or "
        + "belong to another account."
    );
}


def log_activity(
    date: str,
    member_id: str,
    activity: str,
    project_id: str = "",
    category: str = "",
    repo: str = "",
    issue_link: str = "",
    pr_link: str = "",
    status: str = "",
    notes: str = ""
) -> dict[str, any] {
    out = api().call_walker(
        "LogActivity",
        {
            "date": date,
            "member_id": member_id,
            "activity": activity,
            "project_id": project_id,
            "category": category,
            "repo": repo,
            "issue_link": issue_link,
            "pr_link": pr_link,
            "status": status,
            "notes": notes
        }
    );
    if out and isinstance(out[0], dict) {
        return with_ids([out[0]])[0];
    }
    raise StandupError(
        f"LogActivity wrote nothing. Check that member_id {member_id} came "
        + "from list_members."
    );
}


def update_log_entry(
    entry_id: str,
    activity: str = "",
    category: str = "",
    repo: str = "",
    issue_link: str = "",
    pr_link: str = "",
    status: str = "",
    notes: str = ""
) -> dict[str, any] {
    out = api().call_walker(
        "UpdateLogEntry",
        {
            "entry_id": entry_id,
            "activity": activity,
            "category": category,
            "repo": repo,
            "issue_link": issue_link,
            "pr_link": pr_link,
            "status": status,
            "notes": notes
        }
    );
    if out and isinstance(out[0], dict) {
        return with_ids([out[0]])[0];
    }
    raise StandupError(
        f"UpdateLogEntry changed nothing for {entry_id}. The id may be wrong "
        + "or belong to another account."
    );
}
