"""The board's column widths (title, then people, priority, checklist, due,
GitHub), kept in this browser and applied as the --row-cols variable that
every row and the column heads lay out on. A title width of 0 means it fills
the row; once set, the columns sit left and the slack goes to the end."""

glob:pub COLUMN_WIDTHS_KEY: str = "flowline-board-columns",
     DEFAULT_WIDTHS: list[int] = [0, 104, 76, 112, 104, 84],
     MIN_WIDTH: int = 48,
     MAX_WIDTH: int = 360,
     MIN_TITLE: int = 160,
     MAX_TITLE: int = 1200;

# Column 0 is the title, which has bounds of its own.
def:pub clampWidth(idx: int, w: float) -> int {
    lo = MIN_TITLE if idx == 0 else MIN_WIDTH;
    hi = MAX_TITLE if idx == 0 else MAX_WIDTH;
    n = int(w);
    if n < lo {
        n = lo;
    }
    if n > hi {
        n = hi;
    }
    return n;
}

def:pub loadWidths -> list[int] {
    out: list[int] = [];
    try {
        raw = localStorage.getItem(COLUMN_WIDTHS_KEY) or "";
        kept: any = JSON.parse(raw) if raw else [];
        # A list kept before the title was resizable has no title entry.
        if len(kept) == len(DEFAULT_WIDTHS) - 1 {
            padded: list[int] = [0];
            for old in kept {
                padded.append(int(old));
            }
            kept = padded;
        }
        if len(kept) == len(DEFAULT_WIDTHS) {
            out.append(0 if int(kept[0]) <= 0 else clampWidth(0, float(kept[0])));
            for j in range(1, len(kept)) {
                out.append(clampWidth(j, float(kept[j])));
            }
            return out;
        }
    } except Exception as e {
        out = [];
    }
    for w in DEFAULT_WIDTHS {
        out.append(w);
    }
    return out;
}

def:pub keepWidths(widths: list[int]) -> None {
    try {
        localStorage.setItem(COLUMN_WIDTHS_KEY, JSON.stringify(widths));
    } except Exception as e {
        return;
    }
}

# Idempotent, so the heads can call it while rendering and the first paint
# already has the stored widths.
def:pub applyWidths(widths: list[int]) {
    title = widths[0];
    cols = "28px minmax(0," + ((str(title) + "px") if title > 0 else "1fr") + ")";
    for j in range(1, len(widths)) {
        cols = cols + " " + str(widths[j]) + "px";
    }
    tail = " minmax(40px,1fr)" if title > 0 else " 40px";
    document.documentElement.style.setProperty("--row-cols", cols + tail);
}

def dropWidths {
    try {
        localStorage.removeItem(COLUMN_WIDTHS_KEY);
    } except Exception as e {
        return;
    }
}

# Forget this browser's widths; the mounted heads follow the event.
def:pub resetWidths {
    dropWidths();
    w: any = window;
    w.dispatchEvent(new(w.CustomEvent, "flowline:columns"));
}

# The rendered width of column `idx` in the board's column heads.
def:pub headWidth(idx: int) -> float {
    doc: any = document;
    head: any = doc.querySelector("[data-board-heads] [data-head='" + str(idx) + "']");
    return float(head.getBoundingClientRect().width) if head else 0.0;
}

# The widest content of data column `idx` (1 is people) across the rows on
# screen and its label, measured with a Range so truncated text reports its
# full width.
def:pub fitWidth(idx: int) -> int {
    widest = 0.0;
    doc: any = document;
    cells: any = doc.querySelectorAll("[data-col='" + str(idx - 1) + "']");
    for el in cells {
        span_range: any = doc.createRange();
        span_range.selectNodeContents(el);
        width = float(span_range.getBoundingClientRect().width);
        if width > widest {
            widest = width;
        }
    }
    return clampWidth(idx, widest + 6.0);
}
