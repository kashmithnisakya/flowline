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
         "done": "finished - terminal"
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
     },
     # The step's own colour as a card tint: coloured border plus pale opaque fill.
     # Opaque matters - a translucent wash lets the canvas dot grid show through.
     # Dark fills sit at 950 so the saturated hue reads as an accent, not a slab,
     # against the muted pine theme (and matches COLUMN_TINT's volume).
     CARD_TINT: dict[str, str] = {
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

glob CARD_BAR: dict[str, str] = {
         "sky": "border-l-4 border-l-sky-500",
         "indigo": "border-l-4 border-l-indigo-500",
         "amber": "border-l-4 border-l-amber-500",
         "rose": "border-l-4 border-l-rose-500",
         "emerald": "border-l-4 border-l-emerald-500",
         "slate": "border-l-4 border-l-slate-500"
     };

# The step's colour as a COLUMN panel: a soft fill inside a coloured border.
# Light fills are translucent washes so six tinted panels sit quietly on the
# warm paper ground instead of six cool pastel slabs.
glob COLUMN_TINT: dict[str, str] = {
         "sky": "border-sky-400/60 bg-sky-50/70 dark:border-sky-500/40 dark:bg-sky-950/40",
         "indigo": "border-indigo-400/60 bg-indigo-50/70 dark:border-indigo-500/40 dark:bg-indigo-950/40",
         "amber": "border-amber-400/60 bg-amber-50/70 dark:border-amber-500/40 dark:bg-amber-950/40",
         "rose": "border-rose-400/60 bg-rose-50/70 dark:border-rose-500/40 dark:bg-rose-950/40",
         "emerald": "border-emerald-400/60 bg-emerald-50/70 dark:border-emerald-500/40 dark:bg-emerald-950/40",
         "slate": "border-slate-400/60 bg-slate-100/70 dark:border-slate-500/40 dark:bg-slate-900/60"
     };

# Drag-over highlight in the column's own voice (board drop targets).
glob RING_TINT: dict[str, str] = {
         "sky": "ring-2 ring-sky-400/60",
         "indigo": "ring-2 ring-indigo-400/60",
         "amber": "ring-2 ring-amber-400/60",
         "rose": "ring-2 ring-rose-400/60",
         "emerald": "ring-2 ring-emerald-400/60",
         "slate": "ring-2 ring-slate-400/60"
     };

# Count-badge tint for column headers: the step colour at chip volume.
glob COUNT_TINT: dict[str, str] = {
         "sky": "border-transparent bg-sky-500/15 text-sky-700 dark:text-sky-300",
         "indigo": "border-transparent bg-indigo-500/15 text-indigo-700 dark:text-indigo-300",
         "amber": "border-transparent bg-amber-500/15 text-amber-700 dark:text-amber-300",
         "rose": "border-transparent bg-rose-500/15 text-rose-700 dark:text-rose-300",
         "emerald": "border-transparent bg-emerald-500/15 text-emerald-700 dark:text-emerald-300",
         "slate": "border-transparent bg-slate-500/15 text-slate-700 dark:text-slate-300"
     };


def colorKey(raw: str) -> str {
    if raw in DOT_FILL {
        return raw;
    }
    # Default to slate
    return "slate";
}
