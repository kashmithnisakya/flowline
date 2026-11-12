"""Queuing a role's AI responsibilities when a task lands on one of its steps.
A queued run is an AgentRun node, written in the move's own commit; the
runner (services/agents/runner.jac) finds the workspace through the
`ai_queue` docs-store index and claims the run."""

import json;
import logging;
import from jaclang.server.shared_store { shared_store }
import from models {
    Task,
    WorkflowStep,
    AgentRun,
    responsibilities_on_step,
    active_run,
    agent_runs_box,
    agent_run_key,
    ai_enabled,
    on_attached,
    settle_ai
}
import from constants { AI_RESPONSIBILITIES, AGENT_LIMITS }

glob AI_QUEUE: str = "ai_queue",
     log: logging.Logger = logging.getLogger("flowline.agents");

def catalogue_name(key: str) -> str {
    for known in AI_RESPONSIBILITIES {
        if known["key"] == key {
            return known["name"];
        }
    }
    return key;
}


# The task's linked pull request as [repo, number], or [] when it has none.
# The URL is what people paste; pr_number and gh_repo are what the sync set.
def pr_of(t: Task) -> list[any] {
    link = t.pr_link.strip();
    marker = "github.com/";
    if marker in link and "/pull/" in link {
        rest = link.split(marker, 1)[1];
        parts = rest.split("/");
        if len(parts) >= 4 and parts[2] == "pull" {
            digits = "".join(
                [
                    ch
                    for ch in parts[3]
                    if ch.isdigit()
                ]
            );
            if digits {
                return [parts[0] + "/" + parts[1], int(digits)];
            }
        }
    }
    if t.pr_number > 0 and t.gh_repo {
        return [t.gh_repo, t.pr_number];
    }
    return [];
}


# Tell the runner this workspace has queued runs. The row is the root's jid;
# the runner drops it once nothing is left to run there.
def note_queued(root_jid: str, stamp: str) {
    try {
        db = shared_store();
        if db is None {
            return;
        }
        db.rows(
            "INSERT INTO jac_docs (collection, id, doc) "
                + "VALUES (:c, :i, CAST(:d AS jsonb)) "
                + "ON CONFLICT (collection, id) DO UPDATE SET doc = EXCLUDED.doc",
            {
                "c": AI_QUEUE,
                "i": root_jid,
                "d": json.dumps({"root_jid": root_jid, "queued_at": stamp})
            }
        );
    } except Exception as e {
        log.warning("ai queue: could not note " + root_jid + ": " + str(e));
    }
}


# Queue every enabled responsibility of the role that owns `step` for `t`.
# Returns the move's log-line tail: what was queued, or why nothing was. A
# queued run reads the newest commit when it runs, so it is never doubled; a
# `fresh_commit` (new commits on the PR) queues behind a running one, which
# is reviewing the commit before.
def queue_responsibilities(
    holder: Root, t: Task, step: WorkflowStep, stamp: str, fresh_commit: bool = False
) -> str {
    wanted = responsibilities_on_step(holder, step);
    if not wanted {
        return "";
    }
    names = ", ".join([catalogue_name(r.key).lower() for r in wanted]);
    if not ai_enabled(holder) {
        return " · AI " + names + " skipped: AI is off";
    }
    pr = pr_of(t);
    if not pr {
        return " · AI " + names + " skipped: no linked pull request";
    }
    box = agent_runs_box(holder);
    day = stamp[:10];
    queued: list[str] = [];
    fresh: dict[str, str] = {};
    skipped = "";
    for r in wanted {
        busy = [a.status for a in active_run(holder, jid(t), jid(r))];
        if "queued" in busy or (busy and not fresh_commit) {
            continue;
        }
        used = int(box.day_counts.get(day, 0));
        if used >= AGENT_LIMITS["daily_runs"] {
            skipped = " · AI " + names + " skipped: daily AI budget reached";
            break;
        }
        run = box ++> AgentRun(
            task_id=jid(t),
            responsibility_id=jid(r),
            key=r.key,
            step_id=jid(step),
            run_key=agent_run_key(jid(t), jid(r), "queued:" + stamp),
            status="queued",
            pr_repo=str(pr[0]),
            pr_number=int(pr[1]),
            model=r.model,
            queued_at=stamp,
            next_try_at=stamp
        );
        on_attached(holder, run);
        fresh[jid(run)] = "queued";
        box.day_counts = {day: used + 1};
        queued.append(catalogue_name(r.key).lower());
    }
    if queued {
        t.ai_queued_at = stamp;
        settle_ai(holder, t, fresh, stamp);
        note_queued(jid(holder), stamp);
        return " · Queued AI " + ", ".join(queued) + skipped;
    }
    return skipped;
}
