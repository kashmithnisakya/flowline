"""Saved filters: the board's filters kept on the account, so the board opens
on them in any browser, and named filter sets for the board and the tasks
table. The sets ride on GetWorkspace and the board's filters on
BoardSnapshot; these walkers only write."""

import from models {
    FilterSet,
    FilterSets,
    filter_set_view,
    filter_sets_box,
    page_filter_sets,
    resolve,
    on_attached,
    owned
}
import from constants { FILTER_TABLES, FILTER_SET_PAGES, PRIORITIES }
import from services.util { now_iso }

glob FILTER_SET_MAX: int = 50,
     FILTER_NAME_MAX: int = 60,
     FILTER_VALUE_MAX: int = 200,
     # Keys whose value is one of a few words, on any page: any other value
     # drops the key.
     FILTER_CHOICES: dict[str, list[str]] = {
         "priority": PRIORITIES,
         "estimate": ["yes", "no"],
         "done": ["hide"]
     };


# `raw` as it is stored: the page's keys only, each a trimmed string that is
# not the key's default, and a listed value for the keys FILTER_CHOICES names.
def clean_filters(page: str, raw: dict[str, str]) -> dict[str, str] {
    out: dict[str, str] = {};
    if page not in FILTER_TABLES {
        return out;
    }
    for pair in FILTER_TABLES[page] {
        key = pair[0];
        value = str(raw[key] or "").strip()[:FILTER_VALUE_MAX] if key in raw else "";
        if not value or value == pair[1] {
            continue;
        }
        if key in FILTER_CHOICES and value not in FILTER_CHOICES[key] {
            continue;
        }
        out[key] = value;
    }
    return out;
}


def refusal(error: str, message: str) -> dict[str, any] {
    return {"ok": False, "error": error, "message": message};
}


# Is `name` already taken on the page, ignoring case and the set `except_id`?
def name_taken(sets: list[FilterSet], name: str, except_id: str) -> bool {
    wanted = name.lower();
    for s in sets {
        if jid(s) != except_id and s.name.lower() == wanted {
            return True;
        }
    }
    return False;
}


walker SetBoardFilters {
    """Keep the board's filters on the account. `filters` is stored as
    clean_filters leaves it; `set_id` names the saved set they came from and
    is kept only when it is one of this account's board sets."""
    has filters: dict[str, str] = {},
        set_id: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        visit filter_sets_box(here);
    }

    can keep with FilterSets entry {
        came_from = "";
        picked = resolve(self.set_id);
        if isinstance(picked, FilterSet)
            and owned(root, picked)
            and picked.page == "board" {
            came_from = self.set_id;
        }
        kept = clean_filters("board", self.filters);
        here.board = kept;
        here.board_set = came_from;
        here.board_at = now_iso();
        report {"ok": True, "filters": kept, "set_id": came_from};
        disengage;
    }
}


walker SaveFilterSet {
    """Name a set of filters. No `set_id` creates one on `page`; otherwise the
    addressed set takes the name and the filters (a rename sends its own
    filters back). A name is 1 to 60 characters and unique on its page
    ignoring case, a set filters on something, and a page holds at most
    FILTER_SET_MAX sets; anything else reports {"ok": False, ...}."""
    has set_id: str = "",
        name: str = "",
        page: str = "board",
        filters: dict[str, str] = {},
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        self.name = " ".join(self.name.split())[:FILTER_NAME_MAX];
        if not self.name {
            report refusal("invalid", "Give the filters a name.");
            disengage;
        }
        if self.set_id {
            target = resolve(self.set_id);
            if isinstance(target, FilterSet) and owned(here, target) {
                visit [target];
            } else {
                report refusal("not_found", "Unknown filter set.");
            }
        } elif self.page not in FILTER_SET_PAGES {
            report refusal("invalid", "Unknown page.");
        } else {
            visit filter_sets_box(here);
        }
    }

    can create with FilterSets entry {
        kept = clean_filters(self.page, self.filters);
        siblings = page_filter_sets(root, self.page);
        if not kept {
            report refusal("empty", "Pick at least one filter to save.");
        } elif name_taken(siblings, self.name, "") {
            report refusal("duplicate", "A saved set already has that name.");
        } elif len(siblings) >= FILTER_SET_MAX {
            report refusal(
                "full",
                "This page holds " + str(FILTER_SET_MAX) + " saved sets at most."
            );
        } else {
            stamp = now_iso();
            fresh = here ++> FilterSet(
                name=self.name,
                page=self.page,
                filters=kept,
                created_at=stamp,
                updated_at=stamp
            );
            on_attached(root, fresh);
            report {"ok": True, "set": filter_set_view(fresh)};
        }
        disengage;
    }

    can update with FilterSet entry {
        kept = clean_filters(here.page, self.filters);
        if not kept {
            report refusal("empty", "Pick at least one filter to save.");
        } elif name_taken(page_filter_sets(root, here.page), self.name, jid(here)) {
            report refusal("duplicate", "A saved set already has that name.");
        } else {
            here.name = self.name;
            here.filters = kept;
            here.updated_at = now_iso();
            report {"ok": True, "set": filter_set_view(here)};
        }
        disengage;
    }
}


walker DeleteFilterSet {
    """Delete one saved set. The board keeps its filters, and forgets the set
    as the one they came from."""
    has set_id: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        target = resolve(self.set_id);
        if isinstance(target, FilterSet) and owned(here, target) {
            visit [target];
        } else {
            report refusal("not_found", "Unknown filter set.");
        }
    }

    can remove with FilterSet entry {
        gone = jid(here);
        for box in [root-->[?:FilterSets]] {
            if box.board_set == gone {
                box.board_set = "";
            }
        }
        del here;
        report {"ok": True, "deleted": gone};
        disengage;
    }
}
