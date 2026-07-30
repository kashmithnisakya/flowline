"""Member identity picker — the entire v1 identity story.

No auth: the picked member's jid is persisted in localStorage and prefills
the log form, assignee defaults, and the board's team filter.
"""

import from endpoints { Member }
import from .ui.select { Select, SelectTrigger, SelectValue, SelectContent, SelectItem }

def:pub WhoAmIPicker(
    members: list[Member],
    value: str,
    onChange: Callable[[str], None]
) -> JsxElement {
    <Select value={value} onValueChange={onChange}>
        <SelectTrigger className="h-8 w-44" size="sm">
            <SelectValue placeholder="Who are you?" />
        </SelectTrigger>
        <SelectContent>
            {for m in members {
                <SelectItem key={jid(m)} value={jid(m)}>{m.name}</SelectItem>
            }}
        </SelectContent>
    </Select>
}
