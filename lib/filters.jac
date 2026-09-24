"""Saved filters on the client: the stored form (only the keys set away from
their default, as the server keeps them), a comparable key and a one-line
summary of a set, per page (FILTER_TABLES; the board unless a page is
named), and this browser's copy of the account's board filters, which
paints the first frame before the board's first page lands."""

import from ..constants { FILTER_TABLES }
import from ..models { Project, MemberView, IterationView }
import from .session { BOARD_FILTERS_KEY }

glob SCOPE_WORDS: dict[str, str] = {
         "done": "Done tasks",
         "all": "All tasks",
         "attention": "Needs attention"
     },
     SORT_WORDS: dict[str, str] = {
         "title": "title",
         "step": "step",
         "priority": "priority",
         "due": "due date",
         "updated": "last update"
     };

def keysOf(page: str) -> list[list[str]] {
    return FILTER_TABLES[page] if page in FILTER_TABLES else [];
}

# A key's value in a stored dict, or the key's default when it is not set.
def:pub filterValue(filters: dict[str, str], key: str, page: str = "board") -> str {
    if key in filters and filters[key] {
        return filters[key];
    }
    for pair in keysOf(page) {
        if pair[0] == key {
            return pair[1];
        }
    }
    return "";
}

# Every key's value to the stored form: defaults and empty values dropped.
def:pub trimFilters(picked: dict[str, str], page: str = "board") -> dict[str, str] {
    kept: dict[str, str] = {};
    for pair in keysOf(page) {
        value = picked[pair[0]] if pair[0] in picked else "";
        if value and value != pair[1] {
            kept[pair[0]] = value;
        }
    }
    return kept;
}

# One string per filter state, in the page's key order, so two dicts compare
# as strings ("" is no filter at all).
def:pub filterKey(filters: dict[str, str], page: str = "board") -> str {
    parts: list[str] = [];
    for pair in keysOf(page) {
        value = filterValue(filters, pair[0], page);
        if value != pair[1] {
            parts.append(pair[0] + "=" + value);
        }
    }
    return "\n".join(parts);
}

# What a set filters on, in words: "Platform · High priority · Done hidden".
# `steps` names the table's step keys ([key, name] pairs).
def:pub filterSummary(
    filters: dict[str, str],
    projects: list[Project],
    members: list[MemberView],
    iterations: list[IterationView],
    page: str = "board",
    steps: list[list[str]] = []
) -> str {
    parts: list[str] = [];
    for pair in keysOf(page) {
        key = pair[0];
        value = filterValue(filters, key, page);
        if value == pair[1] or key == "sort" or key == "dir" {
            continue;
        }
        if key == "scope" {
            parts.append(SCOPE_WORDS[value] if value in SCOPE_WORDS else value);
        } elif key == "step" {
            label = "Removed step";
            for st in steps {
                if st[0] == value {
                    label = st[1];
                }
            }
            parts.append(label);
        } elif key == "q" {
            parts.append("“" + value + "”");
        } elif key == "project" {
            label = "Removed project";
            for p in projects {
                if jid(p) == value {
                    label = p.name;
                }
            }
            parts.append(label);
        } elif key == "assignee" {
            label = "Removed person";
            for m in members {
                if m.id == value {
                    label = m.name;
                }
            }
            parts.append(label);
        } elif key == "priority" {
            parts.append(value + " priority");
        } elif key == "category" {
            parts.append("Category " + value);
        } elif key == "tag" {
            parts.append("Tag " + value);
        } elif key == "estimate" {
            parts.append("Estimated" if value == "yes" else "Unestimated");
        } elif key == "iteration" {
            label = "Removed iteration";
            if value == "current" {
                label = "Current iteration";
            } elif value == "none" {
                label = "No iteration";
            }
            for it in iterations {
                if it.id == value {
                    label = it.name;
                }
            }
            parts.append(label);
        } elif key == "done" {
            parts.append("Done hidden");
        }
    }
    order = filterValue(filters, "sort", page);
    way = filterValue(filters, "dir", page);
    if page == "tasks" and (order != "updated" or way != "desc") {
        parts.append(
            "Sorted by "
                + (SORT_WORDS[order] if order in SORT_WORDS else order)
                + (", ascending" if way == "asc" else ", descending")
        );
    }
    return " · ".join(parts);
}

# This browser's copy: {"ok", "filters", "set", "name"}, "ok" False when there
# is none. A session change clears it with the other session keys.
def:pub readBoardFilters -> dict[str, any] {
    empty: dict[str, any] = {"ok": False, "filters": {}, "set": "", "name": ""};
    try {
        raw = localStorage.getItem(BOARD_FILTERS_KEY) or "";
        if not raw {
            return empty;
        }
        kept: any = JSON.parse(raw);
        return {
            "ok": True,
            "filters": trimFilters(kept["filters"] or {}),
            "set": str(kept["set"] or ""),
            "name": str(kept["name"] or "")
        };
    } except Exception as e {
        return empty;
    }
}

# Keep the account's filters in this browser. The project also goes under the
# key the flow line page opens on, so it follows the board's project.
def:pub keepBoardFilters(filters: dict[str, str], setId: str, name: str) -> None {
    try {
        localStorage.setItem(
            BOARD_FILTERS_KEY,
            JSON.stringify({"filters": filters, "set": setId, "name": name})
        );
        localStorage.setItem("flowline_project", filterValue(filters, "project"));
    } except Exception as e {
        return;
    }
}
