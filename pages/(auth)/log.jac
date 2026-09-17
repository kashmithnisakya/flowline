"""flowline - Daily Log page: a rail of the week's days beside the selected day
written as a standup, its timeline and a one-line composer; Week view swaps
the day for a people by weekday grid. The PM logs on behalf of roster members
(members have no accounts). One fetch covers the week plus the Friday to
Sunday before it, so a Monday standup can read back to Friday.
"""

import from "@jac/runtime" { useState, Link }
import from "react" { useEffect, useRef }
import from ...models { LogEntry, MemberView, Project, TaskView }
import from ...services.log.log {
    ListLogEntries,
    DeleteLogEntries,
    LogActivity,
    UpdateLogEntry
}
import from ...services.roster.roster { ListMembers }
import from ...services.projects.projects { ListProjects }
import from ...services.tasks.tasks { ListTasks }
import from ...components.log.DayRail { DayRail }
import from ...components.log.DayLog { Standup, LogTimeline }
import from ...components.log.Composer { Composer }
import from ...components.log.EntryDialog { EntryDialog }
import from ...components.log.DatePicker { DatePicker }
import from ...components.log.WeekMatrix { WeekMatrix }
import from ...components.ui.button { Button }
import from ...components.ui.skeleton { Skeleton }
import from ...components.ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuItem
}
import from ...components.common.LoadFailed { LoadFailed, StaleDataStrip }
import from ...components.common.glyphs { Spinner }
import from "sonner" { toast }

glob DAY_LONG: list[str] = [
         "Sunday",
         "Monday",
         "Tuesday",
         "Wednesday",
         "Thursday",
         "Friday",
         "Saturday"
     ],
     MONTH_LONG: list[str] = [
         "January",
         "February",
         "March",
         "April",
         "May",
         "June",
         "July",
         "August",
         "September",
         "October",
         "November",
         "December"
     ];

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

def weekdayOf(iso: str) -> int {
    return int(new(Date, iso + "T00:00:00").getDay());
}

def mondayOf(iso: str) -> str {
    return shiftDay(iso, -((weekdayOf(iso) + 6) % 7));
}

# The day the standup reads back to: Friday for a Monday or a weekend day.
def prevWorkday(iso: str) -> str {
    dow = weekdayOf(iso);
    return shiftDay(iso, -3 if dow == 1 else (-2 if dow == 0 else -1));
}

def sinceLabel(iso: str) -> str {
    dow = weekdayOf(iso);
    if dow == 1 {
        return "Since Friday, weekend included";
    }
    return "Since " + DAY_LONG[weekdayOf(prevWorkday(iso))];
}

# "2026-09-15" -> "Tuesday 15 September"
def longDate(iso: str) -> str {
    return DAY_LONG[weekdayOf(iso)]
        + " "
        + str(int(iso[8:10]))
        + " "
        + MONTH_LONG[int(iso[5:7]) - 1];
}

# Monday's ISO -> "14 to 20 September" ("28 September to 4 October").
def weekTitle(monday: str) -> str {
    sunday = shiftDay(monday, 6);
    ma = MONTH_LONG[int(monday[5:7]) - 1];
    mb = MONTH_LONG[int(sunday[5:7]) - 1];
    a = str(int(monday[8:10]));
    b = str(int(sunday[8:10]));
    if ma == mb {
        return a + " to " + b + " " + mb;
    }
    return a + " " + ma + " to " + b + " " + mb;
}

def countLabel(n: int) -> str {
    return str(n) + (" entry" if n == 1 else " entries");
}

# The composer, or the roster hint that stands in for it when nobody is listed.
def focusComposer {
    box: any = document.getElementById("log-composer")
        or document.getElementById("log-add-people");
    if box {
        box.focus();
        box.scrollIntoView({"block": "center"});
    }
}

def:pub DailyLogPage -> JsxPage {
    has entries: list[LogEntry] = [],
        # Roster names give the week matrix a row per person, quiet or not;
        # the full views feed the entry dialog and the composer.
        memberNames: list[str] = [],
        members: list[MemberView] = [],
        projects: list[Project] = [],
        entryOpen: bool = False,
        entryEditing: bool = False,
        entryId: str = "",
        # Every key the dialog reads exists from the start; a missing key
        # would be undefined and .strip() on it throws at render time.
        entryForm: dict[str, str] = {
            "date": "",
            "member": "",
            "member_name": "",
            "activity": "",
            "project": "none",
            "category": "",
            "status": "none",
            "issue_link": "",
            "pr_link": "",
            "notes": "",
            "repo": ""
        },
        entrySaving: bool = False,
        quickSaving: bool = False,
        selecting: bool = False,
        selectedIds: list[str] = [],
        selectedDate: str = "",
        viewMode: str = "day",
        loading: bool = True,
        # The last week fetch failed: a full panel when nothing is showing,
        # a strip over the day when a hop or refresh failed.
        loadFailed: bool = False,
        retrying: bool = False,
        loadedMonday: str = "",
        # First day the fetch covers (the Friday before the week).
        loadedFrom: str = "",
        # The fetch arrives in pages of 500, newest day first: the first page
        # paints, the rest stream in behind it. `weekTotal` is the whole
        # range, `weekLoaded` how much of it is on screen.
        weekTotal: int = 0,
        weekLoaded: int = 0,
        # A page is in flight. Separate from weekLoaded < weekTotal, which
        # also holds when the fetch stopped early.
        weekStreaming: bool = False,
        weekReqRef: Ref[any] = Ref(),
        # Tasks blocked right now, so today's Stuck is not limited to what
        # the loaded log shows; `blockedLive` is False until that call lands.
        blockedTasks: list[TaskView] = [],
        blockedLive: bool = False,
        rosterReady: bool = False;

    async can with entry {
        selectedDate = todayIso();
    }

    async can with [selectedDate] entry {
        if selectedDate {
            loadWeek();
        }
    }

    async def loadWeek -> None;
    async def loadBlocked -> None;
    async def retryLoad -> None;
    async def deleteSelected -> None;
    def toggleSelect(rowId: str) -> None;
    def openNewEntry -> None;
    def openEditEntry(en: LogEntry) -> None;
    def entryField(key: str, value: str) -> None;
    async def saveEntry -> None;
    async def createEntry(fields: dict[str, str]) -> bool;
    async def quickLog(fields: dict[str, str]) -> bool;
    def logNote -> None;
    def step(direction: int) -> None;

    today = todayIso();
    weekMonday = mondayOf(selectedDate) if selectedDate else "";
    weekDays = [shiftDay(weekMonday, i) for i in range(7)] if weekMonday else [];
    weekSunday = weekDays[6] if len(weekDays) == 7 else "";
    weekEntries = [
        e
        for e in entries
        if e.date >= weekMonday and e.date <= weekSunday
    ];
    dayEntries = [
        e
        for e in entries
        if e.date == selectedDate
    ];
    counts = [
        len(
            [
                e
                for e in weekEntries
                if e.date == d
            ]
        ) for d in weekDays
    ];
    since = prevWorkday(selectedDate) if selectedDate else "";
    windowCount = len(
        [
            e
            for e in entries
            if e.date >= since and e.date <= selectedDate
        ]
    );
    isWeek = viewMode == "week";
    onToday = (weekMonday == mondayOf(today)) if isWeek else (selectedDate == today);
    showStandup = windowCount > 0
        or (selectedDate == today and blockedLive and len(blockedTasks) > 0);
    dayName = DAY_LONG[weekdayOf(selectedDate)] if selectedDate else "";
    emptyLine = (
        "Nothing logged this week; board moves land here on their own."
            if isWeek
            else "Nothing logged on "
                + dayName
                + (" yet" if selectedDate >= today else "")
                + "; board moves land here on their own."
    );

    return
        <div className="@container flex min-w-0 flex-col gap-4">
            <div className="flex min-h-9 flex-wrap items-center gap-3">
                <h1 className="page-title">Log</h1>
                {if selecting {
                    <div key="picking" className="ml-auto flex items-center gap-2">
                        <span
                            className="text-[13px] text-muted-foreground tabular-nums"
                        >
                            {str(len(selectedIds)) + " selected"}
                        </span>
                        <Button
                            variant="outline"
                            size="sm"
                            onClick={lambda {
                                selecting = False;
                                selectedIds = [];
                            }}
                        >
                            Cancel
                        </Button>
                        <Button
                            variant="destructive"
                            size="sm"
                            className="tabular-nums"
                            disabled={len(selectedIds) == 0}
                            onClick={deleteSelected}
                        >
                            {"Delete (" + str(len(selectedIds)) + ")"}
                        </Button>
                    </div>
                } else {
                    <div key="views" className="ml-auto flex items-center gap-2">
                        <div
                            className="inline-flex gap-0.5 rounded-md border bg-card p-0.5"
                            role="group"
                            aria-label="View"
                        >
                            <button
                                type="button"
                                aria-pressed={"true" if not isWeek else "false"}
                                className={"rounded-sm px-2.5 py-1 text-[13px] transition-colors "
                                    + (
                                        "bg-muted font-semibold text-foreground"
                                            if not isWeek
                                            else "text-muted-foreground hover:text-foreground"
                                    )}
                                onClick={lambda { viewMode = "day"; }}
                            >
                                Day
                            </button>
                            <button
                                type="button"
                                aria-pressed={"true" if isWeek else "false"}
                                className={"rounded-sm px-2.5 py-1 text-[13px] transition-colors "
                                    + (
                                        "bg-muted font-semibold text-foreground"
                                            if isWeek
                                            else "text-muted-foreground hover:text-foreground"
                                    )}
                                onClick={lambda { viewMode = "week"; }}
                            >
                                Week
                            </button>
                        </div>
                        <DropdownMenu>
                            <DropdownMenuTrigger asChild={True}>
                                <Button
                                    variant="ghost"
                                    size="icon-sm"
                                    aria-label="More log actions"
                                    title="More log actions"
                                >
                                    <svg
                                        width={16}
                                        height={16}
                                        viewBox="0 0 16 16"
                                        fill="currentColor"
                                        aria-hidden="true"
                                    >
                                        <circle cx={3.5} cy={8} r={1.3}/>
                                        <circle cx={8} cy={8} r={1.3}/>
                                        <circle cx={12.5} cy={8} r={1.3}/>
                                    </svg>
                                </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end" className="w-56">
                                <DropdownMenuItem onSelect={lambda { openNewEntry(); }}>
                                    Add an entry with details
                                </DropdownMenuItem>
                                <DropdownMenuItem
                                    onSelect={lambda { selecting = True; }}
                                >
                                    Select entries to delete
                                </DropdownMenuItem>
                            </DropdownMenuContent>
                        </DropdownMenu>
                    </div>
                } }
            </div>
            {if loadFailed and not loading and len(entries) > 0 {
                <StaleDataStrip key="stale" onRetry={retryLoad} retrying={retrying}/>
            }}
            {if not loading and weekStreaming {
                <div
                    key="partial"
                    className="num flex items-center gap-2 text-xs text-muted-foreground"
                    role="status"
                >
                    <Spinner/>
                    {"Loading the rest of the log ("
                        + str(weekLoaded)
                        + " of "
                        + str(weekTotal)
                        + " entries)"}
                </div>
            }}
            {if not loading and not weekStreaming and weekLoaded < weekTotal {
                <div
                    key="partialstop"
                    className="num flex items-center justify-between gap-2 rounded-md border border-warning/50 bg-card px-3 py-2 text-xs text-warning"
                    role="status"
                >
                    {"Showing "
                        + str(weekLoaded)
                        + " of "
                        + str(weekTotal)
                        + " entries."}
                    <button
                        type="button"
                        className="font-semibold underline-offset-2 hover:underline"
                        onClick={retryLoad}
                    >
                        Load again
                    </button>
                </div>
            }}
            <div
                className="grid min-w-0 gap-4 lg:grid-cols-[168px_minmax(0,1fr)] lg:gap-6"
            >
                <DayRail
                    weekDays={weekDays}
                    counts={counts}
                    selectedDate={selectedDate}
                    today={today}
                    viewMode={viewMode}
                    onSelectDate={lambda (d: str) {
                        selectedDate = d;
                        viewMode = "day";
                    }}
                />
                <div className="flex min-w-0 flex-col gap-[18px]">
                    <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                        <h2 className="font-display text-[22px] leading-7 font-bold">
                            {weekTitle(weekMonday)
                                if isWeek and weekMonday
                                else (longDate(selectedDate) if selectedDate else "")}
                        </h2>
                        <span className="text-[13px] text-muted-foreground">
                            {(countLabel(len(weekEntries)) if not loading else "")
                                if isWeek
                                else (sinceLabel(selectedDate) if showStandup else "")}
                        </span>
                        <div className="ml-auto flex items-center gap-1 self-center">
                            {if not onToday {
                                <Button
                                    key="today"
                                    variant="outline"
                                    size="sm"
                                    className="mr-1"
                                    onClick={lambda { selectedDate = today; }}
                                >
                                    Today
                                </Button>
                            }}
                            <Button
                                variant="ghost"
                                size="icon-sm"
                                aria-label={"Previous week"
                                    if isWeek
                                    else "Previous day"}
                                title={"Previous week" if isWeek else "Previous day"}
                                onClick={lambda { step(-1); }}
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
                                    aria-hidden="true"
                                >
                                    <path d="m15 18-6-6 6-6"/>
                                </svg>
                            </Button>
                            <Button
                                variant="ghost"
                                size="icon-sm"
                                aria-label={"Next week" if isWeek else "Next day"}
                                title={"Next week" if isWeek else "Next day"}
                                onClick={lambda { step(1); }}
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
                                    aria-hidden="true"
                                >
                                    <path d="m9 18 6-6-6-6"/>
                                </svg>
                            </Button>
                            <DatePicker
                                value={selectedDate}
                                onChange={lambda (d: str) { if d { selectedDate = d; }}}
                                iconOnly={True}
                                label="Jump to a date"
                                className="size-7 border-transparent bg-transparent"
                            />
                        </div>
                    </div>
                    {if loading {
                        <div
                            key="sk"
                            className="grid max-w-[68ch] gap-3"
                            aria-hidden="true"
                        >
                            <Skeleton className="h-4 w-28"/>
                            <Skeleton className="h-4 w-4/5"/>
                            <Skeleton className="h-4 w-3/5"/>
                            <Skeleton className="mt-2 h-4 w-32"/>
                            <Skeleton className="h-4 w-2/3"/>
                            <Skeleton className="h-4 w-1/2"/>
                            <Skeleton className="mt-4 h-24 w-full"/>
                        </div>
                    } elif loadFailed and len(entries) == 0 {
                        <LoadFailed
                            key="failed"
                            title="Could not load the log"
                            onRetry={retryLoad}
                            retrying={retrying}
                        />
                    } elif selecting {
                        <div key="picklist" className="flex min-w-0 flex-col gap-2">
                            <p className="text-[13px] text-muted-foreground">
                                {"Pick the entries to delete from "
                                    + ("this week." if isWeek else "this day.")}
                            </p>
                            <LogTimeline
                                entries={weekEntries if isWeek else dayEntries}
                                roster={memberNames}
                                showDate={isWeek}
                                selecting={True}
                                selected={selectedIds}
                                onToggleSelect={toggleSelect}
                            />
                        </div>
                    } elif isWeek and len(weekEntries) > 0 {
                        <WeekMatrix
                            key="matrix"
                            entries={weekEntries}
                            weekDays={weekDays}
                            memberNames={memberNames}
                            selectedDate={selectedDate}
                            today={today}
                            onSelectDate={lambda (d: str) {
                                selectedDate = d;
                                viewMode = "day";
                            }}
                        />
                    } else {
                        <div
                            key="day"
                            className="grid min-w-0 gap-[18px] @min-[90rem]:grid-cols-[minmax(0,68ch)_minmax(0,1fr)] @min-[90rem]:items-start @min-[90rem]:gap-x-8"
                        >
                            {if showStandup and not isWeek {
                                <Standup
                                    key={"standup" + selectedDate}
                                    entries={entries}
                                    day={selectedDate}
                                    since={since}
                                    loadedFrom={loadedFrom}
                                    today={today}
                                    blocked={blockedTasks}
                                    liveBlocked={blockedLive}
                                    roster={memberNames}
                                    windowLabel={sinceLabel(selectedDate)}
                                />
                            }}
                            {if len(dayEntries) > 0 and not isWeek {
                                <section key="timeline" aria-label="Timeline">
                                    <h3 className="mb-2 text-[13.5px] font-semibold">
                                        Timeline
                                    </h3>
                                    <LogTimeline
                                        entries={dayEntries}
                                        roster={memberNames}
                                        onEdit={openEditEntry}
                                    />
                                </section>
                            } else {
                                <div
                                    key="empty"
                                    className="flex flex-col items-start gap-3 border-y py-5"
                                >
                                    <p className="text-sm text-foreground">
                                        {emptyLine}
                                    </p>
                                    <div className="flex flex-wrap items-center gap-2">
                                        <Button
                                            variant="outline"
                                            size="sm"
                                            onClick={logNote}
                                        >
                                            Log a note
                                        </Button>
                                        <Button
                                            asChild={True}
                                            variant="ghost"
                                            size="sm"
                                        >
                                            <Link to="/board">Open the board</Link>
                                        </Button>
                                    </div>
                                </div>
                            } }
                            {if not isWeek {
                                <div key="composer" className="@min-[90rem]:col-span-2">
                                    <Composer
                                        members={members}
                                        projects={projects}
                                        saving={quickSaving}
                                        onLog={quickLog}
                                        rosterReady={rosterReady}
                                    />
                                </div>
                            }}
                        </div>
                    }    }
                </div>
            </div>
            <EntryDialog
                open={entryOpen}
                editing={entryEditing}
                form={entryForm}
                members={members}
                projects={projects}
                saving={entrySaving}
                onField={entryField}
                onOpenChange={lambda (o: bool) { entryOpen = o; }}
                onSave={saveEntry}
            />
        </div>;
}
