"""Step-kind and colour metadata shared by every flow line surface. The step
stores a colour KEY; class strings stay literal here or Tailwind drops them.
A step colour shows only as a swatch or a 2px rule; kind is a glyph, never a tint.
Pinned client in jac.toml, so what other modules import is `:pub`; a server
`def:pub` here would register a partial effects table and break the cache.
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
         "active": "someone is working on it",
         "handoff": "waiting on someone else",
         "blocked": "stuck, needs attention",
         "done": "finished, work stops here"
     },
     # The glyph's ink. Only blocked earns andon red; the rest stay quiet so
     # the step colour next to the name is the one colour on a node.
     KIND_TONE: dict[str, str] = {
         "start": "text-subtle",
         "active": "text-subtle",
         "handoff": "text-subtle",
         "blocked": "text-destructive",
         "done": "text-subtle"
     },
     COLOR_KEYS: list[str] = ["sky", "indigo", "amber", "rose", "emerald", "slate"],
     # Every table keys the same six tokens (--step-X, -ink, -wash in
     # styles/global.css), so light and dark are the token's business.
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
     # Kept for callers from before the redesign: a card is a plain surface
     # now, whatever its step colour.
     CARD_TINT: dict[str, str] = {
         "sky": "border-border bg-card",
         "indigo": "border-border bg-card",
         "amber": "border-border bg-card",
         "rose": "border-border bg-card",
         "emerald": "border-border bg-card",
         "slate": "border-border bg-card"
     };

# The same colour as a raw CSS value, for inline styles.
glob:pub DOT_VAR: dict[str, str] = {
         "sky": "var(--step-sky)",
         "indigo": "var(--step-indigo)",
         "amber": "var(--step-amber)",
         "rose": "var(--step-rose)",
         "emerald": "var(--step-emerald)",
         "slate": "var(--step-slate)"
     };

# No coloured left bars any more; the key set stays so old lookups resolve.
glob CARD_BAR: dict[str, str] = {
         "sky": "",
         "indigo": "",
         "amber": "",
         "rose": "",
         "emerald": "",
         "slate": ""
     },
     LANE_BAR: dict[str, str] = {
         "sky": "bg-step-sky",
         "indigo": "bg-step-indigo",
         "amber": "bg-step-amber",
         "rose": "bg-step-rose",
         "emerald": "bg-step-emerald",
         "slate": "bg-step-slate"
     },
     RING_TINT: dict[str, str] = {
         "sky": "ring-2 ring-step-sky/60",
         "indigo": "ring-2 ring-step-indigo/60",
         "amber": "ring-2 ring-step-amber/60",
         "rose": "ring-2 ring-step-rose/60",
         "emerald": "ring-2 ring-step-emerald/60",
         "slate": "ring-2 ring-step-slate/60"
     },
     COUNT_TINT: dict[str, str] = {
         "sky": "border-transparent bg-muted text-muted-foreground",
         "indigo": "border-transparent bg-muted text-muted-foreground",
         "amber": "border-transparent bg-muted text-muted-foreground",
         "rose": "border-transparent bg-muted text-muted-foreground",
         "emerald": "border-transparent bg-muted text-muted-foreground",
         "slate": "border-transparent bg-muted text-muted-foreground"
     };


# The step's colour as a 2px rule (a board lane header, a roadmap row).

# Drag-over highlight: an outline in the column's colour, no tinted fill.

# One neutral count badge; the step colour no longer tints counts.
def:pub colorKey(raw: str) -> str {
    if raw in DOT_FILL {
        return raw;
    }
    return "slate";
}


# What a transition carries: an issue (no code yet) or a PR (code, waiting on
# a person). Shown as a quiet word before the label, never as a tinted chip.
glob:pub CARRY_LABEL: dict[str, str] = {"issue": "Issue", "pr": "PR"};
