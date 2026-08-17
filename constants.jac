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
     # What a step MEANS independent of its name; the app keys behaviour on
     # the kind, so renaming a step is always safe.
     STEP_KINDS: list[str] = ["start", "active", "handoff", "blocked", "done"],
     # Default colour key per kind; the client maps keys to literal classes.
     KIND_COLORS: dict[str, str] = {
         "start": "sky",
         "active": "indigo",
         "handoff": "amber",
         "blocked": "rose",
         "done": "emerald"
     },
     # The one prebuilt flow. The picker offers exactly this or a blank
     # canvas; the removed Kanban/Software/Support entries only ever seeded
     # steps, so workspaces created from them keep working untouched.
     WORKFLOW_TEMPLATES: list[dict[str, any]] = [
         {
             "key": "jaseci",
             "name": "Jaseci flow",
             "description": "Specify, triage, design, build, review, de-slop. Four roles, loops included.",
             # The four Jaseci roles. ApplyTemplate seeds these as Role
             # nodes (editable org data from then on); colors match the
             # step each role owns so the Roles tab echoes the canvas.
             "roles": [
                 {
                     "name": "Product Engineer",
                     "blurb": "Triages, reviews, merges, closes.",
                     "color": "indigo"
                 },
                 {
                     "name": "Builder",
                     "blurb": "Implements. Many PRs, fast.",
                     "color": "amber"
                 },
                 {
                     "name": "Architect",
                     "blurb": "Designs the approach for big changes.",
                     "color": "slate"
                 },
                 {
                     "name": "De-slop Engineer",
                     "blurb": "Small fixes and flagged rewrites.",
                     "color": "rose"
                 }
             ],
             # Triage is `start`, not `handoff`: triaged-but-unstarted work
             # must report Backlog, not Review. Two start steps is fine; the
             # no-step fallback lands on the first of the kind (Specify).
             "steps": [
                 {
                     "name": "Specify",
                     "kind": "start",
                     "color": "sky",
                     "owner": "anyone",
                     "x": 60.0,
                     "y": 40.0
                 },
                 {
                     "name": "Triage",
                     "kind": "start",
                     "color": "indigo",
                     "owner": "Product Engineer",
                     "x": 60.0,
                     "y": 260.0
                 },
                 {
                     "name": "Design",
                     "kind": "active",
                     "color": "slate",
                     "owner": "Architect",
                     "x": 400.0,
                     "y": 430.0
                 },
                 {
                     "name": "Implement",
                     "kind": "active",
                     "color": "amber",
                     "owner": "Builder",
                     "x": 740.0,
                     "y": 560.0
                 },
                 {
                     "name": "Review & merge",
                     "kind": "handoff",
                     "color": "indigo",
                     "owner": "Product Engineer",
                     "x": 860.0,
                     "y": 260.0
                 },
                 {
                     "name": "Refactor",
                     "kind": "active",
                     "color": "rose",
                     "owner": "De-slop Engineer",
                     "x": 1210.0,
                     "y": 560.0
                 },
                 {
                     "name": "Done",
                     "kind": "done",
                     "color": "emerald",
                     "owner": "Product Engineer",
                     "x": 1330.0,
                     "y": 260.0
                 }
             ],
             # Forward first, then the send-back: review that can only
             # approve is a review nobody needs.
             "links": [
                 [0, 1],
                 [1, 0],
                 [1, 2],
                 [1, 3],
                 [2, 3],
                 [3, 4],
                 [4, 6],
                 [4, 3],
                 [4, 5],
                 [5, 6]
             ],
             # Kept short: two of these share a pair of steps, and long chips
             # collide.
             "link_labels": [
                 "to PE first",
                 "PE too",
                 "needs design",
                 "small, straight to build",
                 "approach agreed",
                 "ready and tested",
                 "merged, clean",
                 "big changes, back to builder",
                 "brittle, small changes",
                 "rewritten, merged"
             ]
         }
     ],
     # Kind -> legacy status. A move writes both, so insights, GitHub sync
     # and the assistant never have to learn what a step is.
     KIND_STATUS: dict[str, str] = {
         "start": "Backlog",
         "active": "In Progress",
         "handoff": "Review",
         "blocked": "Blocked",
         "done": "Done"
     },
     # Legacy status -> kind, for placing tasks that carry no step_id.
     STATUS_KIND: dict[str, str] = {
         "Backlog": "start",
         "In Progress": "active",
         "Review": "handoff",
         "Changes Requested": "active",
         "Done": "done",
         "Blocked": "blocked"
     };
