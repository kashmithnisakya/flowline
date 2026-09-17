"""Implementations for the assistant dock. Every LLM call is one `root spawn`
of a bare walker (JWT + per-root isolation). The model never mutates: only
`applyProposal` writes, after the user presses Apply, via CreateTask/MoveTask.
"""

impl AssistantDock.setTurnState(index: int, state: str) -> None {
    out: list[dict[str, any]] = [];
    at = 0;
    for t in turns {
        if at == index {
            out.append({** t, "state": state});
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

    # One user-facing line for every way the model can fail to answer. The
    # walkers log the real cause server-side; nothing about keys or billing
    # belongs in a browser.
    unavailable = "The assistant is not available right now. Try again in a moment.";
    reply: dict[str, any] = {"role": "assistant", "kind": "error", "text": unavailable};
    try {
        if kind == "note" {
            noteRun = root spawn WriteStandup(
                period=value, from_date=fromDate, to_date=toDate
            );
            note = noteRun.reports[0] if noteRun.reports else None;
            if note {
                noteText = " ".join(
                    note.shipped + note.in_flight + note.blocked + note.needs_attention
                );
                cites = await citeTasks(noteText);
                reply = {
                    "role": "assistant",
                    "kind": "note",
                    "note": note,
                    "cites": cites
                };
            } else {
                reply = {"role": "assistant", "kind": "error", "text": unavailable};
            }
        } elif kind == "do" {
            propRun = root spawn ProposeAction(
                instruction=value, from_date=fromDate, to_date=toDate
            );
            proposal = propRun.reports[0] if propRun.reports else None;
            if proposal {
                reply = {
                    "role": "assistant",
                    "kind": "proposal",
                    "proposal": proposal,
                    "state": ""
                };
            } else {
                reply = {"role": "assistant", "kind": "error", "text": unavailable};
            }
        } else {
            askRun = root spawn AskAssistant(
                question=value, from_date=fromDate, to_date=toDate
            );
            answer = askRun.reports[0] if askRun.reports else "";
            if answer {
                cites = await citeTasks(answer);
                reply = {
                    "role": "assistant",
                    "kind": "text",
                    "text": answer,
                    "cites": cites
                };
            }
        }
    } except Exception as e {
        reply = {"role": "assistant", "kind": "error", "text": unavailable};
    }
    turns = history + [reply];
    busy = False;
}

# The working tasks whose titles the text names as whole words, in the order it
# names them. The walkers return prose, not ids, so a title match is the
# citation; ListTaskTitles carries ids and titles alone.
impl AssistantDock.citeTasks(text: str) -> list[dict[str, str]] {
    hay = text.lower();
    found: list[dict[str, any]] = [];
    taken: list[dict[str, int]] = [];
    try {
        run = root spawn ListTaskTitles();
        pool = run.reports[0] if run.reports else [];
        for t in sorted(pool, key=citeLength) {
            title = t.title.strip();
            needle = title.lower();
            where = findTitle(hay, needle, taken) if len(title) >= MIN_CITE else -1;
            if where >= 0 {
                taken.append({"from": where, "to": where + len(needle)});
                found.append({"id": t.id, "title": title, "at": where});
            }
        }
    } except Exception as e {
        return [];
    }
    ordered = sorted(found, key=citeOrder);
    out: list[dict[str, str]] = [];
    for f in ordered[:MAX_CITES] {
        out.append({"id": f["id"], "title": f["title"]});
    }
    return out;
}

impl AssistantDock.applyProposal(index: int) -> None {
    if busy or index >= len(turns) {
        return;
    }
    # `turns` is list[dict], so the payload arrives untyped; the walker already
    # validated status and priority against the real vocabularies.
    p: any = turns[index]["proposal"];
    busy = True;
    where = "";
    try {
        if p.kind == "move_task" {
            # The model returns a title, never a jid. The server ranks an
            # exact title first, then a prefix, then a containment match, so
            # the first row is the card "the onboarding flow" meant.
            wanted = p.title.lower().strip();
            found = root spawn ListTasks(scope="all", q=wanted, page_size=5);
            page = found.reports[0] if found.reports else None;
            hits = page.rows if page else [];
            taskId = hits[0].id if len(hits) > 0 and wanted else "";
            if not taskId {
                toast.error("No task called \"" + p.title + "\" on the board");
                busy = False;
                return;
            }
            root spawn MoveTask(task_id=taskId, status=p.status or "In Progress");
        } else {
            mResult = root spawn ListMembers();
            pResult = root spawn ListProjects();
            people = mResult.reports[0] if mResult.reports else [];
            projects = pResult.reports[0] if pResult.reports else [];
            # A task always has a project: the one the model named, else
            # the first active one, and the toast says where it went.
            projectId = "";
            for pr in projects {
                if pr.active and pr.name == p.project {
                    projectId = jid(pr);
                    where = " · " + pr.name;
                }
            }
            if not projectId {
                for pr in projects {
                    if pr.active and not projectId {
                        projectId = jid(pr);
                        where = " · " + pr.name;
                    }
                }
            }
            if not projectId {
                toast.error("Create a project before adding tasks");
                busy = False;
                return;
            }
            assignees: list[str] = [];
            for m in people {
                if m.name == p.assignee {
                    assignees = [m.id];
                }
            }
            made = root spawn CreateTask(
                title=p.title,
                category=p.category,
                priority=p.priority or "Medium",
                status=p.status or "Backlog",
                due_date=p.due_date,
                notes=p.note,
                assignee_ids=assignees,
                project_id=projectId
            );
            # The walker creates nothing (and reports nothing) for a project
            # it refuses, so an empty report is a failure, not an apply.
            if not made.reports {
                toast.error("Could not add that task");
                busy = False;
                return;
            }
        }
        setTurnState(index, "applied");
        # The board is not in this component tree, so tell it to refetch
        # instead of leaving the change invisible until its next poll.
        announceRefresh();
        toast.success("Applied", {"description": p.title + where});
    } except Exception as e {
        toast.error("Could not apply that");
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
        toast.success("Standup note copied");
    } except Exception as e {
        toast.error("Could not reach the clipboard");
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
        lambda (text: str) { draft = text; }, lambda { listening = False; }
    );
    listening = started;
    if not started {
        toast.error("Your browser would not start dictation");
    }
}
