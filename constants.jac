"""standup - shared vocabulary lists."""

glob STATUSES: list[str] = [
         "Backlog",
         "In Progress",
         "Review",
         "Changes Requested",
         "Done",
         "Blocked"
     ],
     PRIORITIES: list[str] = ["High", "Medium", "Low"],
     MILESTONE_STATUSES: list[str] = ["Planned", "In Progress", "Done"],
     STEP_KINDS: list[str] = ["start", "active", "handoff", "blocked", "done"],
     KIND_COLORS: dict[str, str] = {
         "start": "sky",
         "active": "indigo",
         "handoff": "amber",
         "blocked": "rose",
         "done": "emerald"
     },
     WORKFLOW_TEMPLATES: list[dict[str, any]] = [
         {
             "key": "jaseci",
             "name": "Jaseci flow",
             "description": "How we actually work: raise an issue, solve it with a model, get the plan approved if it is big, let the model build, then the architect reviews and merges.",
             "steps": [
                 # Laid out as a loop rather than a line. Solving and Approve
                 # stack so the "rethink" return is a short hop; Validate drops
                 # to a second row so "still broken" travels back to Build
                 # underneath Review rather than through it.
                 #
                 # Raised is intake and nothing else: work lands here and
                 # nobody is doing anything to it yet. Keeping it separate is
                 # what makes the move into Solving a real event with a person
                 # attached, instead of every new issue pretending to be
                 # underway. Six colours exist for seven steps, so Approve and
                 # Validate share one: both are a named person signing off.
                 {
                     "name": "Raised",
                     "kind": "start",
                     "color": "slate",
                     "owner": "nobody yet",
                     "x": 40.0,
                     "y": 200.0
                 },
                 {
                     "name": "Solving",
                     "kind": "active",
                     "color": "sky",
                     "owner": "person + model",
                     "x": 360.0,
                     "y": 200.0
                 },
                 {
                     "name": "Approve",
                     "kind": "handoff",
                     "color": "indigo",
                     "owner": "domain expert",
                     "x": 360.0,
                     "y": 20.0
                 },
                 {
                     "name": "Build",
                     "kind": "active",
                     "color": "amber",
                     "owner": "model + PR owner",
                     "x": 780.0,
                     "y": 200.0
                 },
                 # Reading the code and merging it is one act by one person in
                 # one sitting, so it is one step rather than two.
                 {
                     "name": "Review",
                     "kind": "handoff",
                     "color": "rose",
                     "owner": "original architect",
                     "x": 1140.0,
                     "y": 200.0
                 },
                 {
                     "name": "Done",
                     "kind": "done",
                     "color": "emerald",
                     "owner": "",
                     "x": 1500.0,
                     "y": 200.0
                 }
             ],
             # Forward first, then the two send-backs. A review that can only
             # approve is a review nobody needs, so those return paths are
             # part of the model rather than an omission.
             #
             # There is deliberately NO return from Validate: work only
             # reaches it once a reviewer has approved, and a fault found
             # later is a new issue entering at Raised, not this one moving
             # backwards. An arrow for that would imply the graph tracks a
             # thing it does not.
             "links": [
                 [0, 1], [1, 2], [1, 3], [2, 3], [3, 4], [4, 5],
                 [2, 1], [4, 3]
             ],
             # Kept short: two of these sit on the same pair of steps, and a
             # long chip is what makes labels collide.
             "link_labels": [
                 "someone takes it",
                 "needs design",
                 "small enough to just build",
                 "plan approved",
                 "PR ready and tested",
                 "approved, merged",
                 "rethink",
                 "changes requested"
             ]
         },
         {
             "key": "kanban",
             "name": "Classic Kanban",
             "description": "The straight line you know: To do, In progress, Done.",
             "steps": [
                 {
                     "name": "To do",
                     "kind": "start",
                     "color": "sky",
                     "x": 40.0,
                     "y": 60.0
                 },
                 {
                     "name": "In progress",
                     "kind": "active",
                     "color": "indigo",
                     "x": 300.0,
                     "y": 60.0
                 },
                 {
                     "name": "Done",
                     "kind": "done",
                     "color": "emerald",
                     "x": 560.0,
                     "y": 60.0
                 }
             ],
             "links": [[0, 1], [1, 2]]
         },
         {
             "key": "software",
             "name": "Software flow",
             "description": "Review loops back to development. Mirrors the classic six statuses.",
             "steps": [
                 {
                     "name": "Backlog",
                     "kind": "start",
                     "color": "sky",
                     "x": 40.0,
                     "y": 40.0
                 },
                 {
                     "name": "In progress",
                     "kind": "active",
                     "color": "indigo",
                     "x": 300.0,
                     "y": 40.0
                 },
                 {
                     "name": "Review",
                     "kind": "handoff",
                     "color": "amber",
                     "x": 560.0,
                     "y": 40.0
                 },
                 {
                     "name": "Changes requested",
                     "kind": "active",
                     "color": "rose",
                     "x": 560.0,
                     "y": 220.0
                 },
                 {
                     "name": "Blocked",
                     "kind": "blocked",
                     "color": "slate",
                     "x": 300.0,
                     "y": 220.0
                 },
                 {
                     "name": "Done",
                     "kind": "done",
                     "color": "emerald",
                     "x": 820.0,
                     "y": 120.0
                 }
             ],
             "links": [[0, 1], [1, 2], [2, 5], [2, 3], [3, 1], [1, 4], [4, 1]]
         },
         {
             "key": "support",
             "name": "Support flow",
             "description": "Triage, work, wait on the customer, resolve. Waiting loops back.",
             "steps": [
                 {"name": "New", "kind": "start", "color": "sky", "x": 40.0, "y": 60.0},
                 {
                     "name": "Triage",
                     "kind": "active",
                     "color": "indigo",
                     "x": 300.0,
                     "y": 60.0
                 },
                 {
                     "name": "In progress",
                     "kind": "active",
                     "color": "amber",
                     "x": 560.0,
                     "y": 60.0
                 },
                 {
                     "name": "Waiting on customer",
                     "kind": "handoff",
                     "color": "rose",
                     "x": 560.0,
                     "y": 240.0
                 },
                 {
                     "name": "Resolved",
                     "kind": "done",
                     "color": "emerald",
                     "x": 820.0,
                     "y": 140.0
                 }
             ],
             "links": [[0, 1], [1, 2], [2, 3], [3, 2], [2, 4]]
         }
     ],
     KIND_STATUS: dict[str, str] = {
         "start": "Backlog",
         "active": "In Progress",
         "handoff": "Review",
         "blocked": "Blocked",
         "done": "Done"
     },
     STATUS_KIND: dict[str, str] = {
         "Backlog": "start",
         "In Progress": "active",
         "Review": "handoff",
         "Changes Requested": "active",
         "Done": "done",
         "Blocked": "blocked"
     };
# What a workflow step MEANS, independent of what the org names it. The rest
# of the app keys behavior on the kind ("done" is terminal, "blocked" raises
# attention, "handoff" is waiting on someone), so renaming a step is always
# safe and every workflow needs at least a start and a done to be complete.

# Default color key per kind; the step stores the key, the client maps it to
# literal Tailwind classes.

# Seed data for ApplyTemplate AND the picker's mini previews: one source, so
# the preview can never drift from what actually gets created. `links` pairs
# are indexes into `steps`; x/y are designer-canvas px.

# A step's kind maps onto the legacy status vocabulary. Moving a task to a
# step writes both: `step_id` drives the board, `status` keeps every semantic
# check in insights, GitHub sync, the assistant and the log working without
# any of them learning what a step is.

# The other direction, for placing tasks written before workflows existed:
# a task with no step_id lands in the first step whose kind matches.
