"""standup - shared vocabulary lists.

One vocabulary for the whole app: board columns and priorities. Categories
and tags are org-defined VocabTerm nodes (seeded in setup, managed on the
Workspace tab) rather than hardcoded lists.
"""

glob STATUSES: list[str] = [
    "Backlog", "In Progress", "Review", "Changes Requested", "Done", "Blocked"
];

glob PRIORITIES: list[str] = ["High", "Medium", "Low"];

# Roadmap milestone states. Deliberately coarser than the board's six
# columns: a milestone is a phase, not a card.
glob MILESTONE_STATUSES: list[str] = ["Planned", "In Progress", "Done"];
