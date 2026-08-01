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
                        <TableHead>Name</TableHead>
                        <TableHead>Projects</TableHead>
                        <TableHead>Role</TableHead>
                        <TableHead>Section</TableHead>
                        <TableHead>Email</TableHead>
                        <TableHead>GitHub</TableHead>
                        <TableHead className="text-right">Actions</TableHead>
                    </TableRow>
                </TableHeader>
                <TableBody>
                    {for m in members {
                        <TableRow key={m.id}>
                            <TableCell className="font-medium">{m.name}</TableCell>
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
                            <TableCell className="text-muted-foreground">{m.role}</TableCell>
                            <TableCell className="text-muted-foreground">{m.section}</TableCell>
                            <TableCell className="text-muted-foreground">{m.email}</TableCell>
                            <TableCell className="text-muted-foreground">{m.github_username}</TableCell>
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
