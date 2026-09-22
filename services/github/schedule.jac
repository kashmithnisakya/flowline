"""The scheduled GitHub sync. Every SYNC_INTERVAL_SECONDS one worker (the
runtime's own sched: lease picks it across workers and pods) walks the
gh_installations index and runs one SyncGithub(auto=True) pass in each bound
workspace's own root, so no page load waits on GitHub. A per-workspace lease
keeps two passes apart and yields to a manual sync."""

import os;
import from jaclang { JacRuntime as Jac }
import from jaclang.runtime.exceptions { MissingAnchorError }
import from models { GithubConnection }
import from services.github.github { SyncGithub, SYNC_LEASE_SECONDS, connection_of }
import from services.github.util {
    bound_installations,
    release_binding,
    acquire_sync_lease,
    release_sync_lease,
    lease_owner,
    log
}
import from services.util { minutes_since }

# Read once at load. The gates shorten it to observe a pass; a deployment
# keeps the default. Never under ten seconds.
def interval_seconds -> int {
    raw = os.environ.get("FLOWLINE_SYNC_INTERVAL_SECONDS") or "";
    seconds = 300;
    if raw {
        try {
            seconds = int(raw);
        } except Exception {
            seconds = 300;
        }
    }
    return seconds if seconds >= 10 else 10;
}


glob SYNC_INTERVAL_SECONDS: int = interval_seconds();


# A binding outlives its workspace only when the root is gone or no longer
# holds that installation (the connect race #187 fixed, a store reset). The
# tick drops such a row instead of visiting it forever; an invalid
# connection keeps its row, so an unsuspend delivery can still reach it.
def drop_dead_binding(installation_id: int, root_jid: str, why: str) {
    if release_binding(installation_id, root_jid) {
        log.info(
            "github sync: installation " + str(installation_id) + " unbound: " + why
        );
    }
}


# One pass in the workspace's own root: inside the walker `here` and `root`
# are that root, so owned() and every helper work unchanged. Reports come
# back on the walker; a failure is logged and the tick moves on.
def sync_workspace(root_jid: str, installation_id: int) {
    where = "github sync: installation " + str(installation_id);
    try {
        ctx = Jac.create_j_context(user_root=root_jid);
    } except MissingAnchorError {
        drop_dead_binding(installation_id, root_jid, "its workspace no longer exists");
        return;
    } except Exception as e {
        log.warning(where + " raised " + type(e).__name__ + ": " + str(e));
        return;
    }
    token = Jac.push_request_context(ctx);
    try {
        holder: any = ctx.get_root();
        c = connection_of(holder);
        if not isinstance(c, GithubConnection)
            or c.installation_id != installation_id {
            drop_dead_binding(
                installation_id, root_jid, "the workspace no longer holds it"
            );
            return;
        }
        # A pass on cooldown reports the previous stamp back; a pass that
        # ran stamps a new one, even with nothing to poll.
        was = c.last_sync_at;
        pass_walker: any = SyncGithub(auto=True);
        w: any = Jac.spawn(pass_walker, holder);
        Jac.commit();
        summary: dict[str, any] = w.reports[0] if w.reports else {};
        on_cooldown = str(summary.get("last_sync_at") or "") == was;
        if not summary.get("ok") {
            log.warning(
                where + " skipped: " + str(summary.get("error") or "no report")
            );
        } elif summary.get("failure") {
            log.warning(where + " failed: " + str(summary.get("failure")));
        } else {
            log.info(
                where
                    + ": drained "
                    + str(summary.get("drained") or 0)
                    + ", added "
                    + str(summary.get("auto_added") or 0)
                    + ", moved "
                    + str(summary.get("auto_done") or 0)
                    + ", refreshed "
                    + str(summary.get("refreshed") or 0)
                    + ", scanned "
                    + str(summary.get("scanned") or 0)
                    + " in "
                    + str(summary.get("pages") or 0)
                    + " pages, lists "
                    + str(summary.get("lists") or 0)
                    + (", more pending" if summary.get("has_more") else "")
                    + (
                        (
                            ", on cooldown ("
                            + str(summary.get("cooldown_minutes") or 0)
                            + " min)"
                        )
                            if on_cooldown
                            else ""
                    )
            );
        }
    } except Exception as e {
        log.warning(where + " raised " + type(e).__name__ + ": " + str(e));
    } finally {
        ctx.close();
        Jac.reset_request_context(token);
    }
}


@schedule(trigger=ScheduleTrigger.STATIC, interval=SYNC_INTERVAL_SECONDS)
def sync_connected_workspaces {
    owner = lease_owner();
    for row in bound_installations() {
        root_jid = str(row["root_jid"]);
        installation_id = int(row["installation_id"]);
        if not root_jid {
            continue;
        }
        # A workspace bound inside the last interval is still being set up
        # on the GitHub page; its first pass is the next tick.
        if minutes_since(str(row["bound_at"])) * 60.0 < SYNC_INTERVAL_SECONDS {
            continue;
        }
        if not acquire_sync_lease(root_jid, owner, SYNC_LEASE_SECONDS) {
            log.info(
                "github sync: installation "
                    + str(installation_id)
                    + " is leased elsewhere, skipped"
            );
            continue;
        }
        try {
            sync_workspace(root_jid, installation_id);
        } finally {
            release_sync_lease(root_jid, owner);
        }
    }
}
