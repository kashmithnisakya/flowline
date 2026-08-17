"""Step-kind and colour metadata shared by every workflow surface. The step
stores a colour KEY; class strings stay literal here or Tailwind drops them.
Pinned client (.cl.jac) with :pub on every table, so the compiled module
always exports all of them: a plain glob module only exports what the first
importers the client build happens to visit have pulled (see CLAUDE.md).
"""

glob:pub KIND_LABEL: dict[str, str] = {
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
     # Every table keys the same six tokens (--step-X, -ink, -wash in
     # styles/global.css), so light and dark are the token's business and
     # no table needs a dark: variant.
     DOT_FILL: dict[str, str] = {
         "sky": "bg-step-sky",
         "indigo": "bg-step-indigo",
         "amber": "bg-step-amber",
         "rose": "bg-step-rose",
         "emerald": "bg-step-emerald",
         "slate": "bg-step-slate"
     },
     TEXT_FILL: dict[str, str] = {
         "sky": "text-step-sky-ink",
         "indigo": "text-step-indigo-ink",
         "amber": "text-step-amber-ink",
         "rose": "text-step-rose-ink",
         "emerald": "text-step-emerald-ink",
         "slate": "text-step-slate-ink"
     },
     # The step's own colour as a canvas card: coloured border plus an opaque
     # pale fill (a translucent wash would let the canvas dot grid through).
     CARD_TINT: dict[str, str] = {
         "sky": "border-step-sky/60 bg-step-sky-wash",
         "indigo": "border-step-indigo/60 bg-step-indigo-wash",
         "amber": "border-step-amber/60 bg-step-amber-wash",
         "rose": "border-step-rose/60 bg-step-rose-wash",
         "emerald": "border-step-emerald/60 bg-step-emerald-wash",
         "slate": "border-step-slate/60 bg-step-slate-wash"
     };

# The same colour as a raw CSS value, for the board column dots.
glob:pub DOT_VAR: dict[str, str] = {
         "sky": "var(--step-sky)",
         "indigo": "var(--step-indigo)",
         "amber": "var(--step-amber)",
         "rose": "var(--step-rose)",
         "emerald": "var(--step-emerald)",
         "slate": "var(--step-slate)"
     };

glob:pub CARD_BAR: dict[str, str] = {
         "sky": "border-l-4 border-l-step-sky",
         "indigo": "border-l-4 border-l-step-indigo",
         "amber": "border-l-4 border-l-step-amber",
         "rose": "border-l-4 border-l-step-rose",
         "emerald": "border-l-4 border-l-step-emerald",
         "slate": "border-l-4 border-l-step-slate"
     };

# The step's colour on a board lane: a solid rule at the top of the panel
# (and the header dot and count). The lane ground itself stays neutral so the
# cards, not the panel, are the brightest thing in it.
glob:pub LANE_BAR: dict[str, str] = {
         "sky": "bg-step-sky",
         "indigo": "bg-step-indigo",
         "amber": "bg-step-amber",
         "rose": "bg-step-rose",
         "emerald": "bg-step-emerald",
         "slate": "bg-step-slate"
     };

# Drag-over highlight in the column's own voice: the full tint comes back
# only while a card can be dropped here.
glob:pub RING_TINT: dict[str, str] = {
         "sky": "ring-2 ring-step-sky/60 bg-step-sky/10",
         "indigo": "ring-2 ring-step-indigo/60 bg-step-indigo/10",
         "amber": "ring-2 ring-step-amber/60 bg-step-amber/10",
         "rose": "ring-2 ring-step-rose/60 bg-step-rose/10",
         "emerald": "ring-2 ring-step-emerald/60 bg-step-emerald/10",
         "slate": "ring-2 ring-step-slate/60 bg-step-slate/10"
     };

# Count-badge tint for column headers: the step colour at chip volume.
glob:pub COUNT_TINT: dict[str, str] = {
         "sky": "border-transparent bg-step-sky/15 text-step-sky-ink",
         "indigo": "border-transparent bg-step-indigo/15 text-step-indigo-ink",
         "amber": "border-transparent bg-step-amber/15 text-step-amber-ink",
         "rose": "border-transparent bg-step-rose/15 text-step-rose-ink",
         "emerald": "border-transparent bg-step-emerald/15 text-step-emerald-ink",
         "slate": "border-transparent bg-step-slate/15 text-step-slate-ink"
     };


def:pub colorKey(raw: str) -> str {
    if raw in DOT_FILL {
        return raw;
    }
    # Default to slate
    return "slate";
}
