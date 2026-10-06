"""Saved board filters on the client: the stored form (only the keys set
away from their default, as the server keeps them), a comparable key and a
one-line summary of a set, and this browser's copy of the account's board
filters, which paints the first frame before the board's first page lands.
`defaultProject` is the project a page opens on when none is picked."""

import from ..constants { BOARD_FILTERS }
import from ..models { Project, MemberView }
import from .session { BOARD_FILTERS_KEY }

# A key's value in a stored dict, or the key's default when it is not set.
def:pub filterValue(filters: dict[str, str], key: str) -> str {
    if key in filters and filters[key] {
        return filters[key];
    }
    for pair in BOARD_FILTERS {
        if pair[0] == key {
            return pair[1];
        }
    }
    return "";
}

# Every key's value to the stored form: defaults and empty values dropped.
def:pub trimFilters(picked: dict[str, str]) -> dict[str, str] {
    kept: dict[str, str] = {};
    for pair in BOARD_FILTERS {
        value = picked[pair[0]] if pair[0] in picked else "";
        if value and value != pair[1] {
            kept[pair[0]] = value;
        }
    }
    return kept;
}

# The project the board and the flow line open on when none is picked: the
# earliest-created active one, the server's `default_project` rule (stable
# passes: jid, name, then created_at as the primary key). "" without one.
def:pub defaultProject(projects: list[Project]) -> str {
    live = [
        p
        for p in projects
        if p.active
    ];
    live.sort(key=lambda (p: Project) { jid(p); });
    live.sort(key=lambda (p: Project) { p.name.lower(); });
    live.sort(key=lambda (p: Project) { p.created_at; });
    return jid(live[0]) if len(live) > 0 else "";
}

# One string per filter state, in key order, so two dicts compare as
# strings ("" is no filter at all).
def:pub filterKey(filters: dict[str, str]) -> str {
    parts: list[str] = [];
    for pair in BOARD_FILTERS {
        value = filterValue(filters, pair[0]);
        if value != pair[1] {
            parts.append(pair[0] + "=" + value);
        }
    }
    return "\n".join(parts);
}

# What a set filters on, in words: "Platform · High priority · Done hidden".
def:pub filterSummary(filters: dict[str, str], members: list[MemberView]) -> str {
    parts: list[str] = [];
    for pair in BOARD_FILTERS {
        key = pair[0];
        value = filterValue(filters, key);
        if value == pair[1] {
            continue;
        }
        if key == "assignee" {
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
        } elif key == "done" {
            parts.append("Done hidden");
        }
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

# Keep the account's filters in this browser.
def:pub keepBoardFilters(filters: dict[str, str], setId: str, name: str) -> None {
    try {
        localStorage.setItem(
            BOARD_FILTERS_KEY,
            JSON.stringify({"filters": filters, "set": setId, "name": name})
        );
    } except Exception as e {
        return;
    }
}
