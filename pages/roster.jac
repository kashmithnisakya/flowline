"""standup - Roster page: members table + GitHub repos list.

Stateful shell: this page owns all roster state and handlers (bodies in
roster.impl.jac); the member form dialog and repo manager are composed
inline from shadcn primitives.
"""

import from ..constants { TEAMS, SECTIONS }
import from endpoints {
    Member, Repo,
    ListMembers, SaveMember, ArchiveMember,
    ListRepos, AddRepo, RemoveRepo
}
import from ..components.ui.button { Button }
import from ..components.ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ..components.ui.table {
    Table, TableHeader, TableBody, TableRow, TableHead, TableCell
}
import from ..components.ui.dialog {
    Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter
}
import from ..components.ui.input { Input }
import from ..components.ui.label { Label }
import from ..components.ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}
import from ..components.ui.badge { Badge }
import from ..components.ui.skeleton { Skeleton }
import from "sonner" { toast }

def:pub RosterPage() -> JsxPage {
    has members: list[Member] = [],
        repos: list[Repo] = [],
        loading: bool = True,
        dialogOpen: bool = False,
        editingId: str = "",
        fName: str = "",
        fTeam: str = "",
        fRole: str = "",
        fEmail: str = "",
        fGithub: str = "",
        fSection: str = "",
        newRepo: str = "",
        saving: bool = False;

    async can with entry {
        loadAll();
    }

    async def loadAll -> None;
    async def saveMember -> None;
    async def archiveMember(memberId: str) -> None;
    async def addRepo -> None;
    async def removeRepo(repoId: str) -> None;
    def openCreate -> None;
    def openEdit(m: Member) -> None;

    active = [m for m in members if m.active];

    <div className="space-y-8">
        <div className="flex items-center justify-between">
            <div>
                <h1 className="text-2xl font-semibold tracking-tight">Roster</h1>
                <p className="text-sm text-muted-foreground">
                    {len(active)} members — feeds every dropdown in the app.
                </p>
            </div>
            <Button onClick={openCreate}>Add member</Button>
        </div>

        {if loading {
            <Skeleton className="h-48 w-full" />
        } elif len(active) == 0 {
            <Card>
                <CardContent className="py-10 text-center text-sm text-muted-foreground">
                    No members yet. Add one with “Add member”, or import the spreadsheet
                    export via the ImportCsv endpoint (see PLAN.md).
                </CardContent>
            </Card>
        } else {
            <Card>
                <CardContent className="pt-4">
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead>Name</TableHead>
                                <TableHead>Team</TableHead>
                                <TableHead>Section</TableHead>
                                <TableHead>Role</TableHead>
                                <TableHead>Email</TableHead>
                                <TableHead>GitHub</TableHead>
                                <TableHead className="text-right">Actions</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {for m in active {
                                <TableRow key={jid(m)}>
                                    <TableCell className="font-medium">{m.name}</TableCell>
                                    <TableCell><Badge variant="secondary">{m.team}</Badge></TableCell>
                                    <TableCell className="text-muted-foreground">{m.section}</TableCell>
                                    <TableCell className="text-muted-foreground">{m.role}</TableCell>
                                    <TableCell className="text-muted-foreground">{m.email}</TableCell>
                                    <TableCell className="text-muted-foreground">{m.github_username}</TableCell>
                                    <TableCell className="text-right">
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            onClick={lambda { openEdit(m); }}
                                        >
                                            Edit
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            className="text-destructive"
                                            onClick={lambda { archiveMember(jid(m)); }}
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
        }}

        <Card>
            <CardHeader>
                <CardTitle>GitHub Repos</CardTitle>
                <CardDescription>The repo dropdown on daily-log entries.</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
                <div className="flex gap-2">
                    <Input
                        placeholder="org/repo"
                        className="max-w-sm"
                        value={newRepo}
                        onChange={lambda (e: ChangeEvent) { newRepo = e.target.value; }}
                    />
                    <Button variant="outline" onClick={addRepo} disabled={not newRepo.strip()}>
                        Add
                    </Button>
                </div>
                {for r in repos {
                    <div
                        key={jid(r)}
                        className="flex items-center justify-between rounded-md border px-3 py-2 text-sm"
                    >
                        <span className="font-mono">{r.full_name}</span>
                        <Button variant="ghost" size="sm" onClick={lambda { removeRepo(jid(r)); }}>
                            Remove
                        </Button>
                    </div>
                }}
            </CardContent>
        </Card>

        <Dialog open={dialogOpen} onOpenChange={lambda (o: bool) { dialogOpen = o; }}>
            <DialogContent>
                <DialogHeader>
                    <DialogTitle>{"Edit member" if editingId else "Add member"}</DialogTitle>
                </DialogHeader>
                <div className="grid gap-4 py-2">
                    <div className="grid gap-2">
                        <Label>Name</Label>
                        <Input
                            value={fName}
                            onChange={lambda (e: ChangeEvent) { fName = e.target.value; }}
                        />
                    </div>
                    <div className="grid gap-2">
                        <Label>Team</Label>
                        <Select value={fTeam} onValueChange={lambda (v: str) { fTeam = v; }}>
                            <SelectTrigger>
                                <SelectValue placeholder="Pick a team" />
                            </SelectTrigger>
                            <SelectContent>
                                {for t in TEAMS {
                                    <SelectItem key={t} value={t}>{t}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    {if fTeam == "Jac Scale" {
                        <div className="grid gap-2">
                            <Label>Section</Label>
                            <Select value={fSection} onValueChange={lambda (v: str) { fSection = v; }}>
                                <SelectTrigger>
                                    <SelectValue placeholder="Pick a section" />
                                </SelectTrigger>
                                <SelectContent>
                                    {for s in SECTIONS {
                                        <SelectItem key={s} value={s}>{s}</SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </div>
                    }}
                    <div className="grid gap-2">
                        <Label>Role</Label>
                        <Input
                            value={fRole}
                            onChange={lambda (e: ChangeEvent) { fRole = e.target.value; }}
                        />
                    </div>
                    <div className="grid gap-2">
                        <Label>Email</Label>
                        <Input
                            type="email"
                            value={fEmail}
                            onChange={lambda (e: ChangeEvent) { fEmail = e.target.value; }}
                        />
                    </div>
                    <div className="grid gap-2">
                        <Label>GitHub username</Label>
                        <Input
                            value={fGithub}
                            onChange={lambda (e: ChangeEvent) { fGithub = e.target.value; }}
                        />
                    </div>
                </div>
                <DialogFooter>
                    <Button variant="outline" onClick={lambda { dialogOpen = False; }}>
                        Cancel
                    </Button>
                    <Button
                        onClick={saveMember}
                        disabled={saving or not fName.strip() or not fTeam}
                    >
                        Save
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    </div>
}
