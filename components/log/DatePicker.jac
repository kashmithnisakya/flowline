"""A modern month-grid date picker.

Replaces the native date input. The trigger shows the date the way a
person says it; the dropdown is a month grid with prev/next controls.
"""

import from ..ui.button { Button }
import from ..ui.dropdown_menu { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent }

glob MONTHS: list[str] = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
];
glob WEEKDAYS: list[str] = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];

def pad2(n: int) -> str {
    return ("0" + str(n))[-2:];
}

def isoOf(year: int, month: int, day: int) -> str {
    return str(year) + "-" + pad2(month + 1) + "-" + pad2(day);
}

# Days in month, month 0-11.
def daysIn(year: int, month: int) -> int {
    return int(new(Date, year, month + 1, 0).getDate());
}

# Monday-first column index of day 1, month 0-11.
def firstOffset(year: int, month: int) -> int {
    return int((new(Date, year, month, 1).getDay() + 6) % 7);
}

def prettyLabel(iso: str) -> str {
    d = new(Date, iso + "T00:00:00");
    names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    return names[int(d.getDay())] + ", " + MONTHS[int(d.getMonth())][:3] + " " + str(int(d.getDate()));
}

def:pub DatePicker(value: str, onChange: Callable[[str], None]) -> JsxElement {
    has viewYear: int = 0,
        viewMonth: int = -1;

    year = viewYear if viewMonth >= 0 else int(value[:4]);
    month = viewMonth if viewMonth >= 0 else int(value[5:7]) - 1;
    total = daysIn(year, month);
    offset = firstOffset(year, month);

    <DropdownMenu
        onOpenChange={lambda (o: bool) {
            if o {
                viewYear = int(value[:4]);
                viewMonth = int(value[5:7]) - 1;
            }
        }}
    >
        <DropdownMenuTrigger asChild={False}>
            <span className="inline-flex h-8 cursor-pointer items-center gap-2 rounded-lg border bg-card px-3 text-sm font-medium hover:bg-accent">
                {prettyLabel(value) if value else "Pick a date"}
            </span>
        </DropdownMenuTrigger>
        <DropdownMenuContent className="w-64 p-3">
            <div className="mb-2 flex items-center justify-between">
                <Button
                    variant="ghost"
                    size="icon-xs"
                    onClick={lambda (e: MouseEvent) {
                        e.preventDefault();
                        if month == 0 {
                            viewMonth = 11;
                            viewYear = year - 1;
                        } else {
                            viewMonth = month - 1;
                            viewYear = year;
                        }
                    }}
                >
                    ←
                </Button>
                <span className="text-sm font-semibold">{MONTHS[month]} {year}</span>
                <Button
                    variant="ghost"
                    size="icon-xs"
                    onClick={lambda (e: MouseEvent) {
                        e.preventDefault();
                        if month == 11 {
                            viewMonth = 0;
                            viewYear = year + 1;
                        } else {
                            viewMonth = month + 1;
                            viewYear = year;
                        }
                    }}
                >
                    →
                </Button>
            </div>
            <div className="grid grid-cols-7 gap-0.5 text-center">
                {for w in WEEKDAYS {
                    <span key={w} className="py-1 text-[11px] font-medium text-muted-foreground">{w}</span>
                }}
                {for i in range(offset) {
                    <span key={"pad" + str(i)} />
                }}
                {for d in range(1, total + 1) {
                    <button
                        key={"d" + str(d)}
                        type="button"
                        className={
                            "rounded-md py-1 text-sm transition-colors "
                            + (
                                "bg-primary font-semibold text-primary-foreground"
                                if isoOf(year, month, d) == value
                                else "hover:bg-accent"
                            )
                        }
                        onClick={lambda { onChange(isoOf(year, month, d)); }}
                    >
                        {d}
                    </button>
                }}
            </div>
        </DropdownMenuContent>
    </DropdownMenu>
}
