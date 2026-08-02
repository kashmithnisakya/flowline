"""standup - Daily Log page.

The standup ritual: one row per person per weekday. The PM logs on behalf
of roster members (members have no accounts in v2). The week's entries are
fetched once (Mon-Sun) and the day view filters locally.
"""

import from ...models { LogEntry }
import from ...walkers.log { ListLogEntries, DeleteLogEntries }
import from ...components.log.WeekStrip { WeekStrip }
import from ...components.log.LogTable { LogTable }
import from ...components.log.DatePicker { DatePicker }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
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
        selecting: bool = False,
        selectedIds: list[str] = [],
        selectedDate: str = "",
        viewMode: str = "day",
        loading: bool = True,
        weekReqRef: Ref[any] = Ref();

    async can with entry {
        selectedDate = todayIso();
    }

    async can with [selectedDate] entry {
        if selectedDate {
            loadWeek();
        }
    }

    async def loadWeek -> None;
    async def deleteSelected -> None;
    def toggleSelect(entryId: str) -> None;

    shown = entries if viewMode == "week" else [e for e in entries if e.date == selectedDate];

    return <div className="space-y-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
                <h1 className="font-display text-2xl font-bold tracking-tight">Log</h1>
                <p className="text-sm text-muted-foreground">Written automatically as tasks move on the board.</p>
            </div>
            <div className="flex items-center gap-2">
                <Button
                    variant="outline"
                    size="sm"
                    onClick={lambda { if selectedDate { selectedDate = shiftDay(selectedDate, -1); } }}
                >
                    ←
                </Button>
                <DatePicker
                    value={selectedDate}
                    onChange={lambda (d: str) { selectedDate = d; }}
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

        <WeekStrip
            entries={entries}
            selectedDate={selectedDate}
            onSelectDate={lambda (d: str) { selectedDate = d; viewMode = "day"; }}
        />

        <div className="flex items-center justify-end gap-2">
            {if selecting {
                <Button key="cancel" variant="outline" size="sm"
                    onClick={lambda { selecting = False; selectedIds = []; }}
                >
                    Cancel
                </Button>
            }}
            {if selecting {
                <Button key="del" variant="destructive" size="sm"
                    disabled={len(selectedIds) == 0}
                    onClick={deleteSelected}
                >
                    Delete ({len(selectedIds)})
                </Button>
            } else {
                <Button key="sel" variant="outline" size="sm"
                    onClick={lambda { selecting = True; }}
                >
                    Select
                </Button>
            }}
        </div>

        {if loading {
            <Skeleton key="sk" className="h-40 w-full" />
        } else {
            <LogTable key="table"
                entries={shown}
                emptyLabel={
                    "Nothing logged this week yet." if viewMode == "week"
                    else "Nothing logged for this day yet."
                }
                selecting={selecting}
                selected={selectedIds}
                onToggleSelect={toggleSelect}
            />
        }}
    </div>;
}
