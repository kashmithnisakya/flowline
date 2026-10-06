# Roster and roles

The roster is the people a workspace tracks. Members never sign
in; they are assigned to tasks, hold roles, and appear in the log. This page
also covers the repos attached to projects. Source:
`services/roster/roster.jac`.
{ .fl-lede }

## Members

::: walker ListMembers h3

**Reports** one list of [`MemberView`](types.md#memberview) sorted by name,
archived members included. With no roster yet, `[]`.

::: walker SaveMember h3

An empty `member_id` creates a member; otherwise it replaces the member's
fields.

**Reports** the saved [`MemberView`](types.md#memberview).
**No-op when** `first_name` is blank after trimming, or `member_id` is set but
unknown or foreign.

!!! warning "Send the whole member"

    `roles` replaces every role the member holds, so omitting it clears them.
    A role name that does not exist yet is created as a `Role`. Saving never
    changes `active`.

```bash
curl -X POST $BASE/walker/SaveMember -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"first_name": "Priya", "last_name": "Raman", "roles": ["Model Pilot Engineer"],
       "github_username": "priyar", "tags": ["backend"], "color": "amber"}'
```

`github_username` is how the GitHub sync assigns imported issues: an issue
assigned to `priyar` on GitHub is assigned to this member on the card.

::: walker SetMemberRoles h3

Changes only a member's roles. The Workspace calls it from a person's roles
menu under People (the picks save when the menu closes) and from a role's
holders under Roles (one call per person whose roles change).

**Reports** the updated [`MemberView`](types.md#memberview).
**Side effects** replaces every `HasRole` edge; an empty list clears them; new
names become `Role` nodes.

::: walker ArchiveMember h3

**Reports** `{"archived": "<member id>"}`.
**Side effects** sets `active = false`; members are never deleted, so history
keeps its names. Every task the member is assigned to that is not Done has its
assignees cleared, so live work returns to Unassigned. Done tasks keep their
assignees.

## Roles

::: walker ListRoles h3

**Reports** one list of [`RoleView`](types.md#roleview) sorted by
`sort_order`. With no roles yet, `[]`.

::: walker SaveRole h3

Gets or creates the role called `name`, then optionally renames it or sets its
blurb and colour.

**Reports** `{"ok": true, "role": RoleView}`, or
`{"ok": false, "error": "name_taken"}` when `new_name` belongs to another role
(nothing is written).
**Side effects** a rename rewrites every flow line step whose `owner` was the
old name. `blurb` is written only when `touch_blurb` is true (so it can be
cleared); `color` is written only when non-empty.
**No-op when** `name` is blank.

::: walker DeleteRole h3

**Reports** `{"ok": true, "deleted": "<name>"}`, also when no role had that
name.
**Side effects** deletes the role (members lose it through the removed edge)
and clears `owner` on every step that named it.

## Repos

::: walker ListRepos h3

**Reports** one list of [`RepoView`](types.md#repoview) sorted by `full_name`.

::: walker AddRepo h3

Attaches `owner/repo` to a project. The GitHub sync files that repo's issues
under this project.

**Reports** the [`RepoView`](types.md#repoview).
**No-op when** `full_name` is not exactly `owner/repo` (alphanumerics and
`-_.`, each part at most 100 characters), or the project is missing, foreign or
archived.
**Side effects** reuses an existing repo with the same name; adding it with a
different project **moves** it there. Existing tasks do not move.

::: walker RemoveRepo h3

**Reports** `{"deleted": "<repo id>"}`.
**Side effects** deletes the repo and its project link. Tasks keep their GitHub
fields, and the GitHub installation is untouched.

## Lookup base

The base the jid-addressed walkers above extend: it resolves the id, checks ownership and only then visits. It is not an HTTP endpoint.

::: walker find_member h3
