"""flowline - Daily Log page: one row per person per weekday. The PM logs on
behalf of roster members (members have no accounts). The week's entries are
fetched once (Mon-Sun) and the day view filters locally.
"""

import from ...models { LogEntry, MemberView }
import from ...walkers.log { ListLogEntries, DeleteLogEntries }
import from ...walkers.roster { ListMembers }
import from ...components.log.WeekStrip { WeekStrip }
import from ...components.log.LogTable { LogTable }
import from ...components.log.DatePicker { DatePicker }
import from ...components.log.Digest { Digest }
import from ...components.log.WeekMatrix { WeekMatrix }
import from ...components.ui.button { Button }
import from ...components.ui.card { Card, CardContent }
import from ...components.ui.skeleton { Skeleton }
import from ...components.common.LoadFailed { LoadFailed, StaleDataStrip }
import from ...components.common.glyphs { Spinner }
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

def:pub DailyLogPage -> JsxPage {
    has entries: list[LogEntry] = [],
        # Roster names give the week matrix a row per person, quiet or not.
        memberNames: list[str] = [],
        selecting: bool = False,
        selectedIds: list[str] = [],
        selectedDate: str = "",
        viewMode: str = "day",
        loading: bool = True,
        # The last week fetch failed: a full panel when nothing is showing,
        # a strip over the table when a hop or refresh failed.
        loadFailed: bool = False,
        retrying: bool = False,
        loadedMonday: str = "",
        # The week arrives in pages of 500, newest day first: the first page
        # paints, the rest stream in behind it. `weekTotal` is the whole
        # week, `weekLoaded` how much of it is on screen.
        weekTotal: int = 0,
        weekLoaded: int = 0,
        # The week is still streaming (a page is in flight). Separate from
        # weekLoaded < weekTotal, which also holds when the fetch stopped
        # early: then the strip says so instead of spinning forever.
        weekStreaming: bool = False,
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
    async def retryLoad -> None;
    async def deleteSelected -> None;
    def toggleSelect(entryId: str) -> None;

    shown = entries
        if viewMode == "week"
        else [
            e
            for e in entries
            if e.date == selectedDate
        ];
    weekMonday = mondayOf(selectedDate) if selectedDate else "";
    weekDays = [shiftDay(weekMonday, i) for i in range(7)] if weekMonday else [];

    return
        <div className="space-y-6">
            <div className="flex flex-wrap items-center justify-between gap-3">
                <div>
                    <h1 className="page-title">Log</h1>
                    <p className="page-subtitle">
                        Written automatically as tasks move on the board.
                    </p>
                </div>
                <div className="flex flex-wrap items-center gap-2">
                    <Button
                        variant="outline"
                        size="icon"
                        aria-label="Previous day"
                        onClick={lambda { if selectedDate {
                            selectedDate = shiftDay(selectedDate, -1);
                        }}}
                    >
                        <svg
                            width={16}
                            height={16}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        >
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
                        onClick={lambda { if selectedDate {
                            selectedDate = shiftDay(selectedDate, 1);
                        }}}
                    >
                        <svg
                            width={16}
                            height={16}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        >
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
                    <div
                        className="inline-flex items-center gap-0.5 rounded-lg border border-border/70 bg-muted p-0.5"
                    >
                        <button
                            type="button"
                            className={"rounded-md bg-background px-2.5 py-1 text-sm font-medium text-foreground shadow-sm"
                                if viewMode == "day"
                                else "rounded-md px-2.5 py-1 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"}
                            onClick={lambda { viewMode = "day"; }}
                        >
                            Day
                        </button>
                        <button
                            type="button"
                            className={"rounded-md bg-background px-2.5 py-1 text-sm font-medium text-foreground shadow-sm"
                                if viewMode == "week"
                                else "rounded-md px-2.5 py-1 text-sm font-medium text-muted-foreground transition-colors hover:text-foreground"}
                            onClick={lambda { viewMode = "week"; }}
                        >
                            Week
                        </button>
                    </div>
                    {if selecting {
                        <Button
                            key="cancel"
                            variant="outline"
                            size="sm"
                            onClick={lambda {
                                selecting = False;
                                selectedIds = [];
                            }}
                        >
                            Cancel
                        </Button>
                    }}
                    {if selecting {
                        <Button
                            key="del"
                            variant="destructive"
                            size="sm"
                            className="tabular-nums"
                            disabled={len(selectedIds) == 0}
                            onClick={deleteSelected}
                        >
                            Delete ({len(selectedIds)})
                        </Button>
                    } else {
                        <Button
                            key="sel"
                            variant="outline"
                            size="sm"
                            onClick={lambda { selecting = True; }}
                        >
                            Select
                        </Button>
                    } }
                </div>
            </div>
            {if loading {
                <div key="wsk" className="flex flex-wrap items-center gap-1.5">
                    {for i in range(7) {
                        <Skeleton
                            key={"p" + str(i)}
                            className="h-[50px] w-16 rounded-lg"
                        />
                    }}
                </div>
            } else {
                <WeekStrip
                    key="ws"
                    entries={entries}
                    selectedDate={selectedDate}
                    onSelectDate={lambda (d: str) {
                        selectedDate = d;
                        viewMode = "day";
                    }}
                />
            } }
            {if loadFailed and not loading and len(entries) > 0 {
                <StaleDataStrip key="stale" onRetry={retryLoad} retrying={retrying}/>
            }}
            {if not loading and weekStreaming {
                <div
                    key="partial"
                    className="flex items-center gap-2 rounded-lg border border-dashed px-3 py-2 text-xs tabular-nums text-muted-foreground"
                    role="status"
                >
                    <Spinner/>
                    {"Loading the rest of the week (" + str(weekLoaded) + " of " + str(
                        weekTotal
                    ) + " entries)"}
                </div>
            }}
            {if not loading and not weekStreaming and weekLoaded < weekTotal {
                <div
                    key="partialstop"
                    className="flex items-center justify-between gap-2 rounded-lg border border-warning/50 bg-warning/10 px-3 py-2 text-xs tabular-nums text-warning"
                    role="status"
                >
                    {"Showing " + str(weekLoaded) + " of " + str(weekTotal) + " entries for this week."}
                    <button
                        type="button"
                        className="font-medium underline-offset-2 hover:underline"
                        onClick={retryLoad}
                    >
                        Load again
                    </button>
                </div>
            }}
            {if loading {
                <Card key="sk">
                    <CardContent className="pt-4">
                        <div className="flex items-center gap-4 border-b pb-3">
                            <Skeleton className="h-3 w-20"/>
                            <Skeleton className="h-3 w-32"/>
                            <Skeleton className="h-3 w-16"/>
                            <Skeleton className="h-3 w-24"/>
                            <Skeleton className="h-3 w-20"/>
                            <Skeleton className="h-3 w-10"/>
                            <Skeleton className="h-3 w-10"/>
                            <Skeleton className="h-3 w-16"/>
                            <Skeleton className="h-3 flex-1"/>
                        </div>
                        {for i in range(6) {
                            <div
                                key={"r" + str(i)}
                                className="flex items-center gap-4 border-b py-3 last:border-0"
                            >
                                <Skeleton className="h-4 w-20"/>
                                <Skeleton className="h-4 w-40"/>
                                <Skeleton className="h-4 w-16"/>
                                <Skeleton className="h-4 w-24"/>
                                <Skeleton className="h-4 w-20"/>
                                <Skeleton className="h-4 w-10"/>
                                <Skeleton className="h-4 w-10"/>
                                <Skeleton className="h-4 w-16 rounded-full"/>
                                <Skeleton className="h-4 flex-1"/>
                            </div>
                        }}
                    </CardContent>
                </Card>
            } elif loadFailed and len(entries) == 0 {
                <LoadFailed
                    key="failed"
                    title="Could not load the log"
                    onRetry={retryLoad}
                    retrying={retrying}
                />
            } elif viewMode == "week" and not selecting and len(entries) > 0 {
                <div
                    key="matrix"
                    className="animate-in fade-in slide-in-from-bottom-1 duration-300"
                >
                    <WeekMatrix
                        entries={entries}
                        weekDays={weekDays}
                        memberNames={memberNames}
                        selectedDate={selectedDate}
                        onSelectDate={lambda (d: str) {
                            selectedDate = d;
                            viewMode = "day";
                        }}
                    />
                </div>
            } else {
                <div
                    key="table"
                    className="animate-in fade-in slide-in-from-bottom-1 duration-300 space-y-4"
                >
                    {if viewMode == "day" and not selecting {
                        <Digest key="digest" entries={entries} day={selectedDate}/>
                    }}
                    <LogTable
                        entries={shown}
                        emptyLabel={"Nothing logged this week yet."
                            if viewMode == "week"
                            else "Nothing logged for this day yet."}
                        selecting={selecting}
                        selected={selectedIds}
                        onToggleSelect={toggleSelect}
                        showDate={viewMode == "week"}
                    />
                </div>
            }   }
        </div>;
}
