# Review the four delivery processes locally

The process library at `/processes` is a working review milestone. It stores
current and proposed React migration and BAU definitions, without changing the
workspace's operational flow line, board or tasks.

## Start and open

Use the pinned Jac 0.38.2 toolchain from the repository root:

```sh
jac install
jac run --no-dev --host 127.0.0.1 -w 1 main.jac
```

### Compiler prerequisite for this UX revision

Review-note drafts exercise the bound dictionary-key fix in
[Jac PR #10441](https://github.com/jaseci-labs/jac/pull/10441). Stock 0.38.2
emits a variable key as its identifier spelling, so it cannot retain separate
drafts correctly. Validate this revision with that compiler fix until a
compatible release includes it. The local review uses a scoped copy of 0.38.2
with the upstream fix backported; the installed compiler and project version
pin are unchanged. No application workaround replaces the dictionary idiom.
The extended draft regression is expected to fail on unmodified 0.38.2;
this compiler fix is an upstream merge dependency for this revision.

Open `http://localhost:8000/processes`. Sign up or sign in to a **local**
workspace using email and password. Hosted Flowline accounts are stored on a
different server. Google/GitHub SSO needs project credentials and is not
configured for this local review.

Choose **Add the four example flows** once. This saves the definitions to the
workspace. Repeating the installation preserves their IDs and review notes.
The installer adds nothing to the operational board.

Direct links after installation:

| Flow | Local URL |
| --- | --- |
| React migration — current | `http://localhost:8000/processes?family=react&version=current` |
| React migration — proposed | `http://localhost:8000/processes?family=react&version=proposed` |
| BAU — current | `http://localhost:8000/processes?family=bau&version=current` |
| BAU — proposed | `http://localhost:8000/processes?family=bau&version=proposed` |

## Review the process

Select the family and version, or choose **Compare**. Click a diagram step,
use **Jump to step**, or choose **List**. Step details open in a contextual
panel, or a bottom sheet on a phone. The inspector shows
the owner, action, decision rule, inputs, outputs, dependencies and rework
destinations. Solid lines move forward; dashed lines return for revision or
repair. Select a step to highlight its connections. The diagrams use the native
Flowline canvas: drag or scroll to pan, use the zoom controls or Ctrl/Cmd with
the wheel to zoom, and use **Fit** to fit the diagram width. Focus the diagram
to pan with arrow keys, zoom with +/-, or fit width with F. Comparison shares
one zoom control. Text retains its native size at every zoom.

Narrow comparison views default to readable lists. A diagram can still be
chosen explicitly; phone comparison lists stack the versions and scroll with
the page.

Save feedback in **Review note**. Unsaved drafts stay in the page when changing
steps, families, versions or review sections. Save notes to keep them after a
reload. A failed save keeps the input and offers retry. A note is not an
approval or execution result.

Under **Review options**, **Shared QA & rules** records the agreed testing, review, repair, timing and
evidence requirements. **To configure** lists values that are deliberately
unset. **Build stages** separates this working milestone from later operational
contributions. The full implementation plan is in
`docs/plans/delivery-workflows.md`.

## Capability labels

| Label | Meaning in this review build |
| --- | --- |
| Working locally | Definition persistence, flow selection/comparison, diagram/list views, step inspection and saved notes |
| Manual | A person performs the depicted business action; the library describes it |
| Planned | Automation or enforcement has not been implemented |
| Placeholder | An unavailable adapter or proprietary tool, including Reactinator, developer agent sets, Spark and Ally integrations |
| To configure | Actual screens/states, references, thresholds, environment, test data and execution limits remain unset |

There is no process executor in this milestone. It does not run agents or QA,
enforce approvals, start clocks, collect delivery evidence, open PRs, merge or
deploy. No missing configuration or unexecuted check is represented as passed.

The current flows include QA staff approval of stories and acceptance criteria
in Spark before development. Proposed flows approve the spec/criteria before
autonomous story validation and implementation, with no routine intermediate
human QA checkpoint. The PR owner performs final human review and may merge
their own PR. Automated BAU regression precedes merge, and business-user UAT
follows merge. UAT rejection creates new linked work that repeats the relevant
story validation and verification steps.

## Verification

Against the running server:

```sh
python tests/smoke/process_gate.py http://localhost:8000
python tests/smoke/process_browser_gate.py http://localhost:8000
```

The API gate uses Python's standard library. The browser gate requires
`playwright` and an installed Chrome; it creates an isolated test workspace
and saves screenshots under `.jac/process-review/`. Desktop, intermediate and
phone widths exercise this library's own UI, and do not set a project's QA
screen matrix. Tests do not exercise any of the planned delivery automation.

For UI changes, follow the [style and UX guide](style-and-ux-guide.md). This
page reuses the native flow renderer, step rows, controls and form components;
the storyboard adapter suppresses task counts instead of inventing work items.
