"""Step-kind and color metadata shared by every workflow surface.

The step stores a color KEY; class strings must stay literal in these
tables or Tailwind's scanner drops them from the build.
"""

glob KIND_LABEL: dict[str, str] = {
         "start": "Start",
         "active": "Active",
         "handoff": "Handoff",
         "blocked": "Blocked",
         "done": "Done"
     },
     KIND_HINT: dict[str, str] = {
         "start": "where new work lands",
         "active": "being worked on",
         "handoff": "waiting on someone",
         "blocked": "needs attention",
         "done": "finished — terminal"
     },
     COLOR_KEYS: list[str] = ["sky", "indigo", "amber", "rose", "emerald", "slate"],
     DOT_FILL: dict[str, str] = {
         "sky": "bg-sky-500",
         "indigo": "bg-indigo-500",
         "amber": "bg-amber-500",
         "rose": "bg-rose-500",
         "emerald": "bg-emerald-500",
         "slate": "bg-slate-500"
     },
     TEXT_FILL: dict[str, str] = {
         "sky": "text-sky-500",
         "indigo": "text-indigo-500",
         "amber": "text-amber-500",
         "rose": "text-rose-500",
         "emerald": "text-emerald-500",
         "slate": "text-slate-500"
     };

def colorKey(raw: str) -> str {
    if raw in DOT_FILL {
        return raw;
    }
    return "slate";
}
