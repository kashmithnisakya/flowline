"""Project list with edit/archive actions."""

import from ...models { Project }
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent }
import from ..ui.table {
    Table, TableHeader, TableBody, TableRow, TableHead, TableCell
}

def:pub ProjectTable(
    projects: list[Project],
    onEdit: Callable[[Project], None],
    onArchive: Callable[[str], None]
) -> JsxElement {
    if len(projects) == 0 {
        return <Card>
            <CardContent className="py-10 text-center text-sm text-muted-foreground">
                No projects yet — create your first one.
            </CardContent>
        </Card>;
    }

    <Card>
        <CardContent className="pt-4">
            <Table>
                <TableHeader>
                    <TableRow>
                        <TableHead>Name</TableHead>
                        <TableHead>Description</TableHead>
                        <TableHead className="text-right">Actions</TableHead>
                    </TableRow>
                </TableHeader>
                <TableBody>
                    {for p in projects {
                        <TableRow key={jid(p)}>
                            <TableCell className="font-medium">{p.name}</TableCell>
                            <TableCell className="text-muted-foreground">{p.description}</TableCell>
                            <TableCell className="text-right">
                                <Button variant="ghost" size="sm" onClick={lambda { onEdit(p); }}>
                                    Edit
                                </Button>
                                <Button
                                    variant="ghost"
                                    size="sm"
                                    className="text-destructive"
                                    onClick={lambda { onArchive(jid(p)); }}
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
