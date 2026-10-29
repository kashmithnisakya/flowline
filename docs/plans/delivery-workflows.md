# Flowline delivery workflows and upstream implementation plan

Status: agreed requirements incorporated; local storyboard review milestone implemented. Autonomous delivery remains planned.

Build reusable Flowline improvements for versioned process models, story traceability, configurable quality checks, autonomous delivery and evidence for final review. React migration and BAU are demonstration workflows. Proprietary Ally tools and agent sets remain labelled integration placeholders. The first deliverable is a local demonstration of the four flows; operational capabilities follow in independently reviewable contributions.

## Scope and current implementation status

The review milestone is based on upstream dev at 38a25f9d2d9d5d2b7c67fa6c6a568a3d1d640217, with Jac pinned to 0.38.2. It adds a tenant-owned process library at `/processes`. This page selects and compares reviewable storyboards; the workspace's operational flow line remains separate.

| Label | Meaning | Current examples |
| --- | --- | --- |
| Baseline present | Implemented in the inspected source; runtime must be revalidated before describing it as working | One flow per workspace, canvas and role lanes, tasks, checklists, history, GitHub synchronization, queued AI code review |
| Manual | A person performs the work or decision; external actions and evidence are recorded explicitly | UX design in Figma, current QA staff approval in Spark, user spec approval, PR owner final review and merge, business-user UAT |
| Working locally | Implemented and exercised in the local app | Four persisted storyboard definitions, current/proposed comparison, diagram and step-list views, step details, shared rules, configuration gaps and saved review notes |
| Planned | Reusable operational capability still to implement | Operational multi-flow task scoping, story evaluation, configurable QA execution, independent reviewer, repair coordinator and evidence readiness |
| Placeholder | An unavailable integration or proprietary implementation; it cannot return fabricated success | Reactinator, developer agent set, Ally QA agent and proprietary Spark integration |
| To configure | A required project or spec value has not been supplied | Actual viewports and states, references, numeric execution limits, quality thresholds, QA environment and test-data provision |

The four diagrams describe agreed business processes. Their boxes do not claim that corresponding integrations already work in Flowline. A manual result, simulated storyboard result and verified automated result must remain distinguishable.

Reusable upstream code uses generic roles, configuration and execution interfaces. Example workflows may name Jacob, PO, UX and QA as demonstration actors. Keep meeting transcripts, proprietary instructions, credentials and Ally-specific implementations outside the upstream contribution.

## Settled process rules

1. Current flows require QA staff in Spark to approve generated business stories and acceptance criteria before development.
2. Proposed flows require user approval of the generated spec and acceptance criteria before autonomous story generation and validation, implementation, testing, automated review and repair.
3. Proposed flows have no routine intermediate human QA approval. Humans resolve exceptions that require a decision or an approved change.
4. The PR owner performs the final human review and may merge their own PR. A separate automated reviewer is read-only; this does not imply a second mandatory human approver.
5. Required automated BAU regression finishes before merge. Business-user UAT happens after merge.
6. Approved behavior, required checks and visual expectations change only after approval. The agent may adjust implementation tasks and add tests within those boundaries.
7. Generating stories, tests or a model-written success summary never establishes that implementation passed.
8. Missing configuration, unexecuted required checks, unresolved confirmed defects and unexplained failed-then-passing tests cannot appear passed or establish readiness.
9. For these examples, users select a QA deadline between 48 and 96 hours. This is a deadline policy, distinct from any reported historical QA duration.

## Four demonstration workflows

### React migration current

~~~mermaid
flowchart TD
    A["Jira migration item selected and assigned"] --> B["Jacob runs Reactinator · placeholder"]
    B --> C["Prepare spec, generated business stories<br/>and acceptance criteria"]
    C --> D{"QA staff in Spark approve<br/>stories and acceptance criteria?"}
    D -->|"Revise"| C
    D -->|"Approved"| E["Link implementation tasks and QA scenarios<br/>Assign Jacob or developer owners"]
    E --> F["Jacob or developers implement<br/>Reactinator / developer agent set placeholders"]
    F --> G["Open or update PR"]
    G --> H["QA execution in Spark<br/>Required tests and automated BAU regression"]
    H --> I{"Required QA passed?"}
    I -->|"Fix defects"| F
    I -->|"Yes"| J{"PR owner final human review"}
    J -->|"Changes requested"| F
    J -->|"Approved: may merge own PR"| K["Merge and deploy candidate to UAT"]
    K --> L{"Business-user UAT accepted?"}
    L -->|"Yes"| M["Production release"]
    L -->|"No"| N["Create linked Jira defect or fix story"]
    N --> C
~~~

The pre-development Spark approval and the later execution of QA are distinct activities. The selected QA deadline starts at the first runnable build entering QA, not at story approval.

### BAU current

~~~mermaid
flowchart TD
    A["PO records business need · Jira intake"] --> B["UX creates or revises design in Figma"]
    B --> C{"PO approves design?"}
    C -->|"Design feedback"| B
    C -->|"Approved"| D["PO prepares knowledge article and spec"]
    D --> E["Generate epics and business stories<br/>with acceptance criteria"]
    E --> F{"QA staff in Spark approve<br/>stories and acceptance criteria?"}
    F -->|"Revise"| E
    F -->|"Approved"| G["Link implementation tasks and QA scenarios<br/>Assign developer owners"]
    G --> H["Developers implement and open PR"]
    H --> I["QA execution in Spark<br/>Required tests and automated BAU regression"]
    I --> J{"Required QA passed?"}
    J -->|"Fix defects"| H
    J -->|"Yes"| K{"PR owner final human review"}
    K -->|"Changes requested"| H
    K -->|"Approved: may merge own PR"| L["Merge and deploy candidate to UAT"]
    L --> M{"Business-user UAT accepted?"}
    M -->|"Yes"| N["Production release"]
    M -->|"No"| O["Create and assign linked fix story"]
    O --> E
~~~

### React migration proposed

~~~mermaid
flowchart TD
    A["Jira migration item<br/>Jacob supplies Reactinator output · placeholder"] --> B["Generate spec and acceptance criteria"]
    B --> C{"User approves generated<br/>spec and acceptance criteria?"}
    C -->|"Revise"| B
    C -->|"Approved"| D["Autonomously generate business stories<br/>Link implementation tasks and QA scenarios"]
    D --> V{"Stories complete, consistent<br/>and testable?"}
    V -->|"Revise within approved behavior"| D
    V -->|"Approval or clarification needed"| X["Pause with evidence and decision needed"]
    V -->|"Yes"| E["Agents implement and open or update PR<br/>Named pilot / developer owner"]
    E --> F["Execute required QA and automated BAU regression<br/>Separate read-only automated review"]
    F --> G{"Implementation criteria and mandatory checks<br/>satisfied; findings and retries resolved?"}
    G -->|"Permitted repair within run limits"| E
    G -->|"Exception, approval needed or exhausted limits"| X
    X -->|"Approved behavior or expectations change"| B
    X -->|"Authorized resume"| R{"Saved checkpoint"}
    R -->|"Stories"| D
    R -->|"Implementation"| E
    R -->|"QA or review"| F
    G -->|"Yes"| H["Evidence for current commit / build<br/>Ready for final human review"]
    H --> I{"PR owner final human review"}
    I -->|"Implementation changes"| E
    I -->|"Approved: may merge own PR"| J["Merge and deploy candidate to UAT"]
    J --> K{"Business-user UAT accepted?"}
    K -->|"Yes"| L["Production release and verification"]
    K -->|"No"| M["Create linked business fix story<br/>and implementation / QA work"]
    M --> D
~~~

Story validation is a prerequisite to development. A story that fails completeness, consistency or testability evaluation returns to autonomous story revision first.

### BAU proposed

~~~mermaid
flowchart TD
    A["PO records business need · Jira intake"] --> B["UX creates or revises design in Figma"]
    B --> C["Draft knowledge article, spec<br/>and acceptance criteria"]
    C --> D{"User / PO approves design,<br/>generated spec and acceptance criteria?"}
    D -->|"Design feedback"| B
    D -->|"Spec or criteria feedback"| C
    D -->|"Approved"| E["Autonomously generate epics and business stories<br/>Link implementation tasks and QA scenarios"]
    E --> V{"Stories complete, consistent<br/>and testable?"}
    V -->|"Revise within approved behavior"| E
    V -->|"Approval or clarification needed"| X["Pause with evidence and decision needed"]
    V -->|"Yes"| F["Agents implement and open or update PRs<br/>Named pilot / developer owners"]
    F --> G["Execute required QA and automated BAU regression<br/>Separate read-only automated review"]
    G --> H{"Implementation criteria and mandatory checks<br/>satisfied; findings and retries resolved?"}
    H -->|"Permitted repair within run limits"| F
    H -->|"Exception, approval needed or exhausted limits"| X
    X -->|"Approved behavior or expectations change"| C
    X -->|"Authorized resume"| R{"Saved checkpoint"}
    R -->|"Stories"| E
    R -->|"Implementation"| F
    R -->|"QA or review"| G
    H -->|"Yes"| I["Evidence for current commit / build<br/>Ready for final human review"]
    I --> J{"PR owner final human review"}
    J -->|"Implementation changes"| F
    J -->|"Approved: may merge own PR"| K["Merge and deploy candidate to UAT"]
    K --> L{"Business-user UAT accepted?"}
    L -->|"Yes"| M["Production release and verification"]
    L -->|"No"| N["Create linked business fix story<br/>and implementation / QA work"]
    N --> E
~~~

Drafting the knowledge article, spec and criteria alongside the design supports one combined user/PO approval. Generated business stories follow that approval. They are then evaluated autonomously, without a routine Spark or human QA approval.

In both proposed flows, a resume returns to the affected step: story revision, implementation, QA or review. An exception that requires changing approved behavior, required checks or visual expectations returns to explicit approval and a new applicable version before execution resumes. The exception panel routes configuration-only approvals to the affected profile/reference configuration before resuming the saved checkpoint. UAT rejection creates new linked work; new stories pass the applicable pre-development approval or automated validation. A merged PR is not reopened as an implementation branch.

## Stories and executed evidence

Maintain stable, versioned links through the complete chain:

**Spec → business story → acceptance criteria → tests → executed evidence.**

Criteria are approved with the spec and then mapped onto generated stories. This chain describes traceability, not the order in which approval occurs.

Implementation tasks and QA scenarios link to the business story and its criteria. Generate business stories before development; an implementation task alone does not substitute for a business story.

The automated story evaluator checks completeness, consistency with the approved spec and other stories, and testability. It flags unanswered business questions and contradictory or unverifiable criteria. It may refine derived stories within approved behavior; it requests a decision when approved requirements must change.

For every applicable acceptance criterion, distinguish:

- No test mapped.
- Test defined but not executed.
- Executed and passed.
- Executed and failed.
- Blocked or requiring investigation.

Evaluate the implementation against each criterion using actual assertions and execution evidence. Coverage summaries must distinguish generated tests from executed checks. Required checks remain mandatory even where they are shared across several criteria.

## Common QA policy

Combine a reusable checklist with feature-specific cases:

| Area | Expected coverage |
| --- | --- |
| Expected behavior | Approved user journeys, outcomes and feature-specific acceptance criteria |
| Invalid inputs and boundaries | Invalid, empty, long and boundary values appropriate to the feature |
| Permissions | Allowed and refused operations for the configured roles |
| Data integrity | Correct writes, persistence, relationships and consistency |
| Failure and recovery | Errors, interrupted operations, recovery and duplicate actions where applicable |
| Rendering | Selected views and states, references, clipping, overlap and hidden required controls |
| Accessibility | Checks and thresholds from the effective project/spec quality profile |
| BAU regression | Relevant established behavior completes before merge |
| Performance and security | Configured required checks and thresholds from the effective quality profile |

Use direct logic, API and component tests alongside complete browser journeys. Choose tests based on the behavior being evaluated; a browser click alone is not an assertion of a correct business outcome.

Chrome is required for the initial pilot. Record the actual browser/channel and version in evidence. Other browsers may be configured later without becoming invented pilot requirements.

### Configuration and visual evaluation

| Configuration | Agreed behavior | Values still to configure |
| --- | --- | --- |
| Screens and layouts | Explain dimension, layout and orientation options; users choose appropriate viewport dimensions, views and states | Actual dimensions, views and states |
| Visual references | Users select references, with specific references allowed per spec; record the approved reference versions | Actual images, designs and baseline selections |
| Visual tolerances | Support configurable screenshot tolerances and scoped approved exceptions | Numeric tolerances and approved exceptions |
| Layout checks | Detect clipping, unintended overlap and hidden required controls; failed layout checks remain blocking despite visual tolerances or exceptions | Feature-specific layout assertions |
| Quality profiles | Project profiles define accessibility, performance and security checks/thresholds; approved per-spec overrides are versioned | Actual checks, thresholds and overrides |
| QA environment | Project configuration identifies the test environment; prefer a separate isolated preview per PR and identify its tested build | Actual environment and provisioning details |
| Test-data provision | Explicit To configure placeholder; required tests cannot appear passed without their prerequisites | Data source, setup, reset and ownership |
| Execution limits | Separate repair and pilot/developer exchange limits, using project defaults and caps | Numeric defaults, caps and selected run limits |

A visual pass combines screenshot comparisons and layout results. Tolerances and approved exceptions cannot override failed layout checks. Agents cannot update approved visual expectations or exceptions on their own to make a result green.

Validate required configuration before execution. If a missing prerequisite is encountered, report To configure or Blocked with the affected checks. Do not fabricate evidence or silently convert an unexecuted check to pass.

### QA time and retry history

- For these example flows, select a duration from 48 through 96 hours.
- Start the clock when a runnable build/preview first enters QA. Record waiting before that entry separately.
- Keep the original deadline through clarification, environment blockers, pauses in agent execution, repairs and retries. Record blocked intervals separately while elapsed QA time continues.
- Persist the initial entry time, deadline, blocked intervals and every test/review attempt. Notes, new commits, resumed execution and retry buttons never reset the deadline.
- A deadline breach is recorded and surfaced; expiration never establishes a pass.
- A later pass does not erase an earlier failure. Unexplained failed-then-passing tests remain blocking until investigated.
- Investigation records the cause and disposition with evidence. A confirmed defect still requires resolution and the relevant rerun.
- Track readiness and re-entry history against the original QA entry. A new attempt has its own run identity, not a new handoff deadline.

## Automated code review and repair

The automated reviewer uses a common checklist plus project rules covering spec correctness, error handling, permissions, data integrity, test quality, repository conventions and configured build, lint and security checks.

Run the reviewer separately from the implementation agent, against an identified immutable candidate. It reads the implementation and emits findings; it cannot edit code, tests, approved behavior, required checks or references. The coordinator persists the results and any permitted integration output.

Classify findings as confirmed defects, uncertain findings requiring investigation, or optional improvement suggestions. Confirmed defects and failed mandatory checks block readiness. Optional improvements are advisory. Investigate uncertain findings before treating them as resolved; do not silently recategorize a possible defect as a suggestion.

Repair agents may:

- Fix implementation.
- Adjust implementation tasks within approved behavior.
- Add tests and scenarios.
- Re-execute affected checks and request another independent review.

They must ask before changing approved behavior, required checks or visual expectations. Preserve the requested change, affected versions and the approving actor.

Maintain independent counters and limits for repair rounds and exchanges with the pilot/developer. Project defaults and caps govern each; a pilot may adjust run limits within those caps. The current code-review runner's existing retry settings are not the agreed defaults for this new capability.

Pause on unresolved exceptions or exhausted limits. Show the current candidate, relevant failures, prior attempts, consumed limits, remaining configuration gaps and the decision needed to resume. Resuming preserves retry history and the original QA deadline.

## Final review and release

The final review view brings together:

- Diff and runnable preview.
- Business stories and acceptance coverage.
- Screenshot/reference comparisons and layout findings.
- Direct test and browser journey results, including completed automated BAU regression.
- Independent reviewer findings, investigations, repairs and retry history.
- Missing or blocked configuration, required checks and unresolved exceptions.

Each evidence record identifies the tested commit/build and the applicable spec and configuration versions. Include the effective project profile, approved spec overrides, visual references, test definitions, environment, browser/viewport/state and result provenance where relevant.

New code/build or relevant spec/configuration changes invalidate affected readiness evidence. Evaluation must use the applicable versions instead of a stale green summary.

Readiness requires successful story evaluation, demonstrated satisfaction of applicable acceptance criteria, executed required checks, resolved confirmed defects, investigated uncertain findings and failed-then-passing tests, and a completed independent review. Missing configuration and unexecuted checks remain visible and cannot appear passed.

The PR owner performs the final human review and may merge their own PR. Flowline must not impose a routine second human QA or non-author reviewer requirement for these proposed examples.

Merge leads to a candidate for business-user UAT. Associate UAT acceptance with the candidate being tested. Promote the accepted candidate through the configured release process, and reserve terminal Done for successful production completion. Issue closure or PR merge alone cannot bypass UAT.

## Reusable architecture

Preserve Jac's existing archetype declarations and stored identifiers. Extend the current application patterns; consult the guides shipped with the pinned compiler before editing Jac sources.

| Area | Proposed reusable change | Existing source to extend |
| --- | --- | --- |
| Process definitions | Multiple named/versioned flows, current/proposed variants, project/task scope, explicit storyboard/manual/automated capability metadata | [models.jac](../../models.jac), [flow line service](../../services/flowlines/flowlines.jac), [constants.jac](../../constants.jac) |
| Process UI | Process and variant selection, comparison, role lanes, step details and capability labels | [flow line page](../../pages/(auth)/flowlines.jac), [flow line components](../../components/flowlines/) |
| Traceability | Versioned specs, business stories, criteria, implementation tasks, QA scenarios, tests and evidence relationships | [task service](../../services/tasks/tasks.jac), [board service](../../services/board/board.jac), models |
| Identity and approvals | Account/workspace compatibility investigation, explicit actor identity and approved version records; no self-merge prohibition | [tenancy model](../content/concepts/security.md), [workspace service](../../services/workspace/workspace.jac), [session code](../../lib/session.jac) |
| Configuration | Project quality, environment and execution profiles; approved spec overrides and effective version snapshots | New focused configuration service and UI |
| Evaluation | Story quality, criterion satisfaction, mandatory/advisory findings, unresolved retry investigation and evidence completeness | New evaluation and QA services |
| Execution | Separate implementation and read-only review jobs, adapters, caps, independent counters, leases, cancellation and pause/resume | [agent runner patterns](../../services/agents/runner.jac), [existing review service](../../review/) |
| QA clock and measurement | Durable first-entry clock, blocked intervals, retry history, stage visits, active/wait time and handoffs | New QA schedule/history services, [log service](../../services/log/log.jac), [insights](../../services/insights/insights.jac) |
| Integration and release | Generic Jira/Figma/change-request/environment references and adapter contracts; stage-aware synchronization | [GitHub service](../../services/github/github.jac), [events](../../services/github/events.jac) |

Flowline currently has one flow and one account-owned workspace. Add definition scoping without mixing tasks, counts, transitions or automation between flow variants. Keep draft storyboards separate from operational work and automatic job scheduling.

Use a shared server-side transition policy across create, move, task edit, assistant, scheduled, webhook and automation paths. A status-only update or GitHub auto-done fallback must not bypass the flow's approval, evidence, merge or UAT rules.

Investigate the account/workspace model early. A single-owner storyboard can be demonstrated first; authenticated operational approvals need validated actor/workspace resolution. Do not present a roster assignee name as proof of who approved.

Begin with explicit story-to-PR linkage and define supported cardinality. The existing PR-to-task linker selects one task; support for several stories in one PR requires explicit associations and coverage evaluation for every included story.

## Reviewable upstream contribution stages

### Stage zero Fork and verify the baseline

Create or reuse the authorized fork, with the original repository as upstream, and branch from current upstream dev using the codex prefix. Preserve the MIT license and project conventions. Install the pinned toolchain, start locally and run existing gates before application edits.

Deliverable: a runnable fork and baseline verification record. Keep parent-directory meeting transcripts outside the fork.

### Stage one Process library, then operational flow scoping

The review milestone adds `ProcessDefinitions → ProcessDefinition` under the tenant root. These versioned storyboards coexist with the operational `WorkflowSteps` graph and do not move tasks or fabricate execution state. `ListProcesses`, `InstallProcessExamples` and `SaveProcessNote` support the working review library.

The next operational increment adds project/task/step scope and compatible migration from the existing single flow. Preserve legacy IDs and status mapping. Scope queries, counts, role updates and automation lookups.

Acceptance: several flows coexist without cross-flow moves or data leakage; existing workspaces retain their tasks and history; reads do not perform destructive migration.

### Stage two Four labelled storyboards

Implemented for local review: a generic persisted catalogue, four example definitions, comparison, a read-only diagram and readable step list, step details, shared rules/configuration panels and workspace-owned review notes. The diagram shares Flowline’s theme; operational canvas/lane editing remains separate. Show manual approvals, planned automation, proprietary placeholders and configuration gaps. This milestone has no process executor or simulation results, and produces no delivery evidence.

Acceptance: all four workflows persist and render correctly; before flows show Spark story approval before development; proposed flows place story generation after spec/criteria approval and have no routine intermediate human QA checkpoint. Every final merge review is assigned to the PR owner, with own-PR merge permitted.

This is the first local review milestone for Jason and the team. See [local review instructions](../content/contributing/process-review.md). Notes record feedback only; they do not approve a spec, execute QA or change workflow state.

### Stage three Traceability and approval identity

Add business stories, criteria, implementation tasks, QA scenarios and versioned artifact relationships. Implement story quality results and criterion coverage states. Address actor/workspace resolution in a separately reviewable compatibility change before authoritative multi-user approvals.

Acceptance: the full spec-to-executed-evidence chain is inspectable; generated but unexecuted tests cannot produce pass; approvals identify the actor and approved versions.

### Stage four Project and spec configuration

Add viewport/view/state selection with explanations, Chrome pilot support, reference selection, visual tolerances, scoped exceptions, layout assertions, quality profiles, approved spec overrides, QA environments and separate execution limits/caps. Keep test-data provision explicitly To configure until supplied.

Acceptance: effective configuration is versioned; missing required values are visible and block affected checks; tolerance/exception settings cannot override failed layout checks; pilots can change run limits only within project caps.

### Stage five QA evidence and durable time

Add test execution/result interfaces for logic, API, component and complete browser journeys. Store screenshot comparisons, layout/accessibility/profile results and BAU regression evidence. Implement the first-runnable-build QA clock, blocked intervals, append-only attempt history and failed-then-passing investigation state.

Acceptance: clocks survive worker restarts and browser closure; duplicate events and retries never reset deadlines; blocked time remains part of elapsed QA time; an unexplained failure followed by a pass still blocks readiness.

### Stage six Independent review and readiness

Add the separate read-only reviewer, common/project rule evaluation, finding classification and investigation, evidence aggregation and the final PR-owner review screen. Apply the shared readiness policy to every mutation and synchronization path.

Acceptance: confirmed defects and mandatory failures block; optional suggestions remain advisory; evidence is tied to the current candidate and applicable versions; completed pre-merge BAU regression is required; merge cannot mark the work production-complete.

### Stage seven Autonomous execution and repair

Add the coordinator that continues from user-approved spec/criteria through story validation, implementation, testing, review and permitted repair. Keep repair and pilot/developer exchange budgets independent. Add approval requests for protected changes and an evidence-backed pause/resume queue.

Acceptance: a complete permitted path reaches final PR-owner review without routine intermediate human QA approval; exhausted limits and unresolved exceptions pause honestly; resumes preserve evidence, retry history and the QA deadline.

### Stage eight Integration contracts and pilot demonstration

Connect generic integration adapters as access becomes available. Evaluate the existing proprietary QA agent through its adapter instead of assuming its output satisfies the quality gate. Keep Reactinator, developer agent sets and Ally-specific tools labelled placeholders while unavailable.

Demonstrate a migration item and a BAU item using clearly labelled sample data/configuration. Operational pilot data remains To configure until provided. Include current/proposed measurement comparisons and documentation for configuring another project.

Acceptance: unsupported adapters cannot return success; real checks have real evidence; business-user UAT occurs after merge; the released candidate is identified. Submit each reusable change separately for upstream review.

## Verification plan

Extend the repository's existing smoke gates and add focused gates for the new contracts.

| Verification | Required cases |
| --- | --- |
| Compatibility and tenancy | Existing single-flow migration, stable IDs, multiple flow isolation, unknown/foreign IDs, valid approval actor resolution |
| Four workflow semantics | Pre-development Spark approval only in current examples; proposed spec/criteria approval before autonomous stories; no routine intermediate human QA gate; PR owner may review and merge own PR |
| Traceability | Incomplete/inconsistent/untestable stories, missing criteria, missing test links, generated-only tests, partial execution and criterion-level implementation failures |
| Configuration and rendering | User-selected dimensions and states, Chrome pilot execution, spec references, clipping/overlap/hidden controls, tolerance and exception boundaries, approved profile overrides |
| QA timing | Initial preview readiness, earlier waiting, clarification/blocker/pause intervals, resumed runs, new commits, retries, deadline breach, duplicate events and worker restarts |
| Retry investigation | Failed-then-passing remains blocking without investigation; retained failed attempts; confirmed defect requires resolution |
| Reviewer and repair | Read-only implementation access, mandatory/advisory classification, uncertain finding investigation, independent repair/exchange limits, caps and approval-required changes |
| Readiness and release | Stale commit/build/spec/config evidence, unexecuted mandatory checks, completed pre-merge BAU regression, issue-close/merge event ordering, post-merge UAT and production completion |

Use the pinned Jac formatter and per-file compiler checks, a real app boot, relevant API/automation/webhook/agent/browser smoke gates, two-account isolation checks when ownership changes, and the deployment dry run. Document every new routed walker in the existing API reference. Keep test doubles and simulated example results explicitly labelled.

Calibrate the QA evaluator with intentionally defective sample variants such as broken behavior, clipping, hidden required controls and faulty retry handling. Evaluate whether the configured checks actually catch them.

## Measurement

For each stage visit, capture arrival, work start, completion, actor/owner, artifacts and rework links. Report active time, waiting time, blocked time, handoffs, end-to-end Jira-to-production time, throughput and post-release defects. Preserve the distinction between measured results, reported observations and configured targets.

Do not infer actual work time from a task's last edit. In proposed flows, clarification and environment waiting after initial QA entry remain inside elapsed QA time, with blocked time separately visible.

## Values deliberately left to configuration

Actual screen dimensions, layout/view/state selections, visual references, numeric repair/exchange limits and caps, exact quality thresholds, per-spec overrides, environment setup and test-data provision remain project/spec values. Chrome for the initial pilot and a selected 48–96-hour QA deadline for these demonstration flows are settled requirements.

No additional Ally-specific policies, tool behavior, quality numbers or test data are assumed.
