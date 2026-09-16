"""One line to log a note on the selected day: who, what, project and status,
Enter saves. `onLog` is the page's own create path (the one the entry dialog
uses) and resolves True once the row is saved. Who and project are
remembered per browser.
"""

import from "@jac/runtime" { Link }
import from ...models { MemberView, Project }
import from ..common.KindGlyph { KindGlyph }
import from ..common.glyphs { Spinner }
import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}

# Status in the words of the standup section the note lands in.
glob STATUS_CHOICES: list[dict[str, str]] = [
         {"value": "In Progress", "kind": "active", "label": "In progress"},
         {"value": "Done", "kind": "done", "label": "Finished"},
         {"value": "Review", "kind": "handoff", "label": "Handed off"},
         {"value": "Blocked", "kind": "blocked", "label": "Stuck"},
         {"value": "Backlog", "kind": "start", "label": "To do"}
     ],
     MEMBER_KEY: str = "flowline_log_member",
     PROJECT_KEY: str = "flowline_log_project",
     PICK: str = "h-8! w-auto! max-w-44 gap-1.5! border-border! bg-card px-2! text-[13px] text-muted-foreground data-[state=open]:text-foreground";

def focusDraft {
    box: any = document.getElementById("log-composer");
    if box {
        box.focus();
    }
}

def remember(key: str, value: str) {
    try {
        localStorage.setItem(key, value);
    } except Exception {}
}


def:pub Composer(
    members: list[MemberView],
    projects: list[Project],
    saving: bool,
    onLog: Callable[[dict[str, str]], any],
    # False until the roster call lands, so an empty roster is not guessed.
    rosterReady: bool = True
) -> JsxElement {
    has draft: str = "",
        who: str = "",
        project: str = "none",
        status: str = "In Progress";

    can with entry {
        try {
            who = localStorage.getItem(MEMBER_KEY) or "";
            project = localStorage.getItem(PROJECT_KEY) or "none";
        } except Exception {}
    }

    memberIds = [m.id for m in members];
    projectIds = [jid(p) for p in projects];
    whoValue = who if who in memberIds else (members[0].id if len(members) > 0 else "");
    projectValue = project if project in projectIds else "none";
    if rosterReady and len(members) == 0 {
        return
            <p className="surface px-3 py-2.5 text-sm text-muted-foreground">
                Notes are logged for people on the roster.{" "}
                <Link
                    id="log-add-people"
                    to="/workspace?tab=people"
                    className="font-medium text-foreground underline underline-offset-[3px]"
                >
                    Add people
                </Link>
            </p>;
    }

    # Radix clears a Select inside a form to "" while its items are still
    # unloaded; taking that as a pick would wipe the remembered choice.
    def pickWho(v: str) {
        if v {
            who = v;
            remember(MEMBER_KEY, v);
        }
    }

    def pickProject(v: str) {
        if v {
            project = v;
            remember(PROJECT_KEY, v);
        }
    }

    def pickStatus(v: str) {
        if v {
            status = v;
        }
    }

    async def submit -> None {
        if saving {
            return;
        }
        if not draft.strip() or not whoValue {
            focusDraft();
            return;
        }
        ok = await onLog(
            {
                "member": whoValue,
                "activity": draft.strip(),
                "project": projectValue,
                "status": status
            }
        );
        if ok {
            draft = "";
        }
    }

    return
        <form
            aria-label="Log a note"
            className="grid grid-cols-2 items-center gap-2 rounded-xl border bg-card p-2.5 md:grid-cols-[minmax(0,1fr)_auto_auto_auto_auto]"
            onSubmit={lambda (e: FormEvent) {
                e.preventDefault();
                submit();
            }}
        >
            <Input
                id="log-composer"
                className="col-span-2 h-[34px] rounded-md bg-card text-sm placeholder:text-subtle md:col-span-1"
                placeholder="What did you work on?"
                aria-label="What did you work on?"
                autoComplete="off"
                value={draft}
                onChange={lambda (e: ChangeEvent) { draft = e.target.value; }}
            />
            <Select value={whoValue} onValueChange={pickWho}>
                <SelectTrigger className={PICK} aria-label="Who">
                    <SelectValue placeholder="Who"/>
                </SelectTrigger>
                <SelectContent>
                    {for m in members {
                        <SelectItem key={m.id} value={m.id}>{m.name}</SelectItem>
                    }}
                </SelectContent>
            </Select>
            <Select value={projectValue} onValueChange={pickProject}>
                <SelectTrigger className={PICK} aria-label="Project">
                    <SelectValue placeholder="Project"/>
                </SelectTrigger>
                <SelectContent>
                    <SelectItem value="none">No project</SelectItem>
                    {for p in projects {
                        <SelectItem key={jid(p)} value={jid(p)}>{p.name}</SelectItem>
                    }}
                </SelectContent>
            </Select>
            <Select value={status} onValueChange={pickStatus}>
                <SelectTrigger className={PICK} aria-label="Status">
                    <SelectValue placeholder="Status"/>
                </SelectTrigger>
                <SelectContent>
                    {for c in STATUS_CHOICES {
                        <SelectItem key={c["value"]} value={c["value"]}>
                            <KindGlyph
                                kind={c["kind"]}
                                className="text-muted-foreground [--kind-knockout:var(--popover)]"
                            />
                            {c["label"]}
                        </SelectItem>
                    }}
                </SelectContent>
            </Select>
            <Button type="submit" className="h-8" disabled={saving}>
                {if saving {
                    <Spinner key="sp"/>
                }}
                Log it
                <span
                    key="kbd"
                    className="num hidden text-xs font-normal md:inline"
                    aria-hidden="true"
                >
                    Enter
                </span>
            </Button>
        </form>;
}
