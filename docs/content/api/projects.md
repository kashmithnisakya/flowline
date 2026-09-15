# Projects

Projects group tasks and repos. Every task lives under exactly
one project, so a workspace needs a project before it can create work.
Source: `services/projects/projects.jac`.
{ .fl-lede }

::: walker ListProjects

**Reports** one list of raw [`Project`](../concepts/data-graph.md#project) nodes
sorted by name, archived projects included. A workspace with no projects
reports `[]` and creates nothing.

```json title="data.reports"
[
  [
    { "_jac_id": "<project-id>", "name": "Docs site", "description": "", "active": true },
    { "_jac_id": "<project-id-2>", "name": "Mobile app", "description": "iOS first", "active": false }
  ]
]
```

::: walker SaveProject

An empty `project_id` creates a project; otherwise the addressed project is
updated.

**Reports** the saved `Project` node.
**No-op when** the name is blank after trimming, or `project_id` is set but
unknown or foreign (it never falls back to creating).
**Notes** saving never changes `active`, so it does not un-archive, and names
are not required to be unique.

```bash
curl -X POST $BASE/walker/SaveProject -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Docs site", "description": "The public docs"}'
```

::: walker ArchiveProject

**Reports** `{"archived": "<project id>"}`.
**Side effects** sets `active = false` and nothing else: tasks, repo links and
members' project assignments stay. An archived project refuses new tasks
(`CreateTask`) and new repos (`AddRepo`); its existing tasks still show on the
board. No walker un-archives.

::: walker AssignToProject

Puts a roster member on a project (a `Member -OnProject-> Project` edge).

**Reports** `{"assigned": true}`, also when the member was already on it.
**No-op when** either id is not an owned member or project.
**Why it matters** a step's owner role hands a card only to a member who holds
the role **and** is on the task's project. See
[Handoffs follow roles](../concepts/flow-lines.md#handoffs-follow-roles).

::: walker UnassignFromProject

**Reports** `{"unassigned": true}`, even when there was no assignment.
**No-op when** either id is not an owned member or project.

## Lookup base

The base the jid-addressed walkers above extend: it resolves the id, checks ownership and only then visits. It is not an HTTP endpoint.

::: walker find_project h3
