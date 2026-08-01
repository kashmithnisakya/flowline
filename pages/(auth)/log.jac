"""standup - Daily Log page.

The standup ritual: one row per person per weekday. The PM logs on behalf
of roster members (members have no accounts in v2). The week's entries are
fetched once (Mon-Sun) and the day view filters locally.
"""

import from ...models { Project, MemberView, Repo, LogEntry }
import from ...walkers.roster { ListMembers, ListRepos }
import from ...walkers.projects { ListProjects }
import from ...walkers.log {
    ListLogEntries, LogActivity, UpdateLogEntry, DeleteLogEntry
}
import from ...components.log.WeekStrip { WeekStrip }
import from ...components.log.LogForm { LogForm }
import from ...components.log.LogTable { LogTable }
import from ...components.ui.button { Button }
import from ...components.ui.input { Input }
import from ...components.ui.skeleton { Skeleton }
import from "sonner" { toast }

glob BLANK_LOG: dict[str, str] = {
    "member": "", "project": "none", "category": "Coding",
    "status": "In Progress", "repo": "none", "activity": "",
    "issue": "", "pr": "", "notes": ""
};

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
        members: list[MemberView] = [],
        projects: list[Project] = [],
        repos: list[Repo] = [],
        selectedDate: str = "",
        viewMode: str = "day",
        loading: bool = True,
        weekReqRef: Ref[any] = Ref(),
        form: dict[str, str] = BLANK_LOG,
        editingEntryId: str = "",
        editingMemberName: str = "",
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
    def setField(key: str, value: str) -> None;
    def startEdit(en: LogEntry) -> None;
    def cancelEdit -> None;

    activeMembers = [m for m in members if m.active];
    activeProjects = [p for p in projects if p.active];
    shown = entries if viewMode == "week" else [e for e in entries if e.date == selectedDate];
    canSubmit = (
        not saving and bool(form["activity"].strip()) and bool(selectedDate)
        and (bool(editingEntryId) or bool(form["member"]))
    );

    <div className="space-y-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
                <h1 className="font-display text-2xl font-bold tracking-tight">Daily Log</h1>
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

        <LogForm
            form={form}
            members={activeMembers}
            projects={activeProjects}
            repos={repos}
            editing={bool(editingEntryId)}
            editingMemberName={editingMemberName}
            canSubmit={canSubmit}
            onField={setField}
            onSubmit={submitLog}
            onCancel={cancelEdit}
        />

        {if loading {
            <Skeleton key="sk" className="h-40 w-full" />
        } else {
            <LogTable key="table"
                entries={shown}
                emptyLabel={
                    "Nothing logged this week yet." if viewMode == "week"
                    else "Nothing logged for this day yet."
                }
                onEdit={startEdit}
                onDelete={deleteEntry}
            />
        }}
    </div>
}
