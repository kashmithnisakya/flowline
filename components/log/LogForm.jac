"""The log-activity form: the PM records one member's day."""

import from ...constants { STATUSES, CATEGORIES }
import from ...models { Project, MemberView, Repo }
import from ..ui.button { Button }
import from ..ui.card { Card, CardHeader, CardTitle, CardContent }
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..ui.textarea { Textarea }
import from ..ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}

def:pub LogForm(
    form: dict[str, str],
    members: list[MemberView],
    projects: list[Project],
    repos: list[Repo],
    editing: bool,
    editingMemberName: str,
    canSubmit: bool,
    onField: Callable[[str, str], None],
    onSubmit: Callable[[], None],
    onCancel: Callable[[], None]
) -> JsxElement {
    <Card>
        <CardHeader>
            <CardTitle className="text-base">
                {"Update entry" if editing else "Log activity"}
            </CardTitle>
        </CardHeader>
        <CardContent className="grid gap-4">
            <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
                <div className="grid gap-2">
                    <Label>Member</Label>
                    {if editing {
                        <Input key="ro" value={editingMemberName} disabled={True} />
                    } else {
                        <Select key="sel"
                            value={form["member"]}
                            onValueChange={lambda (v: str) { onField("member", v); }}
                        >
                            <SelectTrigger><SelectValue placeholder="Who?" /></SelectTrigger>
                            <SelectContent>
                                {for m in members {
                                    <SelectItem key={m.id} value={m.id}>{m.name}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    }}
                </div>
                <div className="grid gap-2">
                    <Label>Project</Label>
                    <Select
                        value={form["project"]}
                        onValueChange={lambda (v: str) { onField("project", v); }}
                        disabled={editing}
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
                    <Label>Category</Label>
                    <Select
                        value={form["category"]}
                        onValueChange={lambda (v: str) { onField("category", v); }}
                    >
                        <SelectTrigger><SelectValue placeholder="Category" /></SelectTrigger>
                        <SelectContent>
                            {for c in CATEGORIES {
                                <SelectItem key={c} value={c}>{c}</SelectItem>
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
                <div className="grid gap-2">
                    <Label>GitHub repo</Label>
                    <Select
                        value={form["repo"]}
                        onValueChange={lambda (v: str) { onField("repo", v); }}
                    >
                        <SelectTrigger><SelectValue placeholder="Repo" /></SelectTrigger>
                        <SelectContent>
                            <SelectItem value="none">No repo</SelectItem>
                            {for r in repos {
                                <SelectItem key={jid(r)} value={r.full_name}>{r.full_name}</SelectItem>
                            }}
                        </SelectContent>
                    </Select>
                </div>
            </div>
            <div className="grid gap-2">
                <Label>Activity / task</Label>
                <Input
                    placeholder="What did they work on?"
                    value={form["activity"]}
                    onChange={lambda (e: ChangeEvent) { onField("activity", e.target.value); }}
                />
            </div>
            <div className="grid grid-cols-2 gap-3">
                <div className="grid gap-2">
                    <Label>GitHub issue link</Label>
                    <Input
                        placeholder="https://github.com/..."
                        value={form["issue"]}
                        onChange={lambda (e: ChangeEvent) { onField("issue", e.target.value); }}
                    />
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
            <div className="grid gap-2">
                <Label>Notes / blockers</Label>
                <Textarea
                    value={form["notes"]}
                    onChange={lambda (e: ChangeEvent) { onField("notes", e.target.value); }}
                />
            </div>
            <div className="flex justify-end gap-2">
                {if editing {
                    <Button key="cancel" variant="outline" onClick={onCancel}>Cancel</Button>
                }}
                <Button onClick={onSubmit} disabled={not canSubmit}>
                    {"Update" if editing else "Log it"}
                </Button>
            </div>
        </CardContent>
    </Card>
}
