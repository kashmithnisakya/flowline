# Tenancy and security

One account is one organization, and one organization must never
see another's data. Most of that is guaranteed by how walkers run. The rest is
one rule that every mutation follows by hand.
{ .fl-lede }

## Isolation is structural

Every walker endpoint requires a JWT. The runtime resolves the caller's root
from the token and spawns the walker **on that root**. A traversal such as
`[root --> ...]` can only reach nodes reachable from there, so a list walker
cannot return another tenant's rows no matter how it filters. There are no
public (`:pub`) walkers.

## Resolution is not authorization

The weak spot is an id in a request body. `jobj(id)` turns a jid into a node,
and on Jac 0.37.7+ it is owner-gated (a foreign node resolves to `None`), but
flowline does not rely on that. **Every jid-addressed mutation checks
ownership explicitly** before touching anything:

```jac title="models.jac"
# Does this node belong to the caller's root? Climbs container edges, at
# most three hops (task, project, Projects box); typed in-edges never lead
# to a container, so they drop out. jobj/jid resolution is NOT authorization:
# every jid-addressed mutation calls this first. "My root" is the tenant line.
def owned(holder: any, target: any) -> bool {
    frontier: list[any] = [target];
    for hop in range(3) {
        higher: list[any] = [];
        for node_ in frontier {
            for owner in [node_<--] {
                if jid(owner) == jid(holder) {
                    return True;
                }
                if is_container(owner) {
                    higher.append(owner);
                }
            }
        }
        frontier = higher;
    }
    return False;
}
```

Most mutations inherit the check from a **lookup base** that resolves, checks
and only then visits:

```jac title="services/tasks/tasks.jac"
walker find_task {
    has task_id: str = "";

    can locate with Root entry {
        target = resolve(self.task_id);
        if isinstance(target, Task) and owned(here, target) {
            visit [target];
        }
    }
}

walker DeleteTask(find_task) {
    can remove with Task entry {
        gone = jid(here);
        del here;
        report {"deleted": gone};
        disengage;
    }
}
```

The same pattern covers `find_project`, `find_member`, `find_step` and
`find_log_entry`. A walker that takes a second id (an assignee, a reviewer, a
target project) resolves and checks that one too.

!!! info "A foreign id is a silent no-op"

    An unknown, malformed or foreign id visits nothing, so the walker reports
    nothing (`reports: []`) with HTTP 200. The response is deliberately the
    same for "does not exist" and "not yours", so ids cannot be probed.

!!! danger "`here` is not always the root"

    Inside a `Task` or `LogDay` entry ability, `here` is the task or day. The
    caller's root is `root`. Passing `here` to `owned` or a box helper there
    silently drops assignee and project links instead of raising.

## Webhooks never touch a tenant graph

GitHub's deliveries arrive with no user attached. The receiver,
`GithubEvent`, runs as the runtime's **system identity** after the runtime has
verified `X-Hub-Signature-256` against the webhook secret. It does not apply
anything:

1. It looks the delivery's installation id up in the `gh_installations` index,
   which only a completed, ownership-proven connection writes.
2. It drops the App's own echoes and unsupported events.
3. It inserts the delivery into the shared `gh_deliveries` queue, keyed by
   GitHub's delivery id, so a redelivery is a primary-key no-op.

The workspace applies its own queue later, **in its own session**
(`DrainGithubEvents`, or the start of `SyncGithub`), and only when the index
binds that installation to its root. No walker ever writes a foreign root.
[GitHub sync](github-sync.md) walks through it.

## GitHub credentials

| Concern | How it is handled |
| --- | --- |
| Long-lived secrets | None stored in the graph. A workspace stores an installation id; each request mints a one-hour installation token from the App's private key and caches it in the worker's memory only. |
| Forged install callbacks | `StartGithubInstall` stores a one-shot nonce. `CompleteGithubInstall` burns it before any check, requires it to match, and expires it after 15 minutes. |
| Claiming someone else's installation | Installation ids are small integers, so completing a connection exchanges GitHub's OAuth code for the installer's user token and requires that installation to be visible to that user. The user token is then dropped. |
| Repo names in API paths | `valid_full_name` accepts exactly `owner/repo` with alphanumerics and `-_.`, so `..`, `?` or `#` cannot redirect a request. |
| The App's own writes | Closing or reopening an issue as a card crosses Done comes back as a webhook; the receiver drops it by sender login so it is never applied twice. |

## Errors do not leak internals

An **uncaught** walker exception is returned to the browser with its Python
traceback: the runtime includes it unconditionally. So anything that can fail
outside the app's control is caught inside the walker, logged server-side with
an operator hint, and reported as an empty result or an
`{"ok": false, "error": ...}` dict:

- The assistant catches LLM failures (`_llm_failed`) and reports nothing; the
  client shows "not available right now".
- Every GitHub call goes through `gh_request`, which maps failures to
  `not_connected`, `network`, `rate_limited`, `unauthorized`, `forbidden`,
  `not_found`, `invalid` or `request_failed`, and never passes exception text,
  headers or raw bodies back.

## Verifying isolation

Before merging a change to walkers or `owned()`, run an API gate that signs up
**two** accounts and asserts:

- cross-account reads return nothing;
- foreign-jid `UpdateTask`, `MoveTask`, `DeleteTask`, `AssignToProject`,
  `UpdateLogEntry`, `SaveProject` and `ArchiveMember` are no-ops;
- every list filter (`project_id`, `assignee_id`, `step_id`, `task_id`) yields
  nothing for a foreign id.

CI's webhook gate additionally checks that three workspaces stay isolated
through the connect, poll and delivery paths. See
[Verification and CI](../contributing/verification.md).
