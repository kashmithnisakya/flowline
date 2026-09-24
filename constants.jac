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
     # What moves a task along a transition on its own, from the step the
     # arrow leaves: a GitHub label added to the issue or its PR (the
     # transition's `match` names it), the PR merging, a review asking for
     # changes. Empty means only a person moves it.
     TRANSITION_TRIGGERS: list[str] = ["", "label", "pr_merged", "changes_requested"],
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
             "description": "Seven steps from the GitHub issue pool to Done: validate, pick, review the PR, then oversight decides. GitHub labels and merges move the work. Adds four roles.",
             # The four roles. ApplyTemplate seeds these as Role nodes
             # (editable org data from then on); colors match the step each
             # role owns so the Roles tab echoes the canvas.
             "roles": [
                 {
                     "name": "Product Engineer",
                     "blurb": "Validates issues, reviews PRs.",
                     "color": "indigo"
                 },
                 {
                     "name": "Model Pilot Engineer",
                     "blurb": "Picks issues and ships the PRs.",
                     "color": "amber"
                 },
                 {
                     "name": "Architect",
                     "blurb": "Makes the design decisions for big changes.",
                     "color": "slate"
                 },
                 {
                     "name": "Model Oversight Engineer",
                     "blurb": "Checks merged work. Decides done.",
                     "color": "rose"
                 }
             ],
             # Unassigned and Validated are both `start`: validated but
             # unpicked work is still Backlog. Ready needs a due date and In
             # review a linked PR, whether a label or a person moves it.
             "steps": [
                 {
                     "name": "Incoming",
                     "kind": "start",
                     "color": "sky",
                     "owner": "anyone",
                     "blurb": "new issues from GitHub",
                     "x": 60.0,
                     "y": 40.0
                 },
                 {
                     "name": "Ready",
                     "kind": "start",
                     "color": "indigo",
                     "owner": "Product Engineer",
                     "blurb": "validated, prioritised, dated",
                     "needs_due_date": True,
                     "x": 60.0,
                     "y": 260.0
                 },
                 {
                     "name": "Building",
                     "kind": "active",
                     "color": "amber",
                     "owner": "Model Pilot Engineer",
                     "blurb": "one engineer; a linked PR is fetched",
                     "x": 400.0,
                     "y": 480.0
                 },
                 {
                     "name": "Design",
                     "kind": "active",
                     "color": "slate",
                     "owner": "Architect",
                     "blurb": "big changes only",
                     "x": 400.0,
                     "y": 700.0
                 },
                 {
                     "name": "In review",
                     "kind": "handoff",
                     "color": "indigo",
                     "owner": "Product Engineer",
                     "blurb": "PR open, being reviewed",
                     "needs_pr": True,
                     "x": 740.0,
                     "y": 260.0
                 },
                 {
                     "name": "Final check",
                     "kind": "handoff",
                     "color": "rose",
                     "owner": "Model Oversight Engineer",
                     "blurb": "is the solution right?",
                     "x": 1080.0,
                     "y": 480.0
                 },
                 {
                     "name": "Done",
                     "kind": "done",
                     "color": "emerald",
                     "owner": "Model Oversight Engineer",
                     "blurb": "correct, no polish needed",
                     "x": 1420.0,
                     "y": 480.0
                 }
             ],
             "links": [[0, 1], [1, 2], [2, 3], [3, 2], [2, 4], [4, 2], [4, 5], [5, 6]],
             # Index-aligned with `links`, as are the carries and triggers.
             "link_labels": [
                 "validated, with priority",
                 "picked up",
                 "needs a design decision",
                 "decision made",
                 "ready to review",
                 "changes requested",
                 "PR merged",
                 "correct, no polish"
             ],
             "link_carries": [
                 "issue",
                 "issue",
                 "issue",
                 "issue",
                 "pr",
                 "pr",
                 "pr",
                 "pr"
             ],
             # What moves a task along the arrow without a person (see
             # TRANSITION_TRIGGERS); `link_matches` names the label.
             "link_triggers": [
                 "label",
                 "",
                 "",
                 "",
                 "label",
                 "changes_requested",
                 "pr_merged",
                 ""
             ],
             "link_matches": ["validated", "", "", "", "ready-to-review", "", "", ""]
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
