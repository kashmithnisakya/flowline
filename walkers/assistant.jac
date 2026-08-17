"""The assistant: byLLM over a deterministic snapshot. Hard-won constraints:
NO tools/ReAct or streaming (graph-reading tools and nested `root spawn` come
back empty), NO `:pub` (bare walkers require a JWT), and the model NEVER
writes: propose_action returns a suggestion the UI applies via normal walkers."""

import from constants { STATUSES, PRIORITIES }
import from walkers.insights { Snapshot, build_snapshot }
import from walkers.util { now_iso }
import logging;

# ------------------------------------------------------------------ LLM shapes

obj StandupNote {
    has headline: str,
        shipped: list[str],
        in_flight: list[str],
        blocked: list[str],
        needs_attention: list[str];
}

obj ProposedAction {
    has kind: str,
        title: str,
        project: str,
        assignee: str,
        status: str,
        priority: str,
        category: str,
        due_date: str,
        note: str,
        confidence: str;
}

# ---------------------------------------------------------------- LLM surface

def answer_question(question: str, workspace: Snapshot) -> str by llm();

def write_standup(workspace: Snapshot, period: str) -> StandupNote by llm();

def propose_action(instruction: str, workspace: Snapshot) -> ProposedAction by llm();

# `sem` is the prompt the model actually sees, so every LLM-visible thing gets one.

sem answer_question = """Answer the user's question about their standup workspace using only
the snapshot. Prefer concrete names, counts and dates over generalities. If the snapshot does
not contain the answer, say that plainly instead of guessing. Two or three sentences unless the
question demands a list.""";

sem answer_question.question = "The user's question, in their own words.";
sem answer_question.workspace = "The current workspace: tasks, people, projects and recent activity.";

sem write_standup = """Write the standup note a team lead would post. Ground every line in the
snapshot: name the people and tasks. Say nothing about work that is not present. Leave a list
empty rather than padding it.""";

sem write_standup.workspace = "The current workspace: tasks, people, projects and recent activity.";
sem write_standup.period = "The period the note covers, e.g. 'today' or 'this week'.";

sem StandupNote = "A standup note, ready to paste into a team channel.";
sem StandupNote.headline = "One sentence on where the team stands overall.";
sem StandupNote.shipped = "Work completed in the period. One short line each, naming the person.";
sem StandupNote.in_flight = "Work actively moving. One short line each, naming the person.";
sem StandupNote.blocked = "Blocked work, with the reason from the snapshot. One line each.";
sem StandupNote.needs_attention = "Anything a lead should chase: overdue, stale, or waiting in review too long.";

sem propose_action = """Turn the user's request into ONE proposed change to the board. Do not
invent a project or person that is absent from the snapshot: leave the field empty instead. This
is only a proposal, a human confirms it before anything is written.""";

sem propose_action.instruction = "What the user asked for, in their own words.";
sem propose_action.workspace = "The current workspace, for resolving names of people and projects.";

sem ProposedAction = "A single proposed board change, awaiting human confirmation.";
sem ProposedAction.kind = "Either 'create_task' or 'move_task'. Use 'none' if the request is not a board change.";
sem ProposedAction.title = "The task title. For a move, the title of the existing task being moved.";
sem ProposedAction.project = "Project name, exactly as it appears in the snapshot, or empty.";
sem ProposedAction.assignee = "Member name, exactly as it appears in the snapshot, or empty.";
sem ProposedAction.status = "One of the board columns, or empty to leave it in Backlog.";
sem ProposedAction.priority = "High, Medium or Low. Empty means Medium.";
sem ProposedAction.category = "A category from the workspace vocabulary, or empty.";
sem ProposedAction.due_date = "ISO date (YYYY-MM-DD) or empty. Never guess a date.";
sem ProposedAction.note = "One sentence telling the user what this will do and what you assumed.";
sem ProposedAction.confidence = "high, medium or low: how sure you are this is what the user meant.";

# ------------------------------------------------------------------- walkers
# Bare (JWT-required) by design. build_snapshot is a plain def, never a spawn.

def _range(from_date: str, to_date: str) -> tuple {
    today = now_iso()[:10];
    return (from_date or today, to_date or today);
}

# The model call is the one part of the assistant outside the app's control
# (key, credits, network). Log the cause for the operator here; the client only
# ever gets an empty report, so nothing about .env or billing reaches a browser.
def _llm_failed(what: str, e: Exception) {
    logging.getLogger("standup.assistant").error(
        "assistant %s failed: %s: %s. Check OPENAI_API_KEY and LLM_MODEL in .env "
        "and the model account's credits, then restart the server.",
        what,
        type(e).__name__,
        e
    );
}


walker AskAssistant {
    has question: str = "",
        from_date: str = "",
        to_date: str = "",
        reports: list[str] = [];

    can ask with Root entry {
        if not self.question.strip() {
            disengage;
        }
        (start, end) = _range(self.from_date, self.to_date);
        snapshot = build_snapshot(here, start, end);
        try {
            report answer_question(self.question.strip(), snapshot);
        } except Exception as e {
            _llm_failed("answer", e);
        }
    }
}

walker WriteStandup {
    has period: str = "today",
        from_date: str = "",
        to_date: str = "",
        reports: list[StandupNote] = [];

    can compose with Root entry {
        (start, end) = _range(self.from_date, self.to_date);
        snapshot = build_snapshot(here, start, end);
        try {
            report write_standup(snapshot, self.period);
        } except Exception as e {
            _llm_failed("standup note", e);
        }
    }
}

walker ProposeAction {
    """Returns a suggestion only. The client confirms it and then calls the
    ordinary CreateTask / MoveTask walkers, so the model never mutates."""
    # NOTE: not `request`, the serve layer reserves that name for the HTTP
    # request object and the body field never reaches the walker.
    has instruction: str = "",
        from_date: str = "",
        to_date: str = "",
        reports: list[ProposedAction] = [];

    can suggest with Root entry {
        if not self.instruction.strip() {
            disengage;
        }
        (start, end) = _range(self.from_date, self.to_date);
        snapshot = build_snapshot(here, start, end);
        try {
            proposal = propose_action(self.instruction.strip(), snapshot);
        } except Exception as e {
            _llm_failed("proposal", e);
            disengage;
        }
        # Never let a hallucinated column or priority reach the board.
        if proposal.status and proposal.status not in STATUSES {
            proposal.status = "";
        }
        if proposal.priority and proposal.priority not in PRIORITIES {
            proposal.priority = "";
        }
        report proposal;
    }
}
