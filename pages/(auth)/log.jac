"""standup - Daily Log page: one row per person per weekday. The PM logs on
behalf of roster members (members have no accounts). The week's entries are
fetched once (Mon-Sun) and the day view filters locally.
"""

import from ...models { LogEntry }
import from ...walkers.log { ListLogEntries, DeleteLogEntries }
import from ...components.log.WeekStrip { WeekStrip }
import from ...components.log.LogTable { LogTable }
import from ...components.log.DatePicker { DatePicker }
import from ...components.ui.button { Button }
import from ...components.ui.card { Card, CardContent }
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
        loadedMonday: str = "",
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
                <h1 className="page-title">Log</h1>
                <p className="page-subtitle">Written automatically as tasks move on the board.</p>
            </div>
            <div className="flex flex-wrap items-center gap-2">
                <Button
                    variant="outline"
                    size="icon"
                    aria-label="Previous day"
                    onClick={lambda { if selectedDate { selectedDate = shiftDay(selectedDate, -1); } }}
                >
                    <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                        <path d="m15 18-6-6 6-6"/>
                    </svg>
                </Button>
                <DatePicker
                    value={selectedDate}
                    onChange={lambda (d: str) { selectedDate = d; }}
                />
                <Button
                    variant="outline"
                    size="icon"
                    aria-label="Next day"
                    onClick={lambda { if selectedDate { selectedDate = shiftDay(selectedDate, 1); } }}
                >
                    <svg width={16} height={16} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
                        <path d="m9 18 6-6-6-6"/>
                    </svg>
                </Button>
                <Button
                    variant="outline"
                    size="sm"
                    disabled={selectedDate == todayIso()}
                    onClick={lambda { selectedDate = todayIso(); }}
                >
                    Today
                </Button>
                <div className="inline-flex items-center gap-0.5 rounded-lg border border-border/70 bg-muted p-0.5">
                    <button
                        type="button"
                        className={
                            "rounded-md bg-background px-2.5 py-1 text-sm font-medium text-foreground shadow-sm"
                            if viewMode == "day"
                            else "rounded-md px-2.5 py-1 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
                        }
                        onClick={lambda { viewMode = "day"; }}
                    >
                        Day
                    </button>
                    <button
                        type="button"
                        className={
                            "rounded-md bg-background px-2.5 py-1 text-sm font-medium text-foreground shadow-sm"
                            if viewMode == "week"
                            else "rounded-md px-2.5 py-1 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"
                        }
                        onClick={lambda { viewMode = "week"; }}
                    >
                        Week
                    </button>
                </div>
                {if selecting {
                    <Button key="cancel" variant="outline" size="sm"
                        onClick={lambda { selecting = False; selectedIds = []; }}
                    >
                        Cancel
                    </Button>
                }}
                {if selecting {
                    <Button key="del" variant="destructive" size="sm"
                        className="tabular-nums"
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
        </div>

        {if loading {
            <div key="wsk" className="flex flex-wrap items-center gap-1.5">
                {for i in range(7) {
                    <Skeleton key={"p" + str(i)} className="h-[50px] w-16 rounded-lg" />
                }}
            </div>
        } else {
            <WeekStrip key="ws"
                entries={entries}
                selectedDate={selectedDate}
                onSelectDate={lambda (d: str) { selectedDate = d; viewMode = "day"; }}
            />
        }}

        {if loading {
            <Card key="sk">
                <CardContent className="pt-4">
                    <div className="flex items-center gap-4 border-b pb-3">
                        <Skeleton className="h-3 w-20" />
                        <Skeleton className="h-3 w-32" />
                        <Skeleton className="h-3 w-16" />
                        <Skeleton className="h-3 w-24" />
                        <Skeleton className="h-3 w-20" />
                        <Skeleton className="h-3 w-10" />
                        <Skeleton className="h-3 w-10" />
                        <Skeleton className="h-3 w-16" />
                        <Skeleton className="h-3 flex-1" />
                    </div>
                    {for i in range(6) {
                        <div key={"r" + str(i)} className="flex items-center gap-4 border-b py-3 last:border-0">
                            <Skeleton className="h-4 w-20" />
                            <Skeleton className="h-4 w-40" />
                            <Skeleton className="h-4 w-16" />
                            <Skeleton className="h-4 w-24" />
                            <Skeleton className="h-4 w-20" />
                            <Skeleton className="h-4 w-10" />
                            <Skeleton className="h-4 w-10" />
                            <Skeleton className="h-4 w-16 rounded-full" />
                            <Skeleton className="h-4 flex-1" />
                        </div>
                    }}
                </CardContent>
            </Card>
        } else {
            <div key="table" className="animate-in fade-in slide-in-from-bottom-1 duration-300">
                <LogTable
                    entries={shown}
                    emptyLabel={
                        "Nothing logged this week yet." if viewMode == "week"
                        else "Nothing logged for this day yet."
                    }
                    selecting={selecting}
                    selected={selectedIds}
                    onToggleSelect={toggleSelect}
                />
            </div>
        }}
    </div>;
}
