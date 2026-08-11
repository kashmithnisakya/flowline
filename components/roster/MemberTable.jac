"""Org roster table with inline project assignment."""

import from ...models { Project, MemberView }
import from ..ui.button { Button }
import from ..ui.badge { Badge }
import from ..ui.card { Card, CardContent }
import from ..ui.table { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}

# Avatar hue pairs picked by name hash; whole literal strings so Tailwind scans them.
glob AVATAR_HUES: list[str] = [
    "bg-chart-1/15 text-chart-1",
    "bg-chart-2/15 text-chart-2",
    "bg-chart-3/15 text-chart-3",
    "bg-chart-4/15 text-chart-4",
    "bg-chart-5/15 text-chart-5"
];

# "Ishara Perera" -> "IP" for the avatar circle.
def initialsOf(name: str) -> str {
    parts = [
        w
        for w in name.split()
        if w
    ];
    first = parts[0][:1] if len(parts) > 0 else "?";
    second = parts[1][:1] if len(parts) > 1 else "";
    return (first + second).upper();
}

# Deterministic avatar hue: sum of character codes into the hue table.
def hueFor(name: any) -> str {
    total = 0;
    for i in range(len(name)) {
        total = total + name.charCodeAt(i);
    }
    return AVATAR_HUES[total % 5];
}

def:pub MemberTable(
    members: list[MemberView],
    projects: list[Project],
    onEdit: Callable[[MemberView], None],
    onArchive: Callable[[str], None],
    onAssign: Callable[[str, str], None],
    onUnassign: Callable[[str, str], None],
    onCreate: Callable[[], None] = None
) -> JsxElement {
    # Archive is a two-step: the first click arms this row, the second fires.
    has armedId: str = "";

    if len(members) == 0 {
        return
            <Card>
                <CardContent
                    className="flex flex-col items-center gap-2 py-10 text-center"
                >
                    <svg
                        className="text-muted-foreground/60"
                        width={28}
                        height={28}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    >
                        <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>
                        <circle cx={9} cy={7} r={4}/>
                        <path d="M22 21v-2a4 4 0 0 0-3-3.87"/>
                        <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
                    </svg>
                    <p className="text-sm font-semibold">No members yet</p>
                    <p className="text-sm text-muted-foreground">
                        Members are roster records, not accounts. Add your team
                        to assign work and sign log entries.
                    </p>
                    {if onCreate {
                        <Button
                            key="cta"
                            size="sm"
                            className="mt-2"
                            onClick={lambda { onCreate(); }}
                        >
                            <svg
                                width={14}
                                height={14}
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            >
                                <path d="M5 12h14"/>
                                <path d="M12 5v14"/>
                            </svg>
                            Add member
                        </Button>
                    }}
                </CardContent>
            </Card>;
    }

    return
        <Card>
            <CardContent className="pt-4">
                <Table>
                    <TableHeader>
                        <TableRow>
                            <TableHead>Member</TableHead>
                            <TableHead>Roles</TableHead>
                            <TableHead>Projects</TableHead>
                            <TableHead>Tags</TableHead>
                            <TableHead>Contact</TableHead>
                            <TableHead className="text-right">Actions</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {for m in members {
                            <TableRow key={m.id} className="transition-colors">
                                <TableCell>
                                    <div className="flex items-center gap-3">
                                        <span
                                            className={"flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-xs font-bold "
                                                + hueFor(m.name)}
                                        >
                                            {initialsOf(m.name)}
                                        </span>
                                        <div className="min-w-0">
                                            <div className="truncate font-medium">
                                                {m.name}
                                            </div>
                                        </div>
                                    </div>
                                </TableCell>
                                <TableCell>
                                    {if len(m.roles) > 0 {
                                        <div className="flex flex-wrap gap-1">
                                            {for r in m.roles {
                                                <Badge
                                                    key={r}
                                                    variant="secondary"
                                                    className="font-normal"
                                                >
                                                    {r}
                                                </Badge>
                                            }}
                                        </div>
                                    } else {
                                        <span
                                            key="dash"
                                            className="text-muted-foreground"
                                        >
                                            —
                                        </span>
                                    } }
                                </TableCell>
                                <TableCell>
                                    <div className="flex flex-wrap items-center gap-1">
                                        {for pname in m.project_names {
                                            <Badge
                                                key={pname}
                                                variant="secondary"
                                                className="cursor-pointer hover:bg-destructive/15 hover:text-destructive"
                                                title="Click to unassign"
                                                onClick={lambda { onUnassign(
                                                    m.id, pname
                                                ); }}
                                            >
                                                {pname} ✕
                                            </Badge>
                                        }}
                                        {if len(projects) > 0 {
                                            <Select
                                                key="assign"
                                                value=""
                                                onValueChange={lambda (v: str) { onAssign(
                                                    m.id, v
                                                ); }}
                                            >
                                                <SelectTrigger
                                                    className="h-6 w-auto border-dashed px-2 text-xs text-muted-foreground"
                                                    size="sm"
                                                    title="Assign to a project"
                                                >
                                                    <SelectValue
                                                        placeholder="+ Assign"
                                                    />
                                                </SelectTrigger>
                                                <SelectContent>
                                                    {for p in projects {
                                                        <SelectItem
                                                            key={jid(p)}
                                                            value={jid(p)}
                                                        >
                                                            {p.name}
                                                        </SelectItem>
                                                    }}
                                                </SelectContent>
                                            </Select>
                                        }}
                                    </div>
                                </TableCell>
                                <TableCell>
                                    {if len(m.tags) > 0 {
                                        <div className="flex flex-wrap gap-1">
                                            {for t in m.tags {
                                                <Badge
                                                    key={t}
                                                    variant="outline"
                                                    className="font-normal"
                                                >
                                                    {t}
                                                </Badge>
                                            }}
                                        </div>
                                    } else {
                                        <span
                                            key="dash"
                                            className="text-muted-foreground"
                                        >
                                            —
                                        </span>
                                    } }
                                </TableCell>
                                <TableCell>
                                    <div
                                        className="grid gap-0.5 text-xs text-muted-foreground"
                                    >
                                        {if m.email {
                                            <span key="mail" className="truncate">
                                                {m.email}
                                            </span>
                                        }}
                                        {if m.github_username {
                                            <span
                                                key="gh"
                                                className="truncate font-mono"
                                            >
                                                @{m.github_username}
                                            </span>
                                        }}
                                        {if not m.email and not m.github_username {
                                            <span key="dash">—</span>
                                        }}
                                    </div>
                                </TableCell>
                                <TableCell className="text-right">
                                    <Button
                                        variant="ghost"
                                        size="sm"
                                        onClick={lambda { onEdit(m); }}
                                    >
                                        Edit
                                    </Button>
                                    <Button
                                        variant={"destructive"
                                            if armedId == m.id
                                            else "ghost"}
                                        size="sm"
                                        className={""
                                            if armedId == m.id
                                            else "text-destructive"}
                                        title={"Click again to archive"
                                            if armedId == m.id
                                            else "Archive"}
                                        onClick={lambda {
                                            if armedId == m.id {
                                                armedId = "";
                                                onArchive(m.id);
                                            } else {
                                                armedId = m.id;
                                            }
                                        }}
                                    >
                                        {"Confirm?" if armedId == m.id else "Archive"}
                                    </Button>
                                </TableCell>
                            </TableRow>
                        }}
                    </TableBody>
                </Table>
            </CardContent>
        </Card>;
}
