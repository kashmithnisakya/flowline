"""The workspace's own scheduled reconcile job. The runtime schedules a
dynamic job as the user who created it, so the tick runs on this workspace's
root and can apply what it finds; nothing else can, since a walker never
learns its own user id. Hence the client creates the job: it is the one
caller that holds an identity. `@jac/runtime` exports no /jobs helper, so
these fetch by hand with the stored JWT, like lib/session.jac.
"""

# Local on purpose, rather than imported from lib/session.jac: a shared
# client def:pub can compile to a dynamic call whose return value is not
# what the caller expects (#154), and this is two lines.
# The walker the job runs, and how often. Literals, not module globs: a glob
# here has no binding in the client bundle (E5086), pinned or not. An hour
# matches the window the live cooldown already uses: deliveries carry the
# minutes, this carries the days a workspace nobody opens would otherwise
# miss.
def reconcileWalker -> str {
    return "ReconcileGithub";
}


def jobHeaders -> dict[str, str] {
    token = localStorage.getItem("jac_token") or "";
    return {"Content-Type": "application/json", "Authorization": "Bearer " + token};
}


# This workspace's reconcile jobs, newest first. Empty when the scheduler is
# off, the request fails, or none were ever created.
async def:pub reconcileJobs -> list[dict[str, any]] {
    try {
        response = await fetch("/jobs?limit=100", {"headers": jobHeaders()});
        if not response.ok {
            return [];
        }
        body = await response.json();
        data = body["data"] if body["data"] else {};
        rows = data["jobs"] if data["jobs"] else [];
        return [
            r
            for r in rows
            if r["walker_or_function"] == reconcileWalker()
                or r["name"] == reconcileWalker()
        ];
    } except Exception as e {
        return [];
    }
}


# One job per workspace: create it only when the workspace has none, so a
# reconnect cannot leave two ticks running the same pass.
async def:pub ensureReconcileJob -> bool {
    existing = await reconcileJobs();
    if len(existing) > 0 {
        return True;
    }
    try {
        response = await fetch(
            "/jobs",
            {
                "method": "POST",
                "headers": jobHeaders(),
                "body": JSON.stringify(
                    {
                        "walker_or_function": reconcileWalker(),
                        "trigger": "interval",
                        "interval": 3600.0
                    }
                )
            }
        );
        return response.ok;
    } except Exception as e {
        return False;
    }
}


# Disconnecting GitHub retires the job: a tick with no connection reports
# not_connected forever, and the scheduler would keep firing it.
async def:pub dropReconcileJobs -> bool {
    rows = await reconcileJobs();
    ok = True;
    for r in rows {
        jobId = r["job_id"] if r["job_id"] else "";
        if not jobId {
            continue;
        }
        try {
            response = await fetch(
                "/jobs/" + jobId, {"method": "DELETE", "headers": jobHeaders()}
            );
            if not response.ok {
                ok = False;
            }
        } except Exception as e {
            ok = False;
        }
    }
    return ok;
}
