"""The AI runner: a scheduled function, like the GitHub sync. Each tick it takes
the workspaces the `ai_queue` index names, and for each one, under a lease,
claims due runs in the workspace's own context, awaits the review service
for them outside any transaction, then writes the results back. A result
lands only on the attempt that asked for it, so a run reclaimed after its
lease lapsed never takes a stale answer."""

import os;
import time;
import asyncio;
import logging;
import datetime;
import from jaclang { JacRuntime as Jac }
import from jaclang.runtime.exceptions { MissingAnchorError }
import from jaclang.server.shared_store { shared_store }
import from jaclang.server.bridge { BridgeError }
import from models {
    Task,
    WorkflowStep,
    Responsibility,
    AgentRun,
    AgentRuns,
    GithubConnection,
    note_lead,
    resolve,
    owned,
    agent_run_key,
    runs_of_task,
    settle_ai,
    note_ai_outcome
}
import from constants { AGENT_LIMITS }
import from services.github.util { installation_token, lease_owner }
import from services.log.log { record_task_event }
import from services.tasks.tasks { follow_trigger }
import from services.agents.runs { AI_QUEUE, catalogue_name }
import from review.service { review_pr }
import from services.agents.metrics { note_run }

# Seconds from an environment knob, never below `floor`. The gates shorten
# them; a deployment keeps the defaults.
def knob(name: str, fallback: int, floor: int) -> int {
    raw = os.environ.get(name) or "";
    value = fallback;
    if raw {
        try {
            value = int(raw);
        } except Exception {
            value = fallback;
        }
    }
    return value if value >= floor else floor;
}


glob INTERVAL_SECONDS: int = knob("FLOWLINE_AI_INTERVAL_SECONDS", 30, 5),
     # A claim outlives the longest review the service may take (rpc 300 s).
     LEASE_SECONDS: int = knob("FLOWLINE_AI_LEASE_SECONDS", 360, 5),
     BACKOFF_SECONDS: int = knob("FLOWLINE_AI_BACKOFF_SECONDS", 30, 1),
     # Retries wait one, four, then twenty times the base.
     BACKOFF_STEPS: list[int] = [1, 4, 20],
     RUNS_PER_TICK: int = 2,
     WORKSPACES_PER_TICK: int = 20,
     log: logging.Logger = logging.getLogger("flowline.agents");

def stamp_after(seconds: int) -> str {
    when = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
        + datetime.timedelta(seconds=seconds);
    return when.isoformat() + "Z";
}


def queued_workspaces(limit: int) -> list[str] {
    try {
        db = shared_store();
        if db is None {
            return [];
        }
        rows = db.rows(
            "SELECT id FROM jac_docs WHERE collection = :c ORDER BY id LIMIT :n",
            {"c": AI_QUEUE, "n": limit}
        );
        return [str(r[0]) for r in rows];
    } except Exception as e {
        log.warning("ai runner: could not read the queue: " + str(e));
        return [];
    }
}


def drop_queued(root_jid: str) {
    try {
        db = shared_store();
        if db is not None {
            db.rows(
                "DELETE FROM jac_docs WHERE collection = :c AND id = :i",
                {"c": AI_QUEUE, "i": root_jid}
            );
        }
    } except Exception as e {
        log.warning("ai runner: could not drop " + root_jid + ": " + str(e));
    }
}


# Run `body(holder)` inside the workspace's own context and commit, as the
# GitHub sync does. A root that no longer exists drops its queue row.
def in_workspace(root_jid: str, body: Callable) -> any {
    try {
        ctx = Jac.create_j_context(user_root=root_jid);
    } except MissingAnchorError {
        drop_queued(root_jid);
        return None;
    }
    token = Jac.push_request_context(ctx);
    try {
        out = body(ctx.get_root());
        Jac.commit();
        return out;
    } finally {
        ctx.close();
        Jac.reset_request_context(token);
    }
}


# The runs due now: queued ones whose wait is over, and running ones whose
# claim lapsed (the pod that held them died), oldest first.
def due_runs(holder: Root, now: str) -> list[AgentRun] {
    due: list[AgentRun] = [];
    for box in [holder-->[?:AgentRuns]] {
        for r in [box-->[?:AgentRun, status=="queued"]] {
            if not r.next_try_at or r.next_try_at <= now {
                due.append(r);
            }
        }
        for r in [box-->[?:AgentRun, status=="running"]] {
            if r.lease_until and r.lease_until < now {
                due.append(r);
            }
        }
    }
    due.sort(key=lambda (r: AgentRun) { jid(r); });
    due.sort(key=lambda (r: AgentRun) { r.queued_at; });
    return due;
}


def finish(holder: Root, run: AgentRun, status: str, why: str, stamp: str) {
    run.status = status;
    run.error = why;
    run.lease_until = "";
    run.finished_at = stamp;
    t = resolve(run.task_id);
    if isinstance(t, Task) and owned(holder, t) {
        note_ai_outcome(t, run);
    }
    if status == "failed" and isinstance(t, Task) and owned(holder, t) {
        record_task_event(
            holder,
            t,
            "AI " + catalogue_name(run.key).lower() + " failed · " + why,
            stamp
        );
    }
}


# Settle ai_state on each task whose runs this request moved.
def settle_tasks(holder: Root, moved: list[AgentRun], stamp: str) {
    by_task: dict[str, dict[str, str]] = {};
    for run in moved {
        if run.task_id not in by_task {
            by_task[run.task_id] = {};
        }
        by_task[run.task_id][jid(run)] = run.status;
    }
    for tid in by_task {
        t = resolve(tid);
        if isinstance(t, Task) and owned(holder, t) {
            settle_ai(holder, t, by_task[tid], stamp);
        }
    }
}


# Whether the workspace has a run queued or running. Read before any write of
# this request: a pushed query does not see this request's own writes.
def has_open(holder: Root) -> bool {
    for box in [holder-->[?:AgentRuns]] {
        if [box-->[?:AgentRun, status=="queued"]]
            or [box-->[?:AgentRun, status=="running"]] {
            return True;
        }
    }
    return False;
}


# Claim up to RUNS_PER_TICK due runs and return what the review service needs
# for each. A run that cannot start (its task or responsibility is gone,
# GitHub is not connected) is settled here.
def claim(holder: Root) -> dict[str, any] {
    now = stamp_after(0);
    left = has_open(holder);
    jobs: list[dict[str, any]] = [];
    moved: list[AgentRun] = [];
    token = "";
    conns = [holder-->[?:GithubConnection]];
    c = conns[0] if conns else None;
    if isinstance(c, GithubConnection)
        and c.installation_id
        and c.status != "invalid" {
        token = installation_token(c.installation_id);
    }
    for run in due_runs(holder, now) {
        if len(jobs) >= RUNS_PER_TICK {
            break;
        }
        moved.append(run);
        t = resolve(run.task_id);
        r = resolve(run.responsibility_id);
        if not isinstance(t, Task) or not owned(holder, t) {
            finish(holder, run, "skipped", "The task is gone.", now);
            continue;
        }
        if not isinstance(r, Responsibility) or not owned(holder, r) or not r.enabled {
            finish(holder, run, "skipped", "The responsibility is off or gone.", now);
            continue;
        }
        if not token {
            finish(holder, run, "failed", "GitHub is not connected.", now);
            continue;
        }
        reviewed = [
            x.head_sha
            for x in runs_of_task(holder, run.task_id)
            if x.responsibility_id == run.responsibility_id
                and x.status == "done"
                and x.head_sha
        ];
        run.status = "running";
        run.attempts = run.attempts + 1;
        run.started_at = now;
        run.lease_until = stamp_after(LEASE_SECONDS);
        jobs.append(
            {
                "run_id": jid(run),
                "attempt": run.attempts,
                "token": token,
                "repo": run.pr_repo,
                "pr_number": run.pr_number,
                "intent": t.title + "\n\n" + note_lead(t.notes),
                "instructions": r.instructions,
                "mode": r.mode,
                "model": r.model,
                "reviewed": reviewed
            }
        );
    }
    settle_tasks(holder, moved, now);
    return {"jobs": jobs, "left": left};
}


async def ask(job: dict[str, any]) -> dict[str, any] {
    started = time.monotonic();
    try {
        out = await review_pr(
            token=job["token"],
            repo=job["repo"],
            pr_number=job["pr_number"],
            intent=job["intent"],
            instructions=job["instructions"],
            mode=job["mode"],
            model=job["model"],
            reviewed=job["reviewed"]
        );
        return {"job": job, "out": out, "ms": int((time.monotonic() - started) * 1000)};
    } except BridgeError as e {
        log.warning("ai runner: review service unavailable: " + str(e));
        return {
            "job": job,
            "error": "The review service is not answering.",
            "retryable": True,
            "ms": int((time.monotonic() - started) * 1000)
        };
    } except Exception as e {
        log.warning("ai runner: review raised " + type(e).__name__ + ": " + str(e));
        return {
            "job": job,
            "error": "The review stopped unexpectedly.",
            "retryable": True,
            "ms": int((time.monotonic() - started) * 1000)
        };
    }
}


async def ask_all(jobs: list[dict[str, any]]) -> list[dict[str, any]] {
    answers: list[dict[str, any]] = list(await asyncio.gather(*[ask(j) for j in jobs]));
    return answers;
}


# Request-changes mode: a review with a blocking finding sends the task back
# along its step's "changes requested" arrow, as a person's review would, but
# only while the task is still on the step the run was queued for.
def send_back(holder: Root, run: AgentRun, t: Task, stamp: str) {
    r = resolve(run.responsibility_id);
    if run.verdict != "request_changes"
        or not isinstance(r, Responsibility)
        or r.mode != "request_changes"
        or not run.step_id
        or t.step_id != run.step_id {
        return;
    }
    t.pr_review_state = "changes_requested";
    t.pr_review_at = stamp;
    why = "AI " + catalogue_name(run.key).lower() + " requested changes";
    if not follow_trigger(holder, t, "changes_requested", [], why, stamp, {}) {
        step = resolve(t.step_id);
        if isinstance(step, WorkflowStep)
            and not [
                a
                for a in step.transitions
                if a.get("trigger", "") == "changes_requested"
            ] {
            record_task_event(
                holder,
                t,
                why
                    + " · no arrow out of "
                    + step.name
                    + " sends work back on changes requested",
                stamp
            );
        }
    }
}


# Write each answer onto its run, if the run is still on that attempt.
def apply(holder: Root, results: list[dict[str, any]]) {
    now = stamp_after(0);
    moved: list[AgentRun] = [];
    for res in results {
        job = res["job"];
        run = resolve(job["run_id"]);
        if not isinstance(run, AgentRun)
            or not owned(holder, run)
            or run.status != "running"
            or run.attempts != job["attempt"] {
            continue;
        }
        moved.append(run);
        out: any = res.get("out");
        ok = out is not None and bool(out.ok);
        error = str(out.error) if out is not None else str(res.get("error") or "");
        retryable = bool(out.retryable)
            if out is not None
            else bool(res.get("retryable"));
        if out is not None and out.head_sha {
            run.head_sha = out.head_sha;
        }
        outcome = "";
        if ok and out.verdict == "skipped" {
            finish(holder, run, "skipped", str(out.summary), now);
            outcome = "skipped";
        } elif ok {
            run.status = "done";
            run.verdict = out.verdict;
            run.summary = out.summary;
            run.comments = out.comments;
            run.blocking = out.blocking;
            run.review_url = out.review_url;
            run.model = out.model or run.model;
            run.tokens_in = out.tokens_in;
            run.tokens_out = out.tokens_out;
            run.cost_usd = out.cost_usd;
            run.error = "";
            run.lease_until = "";
            run.finished_at = now;
            run.run_key = agent_run_key(
                run.task_id, run.responsibility_id, run.head_sha
            );
            t = resolve(run.task_id);
            if isinstance(t, Task) and owned(holder, t) {
                note_ai_outcome(t, run);
                record_task_event(
                    holder,
                    t,
                    "AI "
                        + catalogue_name(run.key).lower()
                        + " · "
                        + str(run.comments)
                        + " comments, "
                        + str(run.blocking)
                        + " blocking",
                    now
                );
                send_back(holder, run, t, now);
            }
            outcome = "done";
        } elif retryable and run.attempts < AGENT_LIMITS["max_attempts"] {
            run.status = "queued";
            run.error = error;
            run.lease_until = "";
            step = BACKOFF_STEPS[min(run.attempts, len(BACKOFF_STEPS)) - 1];
            run.next_try_at = stamp_after(BACKOFF_SECONDS * step);
            outcome = "retry";
        } else {
            finish(holder, run, "failed", error, now);
            outcome = "failed";
        }
        note_run(
            run.key,
            outcome,
            int(res.get("ms") or 0),
            jid(holder),
            run.tokens_in if outcome == "done" else 0,
            run.tokens_out if outcome == "done" else 0,
            run.cost_usd if outcome == "done" else 0.0
        );
        # One line per settled attempt, and never the PR's content.
        log.info(
            "ai run workspace="
                + jid(holder)
                + " run="
                + jid(run)
                + " key="
                + run.key
                + " attempt="
                + str(run.attempts)
                + " outcome="
                + outcome
                + " ms="
                + str(res.get("ms") or 0)
                + " tokens="
                + str(run.tokens_in + run.tokens_out)
                + " cost_usd="
                + str(round(run.cost_usd, 6))
        );
    }
    settle_tasks(holder, moved, now);
}


def run_workspace(root_jid: str) {
    claimed: any = in_workspace(root_jid, claim);
    if claimed is None {
        return;
    }
    jobs: list[dict[str, any]] = claimed["jobs"];
    # Nothing queued or running any more: the index row can go. A run queued
    # since will note the workspace again.
    if not jobs {
        if not claimed["left"] {
            drop_queued(root_jid);
        }
        return;
    }
    results = asyncio.run(ask_all(jobs));
    in_workspace(root_jid, lambda (holder: Root) { apply(holder, results); });
}


@schedule(trigger=ScheduleTrigger.STATIC, interval=INTERVAL_SECONDS)
def run_ai_reviews {
    # The kill switch: nothing is claimed, and queued runs wait for it to lift.
    if os.environ.get("FLOWLINE_AGENTS_PAUSED") == "1" {
        log.info("ai runner: paused by FLOWLINE_AGENTS_PAUSED, queued runs wait");
        return;
    }
    owner = lease_owner();
    db = shared_store();
    for root_jid in queued_workspaces(WORKSPACES_PER_TICK) {
        if db is None
            or not db.kv_acquire_lease("ai:" + root_jid, LEASE_SECONDS, owner) {
            continue;
        }
        try {
            run_workspace(root_jid);
        } except Exception as e {
            log.warning(
                "ai runner: " + root_jid + " raised " + type(e).__name__ + ": " + str(e)
            );
        } finally {
            db.kv_release_lease("ai:" + root_jid, owner);
        }
    }
}
