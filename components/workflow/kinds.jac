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

# The step's own colour, as a card tint: a coloured border plus a pale but
# OPAQUE fill. Opaque matters — a translucent wash lets the canvas dot grid
# show through and print dots across the step name. Saturated fills turn a
# ten-step canvas into a rainbow; this gives each step an identity without
# shouting.
glob CARD_TINT: dict[str, str] = {
         "sky": "border-sky-500/60 bg-sky-50 dark:bg-sky-950",
         "indigo": "border-indigo-500/60 bg-indigo-50 dark:bg-indigo-950",
         "amber": "border-amber-500/60 bg-amber-50 dark:bg-amber-950",
         "rose": "border-rose-500/60 bg-rose-50 dark:bg-rose-950",
         "emerald": "border-emerald-500/60 bg-emerald-50 dark:bg-emerald-950",
         "slate": "border-slate-500/60 bg-slate-100 dark:bg-slate-900"
     };

# The same colour as a raw CSS value, for the board column dots.
glob DOT_VAR: dict[str, str] = {
         "sky": "var(--color-sky-500)",
         "indigo": "var(--color-indigo-500)",
         "amber": "var(--color-amber-500)",
         "rose": "var(--color-rose-500)",
         "emerald": "var(--color-emerald-500)",
         "slate": "var(--color-slate-500)"
     };


def colorKey(raw: str) -> str {
    if raw in DOT_FILL {
        return raw;
    }
    return "slate";
}
