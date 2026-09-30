"""The board's five data column widths (people, priority, checklist, due,
GitHub), kept in this browser and applied as the --row-cols variable that
every row and the column heads lay out on. The title column takes the rest."""

glob:pub COLUMN_WIDTHS_KEY: str = "flowline-board-columns",
     DEFAULT_WIDTHS: list[int] = [104, 76, 112, 104, 84],
     MIN_WIDTH: int = 48,
     MAX_WIDTH: int = 360;

def:pub clampWidth(w: float) -> int {
    n = int(w);
    if n < MIN_WIDTH {
        n = MIN_WIDTH;
    }
    if n > MAX_WIDTH {
        n = MAX_WIDTH;
    }
    return n;
}

def:pub loadWidths -> list[int] {
    out: list[int] = [];
    try {
        raw = localStorage.getItem(COLUMN_WIDTHS_KEY) or "";
        kept: any = JSON.parse(raw) if raw else [];
        if len(kept) == len(DEFAULT_WIDTHS) {
            for w in kept {
                out.append(clampWidth(float(w)));
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
    cols = "28px minmax(0,1fr)";
    for w in widths {
        cols = cols + " " + str(w) + "px";
    }
    document.documentElement.style.setProperty("--row-cols", cols + " 40px");
}
