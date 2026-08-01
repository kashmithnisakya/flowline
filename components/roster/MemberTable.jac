"""Org roster table with inline project assignment."""

import from ...models { Project, MemberView }
import from ..ui.button { Button }
import from ..ui.badge { Badge }
import from ..ui.card { Card, CardContent }
import from ..ui.table {
    Table, TableHeader, TableBody, TableRow, TableHead, TableCell
}
import from ..ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}

# "Ishara Perera" -> "IP" for the avatar circle.
def initialsOf(name: str) -> str {
    parts = [w for w in name.split() if w];
    first = parts[0][:1] if len(parts) > 0 else "?";
    second = parts[1][:1] if len(parts) > 1 else "";
    return (first + second).upper();
}

def:pub MemberTable(
    members: list[MemberView],
    projects: list[Project],
    onEdit: Callable[[MemberView], None],
    onArchive: Callable[[str], None],
    onAssign: Callable[[str, str], None],
    onUnassign: Callable[[str, str], None]
) -> JsxElement {
    if len(members) == 0 {
        return <Card>
            <CardContent className="py-10 text-center text-sm text-muted-foreground">
                No members yet. Add your team with “Add member”.
            </CardContent>
        </Card>;
    }

    <Card>
        <CardContent className="pt-4">
            <Table>
                <TableHeader>
                    <TableRow>
                        <TableHead>Member</TableHead>
                        <TableHead>Projects</TableHead>
                        <TableHead>Section</TableHead>
                        <TableHead>Contact</TableHead>
                        <TableHead className="text-right">Actions</TableHead>
                    </TableRow>
                </TableHeader>
                <TableBody>
                    {for m in members {
                        <TableRow key={m.id}>
                            <TableCell>
                                <div className="flex items-center gap-3">
                                    <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary/10 text-xs font-bold text-primary">
                                        {initialsOf(m.name)}
                                    </span>
                                    <div className="min-w-0">
                                        <div className="truncate font-medium">{m.name}</div>
                                        {if m.role {
                                            <div className="truncate text-xs text-muted-foreground">{m.role}</div>
                                        }}
                                    </div>
                                </div>
                            </TableCell>
                            <TableCell>
                                <div className="flex flex-wrap items-center gap-1">
                                    {for pname in m.project_names {
                                        <Badge
                                            key={pname}
                                            variant="secondary"
                                            className="cursor-pointer"
                                            title="Click to unassign"
                                            onClick={lambda { onUnassign(m.id, pname); }}
                                        >
                                            {pname} ✕
                                        </Badge>
                                    }}
                                    {if len(projects) > 0 {
                                        <Select key="assign"
                                            value=""
                                            onValueChange={lambda (v: str) { onAssign(m.id, v); }}
                                        >
                                            <SelectTrigger
                                                className="h-6 w-9 border-dashed px-1 text-xs"
                                                size="sm"
                                            >
                                                <SelectValue placeholder="+" />
                                            </SelectTrigger>
                                            <SelectContent>
                                                {for p in projects {
                                                    <SelectItem key={jid(p)} value={jid(p)}>{p.name}</SelectItem>
                                                }}
                                            </SelectContent>
                                        </Select>
                                    }}
                                </div>
                            </TableCell>
                            <TableCell>
                                {if m.section {
                                    <Badge variant="outline">{m.section}</Badge>
                                } else {
                                    <span key="dash" className="text-muted-foreground">—</span>
                                }}
                            </TableCell>
                            <TableCell>
                                <div className="grid gap-0.5 text-xs text-muted-foreground">
                                    {if m.email {
                                        <span key="mail" className="truncate">{m.email}</span>
                                    }}
                                    {if m.github_username {
                                        <span key="gh" className="truncate font-mono">@{m.github_username}</span>
                                    }}
                                    {if not m.email and not m.github_username {
                                        <span key="dash">—</span>
                                    }}
                                </div>
                            </TableCell>
                            <TableCell className="text-right">
                                <Button variant="ghost" size="sm" onClick={lambda { onEdit(m); }}>
                                    Edit
                                </Button>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="text-destructive"
                                    onClick={lambda { onArchive(m.id); }}
                                >
                                    Archive
                                </Button>
                            </TableCell>
                        </TableRow>
                    }}
                </TableBody>
            </Table>
        </CardContent>
    </Card>
}
