"""One worklist group: a tinted pill naming why (with its count), up to
SHOW_MAX rows, and a line for the rows it does not list (past the cap, or
counted on the board but not held by the page; `more` -1 is unknown)."""

import from "@jac/runtime" { Link }
import from .NeedsRow { NeedsRow }
import from ..common.StepBadge { stepWash, stepInk }

glob SHOW_MAX: int = 6;

def toneOf(tone: str) -> str {
    if tone == "alarm" {
        return "bg-destructive/10 text-destructive";
    }
    if tone == "muted" {
        return "bg-muted text-muted-foreground";
    }
    return stepWash(tone) + " " + stepInk(tone);
}

def moreText(g: dict[str, any]) -> str {
    capped = len(g["rows"]) - SHOW_MAX if len(g["rows"]) > SHOW_MAX else 0;
    what = g["moreLabel"] + " on the board";
    if g["more"] < 0 {
        return (str(capped) + "+ more " if capped > 0 else "More ") + what;
    }
    extra = capped + g["more"];
    if len(g["rows"]) == 0 {
        return str(extra) + " " + what;
    }
    return "+" + str(extra) + " more " + what;
}

def:pub NeedsGroup(group: dict[str, any]) -> JsxElement {
    rows: list[dict[str, any]] = group["rows"];
    count = len(rows) + (group["more"] if group["more"] > 0 else 0);
    return
        <div role="group" aria-label={group["label"]}>
            <h3
                className={"inline-flex h-6 items-center gap-1.5 rounded-full px-2.5 text-xs font-semibold "
                    + toneOf(group["tone"])}
            >
                {group["label"]}
                <span className="num font-medium opacity-80">
                    {str(count) + ("+" if group["more"] < 0 else "")}
                </span>
            </h3>
            <ul className="mt-1.5">
                {for (i, r) in enumerate(rows) {
                    if i < SHOW_MAX {
                        <NeedsRow key={r["id"]} row={r}/>
                    }
                }}
            </ul>
            {if len(rows) > SHOW_MAX or group["more"] != 0 {
                <Link
                    key="more"
                    to="/board"
                    className="mt-1 block text-xs text-muted-foreground hover:text-foreground"
                >
                    {moreText(group)}
                </Link>
            }}
        </div>;
}
