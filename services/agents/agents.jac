"""AI responsibility walkers: a role's responsibilities, the workspace's AI
switch and a task's runs. A responsibility hangs under its role and a run
under the AgentRuns box, so every jid-addressed write resolves the row and
checks owned() first. Queuing and cancelling the run's job come with the
job queue (#279); here a retry or a cancel moves the run's own status."""

import from jaclang.lib.effects { effects }
import from models {
    Role,
    Roles,
    Responsibility,
    AgentRuns,
    AgentRun,
    WorkflowStep,
    AiSettings,
    ResponsibilityView,
    AgentRunView,
    responsibility_view,
    agent_run_view,
    agent_runs_box,
    ai_enabled,
    resolve,
    owned,
    on_attached
}
import from constants { AI_RESPONSIBILITIES, AGENT_LIMITS }
import from services.util { now_iso }

glob MODEL_NAME_MAX: int = 100;

def refusal(error: str, message: str) -> dict[str, any] {
    return {"ok": False, "error": error, "message": message};
}


def catalogue_entry(key: str) -> dict[str, any] {
    for item in AI_RESPONSIBILITIES {
        if item["key"] == key {
            return item;
        }
    }
    return {};
}


# Why these settings cannot be saved, as a refusal, or {} when they can.
def settings_problem(
    key: str, mode: str, instructions: str, model: str
) -> dict[str, any] {
    known = catalogue_entry(key);
    if not known {
        return refusal(
            "unknown_key", "There is no AI responsibility called " + key + "."
        );
    }
    if mode not in known["modes"] {
        return refusal("bad_mode", known["name"] + " cannot run in " + mode + " mode.");
    }
    if len(instructions.strip()) > AGENT_LIMITS["max_instructions"] {
        return refusal(
            "too_long",
            "Instructions are limited to "
                + str(AGENT_LIMITS["max_instructions"])
                + " characters."
        );
    }
    named = model.strip();
    if len(named) > MODEL_NAME_MAX {
        return refusal("bad_model", "That model name is too long.");
    }
    for ch in named {
        if not (ch.isalnum() or ch in "-_.:/@") {
            return refusal(
                "bad_model", "That model name has characters a model name never has."
            );
        }
    }
    return {};
}


# The step ids worth keeping: each one an existing step of this workspace,
# once. A foreign or unknown id is dropped rather than refused.
def kept_steps(holder: Root, ids: list[str]) -> list[str] {
    out: list[str] = [];
    for sid in ids {
        target = resolve(sid);
        if isinstance(target, WorkflowStep)
            and owned(holder, target)
            and jid(target) not in out {
            out.append(jid(target));
        }
    }
    return out;
}


@effects(reads=["AgentRuns", "Role", "Responsibility"], writes=[])
def read_ai(holder: Root) -> AiSettings {
    enabled = False;
    enabled_at = "";
    for box in [holder-->[?:AgentRuns]] {
        if box.enabled {
            enabled = True;
            enabled_at = box.enabled_at;
        }
    }
    rows: list[ResponsibilityView] = [];
    for box in [holder-->[?:Roles]] {
        for r in [box-->[?:Role]] {
            for x in [r-->[?:Responsibility]] {
                rows.append(responsibility_view(x, jid(r)));
            }
        }
    }
    return AiSettings(enabled=enabled, enabled_at=enabled_at, responsibilities=rows);
}


walker:protect ListResponsibilities {
    """The workspace's AI switch and every role's responsibilities."""
    has reports: list[AiSettings] = [];

    can start with Root entry {
        report read_ai(here);
    }
}

walker:protect SetAiEnabled {
    """Turn the workspace's AI on or off. Off stops new runs from being
    queued; runs already queued are left to the queue."""
    has enabled: bool = False,
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        visit agent_runs_box(here);
    }

    can turn with AgentRuns entry {
        if self.enabled and not here.enabled {
            here.enabled_at = now_iso();
        }
        here.enabled = self.enabled;
        report {"ok": True, "enabled": here.enabled, "enabled_at": here.enabled_at};
    }
}

walker:protect SaveResponsibility {
    """Create or update a role's responsibility. An empty responsibility_id
    saves the role's responsibility with this key, made if it has none, so a
    role holds one of each. `on_steps` keeps the workspace's own step ids."""
    has responsibility_id: str = "",
        role_id: str = "",
        key: str = "code_review",
        enabled: bool = True,
        on_steps: list[str] = [],
        instructions: str = "",
        mode: str = "comment",
        model: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        problem = settings_problem(self.key, self.mode, self.instructions, self.model);
        if problem {
            report problem;
            disengage;
        }
        target = resolve(self.responsibility_id or self.role_id);
        if self.responsibility_id
            and isinstance(target, Responsibility)
            and owned(here, target) {
            visit [target];
        } elif not self.responsibility_id
            and isinstance(target, Role)
            and owned(here, target) {
            visit [target];
        } else {
            report refusal("not_found", "Unknown role or responsibility.");
        }
    }

    can create with Role entry {
        same = [here-->[?:Responsibility, key==self.key]];
        target: Responsibility | None = same[0] if same else None;
        if target is None {
            target = here ++> Responsibility(key=self.key, created_at=now_iso());
            on_attached(root, target);
        }
        self.apply(root, target);
        report {"ok": True, "responsibility": responsibility_view(target, jid(here))};
        disengage;
    }

    can update with Responsibility entry {
        if here.key != self.key {
            report refusal("key_fixed", "A responsibility keeps its key.");
            disengage;
        }
        self.apply(root, here);
        report {"ok": True, "responsibility": responsibility_view(here)};
        disengage;
    }

    def apply(holder: Root, r: Responsibility) {
        r.enabled = self.enabled;
        r.on_steps = kept_steps(holder, self.on_steps);
        r.instructions = self.instructions.strip();
        r.mode = self.mode;
        r.model = self.model.strip();
        r.updated_at = now_iso();
    }
}

walker:protect DeleteResponsibility {
    """Delete one responsibility. Its past runs stay, as history."""
    has responsibility_id: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        target = resolve(self.responsibility_id);
        if isinstance(target, Responsibility) and owned(here, target) {
            visit [target];
        } else {
            report refusal("not_found", "Unknown responsibility.");
        }
    }

    can remove with Responsibility entry {
        gone = jid(here);
        del here;
        report {"ok": True, "deleted": gone};
        disengage;
    }
}

walker:protect ListRuns {
    """One task's runs, newest first. A task holds a few (one per review of a
    commit), so the list is whole."""
    has task_id: str = "",
        reports: list[list[AgentRunView]] = [];

    can start with Root entry {
        visit [here-->[?:AgentRuns]] else {
            report [];
        }
    }

    can gather with AgentRuns entry {
        runs = [here-->[?:AgentRun, task_id==self.task_id]] if self.task_id else [];
        runs.sort(key=lambda (r: AgentRun) { jid(r); }, reverse=True);
        runs.sort(key=lambda (r: AgentRun) { r.queued_at; }, reverse=True);
        report [agent_run_view(r) for r in runs];
    }
}

walker find_run {
    """Lookup base: resolve the jid once, verify the workspace owns it, then
    visit. Resolution is NOT authorization."""
    has run_id: str = "",
        reports: list[dict[str, any]] = [];

    can locate with Root entry {
        target = resolve(self.run_id);
        if isinstance(target, AgentRun) and owned(here, target) {
            visit [target];
        } else {
            report refusal("not_found", "Unknown run.");
        }
    }
}

walker:protect RetryRun(find_run) {
    """Queue a run that failed, was skipped or was cancelled again. Refused
    while the workspace's AI is off."""
    can retry with AgentRun entry {
        if here.status not in ["failed", "skipped", "cancelled"] {
            report refusal(
                "not_retryable",
                "Only a failed, skipped or cancelled run can run again."
            );
            disengage;
        }
        if not ai_enabled(root) {
            report refusal("ai_off", "AI is turned off for this workspace.");
            disengage;
        }
        here.status = "queued";
        here.error = "";
        here.queued_at = now_iso();
        here.started_at = "";
        here.finished_at = "";
        report {"ok": True, "run": agent_run_view(here)};
        disengage;
    }
}

walker:protect CancelRun(find_run) {
    """Cancel a run that is queued or running. Nothing is posted for it."""
    can cancel with AgentRun entry {
        if here.status not in ["queued", "running"] {
            report refusal(
                "not_cancellable", "Only a queued or running run can be cancelled."
            );
            disengage;
        }
        here.status = "cancelled";
        here.error = "Cancelled.";
        here.finished_at = now_iso();
        report {"ok": True, "run": agent_run_view(here)};
        disengage;
    }
}
