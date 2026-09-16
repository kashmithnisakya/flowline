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

glob DAY_MS: int = 86400000;

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
        count = len(iterations);
        first = monday;
        length = 13;
        name = "Iteration 1";
        if count > 0 {
            last = iterations[count - 1];
            first = shiftIso(last.end_date, 1);
            length = spanDays(last.start_date, last.end_date);
            name = nextName(last.name, count);
        }
        busy = True;
        try {
            result = root spawn SaveIteration(
                name=name, start_date=first, end_date=shiftIso(first, length)
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
                            "; " + str(cleared) + " task(s) left without an iteration"
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

    return
        <Dialog open={open} onOpenChange={onOpenChange}>
            <DialogContent className="sm:max-w-2xl">
                <DialogHeader>
                    <DialogTitle>Iterations</DialogTitle>
                    <DialogDescription>
                        Time boxes to plan tasks into. Changes save as you make them.
                    </DialogDescription>
                </DialogHeader>
                <div className="grid gap-2">
                    {if len(iterations) == 0 {
                        <p
                            key="empty"
                            className="rounded-lg border border-dashed px-3 py-6 text-center text-sm text-muted-foreground"
                        >
                            No iterations yet. Add one to start planning.
                        </p>
                    }}
                    {for it in iterations {
                        <div
                            key={it.id}
                            className="grid gap-2 rounded-lg border p-2 sm:grid-cols-[1fr_auto_auto_auto] sm:items-center"
                        >
                            <Input
                                className="h-8"
                                aria-label="Iteration name"
                                value={nameOf(it)}
                                onChange={lambda (e: any) { typed(
                                    it, e.target.value
                                ); }}
                                onBlur={lambda { if nameOf(it).strip()
                                    and nameOf(it).strip() != it.name {
                                    save(it, nameOf(it), it.start_date, it.end_date);
                                }}}
                            />
                            <DatePicker
                                value={it.start_date}
                                className="h-8 justify-between sm:w-40"
                                onChange={lambda (d: str) { save(
                                    it, it.name, d, it.end_date
                                ); }}
                            />
                            <DatePicker
                                value={it.end_date}
                                className="h-8 justify-between sm:w-40"
                                onChange={lambda (d: str) { save(
                                    it, it.name, it.start_date, d
                                ); }}
                            />
                            <Button
                                variant={"destructive" if armed == it.id else "ghost"}
                                size="sm"
                                disabled={busy}
                                onClick={lambda { remove(it); }}
                            >
                                {"Confirm" if armed == it.id else "Delete"}
                            </Button>
                        </div>
                    }}
                </div>
                <div className="flex justify-end">
                    <Button disabled={busy} onClick={lambda { addNext(); }}>
                        Add iteration
                    </Button>
                </div>
            </DialogContent>
        </Dialog>;
}
