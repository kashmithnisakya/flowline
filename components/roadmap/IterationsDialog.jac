"""Manage the workspace's iterations: rename on blur, re-date on pick, delete
with a second click, and add one that starts the day after the last ends
with the same length (two weeks for the first). Every write goes straight to
its walker; `onChanged` reloads whatever the page shows."""

import from "sonner" { toast }
import from ...models { IterationView }
import from ...services.iterations.iterations { SaveIteration, DeleteIteration }
import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.dialog {
    Dialog,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription
}
import from ..log.DatePicker { DatePicker }
import from ...lib.dates { prettyDay, todayIso }

glob DAY_MS: int = 86400000,
     # One grid for the header and every row, so the columns line up. Below sm a
     # row stacks: name and delete, then the two dates side by side.
     ROW_COLS: str = "grid grid-cols-2 gap-x-3 gap-y-2 sm:grid-cols-[minmax(0,1fr)_10rem_10rem_5.5rem] sm:items-center",
     FIELD_LABEL: str = "text-[12.5px] font-semibold sm:sr-only",
     DATE_TRIGGER: str = "h-9! w-full justify-start border-input font-mono text-[13px]! font-normal! tabular-nums";

def shiftIso(iso: str, days: int) -> str {
    return new(
        Date, new(Date, iso + "T00:00:00Z").getTime() + days * DAY_MS
    ).toISOString()[:10];
}

def spanDays(first: str, last: str) -> int {
    return int(
        (
            new(Date, last + "T00:00:00Z").getTime()
            - new(Date, first + "T00:00:00Z").getTime()
        )
            / DAY_MS
            + 0.5
    );
}

# The next name in the last one's series ("Sprint 15" gives "Sprint 16"), or
# "Iteration N" when the last name does not end in a number.
def nextName(last: str, count: int) -> str {
    parts = last.strip().split(" ");
    tail = parts[len(parts) - 1] if len(parts) > 1 else "";
    digits = len(tail) > 0;
    for c in tail {
        if c not in "0123456789" {
            digits = False;
        }
    }
    if digits {
        return " ".join(parts[:len(parts) - 1]) + " " + str(int(tail) + 1);
    }
    return "Iteration " + str(count + 1);
}

def:pub IterationsDialog(
    open: bool,
    iterations: list[IterationView],
    monday: str,
    onOpenChange: Callable[[bool], None],
    onChanged: Callable[[], None]
) -> JsxElement {
    has names: dict[str, str] = {},
        armed: str = "",
        busy: bool = False;

    today = todayIso();
    # What "Add iteration" will write, shown before it is pressed.
    count = len(iterations);
    nextFirst = monday;
    nextLength = 13;
    nextLabel = "Iteration 1";
    if count > 0 {
        last = iterations[count - 1];
        nextFirst = shiftIso(last.end_date, 1);
        nextLength = spanDays(last.start_date, last.end_date);
        nextLabel = nextName(last.name, count);
    }
    nextLast = shiftIso(nextFirst, nextLength);

    async def save(it: IterationView, name: str, first: str, last: str) {
        busy = True;
        try {
            result = root spawn SaveIteration(
                iteration_id=it.id, name=name, start_date=first, end_date=last
            );
            payload: any = result.reports[0] if result.reports else None;
            if payload and payload["ok"] {
                onChanged();
            } else {
                toast(
                    payload["message"] if payload else "Could not save the iteration"
                );
            }
        } except Exception as e {
            toast("Could not save the iteration");
        }
        busy = False;
    }

    async def addNext {
        busy = True;
        try {
            result = root spawn SaveIteration(
                name=nextLabel, start_date=nextFirst, end_date=nextLast
            );
            payload: any = result.reports[0] if result.reports else None;
            if payload and payload["ok"] {
                onChanged();
            } else {
                toast("Could not add an iteration");
            }
        } except Exception as e {
            toast("Could not add an iteration");
        }
        busy = False;
    }

    async def remove(it: IterationView) {
        if armed != it.id {
            armed = it.id;
            return;
        }
        armed = "";
        busy = True;
        try {
            result = root spawn DeleteIteration(iteration_id=it.id);
            payload: any = result.reports[0] if result.reports else None;
            if payload and payload["ok"] {
                cleared = int(payload["cleared"]);
                toast(
                    "Deleted "
                        + it.name
                        + (
                            ". " + str(cleared) + " task(s) left without an iteration."
                                if cleared > 0
                                else ""
                        )
                );
                onChanged();
            }
        } except Exception as e {
            toast("Could not delete the iteration");
        }
        busy = False;
    }

    # A name being typed; the stored name until the field is touched.
    def nameOf(it: IterationView) -> str {
        return names[it.id] if it.id in names else it.name;
    }

    def typed(it: IterationView, value: str) {
        updated = {** names};
        updated[it.id] = value;
        names = updated;
    }

    # Radix would focus and select the first name, so a stray key renames it.
    # Focus the panel instead; Tab still walks into the rows.
    def focusPanel(e: any) {
        e.preventDefault();
        panel: any = e.currentTarget;
        if panel {
            panel.focus();
        }
    }

    def commitName(it: IterationView) {
        if nameOf(it).strip() and nameOf(it).strip() != it.name {
            save(it, nameOf(it).strip(), it.start_date, it.end_date);
        }
    }

    return
        <Dialog
            open={open}
            onOpenChange={lambda (o: bool) {
                armed = "";
                onOpenChange(o);
            }}
        >
            <DialogContent
                className="gap-0 bg-card p-0 shadow-xl sm:max-w-2xl"
                onOpenAutoFocus={focusPanel}
            >
                <DialogHeader className="gap-1 border-b px-5 pt-4 pb-3 pr-12">
                    <DialogTitle className="section-title">Iterations</DialogTitle>
                    <DialogDescription>
                        Time boxes to plan tasks into. Changes save as you make them.
                    </DialogDescription>
                </DialogHeader>
                <div>
                    {if count > 0 {
                        <div
                            key="head"
                            className={"hidden border-b px-5 py-2 text-[12.5px] font-medium text-muted-foreground sm:grid "
                                + ROW_COLS}
                            aria-hidden="true"
                        >
                            <span>Name</span>
                            <span>Starts</span>
                            <span>Ends</span>
                            <span/>
                        </div>
                    } else {
                        <p
                            key="empty"
                            className="px-5 py-10 text-center text-sm text-muted-foreground"
                        >
                            No iterations yet. Add one to start planning.
                        </p>
                    } }
                    {for it in iterations {
                        <div
                            key={it.id}
                            className={"border-b px-4 py-3 last:border-b-0 sm:px-5 sm:py-2 "
                                + ROW_COLS}
                        >
                            <div
                                className="col-span-2 flex items-end gap-2 sm:contents"
                            >
                                <label className="grid min-w-0 flex-1 gap-1">
                                    <span className={FIELD_LABEL}>
                                        {"Name"
                                            + (
                                                " · current"
                                                    if it.start_date <= today
                                                        and it.end_date >= today
                                                    else ""
                                            )}
                                    </span>
                                    <Input
                                        className="h-9 w-full"
                                        aria-label="Iteration name"
                                        value={nameOf(it)}
                                        onChange={lambda (e: any) { typed(
                                            it, e.target.value
                                        ); }}
                                        onKeyDown={lambda (e: KeyboardEvent) { if e.key
                                            == "Enter" {
                                            e.currentTarget.blur();
                                        }}}
                                        onBlur={lambda { commitName(it); }}
                                    />
                                </label>
                                <Button
                                    variant={"destructive"
                                        if armed == it.id
                                        else "ghost"}
                                    size="sm"
                                    className="h-9 shrink-0 sm:order-last sm:w-full"
                                    disabled={busy}
                                    aria-label={(
                                        "Confirm deleting "
                                            if armed == it.id
                                            else "Delete "
                                    )
                                        + it.name}
                                    onClick={lambda { remove(it); }}
                                >
                                    {"Confirm" if armed == it.id else "Delete"}
                                </Button>
                            </div>
                            <div className="grid min-w-0 gap-1">
                                <span className={FIELD_LABEL}>Starts</span>
                                <DatePicker
                                    value={it.start_date}
                                    className={DATE_TRIGGER}
                                    onChange={lambda (d: str) { save(
                                        it, it.name, d, it.end_date
                                    ); }}
                                />
                            </div>
                            <div className="grid min-w-0 gap-1">
                                <span className={FIELD_LABEL}>Ends</span>
                                <DatePicker
                                    value={it.end_date}
                                    className={DATE_TRIGGER}
                                    onChange={lambda (d: str) { save(
                                        it, it.name, it.start_date, d
                                    ); }}
                                />
                            </div>
                        </div>
                    }}
                </div>
                <div
                    className="flex flex-wrap items-center justify-between gap-x-4 gap-y-2 border-t px-5 py-3"
                >
                    <p className="meta min-w-0">
                        {"Next: " + nextLabel + ", "}
                        <span className="num">
                            {prettyDay(nextFirst) + " – " + prettyDay(nextLast)}
                        </span>
                    </p>
                    <Button size="sm" disabled={busy} onClick={lambda { addNext(); }}>
                        Add iteration
                    </Button>
                </div>
            </DialogContent>
        </Dialog>;
}
