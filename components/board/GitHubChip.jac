"""GitHub facts for a board card as text: the linked number, and the nudge a
merged PR earns. Auto-done repos move the card server-side on sync instead,
from the same statuses (MERGE_SUGGEST_STATUSES)."""

import from ...models { TaskRow }
import from ...constants { MERGE_SUGGEST_STATUSES }

# The trailing number of a GitHub issue or pull URL, 0 for anything else.
def linkNumber(url: str) -> int {
    if not url or "github" not in url {
        return 0;
    }
    parts = [
        p
        for p in url.strip().split("/")
        if p
    ];
    tail = parts[-1] if len(parts) > 0 else "";
    digits = "";
    for ch in tail {
        if ch >= "0" and ch <= "9" {
            digits = digits + ch;
        } else {
            break;
        }
    }
    return int(digits) if digits else 0;
}

# The number a card shows: the synced issue, else its PR, else a pasted link.
def:pub ghNumber(task: TaskRow) -> int {
    if task.gh_issue_number > 0 {
        return task.gh_issue_number;
    }
    if task.pr_number > 0 {
        return task.pr_number;
    }
    fromIssue = linkNumber(task.issue_link);
    return fromIssue if fromIssue > 0 else linkNumber(task.pr_link);
}

def:pub ghHref(task: TaskRow) -> str {
    if task.gh_issue_number > 0 {
        return task.issue_link;
    }
    if task.pr_number > 0 or linkNumber(task.issue_link) == 0 {
        return task.pr_link or task.issue_link;
    }
    return task.issue_link;
}

def:pub suggestsDone(task: TaskRow) -> bool {
    return task.pr_state == "merged" and task.status in MERGE_SUGGEST_STATUSES;
}

def:pub GitHubChip(task: TaskRow, onMarkDone: Callable[[str], None]) -> JsxElement {
    return
        <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <span>PR merged</span>
            <span aria-hidden="true">·</span>
            <button
                type="button"
                className="rounded-sm font-medium text-primary hover:underline"
                onClick={lambda (e: MouseEvent) {
                    e.stopPropagation();
                    onMarkDone(task.id);
                }}
                onKeyDown={lambda (e: KeyboardEvent) { e.stopPropagation(); }}
            >
                Mark done
            </button>
        </div>;
}
