"""standup - Daily Log page.

The standup ritual, sheet-faithful: one row per person per weekday with the
exact Sheet 2 columns. The form prefills from the WhoAmI picker; the week's
entries are fetched once (Mon-Sun) and the day view filters locally.
"""

import from ..constants { STATUSES, CATEGORIES }
import from endpoints {
    Member, Repo, LogEntry,
    ListMembers, ListRepos, ListLogEntries, LogActivity, UpdateLogEntry, DeleteLogEntry
}
import from ..components.WeekStrip { WeekStrip }
import from ..components.ui.button { Button }
import from ..components.ui.card { Card, CardHeader, CardTitle, CardContent }
import from ..components.ui.table {
    Table, TableHeader, TableBody, TableRow, TableHead, TableCell
}
import from ..components.ui.input { Input }
import from ..components.ui.label { Label }
import from ..components.ui.textarea { Textarea }
import from ..components.ui.select {
    Select, SelectTrigger, SelectValue, SelectContent, SelectItem
}
import from ..components.ui.skeleton { Skeleton }
import from "sonner" { toast }

def localIso(d: any) -> str {
    shifted = new(Date, d.getTime() - d.getTimezoneOffset() * 60000);
    return shifted.toISOString()[:10];
}

def todayIso -> str {
    return localIso(new(Date));
}

def shiftDay(iso: str, delta: int) -> str {
    d = new(Date, iso + "T00:00:00");
    d.setDate(d.getDate() + delta);
    return localIso(d);
}

def mondayOf(iso: str) -> str {
    d = new(Date, iso + "T00:00:00");
    offset = (d.getDay() + 6) % 7;
    d.setDate(d.getDate() - offset);
    return localIso(d);
}

def:pub DailyLogPage() -> JsxPage {
    has entries: list[LogEntry] = [],
        members: list[Member] = [],
        repos: list[Repo] = [],
        selectedDate: str = "",
        viewMode: str = "day",
        loading: bool = True,
        weekReqRef: Ref[any] = Ref(),
        lMember: str = "",
        editingMemberName: str = "",
        lActivity: str = "",
        lCategory: str = "Coding",
        lRepo: str = "none",
        lIssue: str = "",
        lPr: str = "",
        lStatus: str = "In Progress",
        lNotes: str = "",
        editingEntryId: str = "",
        saving: bool = False;

    async can with entry {
        loadLists();
        selectedDate = todayIso();
    }

    async can with [selectedDate] entry {
        if selectedDate {
            loadWeek();
        }
    }

    async def loadLists -> None;
    async def loadWeek -> None;
    async def submitLog -> None;
    async def deleteEntry(entryId: str) -> None;
    def startEdit(en: LogEntry) -> None;
    def cancelEdit -> None;

    activeMembers = [m for m in members if m.active];
    shown = entries if viewMode == "week" else [e for e in entries if e.date == selectedDate];

    <div className="space-y-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
                <h1 className="text-2xl font-semibold tracking-tight">Daily Log</h1>
                <p className="text-sm text-muted-foreground">One row per person per weekday.</p>
            </div>
            <div className="flex items-center gap-2">
                <Button
                    variant="outline"
                    size="sm"
                    onClick={lambda { if selectedDate { selectedDate = shiftDay(selectedDate, -1); } }}
                >
                    ←
                </Button>
                <Input
                    type="date"
                    className="w-40"
                    value={selectedDate}
                    onChange={lambda (e: ChangeEvent) { selectedDate = e.target.value; }}
                />
                <Button
                    variant="outline"
                    size="sm"
                    onClick={lambda { if selectedDate { selectedDate = shiftDay(selectedDate, 1); } }}
                >
                    →
                </Button>
                <Button
                    variant={"default" if viewMode == "day" else "outline"}
                    size="sm"
                    onClick={lambda { viewMode = "day"; }}
                >
                    Day
                </Button>
                <Button
                    variant={"default" if viewMode == "week" else "outline"}
                    size="sm"
                    onClick={lambda { viewMode = "week"; }}
                >
                    Week
                </Button>
            </div>
        </div>

        <WeekStrip entries={entries} />

        <Card>
            <CardHeader>
                <CardTitle className="text-base">
                    {"Update entry" if editingEntryId else "Log activity"}
                </CardTitle>
            </CardHeader>
            <CardContent className="grid gap-4">
                <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                    <div className="grid gap-2">
                        <Label>Member</Label>
                        {if editingEntryId {
                            <Input value={editingMemberName} disabled={True} />
                        } else {
                            <Select
                                value={lMember}
                                onValueChange={lambda (v: str) { lMember = v; }}
                            >
                                <SelectTrigger>
                                    <SelectValue placeholder="Who?" />
                                </SelectTrigger>
                                <SelectContent>
                                    {for m in activeMembers {
                                        <SelectItem key={jid(m)} value={jid(m)}>{m.name}</SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        }}
                    </div>
                    <div className="grid gap-2">
                        <Label>Category</Label>
                        <Select value={lCategory} onValueChange={lambda (v: str) { lCategory = v; }}>
                            <SelectTrigger>
                                <SelectValue placeholder="Category" />
                            </SelectTrigger>
                            <SelectContent>
                                {for c in CATEGORIES {
                                    <SelectItem key={c} value={c}>{c}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="grid gap-2">
                        <Label>Status</Label>
                        <Select value={lStatus} onValueChange={lambda (v: str) { lStatus = v; }}>
                            <SelectTrigger>
                                <SelectValue placeholder="Status" />
                            </SelectTrigger>
                            <SelectContent>
                                {for s in STATUSES {
                                    <SelectItem key={s} value={s}>{s}</SelectItem>
                                }}
                            </SelectContent>
                        </Select>
                    </div>
                    <div className="grid gap-2">
                        <Label>GitHub repo</Label>
                        <Select value={lRepo} onValueChange={lambda (v: str) { lRepo = v; }}>
                            <SelectTrigger>
                                <SelectValue placeholder="Repo" />
                            </SelectTrigger>
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
                        placeholder="What did you work on?"
                        value={lActivity}
                        onChange={lambda (e: ChangeEvent) { lActivity = e.target.value; }}
                    />
                </div>
                <div className="grid grid-cols-2 gap-3">
                    <div className="grid gap-2">
                        <Label>GitHub issue link</Label>
                        <Input
                            placeholder="https://github.com/..."
                            value={lIssue}
                            onChange={lambda (e: ChangeEvent) { lIssue = e.target.value; }}
                        />
                    </div>
                    <div className="grid gap-2">
                        <Label>PR link</Label>
                        <Input
                            placeholder="https://github.com/..."
                            value={lPr}
                            onChange={lambda (e: ChangeEvent) { lPr = e.target.value; }}
                        />
                    </div>
                </div>
                <div className="grid gap-2">
                    <Label>Notes / blockers</Label>
                    <Textarea
                        value={lNotes}
                        onChange={lambda (e: ChangeEvent) { lNotes = e.target.value; }}
                    />
                </div>
                <div className="flex justify-end gap-2">
                    {if editingEntryId {
                        <Button variant="outline" onClick={cancelEdit}>Cancel</Button>
                    }}
                    <Button
                        onClick={submitLog}
                        disabled={
                            saving or not lActivity.strip() or not selectedDate
                            or (not editingEntryId and not lMember)
                        }
                    >
                        {"Update" if editingEntryId else "Log it"}
                    </Button>
                </div>
            </CardContent>
        </Card>

        {if loading {
            <Skeleton className="h-40 w-full" />
        } elif len(shown) == 0 {
            <Card>
                <CardContent className="py-10 text-center text-sm text-muted-foreground">
                    {"Nothing logged this week yet." if viewMode == "week" else "Nothing logged for this day yet."}
                </CardContent>
            </Card>
        } else {
            <Card>
                <CardContent className="pt-4">
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead>Date</TableHead>
                                <TableHead>Member</TableHead>
                                <TableHead>Team</TableHead>
                                <TableHead>Section</TableHead>
                                <TableHead>Activity</TableHead>
                                <TableHead>Category</TableHead>
                                <TableHead>Repo</TableHead>
                                <TableHead>Links</TableHead>
                                <TableHead>Status</TableHead>
                                <TableHead>Notes</TableHead>
                                <TableHead className="text-right">Actions</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {for en in shown {
                                <TableRow key={jid(en)}>
                                    <TableCell className="whitespace-nowrap text-muted-foreground">{en.date}</TableCell>
                                    <TableCell className="font-medium">{en.member_name}</TableCell>
                                    <TableCell className="text-muted-foreground">{en.team}</TableCell>
                                    <TableCell className="text-muted-foreground">{en.section}</TableCell>
                                    <TableCell>{en.activity}</TableCell>
                                    <TableCell className="text-muted-foreground">{en.category}</TableCell>
                                    <TableCell className="font-mono text-xs">{en.repo}</TableCell>
                                    <TableCell className="whitespace-nowrap text-xs">
                                        {if en.issue_link {
                                            <a
                                                href={en.issue_link}
                                                target="_blank"
                                                className="text-primary underline-offset-2 hover:underline"
                                            >
                                                Issue
                                            </a>
                                        }}
                                        {if en.issue_link and en.pr_link {
                                            <span className="text-muted-foreground"> · </span>
                                        }}
                                        {if en.pr_link {
                                            <a
                                                href={en.pr_link}
                                                target="_blank"
                                                className="text-primary underline-offset-2 hover:underline"
                                            >
                                                PR
                                            </a>
                                        }}
                                    </TableCell>
                                    <TableCell>{en.status}</TableCell>
                                    <TableCell className="max-w-48 truncate text-muted-foreground">{en.notes}</TableCell>
                                    <TableCell className="text-right whitespace-nowrap">
                                        <Button variant="ghost" size="sm" onClick={lambda { startEdit(en); }}>
                                            Edit
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            size="sm"
                                            className="text-destructive"
                                            onClick={lambda { deleteEntry(jid(en)); }}
                                        >
                                            Delete
                                        </Button>
                                    </TableCell>
                                </TableRow>
                            }}
                        </TableBody>
                    </Table>
                </CardContent>
            </Card>
        }}
    </div>
}
