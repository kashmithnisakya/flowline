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
             "description": "How we actually work: an issue is raised, someone takes it and solves it with a model, the plan is approved if it is big, the model builds, the architect reviews and merges, and anything needing a follow-up PR waits until that lands too.",
             "steps": [
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
                 # Approve is the optional detour at the start, Follow-up the
                 # one at the end. Most work takes neither.
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
                     "x": 720.0,
                     "y": 200.0
                 },
                 {
                     "name": "Review",
                     "kind": "handoff",
                     "color": "rose",
                     "owner": "original architect",
                     "x": 1040.0,
                     "y": 200.0
                 },
                 # Merged but not finished: the change is live and another PR
                 # is still owed before the job is really complete. Work waits
                 # here until that one lands, then both reach Done together.
                 {
                     "name": "Follow-up",
                     "kind": "handoff",
                     "color": "amber",
                     "owner": "follow-up PR owner",
                     "x": 1320.0,
                     "y": 370.0
                 },
                 {
                     "name": "Done",
                     "kind": "done",
                     "color": "emerald",
                     "owner": "",
                     "x": 1570.0,
                     "y": 200.0
                 }
             ],
             # Forward first, then the two send-backs: a review that can only
             # approve is a review nobody needs.
             "links": [
                 [0, 1], [1, 2], [1, 3], [2, 3], [3, 4], [4, 5], [4, 6],
                 [5, 6],
                 [2, 1], [4, 3]
             ],
             # Kept short: two of these share a pair of steps, and long chips
             # collide.
             "link_labels": [
                 "someone takes it",
                 "needs design",
                 "small enough to just build",
                 "plan approved",
                 "PR ready and tested",
                 "merged, more to do",
                 "merged, complete",
                 "follow-up merged",
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
