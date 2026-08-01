"""Board filters: project (persisted), assignee, category, hide-Done."""

import from ...models { Project, MemberView }
import from ...constants { CATEGORIES }
import from ..ui.select { Select, SelectTrigger, SelectValue, SelectContent, SelectItem }
import from ..ui.button { Button }

def:pub FilterBar(
    projects: list[Project],
    members: list[MemberView],
    project: str,
    assignee: str,
    category: str,
    hideDone: bool,
    onProject: Callable[[str], None],
    onAssignee: Callable[[str], None],
    onCategory: Callable[[str], None],
    onHideDone: Callable[[], None],
    categories: list[str] = []
) -> JsxElement {
    categoryOptions = categories if categories else CATEGORIES;
    <div className="flex flex-wrap items-center gap-2">
        <Select value={project} onValueChange={onProject}>
            <SelectTrigger className="h-8 w-44" size="sm">
                <SelectValue placeholder="Project" />
            </SelectTrigger>
            <SelectContent>
                <SelectItem value="all">All projects</SelectItem>
                {for p in projects {
                    <SelectItem key={jid(p)} value={jid(p)}>{p.name}</SelectItem>
                }}
            </SelectContent>
        </Select>
        <Select value={assignee} onValueChange={onAssignee}>
            <SelectTrigger className="h-8 w-40" size="sm">
                <SelectValue placeholder="Assignee" />
            </SelectTrigger>
            <SelectContent>
                <SelectItem value="All">Everyone</SelectItem>
                {for m in members {
                    <SelectItem key={m.id} value={m.id}>{m.name}</SelectItem>
                }}
            </SelectContent>
        </Select>
        <Select value={category} onValueChange={onCategory}>
            <SelectTrigger className="h-8 w-40" size="sm">
                <SelectValue placeholder="Category" />
            </SelectTrigger>
            <SelectContent>
                <SelectItem value="All">All categories</SelectItem>
                {for c in categoryOptions {
                    <SelectItem key={c} value={c}>{c}</SelectItem>
                }}
            </SelectContent>
        </Select>
        <Button
            variant={"default" if hideDone else "outline"}
            size="sm"
            className="h-8"
            onClick={lambda { onHideDone(); }}
        >
            Hide Done
        </Button>
    </div>
}
