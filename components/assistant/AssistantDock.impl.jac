"""Implementations for the assistant dock.

Every LLM call is one `root spawn` of a bare walker, so it inherits the JWT and
the per-root tenant isolation the rest of the app already relies on. The model
never mutates: `applyProposal` is the only path to the graph, it runs only after
the user presses Apply, and it goes through the ordinary CreateTask / MoveTask.
"""

impl AssistantDock.setTurnState(index: int, state: str) -> None {
    out: list[dict] = [];
    at = 0;
    for t in turns {
        if at == index {
            out.append({**t, "state": state});
        } else {
            out.append(t);
        }
        at = at + 1;
    }
    turns = out;
}

impl AssistantDock.send -> None {
    text = draft.strip();
    if not text or busy {
        return;
    }
    draft = "";
    await quick("ask" if mode == "ask" else "do", text);
}

# The one entry point for every LLM call: the composer, the quick chips, and
# the mode toggle all land here. `kind` picks the walker.
impl AssistantDock.quick(kind: str, value: str) -> None {
    if busy {
        return;
    }
    busy = True;
    # A week of context, so "what did Nadia do last week" has something to read.
    # The note chips narrow it to the period they name.
    fromDate = isoDaysAgo(6);
    toDate = isoDaysAgo(0);

    # Declared before the branch: a name first assigned inside an `if` is
    # block-scoped in the compiled JS and is not defined after it.
    label = value;
    if kind == "note" {
        label = "Write the standup note for " + value;
        if value == "today" {
            fromDate = toDate;
        }
    }
    # `history` carries the conversation across the await. Reading `turns` again
    # after the walker call would see the value captured when this handler was
    # created, so the second append would silently drop the question.
    history = turns + [{"role": "user", "kind": "text", "text": label}];
    turns = history;

    reply: dict = {
        "role": "assistant", "kind": "error",
        "text": "I did not get an answer back. Try again."
    };
    try {
        if kind == "note" {
            noteRun = root spawn WriteStandup(
                period=value, from_date=fromDate, to_date=toDate
            );
            note = noteRun.reports[0] if noteRun.reports else None;
            if note {
                reply = {"role": "assistant", "kind": "note", "note": note};
            } else {
                reply = {
                    "role": "assistant", "kind": "error",
                    "text": "I could not write that note. Try again in a moment."
                };
            }
        } elif kind == "do" {
            propRun = root spawn ProposeAction(
                instruction=value, from_date=fromDate, to_date=toDate
            );
            proposal = propRun.reports[0] if propRun.reports else None;
            if proposal {
                reply = {
                    "role": "assistant", "kind": "proposal",
                    "proposal": proposal, "state": ""
                };
            } else {
                reply = {
                    "role": "assistant", "kind": "error",
                    "text": "I could not turn that into a board change."
                };
            }
        } else {
            askRun = root spawn AskAssistant(
                question=value, from_date=fromDate, to_date=toDate
            );
            answer = askRun.reports[0] if askRun.reports else "";
            if answer {
                reply = {"role": "assistant", "kind": "text", "text": answer};
            }
        }
    } except Exception as e {
        # Almost always a missing or rejected OPENAI_API_KEY, which is worth
        # naming: the failure is in .env, not in anything the user typed.
        reply = {
            "role": "assistant", "kind": "error",
            "text": "The assistant is unreachable. Check that OPENAI_API_KEY is set in .env "
                    + "and that the server was restarted after."
        };
    }
    turns = history + [reply];
    busy = False;
}

impl AssistantDock.applyProposal(index: int) -> None {
    if busy or index >= len(turns) {
        return;
    }
    # `turns` is list[dict], so the payload arrives untyped; the walker already
    # validated status and priority against the real vocabularies.
    p: any = turns[index]["proposal"];
    busy = True;
    try {
        if p.kind == "move_task" {
            found = root spawn ListTasks();
            all = found.reports[0] if found.reports else [];
            # The model returns a title, never a jid. Exact match first, then a
            # containment pass, so "the onboarding flow" finds the real card.
            taskId = "";
            wanted = p.title.lower().strip();
            for t in all {
                if not taskId and t.title.lower().strip() == wanted {
                    taskId = t.id;
                }
            }
            for t in all {
                if not taskId and wanted and wanted in t.title.lower() {
                    taskId = t.id;
                }
            }
            if not taskId {
                toast("No task called \"" + p.title + "\" on the board");
                busy = False;
                return;
            }
            root spawn MoveTask(
                task_id=taskId, status=p.status if p.status else "In Progress"
            );
        } else {
            mResult = root spawn ListMembers();
            pResult = root spawn ListProjects();
            people = mResult.reports[0] if mResult.reports else [];
            projects = pResult.reports[0] if pResult.reports else [];
            projectId = "";
            for pr in projects {
                if pr.name == p.project {
                    projectId = jid(pr);
                }
            }
            assignees: list[str] = [];
            for m in people {
                if m.name == p.assignee {
                    assignees = [m.id];
                }
            }
            root spawn CreateTask(
                title=p.title, category=p.category,
                priority=p.priority if p.priority else "Medium",
                status=p.status if p.status else "Backlog",
                due_date=p.due_date, notes=p.note,
                assignee_ids=assignees, project_id=projectId
            );
        }
        setTurnState(index, "applied");
        # The board is not in this component tree, so tell it to refetch
        # instead of leaving the change invisible until its next poll.
        announceRefresh();
        toast("Applied", {"description": p.title});
    } except Exception as e {
        toast("Could not apply that");
    }
    busy = False;
}

impl AssistantDock.copyNote(index: int) -> None {
    if index >= len(turns) {
        return;
    }
    note: any = turns[index]["note"];
    lines: list[str] = [note.headline, ""];
    lines = lines + noteSection("Shipped", note.shipped);
    lines = lines + noteSection("In flight", note.in_flight);
    lines = lines + noteSection("Blocked", note.blocked);
    lines = lines + noteSection("Needs attention", note.needs_attention);
    try {
        navigator.clipboard.writeText("\n".join(lines));
        toast("Standup note copied");
    } except Exception as e {
        toast("Could not reach the clipboard");
    }
}

impl AssistantDock.toggleMic -> None {
    if listening {
        stopVoice();
        listening = False;
        return;
    }
    # Interim results stream in, so the composer fills as the user speaks.
    started = startVoice(
        lambda (text: str) { draft = text; },
        lambda { listening = False; }
    );
    listening = started;
    if not started {
        toast("Your browser would not start dictation");
    }
}
