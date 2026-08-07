"""Create/edit dialog for a kanban task.

The form is a plain dict owned by the page; assignees ride separately as
a list (tasks take several people in v2.5). Assignee chips group by
project membership, and picking someone outside the selected project
adds them to it on save. A handoff step reveals the reviewer fields.

The body is one two-column grid. Title, Assignees, the GitHub issue link
and Notes span both columns; the five classification selects and the due
date pair off two per row. It collapses to a single column below sm.
"""

# constants.jac is server-only (imported by walkers); define board vocabulary locally.
glob STATUSES: list[str] = [
         "Backlog",
         "In Progress",
         "Review",
         "Changes Requested",
         "Done",
         "Blocked"
     ],
     PRIORITIES: list[str] = ["High", "Medium", "Low"];

import from ...models { Project, MemberView, RepoView }
import from ..common.Markdown { Markdown }
import from ..log.DatePicker { DatePicker }
import from ..ui.button { Button }
import from ..ui.badge { Badge }
import from ..ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogFooter
}
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.textarea { Textarea }
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ..ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuCheckboxItem
}

# Every control fills its cell, so the labels above them line up as a
# grid instead of a ragged row of chips.
glob FIELD: str = "w-full",
     WIDE: str = "grid gap-2 sm:col-span-2";

# A field that takes the whole row rather than half of it.
def:pub TaskDialog(
    open: bool,
    editing: bool,
    form: dict[str, str],
    projects: list[Project],
    members: list[MemberView],
    saving: bool,
    onField: Callable[[str, str], None],
    onOpenChange: Callable[[bool], None],
    onSave: Callable[[], None],
    onDelete: Callable[[], None],
    categories: list[str] = [],
    # The board's columns, as parallel key/label lists: a column is a
    # workflow step (keyed by its jid) or a legacy status (keyed by itself),
    # so the dialog always offers exactly what the board shows.
    columnKeys: list[str] = [],
    columnLabels: list[str] = [],
    handoffKeys: list[str] = [],
    assignees: list[str] = [],
    onToggleAssignee: Callable[[str], None] = None,
    repos: list[RepoView] = [],
    ghConnected: bool = False,
    ghIssueNumber: int = 0,
    onCreateIssue: Callable[[str], None] = None
) -> JsxElement {
    # Which repo the new issue goes in, when the project tracks more than
    # one. Purely local: the page never needs to know about the picker.
    # Notes open rendered, not raw: the markdown is the point of writing
    # them. The Edit button flips to the textarea and back.
    has repoChoice: str = "",
        notesEditing: bool = False;

    hasNotes = bool(form["notes"] and form["notes"].strip());

    selectedProject = form["project"];
    inProject = [
        m
        for m in members
        if selectedProject != "none" and selectedProject in m.project_ids
    ];
    outsiders = [
        m
        for m in members
        if m not in inProject
    ];
    outsideSelected = False;
    for m in outsiders {
        if m.id in assignees and selectedProject != "none" {
            outsideSelected = True;
        }
    }
    projectRepos = [
        r
        for r in repos
        if selectedProject != "none" and r.project_id == selectedProject
    ];
    chosenRepo = "";
    if len(projectRepos) == 1 {
        chosenRepo = projectRepos[0].id;
    } else {
        # A stale pick from a previous project must not reach the walker.
        for r in projectRepos {
            if r.id == repoChoice {
                chosenRepo = r.id;
            }
        }
    }
    canCreateIssue = (
        editing and ghConnected and ghIssueNumber == 0 and len(projectRepos) > 0
    );

    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="max-h-[calc(100dvh-6rem)] p-6 sm:max-w-3xl">
                <DialogHeader>
                    <DialogTitle>{"Edit task" if editing else "New task"}</DialogTitle>
                </DialogHeader>
                <div className="grid gap-4 py-2">
                    <div className="grid gap-x-4 gap-y-3 sm:grid-cols-2">
                        <div className={WIDE}>
                            <Label>Title</Label>
                            <Input
                                className="h-10 md:text-base"
                                value={form["title"]}
                                onChange={lambda (e: ChangeEvent) { onField(
                                    "title", e.target.value
                                ); }}
                            />
                        </div>
                        <div className={WIDE}>
                            <Label>Assignees</Label>
                            <DropdownMenu>
                                <DropdownMenuTrigger asChild={False}>
                                    <span
                                        className="flex h-8 w-full cursor-pointer items-center justify-between rounded-lg border bg-card px-2.5 text-sm hover:bg-accent"
                                    >
                                        <span
                                            className={"truncate"
                                                + (
                                                    ""
                                                        if len(assignees) > 0
                                                        else " text-muted-foreground"
                                                )}
                                        >
                                            {", ".join(
                                                [
                                                    m.name
                                                    for m in members
                                                    if m.id in assignees
                                                ]
                                            )
                                                if len(assignees) > 0
                                                else "Pick assignees"}
                                        </span>
                                        <span
                                            className="ml-2 shrink-0 text-muted-foreground"
                                        >
                                            ⌄
                                        </span>
                                    </span>
                                </DropdownMenuTrigger>
                                <DropdownMenuContent className="w-64">
                                    {if len(inProject) > 0 {
                                        <DropdownMenuLabel key="inl">
                                            On this project
                                        </DropdownMenuLabel>
                                    }}
                                    {for m in inProject {
                                        <DropdownMenuCheckboxItem
                                            key={m.id}
                                            checked={m.id in assignees}
                                            onCheckedChange={lambda { if onToggleAssignee {
                                                onToggleAssignee(m.id);
                                            }}}
                                            onSelect={lambda (e: any) { e.preventDefault(); }}
                                        >
                                            {m.name}
                                        </DropdownMenuCheckboxItem>
                                    }}
                                    {if len(inProject) > 0 and len(outsiders) > 0 {
                                        <DropdownMenuSeparator key="sep"/>
                                    }}
                                    {if len(outsiders) > 0 {
                                        <DropdownMenuLabel key="ol">
                                            {"Other people"
                                                if selectedProject != "none"
                                                else "People"}
                                        </DropdownMenuLabel>
                                    }}
                                    {for m in outsiders {
                                        <DropdownMenuCheckboxItem
                                            key={m.id}
                                            checked={m.id in assignees}
                                            onCheckedChange={lambda { if onToggleAssignee {
                                                onToggleAssignee(m.id);
                                            }}}
                                            onSelect={lambda (e: any) { e.preventDefault(); }}
                                        >
                                            {m.name}
                                        </DropdownMenuCheckboxItem>
                                    }}
                                </DropdownMenuContent>
                            </DropdownMenu>
                            {if outsideSelected {
                                <p key="hint" className="text-xs text-muted-foreground">
                                    Some picks are not on this project yet. Saving adds them to it.
                                </p>
                            }}
                        </div>
                        <div className="grid content-start gap-2">
                            <Label>Project</Label>
                            <Select
                                value={form["project"]}
                                onValueChange={lambda (v: str) { onField(
                                    "project", v
                                ); }}
                            >
                                <SelectTrigger className={FIELD}>
                                    <SelectValue placeholder="No project"/>
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="none">No project</SelectItem>
                                    {for p in projects {
                                        <SelectItem key={jid(p)} value={jid(p)}>
                                            {p.name}
                                        </SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="grid content-start gap-2">
                            <Label>Step</Label>
                            <Select
                                value={form["status"]}
                                onValueChange={lambda (v: str) { onField(
                                    "status", v
                                ); }}
                            >
                                <SelectTrigger className={FIELD}>
                                    <SelectValue placeholder="Step"/>
                                </SelectTrigger>
                                <SelectContent>
                                    {for (si, s) in enumerate(columnKeys) {
                                        <SelectItem key={s} value={s}>
                                            {columnLabels[si]}
                                        </SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="grid content-start gap-2">
                            <Label>Priority</Label>
                            <Select
                                value={form["priority"]}
                                onValueChange={lambda (v: str) { onField(
                                    "priority", v
                                ); }}
                            >
                                <SelectTrigger className={FIELD}>
                                    <SelectValue placeholder="Priority"/>
                                </SelectTrigger>
                                <SelectContent>
                                    {for p in PRIORITIES {
                                        <SelectItem key={p} value={p}>{p}</SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="grid content-start gap-2">
                            <Label htmlFor="task-category">Category</Label>
                            <Input
                                id="task-category"
                                list="standup-categories"
                                className={FIELD}
                                placeholder="Type or pick"
                                value={form["category"]}
                                onChange={lambda (e: any) { onField(
                                    "category", e.target.value
                                ); }}
                            />
                            <datalist id="standup-categories">
                                {for c in categories {
                                    <option key={c} value={c}/>
                                }}
                            </datalist>
                        </div>
                        <div className="grid content-start gap-2">
                            <Label>Due date</Label>
                            <DatePicker
                                value={form["due_date"]}
                                clearable={True}
                                className="w-full justify-between"
                                onChange={lambda (d: str) { onField("due_date", d); }}
                            />
                        </div>
                        <div className={WIDE}>
                            <Label>GitHub issue (optional)</Label>
                            <Input
                                placeholder="https://github.com/owner/repo/issues/12"
                                value={form["issue"]}
                                onChange={lambda (e: ChangeEvent) { onField(
                                    "issue", e.target.value
                                ); }}
                            />
                        </div>
                    </div>
                    {if canCreateIssue {
                        <div
                            key="ghissue"
                            className="grid gap-3 rounded-lg border bg-muted/30 p-3"
                        >
                            <div
                                className="text-xs font-medium uppercase tracking-wide text-muted-foreground"
                            >
                                GitHub
                            </div>
                            {if len(projectRepos) > 1 {
                                <Select
                                    key="repopick"
                                    value={repoChoice}
                                    onValueChange={lambda (v: str) { repoChoice = v; }}
                                >
                                    <SelectTrigger className={FIELD}>
                                        <SelectValue placeholder="Pick a repo"/>
                                    </SelectTrigger>
                                    <SelectContent>
                                        {for r in projectRepos {
                                            <SelectItem key={r.id} value={r.id}>
                                                {r.full_name}
                                            </SelectItem>
                                        }}
                                    </SelectContent>
                                </Select>
                            }}
                            <div>
                                <Button
                                    variant="outline"
                                    disabled={saving or not chosenRepo}
                                    onClick={lambda { if onCreateIssue and chosenRepo {
                                        onCreateIssue(chosenRepo);
                                    }}}
                                >
                                    Create GitHub issue
                                </Button>
                            </div>
                            <p className="text-xs text-muted-foreground">
                                Opens a new issue from this task's title and notes, then links the two. Later edits here do not change the issue.
                            </p>
                        </div>
                    }}
                    {if form["status"] in handoffKeys {
                        <div
                            key="review"
                            className="grid gap-3 rounded-lg border bg-muted/30 p-3"
                        >
                            <div
                                className="text-xs font-medium uppercase tracking-wide text-muted-foreground"
                            >
                                Review handoff (optional)
                            </div>
                            <div className="grid gap-x-4 gap-y-3 sm:grid-cols-2">
                                <div className="grid content-start gap-2">
                                    <Label>Reviewer</Label>
                                    <Select
                                        value={form["reviewer"]}
                                        onValueChange={lambda (v: str) { onField(
                                            "reviewer", v
                                        ); }}
                                    >
                                        <SelectTrigger className={FIELD}>
                                            <SelectValue placeholder="No reviewer"/>
                                        </SelectTrigger>
                                        <SelectContent>
                                            <SelectItem value="none">
                                                No reviewer
                                            </SelectItem>
                                            {for m in members {
                                                <SelectItem key={m.id} value={m.id}>
                                                    {m.name}
                                                </SelectItem>
                                            }}
                                        </SelectContent>
                                    </Select>
                                </div>
                                <div className="grid content-start gap-2">
                                    <Label>Review by</Label>
                                    <DatePicker
                                        value={form["review_due"]}
                                        clearable={True}
                                        className="w-full justify-between"
                                        onChange={lambda (d: str) { onField(
                                            "review_due", d
                                        ); }}
                                    />
                                </div>
                                <div className={WIDE}>
                                    <Label>PR link</Label>
                                    <Input
                                        placeholder="https://github.com/..."
                                        value={form["pr"]}
                                        onChange={lambda (e: ChangeEvent) { onField(
                                            "pr", e.target.value
                                        ); }}
                                    />
                                </div>
                            </div>
                        </div>
                    }}
                    <div className="grid gap-2">
                        <div className="flex items-center justify-between">
                            <Label>Notes / blockers</Label>
                            <Button
                                variant="ghost"
                                size="xs"
                                onClick={lambda { notesEditing = not notesEditing; }}
                            >
                                {"Preview" if notesEditing else "Edit"}
                            </Button>
                        </div>
                        {if notesEditing {
                            <Textarea
                                key="write"
                                className="min-h-40"
                                placeholder="Markdown works here: **bold**, - lists, `code`, links."
                                value={form["notes"]}
                                onChange={lambda (e: ChangeEvent) { onField(
                                    "notes", e.target.value
                                ); }}
                            />
                        } elif hasNotes {
                            <div
                                key="preview"
                                className="min-h-40 rounded-lg border bg-muted/30 p-3 text-sm"
                            >
                                <Markdown text={form["notes"]}/>
                            </div>
                        } else {
                            <button
                                key="empty"
                                type="button"
                                onClick={lambda { notesEditing = True; }}
                                className="flex min-h-40 items-start rounded-lg border border-dashed bg-muted/30 p-3 text-left text-sm text-muted-foreground hover:bg-muted/50"
                            >
                                Nothing yet. Click to write; markdown is rendered here.
                            </button>
                        }  }
                    </div>
                </div>
                <DialogFooter className="-mx-6 -mb-6 gap-2 px-6 sm:justify-between">
                    {if editing {
                        <Button
                            key="del"
                            variant="destructive"
                            onClick={onDelete}
                            disabled={saving}
                        >
                            Delete
                        </Button>
                    } else {
                        <span key="spacer"/>
                    } }
                    <div className="flex gap-2">
                        <Button
                            variant="outline"
                            onClick={lambda { onOpenChange(False); }}
                        >
                            Cancel
                        </Button>
                        <Button
                            onClick={onSave}
                            disabled={saving or not form["title"].strip()}
                        >
                            Save
                        </Button>
                    </div>
                </DialogFooter>
            </DialogContent>
        </Dialog>;
}
