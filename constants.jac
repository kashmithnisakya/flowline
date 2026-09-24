"""flowline - shared vocabulary lists."""

glob STATUSES: list[str] = [
         "Backlog",
         "In Progress",
         "Review",
         "Changes Requested",
         "Done",
         "Blocked"
     ],
     PRIORITIES: list[str] = ["High", "Medium", "Low"],
     # Open work that someone has actually picked up, as opposed to Backlog
     # (not started) or Blocked (stopped). The Overview reads it as "active".
     ACTIVE_STATUSES: list[str] = ["In Progress", "Review", "Changes Requested"],
     # Statuses where "the PR merged" means the work is done: the board chip
     # suggests Done here, and auto-done repos move the card here on sync.
     MERGE_SUGGEST_STATUSES: list[str] = ["In Progress", "Review"],
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
     # What a transition carries: an issue (no code yet) or a PR (code,
     # waiting on a person). Empty is fine and means untagged.
     CARRY_KINDS: list[str] = ["issue", "pr"],
     # The board's filters as the account and a saved set store them: each
     # key with the value that means "no filter". A stored dict keeps only
     # the keys set to something else; the title search is never stored.
     # The project is the scope every page shares (lib/project), not a filter.
     BOARD_FILTERS: list[list[str]] = [
         ["assignee", "All"],
         ["priority", "All"],
         ["category", "All"],
         ["tag", "All"],
         ["estimate", "All"],
         ["done", "show"]
     ],
     # Each page a saved filter set can belong to, with its keys.
     FILTER_TABLES: dict[str, list[list[str]]] = {"board": BOARD_FILTERS},
     FILTER_SET_PAGES: list[str] = ["board"],
     # Prebuilt flows, recommended first. The key persists on the flow line
     # (WorkflowSteps.template_key), so rename a template, never re-key it.
     # Roles, link_labels and link_carries are optional per template.
     FLOW_LINE_TEMPLATES: list[dict[str, any]] = [
         {
             "key": "simple",
             "name": "Simple",
             "description": "Four steps, and Review can send work back to Doing.",
             "steps": [
                 {
                     "name": "To do",
                     "kind": "start",
                     "color": "sky",
                     "x": 60.0,
                     "y": 60.0
                 },
                 {
                     "name": "Doing",
                     "kind": "active",
                     "color": "indigo",
                     "x": 400.0,
                     "y": 60.0
                 },
                 {
                     "name": "Review",
                     "kind": "handoff",
                     "color": "rose",
                     "x": 740.0,
                     "y": 60.0
                 },
                 {
                     "name": "Done",
                     "kind": "done",
                     "color": "emerald",
                     "x": 1080.0,
                     "y": 60.0
                 }
             ],
             "links": [[0, 1], [1, 2], [2, 3], [2, 1]],
             "link_labels": ["", "", "", "Changes requested"]
         },
         {
             "key": "jaseci",
             "name": "Software team",
             "description": "Seven steps from writing the issue to done, with a design step for big changes and loops back from review. Adds four roles.",
             # The four Jaseci roles. ApplyTemplate seeds these as Role
             # nodes (editable org data from then on); colors match the
             # step each role owns so the Roles tab echoes the canvas.
             "roles": [
                 {
                     "name": "Product Engineer",
                     "blurb": "Triages, reviews, merges.",
                     "color": "indigo"
                 },
                 {
                     "name": "Model Pilot Engineer",
                     "blurb": "Implements. Many PRs, fast.",
                     "color": "amber"
                 },
                 {
                     "name": "Architect",
                     "blurb": "Designs the approach for big changes.",
                     "color": "slate"
                 },
                 {
                     "name": "Model Oversight Engineer",
                     "blurb": "Final pass. Decides done.",
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
                     "blurb": "write the issue, anyone",
                     "x": 60.0,
                     "y": 40.0
                 },
                 {
                     "name": "Triage",
                     "kind": "start",
                     "color": "indigo",
                     "owner": "Product Engineer",
                     "blurb": "sets priority, nothing skips this",
                     "x": 60.0,
                     "y": 260.0
                 },
                 {
                     "name": "Architecturing",
                     "kind": "active",
                     "color": "slate",
                     "owner": "Architect",
                     "blurb": "big changes only",
                     "x": 400.0,
                     "y": 560.0
                 },
                 {
                     "name": "Implement",
                     "kind": "active",
                     "color": "amber",
                     "owner": "Model Pilot Engineer",
                     "blurb": "drive the model, add tests",
                     "x": 740.0,
                     "y": 430.0
                 },
                 {
                     "name": "Review & merge",
                     "kind": "handoff",
                     "color": "indigo",
                     "owner": "Product Engineer",
                     "blurb": "nothing passes without this",
                     "x": 860.0,
                     "y": 260.0
                 },
                 {
                     "name": "Refactor",
                     "kind": "active",
                     "color": "rose",
                     "owner": "Model Oversight Engineer",
                     "blurb": "decides done",
                     "x": 1210.0,
                     "y": 560.0
                 },
                 {
                     "name": "Done",
                     "kind": "done",
                     "color": "emerald",
                     "owner": "Model Oversight Engineer",
                     "blurb": "terminal",
                     "x": 1560.0,
                     "y": 560.0
                 }
             ],
             # Forward first, then the send-back: review that can only
             # approve is a review nobody needs. Merged work has no direct
             # road to Done - it goes through Model Oversight Engineer, which is what marks it.
             "links": [
                 [0, 1],
                 [1, 0],
                 [1, 2],
                 [1, 3],
                 [2, 3],
                 [3, 4],
                 [4, 3],
                 [4, 5],
                 [5, 6]
             ],
             # Kept short: two of these share a pair of steps, and long chips
             # collide. Index-aligned with `links`, as is `link_carries`.
             "link_labels": [
                 "to PE first",
                 "PE too",
                 "needs architecturing",
                 "small, straight to build",
                 "approach agreed",
                 "ready and tested",
                 "big changes, back to builder",
                 "merged",
                 "decides & marks done"
             ],
             # What crosses each arrow: an issue until there is code, a PR
             # after. Read the legend under the canvas.
             "link_carries": [
                 "issue",
                 "issue",
                 "issue",
                 "issue",
                 "issue",
                 "pr",
                 "pr",
                 "pr",
                 "pr"
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
