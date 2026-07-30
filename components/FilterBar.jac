"""Board filters: team (defaults to the viewer's), assignee, category, hide-Done."""

import from endpoints { Member }
import from ..constants { TEAMS, CATEGORIES }
import from .ui.select { Select, SelectTrigger, SelectValue, SelectContent, SelectItem }
import from .ui.button { Button }

def:pub FilterBar(
    members: list[Member],
    team: str,
    assignee: str,
    category: str,
    hideDone: bool,
    onTeam: Callable[[str], None],
    onAssignee: Callable[[str], None],
    onCategory: Callable[[str], None],
    onHideDone: Callable[[], None]
) -> JsxElement {
    <div className="flex flex-wrap items-center gap-2">
        <Select value={team} onValueChange={onTeam}>
            <SelectTrigger className="h-8 w-40" size="sm">
                <SelectValue placeholder="Team" />
            </SelectTrigger>
            <SelectContent>
                <SelectItem value="All">All teams</SelectItem>
                {for t in TEAMS {
                    <SelectItem key={t} value={t}>{t}</SelectItem>
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
                    <SelectItem key={jid(m)} value={jid(m)}>{m.name}</SelectItem>
                }}
            </SelectContent>
        </Select>
        <Select value={category} onValueChange={onCategory}>
            <SelectTrigger className="h-8 w-40" size="sm">
                <SelectValue placeholder="Category" />
            </SelectTrigger>
            <SelectContent>
                <SelectItem value="All">All categories</SelectItem>
                {for c in CATEGORIES {
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
