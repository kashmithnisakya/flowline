"""Create/edit dialog for a kanban task.

The form is a plain dict owned by the page; assignees ride separately as
a list (tasks take several people in v2.5). Assignee chips group by
project membership, and picking someone outside the selected project
adds them to it on save. A Review status reveals the handoff fields.
"""

# The board vocabulary comes from constants.jac rather than a local copy;
# importing it is also what keeps that module in the compiled client.
import from ...constants { STATUSES, PRIORITIES }
import from ...models { Project, MemberView, MilestoneView, RepoView }
import from ..log.DatePicker { DatePicker }
import from ..ui.button { Button }
import from ..ui.badge { Badge }
import from ..ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter
}
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.textarea { Textarea }
import from ..ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}
import from ..ui.dropdown_menu {
    DropdownMenu, DropdownMenuTrigger, DropdownMenuContent,
    DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuCheckboxItem
}

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
    assignees: list[str] = [],
    onToggleAssignee: Callable[[str], None] = None,
    milestones: list[MilestoneView] = [],
    repos: list[RepoView] = [],
    ghConnected: bool = False,
    ghIssueNumber: int = 0,
    onCreateIssue: Callable[[str], None] = None
) -> JsxElement {
    # Which repo the new issue goes in, when the project tracks more than
    # one. Purely local: the page never needs to know about the picker.
    has repoChoice: str = "";

    selectedProject = form["project"];
    inProject = [
        m for m in members
        if selectedProject != "none" and selectedProject in m.project_ids
    ];
    outsiders = [m for m in members if m not in inProject];
    outsideSelected = False;
    for m in outsiders {
        if m.id in assignees and selectedProject != "none" {
            outsideSelected = True;
        }
    }
    # A milestone belongs to exactly one project, so the list only ever
    # offers the selected project's own phases.
    projectMilestones = [
        m for m in milestones
        if selectedProject != "none" and m.project_id == selectedProject
    ];
    projectRepos = [
        r for r in repos
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

    return <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="sm:max-w-lg">
            <DialogHeader>
                <DialogTitle>{"Edit task" if editing else "New task"}</DialogTitle>
            </DialogHeader>
            <div className="grid gap-4 py-2">
                <div className="grid gap-2">
                    <Label>Title</Label>
                    <Input
                        value={form["title"]}
                        onChange={lambda (e: ChangeEvent) { onField("title", e.target.value); }}
                    />
                </div>
                <div className="grid grid-cols-2 gap-3">
                    <div className="grid gap-2">
                        <Label>Project</Label>
                        <Select
                            value={form["project"]}
                            onValueChange={lambda (v: str) { onField("project", v); }}
                        >
                            <SelectTrigger><SelectValue placeholder="Project" /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="none">No project</SelectItem>
                                {for p in projects {
                                    <SelectItem key={jid(p)} value={jid(p)}>{p.name}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="grid gap-2">
                        <Label>Milestone</Label>
                        <Select
                            value={form["milestone"]}
                            onValueChange={lambda (v: str) { onField("milestone", v); }}
                        >
                            <SelectTrigger><SelectValue placeholder="Milestone" /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="none">No milestone</SelectItem>
                                {for m in projectMilestones {
                                    <SelectItem key={m.id} value={m.id}>{m.title}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="grid gap-2">
                        <Label>Category</Label>
                        <Select
                            value={form["category"]}
                            onValueChange={lambda (v: str) { onField("category", v); }}
                        >
                            <SelectTrigger><SelectValue placeholder="Category" /></SelectTrigger>
                            <SelectContent>
                                {for c in categories {
                                    <SelectItem key={c} value={c}>{c}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="grid gap-2">
                        <Label>Priority</Label>
                        <Select
                            value={form["priority"]}
                            onValueChange={lambda (v: str) { onField("priority", v); }}
                        >
                            <SelectTrigger><SelectValue placeholder="Priority" /></SelectTrigger>
                            <SelectContent>
                                {for p in PRIORITIES {
                                    <SelectItem key={p} value={p}>{p}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="grid gap-2">
                        <Label>Status</Label>
                        <Select
                            value={form["status"]}
                            onValueChange={lambda (v: str) { onField("status", v); }}
                        >
                            <SelectTrigger><SelectValue placeholder="Status" /></SelectTrigger>
                            <SelectContent>
                                {for s in STATUSES {
                                    <SelectItem key={s} value={s}>{s}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                </div>
                <div className="grid gap-2">
                    <Label>Assignees</Label>
                    <DropdownMenu>
                        <DropdownMenuTrigger asChild={False}>
                            <span className="flex h-9 w-full cursor-pointer items-center justify-between rounded-lg border bg-card px-3 text-sm hover:bg-accent">
                                <span className={"truncate" + ("" if len(assignees) > 0 else " text-muted-foreground")}>
                                    {
                                        ", ".join([m.name for m in members if m.id in assignees])
                                        if len(assignees) > 0
                                        else "Pick assignees"
                                    }
                                </span>
                                <span className="ml-2 shrink-0 text-muted-foreground">⌄</span>
                            </span>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent className="w-64">
                            {if len(inProject) > 0 {
                                <DropdownMenuLabel key="inl">On this project</DropdownMenuLabel>
                            }}
                            {for m in inProject {
                                <DropdownMenuCheckboxItem
                                    key={m.id}
                                    checked={m.id in assignees}
                                    onCheckedChange={lambda { if onToggleAssignee { onToggleAssignee(m.id); } }}
                                    onSelect={lambda (e: any) { e.preventDefault(); }}
                                >
                                    {m.name}
                                </DropdownMenuCheckboxItem>
                            }}
                            {if len(inProject) > 0 and len(outsiders) > 0 {
                                <DropdownMenuSeparator key="sep" />
                            }}
                            {if len(outsiders) > 0 {
                                <DropdownMenuLabel key="ol">
                                    {"Other people" if selectedProject != "none" else "People"}
                                </DropdownMenuLabel>
                            }}
                            {for m in outsiders {
                                <DropdownMenuCheckboxItem
                                    key={m.id}
                                    checked={m.id in assignees}
                                    onCheckedChange={lambda { if onToggleAssignee { onToggleAssignee(m.id); } }}
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
                <div className="grid grid-cols-2 gap-3">
                    <div className="grid gap-2">
                        <Label>Due date</Label>
                        <div>
                            <DatePicker
                                value={form["due_date"]}
                                onChange={lambda (d: str) { onField("due_date", d); }}
                            />
                        </div>
                    </div>
                    <div className="grid gap-2">
                        <Label>GitHub issue (optional)</Label>
                        <Input
                            placeholder="https://github.com/..."
                            value={form["issue"]}
                            onChange={lambda (e: ChangeEvent) { onField("issue", e.target.value); }}
                        />
                    </div>
                </div>
                {if canCreateIssue {
                    <div key="ghissue" className="grid gap-3 rounded-lg border bg-muted/30 p-3">
                        <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                            GitHub
                        </div>
                        {if len(projectRepos) > 1 {
                            <Select
                                key="repopick"
                                value={repoChoice}
                                onValueChange={lambda (v: str) { repoChoice = v; }}
                            >
                                <SelectTrigger><SelectValue placeholder="Pick a repo" /></SelectTrigger>
                                <SelectContent>
                                    {for r in projectRepos {
                                        <SelectItem key={r.id} value={r.id}>{r.full_name}</SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        }}
                        <div>
                            <Button
                                variant="outline"
                                disabled={saving or not chosenRepo}
                                onClick={lambda {
                                    if onCreateIssue and chosenRepo {
                                        onCreateIssue(chosenRepo);
                                    }
                                }}
                            >
                                Create GitHub issue
                            </Button>
                        </div>
                        <p className="text-xs text-muted-foreground">
                            Opens a new issue from this task's title and notes, then links
                            the two. Later edits here do not change the issue.
                        </p>
                    </div>
                }}
                {if form["status"] == "Review" {
                    <div key="review" className="grid gap-3 rounded-lg border bg-muted/30 p-3">
                        <div className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                            Review handoff (optional)
                        </div>
                        <div className="grid grid-cols-2 gap-3">
                            <div className="grid gap-2">
                                <Label>Reviewer</Label>
                                <Select
                                    value={form["reviewer"]}
                                    onValueChange={lambda (v: str) { onField("reviewer", v); }}
                                >
                                    <SelectTrigger><SelectValue placeholder="Reviewer" /></SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="none">No reviewer</SelectItem>
                                        {for m in members {
                                            <SelectItem key={m.id} value={m.id}>{m.name}</SelectItem>
                                        }}
                                    </SelectContent>
                                </Select>
                            </div>
                            <div className="grid gap-2">
                                <Label>Review by</Label>
                                <div>
                                    <DatePicker
                                        value={form["review_due"]}
                                        onChange={lambda (d: str) { onField("review_due", d); }}
                                    />
                                </div>
                            </div>
                        </div>
                        <div className="grid gap-2">
                            <Label>PR link</Label>
                            <Input
                                placeholder="https://github.com/..."
                                value={form["pr"]}
                                onChange={lambda (e: ChangeEvent) { onField("pr", e.target.value); }}
                            />
                        </div>
                    </div>
                }}
                <div className="grid gap-2">
                    <Label>Notes / blockers</Label>
                    <Textarea
                        value={form["notes"]}
                        onChange={lambda (e: ChangeEvent) { onField("notes", e.target.value); }}
                    />
                </div>
            </div>
            <DialogFooter className="gap-2 sm:justify-between">
                {if editing {
                    <Button key="del" variant="destructive" onClick={onDelete} disabled={saving}>
                        Delete
                    </Button>
                } else {
                    <span key="spacer" />
                }}
                <div className="flex gap-2">
                    <Button variant="outline" onClick={lambda { onOpenChange(False); }}>
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
