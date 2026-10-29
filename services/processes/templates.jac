"""Example process catalogue. Domain-specific adapters are placeholders; every
record is a storyboard, never a promise that an executor or QA check ran."""

glob COMMON_POLICIES: list[dict[str, str]] = [
         {
             'title': 'Stories and traceability',
             'detail': 'Generate business stories before development, with linked implementation tasks and QA '
             'scenarios. Preserve spec → story → acceptance criteria → tests → executed evidence. Validate '
             'completeness, consistency and testability, then evaluate implemented behavior against each '
             'criterion. Generated tests alone never establish a pass.'
         },
         {
             'title': 'QA depth',
             'detail': 'Use a common checklist plus feature-specific checks for expected behavior, invalid inputs and '
             'boundaries, permissions, data integrity, failure and recovery, rendering, accessibility and '
             'relevant BAU regressions. Execute direct logic, API and component tests alongside complete '
             'browser journeys.'
         },
         {
             'title': 'Rendering',
             'detail': 'Compare screenshots to the selected references at configured viewports and states. Also check '
             'clipping, overlap and hidden required controls. Approved visual exceptions and tolerances '
             'cannot override failed layout checks.'
         },
         {
             'title': 'Independent code review',
             'detail': 'Use a separate read-only reviewer run. Apply a common checklist and project rules for spec '
             'correctness, error handling, permissions, data integrity, test quality, conventions and '
             'configured build/lint/security checks. Confirmed defects and mandatory failures block '
             'readiness; optional improvements are advisory; uncertain findings require investigation.'
         },
         {
             'title': 'Repair boundaries',
             'detail': 'Agents may fix implementation, adjust implementation tasks and add tests. Ask before changing '
             'approved behavior, required checks or visual expectations. Pause for unresolved exceptions or '
             'exhausted repair/exchange limits, with evidence and the decision needed to resume.'
         },
         {
             'title': 'QA time and retry history',
             'detail': 'Select a 48–96-hour deadline. Start the clock when a runnable build/preview first enters QA. '
             'Record earlier waiting separately. Keep the clock running during clarification, environment '
             'blockers and paused agents; report blocked time separately. Repairs, commits and retries never '
             'reset it. Retain every attempt; unexplained failed-then-passing checks remain blocking until '
             'investigated; confirmed defects still require resolution.'
         },
         {
             'title': 'Final evidence and merge',
             'detail': 'Bring together the diff, preview, story/acceptance coverage, rendering comparisons, test '
             'results and review findings. Identify the tested commit/build and applicable spec/configuration '
             'versions. Invalidate affected evidence after changes. Missing configuration or unexecuted '
             'required checks cannot be passed. The PR owner performs the final human review and may merge '
             'their own PR.'
         },
         {
             'title': 'Regression and UAT',
             'detail': 'Automated BAU regression completes before merge. Business-user UAT occurs after merge, before '
             'production. UAT failures return to implementation and verification; changed approved behavior '
             'returns to approval.'
         },
         {
             'title': 'Implementation status',
             'detail': 'This is a persisted storyboard, not an executable delivery pipeline. Flow selection, '
             'comparison, step inspection and saved review notes work in this build. All depicted automation, '
             'enforced gates, timers, evidence collection and integrations remain planned or placeholders. No '
             'QA has run for these example workflows.'
         }
     ],
     DEMO_CONFIGURATION: list[dict[str, str]] = [
         {
             'title': 'QA deadline',
             'status': 'To configure',
             'detail': 'Select one deadline from 48–96 hours for each example run. No duration has been selected. Start '
             'at the first runnable build/preview entering QA; record earlier waiting separately.'
         },
         {
             'title': 'Chrome, screens and states',
             'status': 'To configure',
             'detail': 'Chrome is required for the initial pilot. Select viewport width and height for the software, '
             'relevant routes/views and states (for example loading, empty, error, permission or populated '
             'states). These are options, not a prescribed screen matrix.'
         },
         {
             'title': 'Visual references',
             'status': 'To configure',
             'detail': 'Choose versioned references, including references specific to a spec; choose screenshot '
             'tolerances and approved exceptions. Neither tolerances nor exceptions may override failed '
             'clipping, overlap or hidden-required-control layout checks.'
         },
         {
             'title': 'Project quality profile',
             'status': 'To configure',
             'detail': 'Choose accessibility, performance and security checks and numeric thresholds; approve per-spec '
             'overrides explicitly. Missing configuration and required checks that have not run must never '
             'appear passed.'
         },
         {
             'title': 'QA environment',
             'status': 'To configure',
             'detail': 'Select the project QA environment. Prefer an isolated preview for each PR. Provisioning and CI '
             'adapters are unimplemented.'
         },
         {
             'title': 'Test-data provision',
             'status': 'To configure',
             'detail': 'Explicit placeholder. No Ally test data, credentials, fixture provisioning or reset behavior is '
             'supplied.'
         },
         {
             'title': 'Repair and exchange limits',
             'status': 'To configure',
             'detail': 'Configure repair-round limits separately from exchanges with the pilot/developer, with project '
             'defaults and caps. Pilots may adjust run limits within those caps. Numeric values are unset.'
         }
     ],
     DEMO_PROCESSES: list[dict[str, any]] = [
         {
             'template_key': 'react-current',
             'title': 'React migration process · Current',
             'family': 'react',
             'variant': 'current',
             'summary': 'Jacob generates the migration spec. QA staff approve business stories and AC in Spark; '
             'developers or Jacob implement, then QA, review, merge, UAT and production.',
             'steps': [
                 {
                     'id': 'intake',
                     'title': 'Jira migration item',
                     'owner': 'Jacob / PO',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Select the migration item in Jira, bound its scope and assign an owner.',
                     'guard': 'Keep intake, earlier waiting and work time distinct from the QA deadline.',
                     'inputs': 'Migration backlog',
                     'outputs': 'Selected and assigned item',
                     'tool': 'Jira — Placeholder',
                     'x': '280',
                     'y': '32'
                 },
                 {
                     'id': 'reactinator',
                     'title': 'Run Reactinator',
                     'owner': 'Jacob',
                     'mode': 'Human',
                     'status': 'Placeholder',
                     'detail': 'Jacob runs Reactinator against the migration scope. Its proprietary agent set is '
                     'unavailable; this stage records the handoff only.',
                     'guard': 'Reactinator and any Ally integration are placeholders.',
                     'inputs': 'Migration scope + existing UI',
                     'outputs': 'Generated spec draft',
                     'tool': 'Reactinator — Placeholder',
                     'x': '280',
                     'y': '196'
                 },
                 {
                     'id': 'spec',
                     'title': 'Spec + work items',
                     'owner': 'Jacob',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Prepare the migration specification, business stories and acceptance criteria. Link '
                     'implementation tasks and QA scenarios before development.',
                     'guard': 'Separate business outcomes from implementation tasks.',
                     'inputs': 'Reactinator output + migration scope',
                     'outputs': 'Spec, business stories, AC + QA scenarios',
                     'tool': 'Story generation integration — Placeholder',
                     'x': '280',
                     'y': '360'
                 },
                 {
                     'id': 'story_approval',
                     'title': 'Approve stories + AC',
                     'owner': 'QA staff in Spark',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'QA staff in Spark review generated business stories and acceptance criteria before '
                     'development. Return incomplete or untestable stories for revision.',
                     'guard': 'No implementation starts before this current-process approval.',
                     'inputs': 'Generated stories, AC and QA scenarios',
                     'outputs': 'Approved stories and acceptance criteria',
                     'tool': 'Spark — Placeholder',
                     'x': '280',
                     'y': '524'
                 },
                 {
                     'id': 'dev',
                     'title': 'Developer implementation',
                     'owner': 'Developers',
                     'mode': 'Human',
                     'status': 'Placeholder',
                     'detail': 'Assigned developers implement the approved work using the developer agent set.',
                     'guard': 'Keep the approved behavior and acceptance criteria intact.',
                     'inputs': 'Approved stories + linked implementation tasks',
                     'outputs': 'Implementation and tests',
                     'tool': 'Developer agent set — Placeholder',
                     'x': '28',
                     'y': '688'
                 },
                 {
                     'id': 'jacob',
                     'title': 'Jacob implements',
                     'owner': 'Jacob',
                     'mode': 'Human',
                     'status': 'Placeholder',
                     'detail': 'Alternatively Jacob implements the migration himself using Reactinator.',
                     'guard': 'This is an alternative implementation branch, not an extra approval.',
                     'inputs': 'Approved stories and acceptance criteria',
                     'outputs': 'Implementation and tests',
                     'tool': 'Reactinator — Placeholder',
                     'x': '532',
                     'y': '688'
                 },
                 {
                     'id': 'pr',
                     'title': 'PR + runnable preview',
                     'owner': 'PR owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Open or update the PR and provide a runnable build in the configured QA environment. '
                     'Prefer an isolated preview per PR.',
                     'guard': 'A PR link alone does not start QA. Wait until a runnable build first enters QA.',
                     'inputs': 'Implementation + linked tasks',
                     'outputs': 'PR, commit/build identity + runnable preview',
                     'tool': 'Git provider / preview adapter — Placeholder',
                     'x': '280',
                     'y': '852'
                 },
                 {
                     'id': 'qa',
                     'title': 'QA + BAU regression',
                     'owner': 'QA staff',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Execute the common checklist and feature-specific checks. Combine '
                     'logic/API/component tests with complete Chrome journeys, visual/layout checks, '
                     'accessibility and configured performance/security checks. Automated BAU regression '
                     'must finish before merge.',
                     'guard': 'Select a 48–96-hour deadline; the QA clock starts here on first runnable entry. '
                     'Failures, missing configuration and required checks not run block readiness. Retries '
                     'never reset the clock.',
                     'inputs': 'Runnable build, stories/AC, QA scenarios, configured profile + data',
                     'outputs': 'Executed evidence per acceptance criterion; defects and retry history',
                     'tool': 'Spark — Placeholder; QA work — Manual; test data — To configure',
                     'x': '280',
                     'y': '1016'
                 },
                 {
                     'id': 'review',
                     'title': 'Read-only code review',
                     'owner': 'PR reviewer / owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Review implementation against spec and project rules, including errors, permissions, '
                     'data integrity, test quality and build/lint/security results. A proposed reviewer '
                     'run is separate and read-only.',
                     'guard': 'Confirmed defects and failed mandatory checks block. Suggestions are advisory. '
                     'Investigate uncertain findings.',
                     'inputs': 'Diff, approved spec, project rules + executed results',
                     'outputs': 'Classified findings and review evidence',
                     'tool': 'Independent reviewer — Planned',
                     'x': '280',
                     'y': '1180'
                 },
                 {
                     'id': 'evidence',
                     'title': 'Assemble review evidence',
                     'owner': 'PR owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Bring together the diff, preview, story/AC coverage, rendering comparisons, executed '
                     'test results and review findings.',
                     'guard': 'Identify tested commit/build and applicable spec/config versions. Missing '
                     'configuration and unexecuted required checks cannot appear passed. Changed inputs '
                     'invalidate affected evidence.',
                     'inputs': 'Versioned artifacts, test results and classified findings',
                     'outputs': 'Evidence bundle for the current PR revision',
                     'tool': 'Evidence bundle — Planned',
                     'x': '280',
                     'y': '1344'
                 },
                 {
                     'id': 'final',
                     'title': 'Final human review',
                     'owner': 'PR owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Review the diff, preview, story/AC coverage, rendering comparisons, test results and '
                     'findings together. This is the last human checkpoint before merge.',
                     'guard': 'Evidence must identify the tested commit/build and spec/config versions. Missing '
                     'config or unexecuted required checks cannot appear passed.',
                     'inputs': 'Versioned evidence bundle + PR diff',
                     'outputs': 'Human decision: merge or return for repair',
                     'tool': 'Evidence bundle UI / enforcement — Planned',
                     'x': '280',
                     'y': '1508'
                 },
                 {
                     'id': 'merge',
                     'title': 'Merge',
                     'owner': 'PR owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'The PR owner may merge their own PR after the final review.',
                     'guard': 'All mandatory checks resolved; automated BAU regression completed before merge.',
                     'inputs': 'Reviewed PR + current evidence',
                     'outputs': 'Merged commit',
                     'tool': 'Git provider — Placeholder',
                     'x': '280',
                     'y': '1672'
                 },
                 {
                     'id': 'uat',
                     'title': 'Business-user UAT',
                     'owner': 'Business users',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Business users validate the merged change in the configured UAT environment.',
                     'guard': 'UAT happens after merge. Defects go back through repair and verification; behavior '
                     'changes require approval.',
                     'inputs': 'Merged build + approved behavior',
                     'outputs': 'Acceptance or linked defects',
                     'tool': 'UAT environment — To configure',
                     'x': '280',
                     'y': '1836'
                 },
                 {
                     'id': 'production',
                     'title': 'Production',
                     'owner': 'Release owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Promote the accepted build using the project release process.',
                     'guard': 'Business-user acceptance and project release conditions; no proprietary release '
                     'requirements assumed.',
                     'inputs': 'Accepted merged build',
                     'outputs': 'Production release',
                     'tool': 'Release integration — Placeholder',
                     'x': '280',
                     'y': '2000'
                 },
                 {
                     'id': 'fix_story',
                     'title': 'Create linked fix story',
                     'owner': 'PO / developer owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Create and assign new linked work for a UAT rejection. The merged PR remains merged; '
                     'fixes use a new PR and repeat QA.',
                     'guard': 'New stories pass current-process QA approval before development.',
                     'inputs': 'UAT defect evidence',
                     'outputs': 'Linked fix story, tasks and QA scenarios',
                     'tool': 'Jira — Placeholder',
                     'x': '28',
                     'y': '2000'
                 }
             ],
             'transitions': [
                 {
                     'source': 'intake',
                     'target': 'reactinator',
                     'label': '',
                     'kind': 'forward'
                 },
                 {
                     'source': 'reactinator',
                     'target': 'spec',
                     'label': '',
                     'kind': 'forward'
                 },
                 {
                     'source': 'spec',
                     'target': 'story_approval',
                     'label': '',
                     'kind': 'forward'
                 },
                 {
                     'source': 'story_approval',
                     'target': 'dev',
                     'label': 'Assign developers',
                     'kind': 'forward'
                 },
                 {
                     'source': 'story_approval',
                     'target': 'jacob',
                     'label': 'Or Jacob',
                     'kind': 'forward'
                 },
                 {'source': 'dev', 'target': 'pr', 'label': '', 'kind': 'forward'},
                 {'source': 'jacob', 'target': 'pr', 'label': '', 'kind': 'forward'},
                 {
                     'source': 'story_approval',
                     'target': 'spec',
                     'label': 'Revise stories',
                     'kind': 'return'
                 },
                 {'source': 'pr', 'target': 'qa', 'label': '', 'kind': 'forward'},
                 {
                     'source': 'qa',
                     'target': 'review',
                     'label': 'Checks complete',
                     'kind': 'forward'
                 },
                 {
                     'source': 'review',
                     'target': 'evidence',
                     'label': 'Findings resolved',
                     'kind': 'forward'
                 },
                 {
                     'source': 'evidence',
                     'target': 'final',
                     'label': 'Current evidence',
                     'kind': 'forward'
                 },
                 {
                     'source': 'final',
                     'target': 'merge',
                     'label': 'Human agrees',
                     'kind': 'forward'
                 },
                 {'source': 'merge', 'target': 'uat', 'label': '', 'kind': 'forward'},
                 {
                     'source': 'uat',
                     'target': 'production',
                     'label': 'Accepted',
                     'kind': 'forward'
                 },
                 {
                     'source': 'qa',
                     'target': 'dev',
                     'label': 'Defect → implementer',
                     'kind': 'return'
                 },
                 {
                     'source': 'review',
                     'target': 'dev',
                     'label': 'Confirmed defect',
                     'kind': 'return'
                 },
                 {
                     'source': 'final',
                     'target': 'dev',
                     'label': 'Changes requested',
                     'kind': 'return'
                 },
                 {
                     'source': 'uat',
                     'target': 'fix_story',
                     'label': 'Rejected',
                     'kind': 'forward'
                 },
                 {
                     'source': 'fix_story',
                     'target': 'spec',
                     'label': 'New work → approval',
                     'kind': 'return'
                 }
             ],
             'policies': COMMON_POLICIES,
             'configuration': DEMO_CONFIGURATION
         },
         {
             'template_key': 'bau-current',
             'title': 'BAU process · Current',
             'family': 'bau',
             'variant': 'current',
             'summary': 'UX and the PO iterate in Figma. The PO approves the design, a knowledge article/spec becomes '
             'epics and stories, QA approves them in Spark, and developers implement. Testing matches the '
             'migration process.',
             'steps': [
                 {
                     'id': 'intake',
                     'title': 'Business need · Jira',
                     'owner': 'PO',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Describe the business problem, intended outcome and relevant constraints.',
                     'guard': 'Capture requirements without inventing bank-specific controls.',
                     'inputs': 'Business request',
                     'outputs': 'Design brief',
                     'tool': 'Business intake — Manual',
                     'x': '280',
                     'y': '32'
                 },
                 {
                     'id': 'design',
                     'title': 'UX designs in Figma',
                     'owner': 'UX',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'UX works with the PO in a design-feedback cycle, including relevant views and '
                     'states.',
                     'guard': 'Return here when the PO requests design changes.',
                     'inputs': 'Business need + PO feedback',
                     'outputs': 'Design proposal and references',
                     'tool': 'Figma — Manual; connector Placeholder',
                     'x': '280',
                     'y': '196'
                 },
                 {
                     'id': 'design_approval',
                     'title': 'PO approves design',
                     'owner': 'PO',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'The PO reviews the design with UX and approves it or requests another iteration.',
                     'guard': 'An approval is required before producing the agreed delivery documentation.',
                     'inputs': 'UX design + business intent',
                     'outputs': 'Approved design or feedback',
                     'tool': 'PO review — Manual',
                     'x': '280',
                     'y': '360'
                 },
                 {
                     'id': 'spec',
                     'title': 'Knowledge article + spec',
                     'owner': 'PO / author',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Generate the knowledge article and specification from the approved design. Keep '
                     'documentation aligned with approved business behavior; epics and stories follow in '
                     'the next step.',
                     'guard': 'Knowledge article and spec must describe consistent approved behavior.',
                     'inputs': 'Approved design + requirements',
                     'outputs': 'Knowledge article + specification',
                     'tool': 'Knowledge / story generator — Placeholder',
                     'x': '280',
                     'y': '524'
                 },
                 {
                     'id': 'stories',
                     'title': 'Epics + business stories',
                     'owner': 'PO / story author',
                     'mode': 'Human',
                     'status': 'Placeholder',
                     'detail': 'Break the spec into epics and business stories with acceptance criteria, linked '
                     'implementation tasks and QA scenarios.',
                     'guard': 'Stories describe business outcomes before development.',
                     'inputs': 'Approved design, knowledge article + spec',
                     'outputs': 'Epics, business stories, AC, tasks + QA scenarios',
                     'tool': 'Story generator — Placeholder',
                     'x': '280',
                     'y': '688'
                 },
                 {
                     'id': 'story_approval',
                     'title': 'Approve stories + AC',
                     'owner': 'QA staff in Spark',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'QA staff in Spark approve generated business stories and acceptance criteria before '
                     'development.',
                     'guard': 'Revise incomplete, inconsistent or untestable stories before assignment.',
                     'inputs': 'Epics, business stories, AC + QA scenarios',
                     'outputs': 'Approved stories and acceptance criteria',
                     'tool': 'Spark — Placeholder',
                     'x': '280',
                     'y': '852'
                 },
                 {
                     'id': 'dev',
                     'title': 'Assign + implement',
                     'owner': 'Developers',
                     'mode': 'Human',
                     'status': 'Placeholder',
                     'detail': 'Assign stories to developers. Implement with the developer agent set, keeping '
                     'business stories linked to tasks and QA scenarios.',
                     'guard': 'Approved stories and AC precede development.',
                     'inputs': 'Approved epics/stories and linked tasks',
                     'outputs': 'Implementation and tests',
                     'tool': 'Developer agent set — Placeholder',
                     'x': '280',
                     'y': '1016'
                 },
                 {
                     'id': 'pr',
                     'title': 'PR + runnable preview',
                     'owner': 'PR owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Open or update the PR and provide a runnable build in the configured QA environment. '
                     'Prefer an isolated preview per PR.',
                     'guard': 'A PR link alone does not start QA. Wait until a runnable build first enters QA.',
                     'inputs': 'Implementation + linked tasks',
                     'outputs': 'PR, commit/build identity + runnable preview',
                     'tool': 'Git provider / preview adapter — Placeholder',
                     'x': '280',
                     'y': '1180'
                 },
                 {
                     'id': 'qa',
                     'title': 'QA + BAU regression',
                     'owner': 'QA staff',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Execute the common checklist and feature-specific checks. Combine '
                     'logic/API/component tests with complete Chrome journeys, visual/layout checks, '
                     'accessibility and configured performance/security checks. Automated BAU regression '
                     'must finish before merge.',
                     'guard': 'Select a 48–96-hour deadline; the QA clock starts here on first runnable entry. '
                     'Failures, missing configuration and required checks not run block readiness. Retries '
                     'never reset the clock.',
                     'inputs': 'Runnable build, stories/AC, QA scenarios, configured profile + data',
                     'outputs': 'Executed evidence per acceptance criterion; defects and retry history',
                     'tool': 'Spark — Placeholder; QA work — Manual; test data — To configure',
                     'x': '280',
                     'y': '1344'
                 },
                 {
                     'id': 'review',
                     'title': 'Read-only code review',
                     'owner': 'PR reviewer / owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Review implementation against spec and project rules, including errors, permissions, '
                     'data integrity, test quality and build/lint/security results. A proposed reviewer '
                     'run is separate and read-only.',
                     'guard': 'Confirmed defects and failed mandatory checks block. Suggestions are advisory. '
                     'Investigate uncertain findings.',
                     'inputs': 'Diff, approved spec, project rules + executed results',
                     'outputs': 'Classified findings and review evidence',
                     'tool': 'Independent reviewer — Planned',
                     'x': '280',
                     'y': '1508'
                 },
                 {
                     'id': 'evidence',
                     'title': 'Assemble review evidence',
                     'owner': 'PR owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Bring together the diff, preview, story/AC coverage, rendering comparisons, executed '
                     'test results and review findings.',
                     'guard': 'Identify tested commit/build and applicable spec/config versions. Missing '
                     'configuration and unexecuted required checks cannot appear passed. Changed inputs '
                     'invalidate affected evidence.',
                     'inputs': 'Versioned artifacts, test results and classified findings',
                     'outputs': 'Evidence bundle for the current PR revision',
                     'tool': 'Evidence bundle — Planned',
                     'x': '280',
                     'y': '1672'
                 },
                 {
                     'id': 'final',
                     'title': 'Final human review',
                     'owner': 'PR owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Review the diff, preview, story/AC coverage, rendering comparisons, test results and '
                     'findings together. This is the last human checkpoint before merge.',
                     'guard': 'Evidence must identify the tested commit/build and spec/config versions. Missing '
                     'config or unexecuted required checks cannot appear passed.',
                     'inputs': 'Versioned evidence bundle + PR diff',
                     'outputs': 'Human decision: merge or return for repair',
                     'tool': 'Evidence bundle UI / enforcement — Planned',
                     'x': '280',
                     'y': '1836'
                 },
                 {
                     'id': 'merge',
                     'title': 'Merge',
                     'owner': 'PR owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'The PR owner may merge their own PR after the final review.',
                     'guard': 'All mandatory checks resolved; automated BAU regression completed before merge.',
                     'inputs': 'Reviewed PR + current evidence',
                     'outputs': 'Merged commit',
                     'tool': 'Git provider — Placeholder',
                     'x': '280',
                     'y': '2000'
                 },
                 {
                     'id': 'uat',
                     'title': 'Business-user UAT',
                     'owner': 'Business users',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Business users validate the merged change in the configured UAT environment.',
                     'guard': 'UAT happens after merge. Defects go back through repair and verification; behavior '
                     'changes require approval.',
                     'inputs': 'Merged build + approved behavior',
                     'outputs': 'Acceptance or linked defects',
                     'tool': 'UAT environment — To configure',
                     'x': '280',
                     'y': '2164'
                 },
                 {
                     'id': 'production',
                     'title': 'Production',
                     'owner': 'Release owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Promote the accepted build using the project release process.',
                     'guard': 'Business-user acceptance and project release conditions; no proprietary release '
                     'requirements assumed.',
                     'inputs': 'Accepted merged build',
                     'outputs': 'Production release',
                     'tool': 'Release integration — Placeholder',
                     'x': '280',
                     'y': '2328'
                 },
                 {
                     'id': 'fix_story',
                     'title': 'Create linked fix story',
                     'owner': 'PO / developer owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Create and assign new work for UAT rejection. Fixes use a new PR and repeat QA; '
                     'behavior changes also return to UX/PO review.',
                     'guard': 'New business stories require QA approval in Spark before development.',
                     'inputs': 'UAT defect evidence',
                     'outputs': 'Linked fix story and implementation/QA tasks',
                     'tool': 'Jira — Placeholder',
                     'x': '28',
                     'y': '2328'
                 }
             ],
             'transitions': [
                 {
                     'source': 'intake',
                     'target': 'design',
                     'label': '',
                     'kind': 'forward'
                 },
                 {
                     'source': 'design',
                     'target': 'design_approval',
                     'label': '',
                     'kind': 'forward'
                 },
                 {
                     'source': 'design_approval',
                     'target': 'design',
                     'label': 'UX / PO iteration',
                     'kind': 'return'
                 },
                 {
                     'source': 'design_approval',
                     'target': 'spec',
                     'label': 'Approved',
                     'kind': 'forward'
                 },
                 {
                     'source': 'spec',
                     'target': 'stories',
                     'label': '',
                     'kind': 'forward'
                 },
                 {
                     'source': 'stories',
                     'target': 'story_approval',
                     'label': '',
                     'kind': 'forward'
                 },
                 {
                     'source': 'story_approval',
                     'target': 'stories',
                     'label': 'Revise stories',
                     'kind': 'return'
                 },
                 {
                     'source': 'story_approval',
                     'target': 'dev',
                     'label': 'Assign',
                     'kind': 'forward'
                 },
                 {'source': 'dev', 'target': 'pr', 'label': '', 'kind': 'forward'},
                 {'source': 'pr', 'target': 'qa', 'label': '', 'kind': 'forward'},
                 {'source': 'qa', 'target': 'review', 'label': '', 'kind': 'forward'},
                 {
                     'source': 'review',
                     'target': 'evidence',
                     'label': '',
                     'kind': 'forward'
                 },
                 {
                     'source': 'evidence',
                     'target': 'final',
                     'label': 'Current evidence',
                     'kind': 'forward'
                 },
                 {
                     'source': 'final',
                     'target': 'merge',
                     'label': 'Human agrees',
                     'kind': 'forward'
                 },
                 {'source': 'merge', 'target': 'uat', 'label': '', 'kind': 'forward'},
                 {
                     'source': 'uat',
                     'target': 'production',
                     'label': 'Accepted',
                     'kind': 'forward'
                 },
                 {'source': 'qa', 'target': 'dev', 'label': 'Defect', 'kind': 'return'},
                 {
                     'source': 'review',
                     'target': 'dev',
                     'label': 'Confirmed defect',
                     'kind': 'return'
                 },
                 {
                     'source': 'final',
                     'target': 'dev',
                     'label': 'Changes requested',
                     'kind': 'return'
                 },
                 {
                     'source': 'uat',
                     'target': 'fix_story',
                     'label': 'Rejected',
                     'kind': 'forward'
                 },
                 {
                     'source': 'fix_story',
                     'target': 'stories',
                     'label': 'New work → QA approval',
                     'kind': 'return'
                 },
                 {
                     'source': 'fix_story',
                     'target': 'design',
                     'label': 'Behavior change',
                     'kind': 'return'
                 }
             ],
             'policies': COMMON_POLICIES,
             'configuration': DEMO_CONFIGURATION
         },
         {
             'template_key': 'react-proposed',
             'title': 'React migration process · Proposed',
             'family': 'react',
             'variant': 'proposed',
             'summary': 'Approve the spec and AC once, then let story validation, implementation, testing, independent '
             'review and bounded repair run autonomously. The PR owner makes the final human decision; UAT '
             'follows merge.',
             'steps': [
                 {
                     'id': 'intake',
                     'title': 'Jira migration scope',
                     'owner': 'Jacob / user',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Provide the goal, constraints and available references. Identify the project quality '
                     'profile and configuration gaps.',
                     'guard': 'No proprietary requirements or agent behavior inferred.',
                     'inputs': 'Business request or migration scope',
                     'outputs': 'Bounded request + references',
                     'tool': 'Jira — Placeholder; Reactinator output — Placeholder',
                     'x': '280',
                     'y': '32'
                 },
                 {
                     'id': 'spec',
                     'title': 'Generate spec + AC',
                     'owner': 'Specification agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Generate a versioned specification and acceptance criteria from scope and '
                     'references. Use a replaceable Reactinator adapter; proprietary behavior is not '
                     'supplied.',
                     'guard': 'Surface ambiguity for user approval; keep selected visual references versioned.',
                     'inputs': 'Scope + references + project profile',
                     'outputs': 'Draft spec and acceptance criteria',
                     'tool': 'Spec generator — Planned; proprietary adapter Placeholder',
                     'x': '280',
                     'y': '196'
                 },
                 {
                     'id': 'approval',
                     'title': 'Approve spec + AC',
                     'owner': 'User / PO',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Review and approve the generated specification and acceptance criteria. After this '
                     'checkpoint, routine story validation, implementation, testing, review and repair run '
                     'autonomously in the proposed design.',
                     'guard': 'Changes to approved behavior, required checks or visual expectations require renewed '
                     'approval.',
                     'inputs': 'Versioned spec, AC, references and configuration',
                     'outputs': 'Approved behavior baseline',
                     'tool': 'Versioned approval enforcement — Planned',
                     'x': '280',
                     'y': '360'
                 },
                 {
                     'id': 'stories',
                     'title': 'Generate + validate stories',
                     'owner': 'Story agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Create business stories before development, linked implementation tasks and QA '
                     'scenarios. Evaluate completeness, consistency and testability automatically. Repair '
                     'story structure without altering approved behavior.',
                     'guard': 'No routine intermediate human QA approval. Unresolved ambiguity or requested behavior '
                     'change pauses for a decision.',
                     'inputs': 'Approved spec and acceptance criteria',
                     'outputs': 'Validated stories, tasks, QA scenarios + trace links',
                     'tool': 'Story validator — Planned',
                     'x': '280',
                     'y': '524'
                 },
                 {
                     'id': 'dev',
                     'title': 'Implement + add tests',
                     'owner': 'Implementation agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Implement linked tasks and tests against approved stories and criteria. Agents may '
                     'adjust tasks and add tests within the approved baseline.',
                     'guard': 'Generating tests alone never establishes a pass.',
                     'inputs': 'Validated stories + approved behavior',
                     'outputs': 'Implementation, tests and trace links',
                     'tool': 'Developer agent set — Placeholder',
                     'x': '280',
                     'y': '688'
                 },
                 {
                     'id': 'pr',
                     'title': 'PR + runnable preview',
                     'owner': 'Implementation agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Open or update the PR and provide a runnable build in the configured QA environment. '
                     'Prefer an isolated preview per PR.',
                     'guard': 'A PR link alone does not start QA. Wait until a runnable build first enters QA.',
                     'inputs': 'Implementation + linked tasks',
                     'outputs': 'PR, commit/build identity + runnable preview',
                     'tool': 'Git provider / preview adapter — Placeholder',
                     'x': '280',
                     'y': '852'
                 },
                 {
                     'id': 'qa',
                     'title': 'QA + BAU regression',
                     'owner': 'QA agents',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Execute the common checklist and feature-specific checks. Combine '
                     'logic/API/component tests with complete Chrome journeys, visual/layout checks, '
                     'accessibility and configured performance/security checks. Automated BAU regression '
                     'must finish before merge.',
                     'guard': 'Select a 48–96-hour deadline; the QA clock starts here on first runnable entry. '
                     'Failures, missing configuration and required checks not run block readiness. Retries '
                     'never reset the clock.',
                     'inputs': 'Runnable build, stories/AC, QA scenarios, configured profile + data',
                     'outputs': 'Executed evidence per acceptance criterion; defects and retry history',
                     'tool': 'QA harness — Planned; test data — To configure',
                     'x': '280',
                     'y': '1016'
                 },
                 {
                     'id': 'review',
                     'title': 'Read-only code review',
                     'owner': 'Independent reviewer agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Review implementation against spec and project rules, including errors, permissions, '
                     'data integrity, test quality and build/lint/security results. A proposed reviewer '
                     'run is separate and read-only.',
                     'guard': 'Confirmed defects and failed mandatory checks block. Suggestions are advisory. '
                     'Investigate uncertain findings.',
                     'inputs': 'Diff, approved spec, project rules + executed results',
                     'outputs': 'Classified findings and review evidence',
                     'tool': 'Independent reviewer — Planned',
                     'x': '280',
                     'y': '1180'
                 },
                 {
                     'id': 'evidence',
                     'title': 'Assemble review evidence',
                     'owner': 'Evidence agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Bring together the diff, preview, story/AC coverage, rendering comparisons, executed '
                     'test results and review findings.',
                     'guard': 'Identify tested commit/build and applicable spec/config versions. Missing '
                     'configuration and unexecuted required checks cannot appear passed. Changed inputs '
                     'invalidate affected evidence.',
                     'inputs': 'Versioned artifacts, test results and classified findings',
                     'outputs': 'Evidence bundle for the current PR revision',
                     'tool': 'Evidence bundle — Planned',
                     'x': '280',
                     'y': '1344'
                 },
                 {
                     'id': 'final',
                     'title': 'Final human review',
                     'owner': 'PR owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Review the diff, preview, story/AC coverage, rendering comparisons, test results and '
                     'findings together. This is the last human checkpoint before merge.',
                     'guard': 'Evidence must identify the tested commit/build and spec/config versions. Missing '
                     'config or unexecuted required checks cannot appear passed.',
                     'inputs': 'Versioned evidence bundle + PR diff',
                     'outputs': 'Human decision: merge or return for repair',
                     'tool': 'Evidence bundle UI / enforcement — Planned',
                     'x': '280',
                     'y': '1508'
                 },
                 {
                     'id': 'merge',
                     'title': 'Merge',
                     'owner': 'PR owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'The PR owner may merge their own PR after the final review.',
                     'guard': 'All mandatory checks resolved; automated BAU regression completed before merge.',
                     'inputs': 'Reviewed PR + current evidence',
                     'outputs': 'Merged commit',
                     'tool': 'Git provider — Placeholder',
                     'x': '280',
                     'y': '1672'
                 },
                 {
                     'id': 'uat',
                     'title': 'Business-user UAT',
                     'owner': 'Business users',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Business users validate the merged change in the configured UAT environment.',
                     'guard': 'UAT happens after merge. Defects go back through repair and verification; behavior '
                     'changes require approval.',
                     'inputs': 'Merged build + approved behavior',
                     'outputs': 'Acceptance or linked defects',
                     'tool': 'UAT environment — To configure',
                     'x': '280',
                     'y': '1836'
                 },
                 {
                     'id': 'production',
                     'title': 'Production',
                     'owner': 'Release owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Promote the accepted build using the project release process.',
                     'guard': 'Business-user acceptance and project release conditions; no proprietary release '
                     'requirements assumed.',
                     'inputs': 'Accepted merged build',
                     'outputs': 'Production release',
                     'tool': 'Release integration — Placeholder',
                     'x': '280',
                     'y': '2000'
                 },
                 {
                     'id': 'repair',
                     'title': 'Investigate + repair',
                     'owner': 'Repair agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Investigate failures and uncertain findings. Fix confirmed defects, adjust '
                     'implementation tasks and add tests. Re-run all affected mandatory checks and retain '
                     'every attempt.',
                     'guard': 'Separate project-capped repair-round and pilot/developer-exchange limits. Do not '
                     'change approved behavior, required checks or visual expectations without asking.',
                     'inputs': 'Failed checks / review findings + executed evidence',
                     'outputs': 'Repaired commit, new evidence or exception',
                     'tool': 'Repair orchestrator — Planned',
                     'x': '28',
                     'y': '1180'
                 },
                 {
                     'id': 'exception',
                     'title': 'Pause for a decision',
                     'owner': 'User / pilot / developer',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Show the unresolved exception, evidence and exact decision needed. Pause for missing '
                     'configuration, exhausted limits or requested baseline changes. Resume from the saved '
                     'checkpoint after resolution.',
                     'guard': 'The QA clock keeps running during clarification, environment blockers and paused '
                     'agents. Blocked time is reported separately. Retries never reset the deadline.',
                     'inputs': 'Exception + history + configured caps',
                     'outputs': 'Explicit decision; resume checkpoint or revised approval',
                     'tool': 'Pause / resume engine — Planned',
                     'x': '532',
                     'y': '1508'
                 },
                 {
                     'id': 'resume',
                     'title': 'Saved checkpoint',
                     'owner': 'Orchestrator',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Resume the affected story, implementation, QA or review checkpoint after the '
                     'decision; do not restart completed unaffected work.',
                     'guard': 'QA timing and retry history survive the pause. Resume is not a pass.',
                     'inputs': 'Authorized decision and checkpoint',
                     'outputs': 'Resumed run with original QA start time',
                     'tool': 'Checkpoint persistence — Planned',
                     'x': '532',
                     'y': '1672'
                 },
                 {
                     'id': 'fix_story',
                     'title': 'Create linked fix story',
                     'owner': 'Story agent / owner',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Create new linked business work for UAT rejection, including implementation tasks '
                     'and QA scenarios. Use a new PR; do not reopen the merged implementation branch.',
                     'guard': 'Stories are validated before development. Approved behavior changes return to user '
                     'approval.',
                     'inputs': 'UAT rejection + evidence',
                     'outputs': 'Linked new work + trace links',
                     'tool': 'Issue adapter — Placeholder',
                     'x': '28',
                     'y': '2000'
                 }
             ],
             'transitions': [
                 {'source': 'intake', 'target': 'spec', 'label': '', 'kind': 'forward'},
                 {
                     'source': 'spec',
                     'target': 'approval',
                     'label': '',
                     'kind': 'forward'
                 },
                 {
                     'source': 'approval',
                     'target': 'spec',
                     'label': 'Revise baseline',
                     'kind': 'return'
                 },
                 {
                     'source': 'approval',
                     'target': 'stories',
                     'label': 'Approved',
                     'kind': 'forward'
                 },
                 {
                     'source': 'stories',
                     'target': 'dev',
                     'label': 'Validated',
                     'kind': 'forward'
                 },
                 {'source': 'dev', 'target': 'pr', 'label': '', 'kind': 'forward'},
                 {'source': 'pr', 'target': 'qa', 'label': '', 'kind': 'forward'},
                 {
                     'source': 'qa',
                     'target': 'review',
                     'label': 'Executed checks pass',
                     'kind': 'forward'
                 },
                 {
                     'source': 'qa',
                     'target': 'repair',
                     'label': 'Failed checks',
                     'kind': 'forward'
                 },
                 {
                     'source': 'review',
                     'target': 'repair',
                     'label': 'Defect / uncertain',
                     'kind': 'forward'
                 },
                 {
                     'source': 'review',
                     'target': 'evidence',
                     'label': 'All blockers resolved',
                     'kind': 'forward'
                 },
                 {
                     'source': 'repair',
                     'target': 'pr',
                     'label': 'Repair → rebuild + re-test',
                     'kind': 'return'
                 },
                 {
                     'source': 'repair',
                     'target': 'exception',
                     'label': 'Unresolved / limits',
                     'kind': 'forward'
                 },
                 {
                     'source': 'stories',
                     'target': 'exception',
                     'label': 'Unresolved ambiguity',
                     'kind': 'forward'
                 },
                 {
                     'source': 'qa',
                     'target': 'exception',
                     'label': 'Missing configuration',
                     'kind': 'forward'
                 },
                 {
                     'source': 'exception',
                     'target': 'approval',
                     'label': 'Baseline change → approve',
                     'kind': 'return'
                 },
                 {
                     'source': 'exception',
                     'target': 'resume',
                     'label': 'Authorized resume',
                     'kind': 'forward'
                 },
                 {
                     'source': 'resume',
                     'target': 'stories',
                     'label': 'Stories',
                     'kind': 'return'
                 },
                 {
                     'source': 'resume',
                     'target': 'dev',
                     'label': 'Implementation',
                     'kind': 'return'
                 },
                 {
                     'source': 'resume',
                     'target': 'qa',
                     'label': 'QA / review',
                     'kind': 'return'
                 },
                 {
                     'source': 'final',
                     'target': 'repair',
                     'label': 'Changes requested',
                     'kind': 'return'
                 },
                 {
                     'source': 'evidence',
                     'target': 'final',
                     'label': 'Current evidence',
                     'kind': 'forward'
                 },
                 {
                     'source': 'final',
                     'target': 'merge',
                     'label': 'Human agrees',
                     'kind': 'forward'
                 },
                 {'source': 'merge', 'target': 'uat', 'label': '', 'kind': 'forward'},
                 {
                     'source': 'uat',
                     'target': 'production',
                     'label': 'Accepted',
                     'kind': 'forward'
                 },
                 {
                     'source': 'uat',
                     'target': 'fix_story',
                     'label': 'Rejected',
                     'kind': 'forward'
                 },
                 {
                     'source': 'fix_story',
                     'target': 'stories',
                     'label': 'New linked work → validate',
                     'kind': 'return'
                 },
                 {
                     'source': 'fix_story',
                     'target': 'approval',
                     'label': 'Behavior change → approve',
                     'kind': 'return'
                 }
             ],
             'policies': COMMON_POLICIES,
             'configuration': DEMO_CONFIGURATION
         },
         {
             'template_key': 'bau-proposed',
             'title': 'BAU process · Proposed',
             'family': 'bau',
             'variant': 'proposed',
             'summary': 'Approve the spec and AC once, then let story validation, implementation, testing, independent '
             'review and bounded repair run autonomously. The PR owner makes the final human decision; UAT '
             'follows merge.',
             'steps': [
                 {
                     'id': 'intake',
                     'title': 'Business need · Jira',
                     'owner': 'PO',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Provide the goal, constraints and available references. Identify the project quality '
                     'profile and configuration gaps.',
                     'guard': 'No proprietary requirements or agent behavior inferred.',
                     'inputs': 'Business request or migration scope',
                     'outputs': 'Bounded request + references',
                     'tool': 'Jira — Placeholder',
                     'x': '280',
                     'y': '32'
                 },
                 {
                     'id': 'design',
                     'title': 'UX / PO design cycle',
                     'owner': 'UX + PO',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'UX creates the design in Figma with PO feedback. Reuse the approved reference '
                     'throughout delivery.',
                     'guard': 'Iterate until the PO approves the design.',
                     'inputs': 'Business goal + feedback',
                     'outputs': 'Selected design and states',
                     'tool': 'Figma connector — Placeholder',
                     'x': '280',
                     'y': '196'
                 },
                 {
                     'id': 'spec',
                     'title': 'Knowledge article + spec + AC',
                     'owner': 'Specification agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Generate a versioned specification and acceptance criteria from scope and '
                     'references. Generate the linked knowledge article from the draft design and business '
                     'intent for the combined approval.',
                     'guard': 'Surface ambiguity for user approval; keep selected visual references versioned.',
                     'inputs': 'Scope + references + project profile',
                     'outputs': 'Draft spec and acceptance criteria + knowledge article',
                     'tool': 'Spec generator — Planned; proprietary adapter Placeholder',
                     'x': '280',
                     'y': '360'
                 },
                 {
                     'id': 'approval',
                     'title': 'Approve design + spec + AC',
                     'owner': 'User / PO',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Review and approve the generated specification and acceptance criteria. After this '
                     'checkpoint, routine story validation, implementation, testing, review and repair run '
                     'autonomously in the proposed design.',
                     'guard': 'Changes to approved behavior, required checks or visual expectations require renewed '
                     'approval.',
                     'inputs': 'Versioned spec, AC, references and configuration',
                     'outputs': 'Approved behavior baseline',
                     'tool': 'Versioned approval enforcement — Planned',
                     'x': '280',
                     'y': '524'
                 },
                 {
                     'id': 'stories',
                     'title': 'Generate + validate stories',
                     'owner': 'Story agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Create business stories before development within epics, linked implementation tasks '
                     'and QA scenarios. Evaluate completeness, consistency and testability automatically. '
                     'Repair story structure without altering approved behavior.',
                     'guard': 'No routine intermediate human QA approval. Unresolved ambiguity or requested behavior '
                     'change pauses for a decision.',
                     'inputs': 'Approved spec and acceptance criteria',
                     'outputs': 'Validated stories, tasks, QA scenarios + trace links',
                     'tool': 'Story validator — Planned',
                     'x': '280',
                     'y': '688'
                 },
                 {
                     'id': 'dev',
                     'title': 'Implement + add tests',
                     'owner': 'Implementation agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Implement linked tasks and tests against approved stories and criteria. Agents may '
                     'adjust tasks and add tests within the approved baseline.',
                     'guard': 'Generating tests alone never establishes a pass.',
                     'inputs': 'Validated stories + approved behavior',
                     'outputs': 'Implementation, tests and trace links',
                     'tool': 'Developer agent set — Placeholder',
                     'x': '280',
                     'y': '852'
                 },
                 {
                     'id': 'pr',
                     'title': 'PR + runnable preview',
                     'owner': 'Implementation agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Open or update the PR and provide a runnable build in the configured QA environment. '
                     'Prefer an isolated preview per PR.',
                     'guard': 'A PR link alone does not start QA. Wait until a runnable build first enters QA.',
                     'inputs': 'Implementation + linked tasks',
                     'outputs': 'PR, commit/build identity + runnable preview',
                     'tool': 'Git provider / preview adapter — Placeholder',
                     'x': '280',
                     'y': '1016'
                 },
                 {
                     'id': 'qa',
                     'title': 'QA + BAU regression',
                     'owner': 'QA agents',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Execute the common checklist and feature-specific checks. Combine '
                     'logic/API/component tests with complete Chrome journeys, visual/layout checks, '
                     'accessibility and configured performance/security checks. Automated BAU regression '
                     'must finish before merge.',
                     'guard': 'Select a 48–96-hour deadline; the QA clock starts here on first runnable entry. '
                     'Failures, missing configuration and required checks not run block readiness. Retries '
                     'never reset the clock.',
                     'inputs': 'Runnable build, stories/AC, QA scenarios, configured profile + data',
                     'outputs': 'Executed evidence per acceptance criterion; defects and retry history',
                     'tool': 'QA harness — Planned; test data — To configure',
                     'x': '280',
                     'y': '1180'
                 },
                 {
                     'id': 'review',
                     'title': 'Read-only code review',
                     'owner': 'Independent reviewer agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Review implementation against spec and project rules, including errors, permissions, '
                     'data integrity, test quality and build/lint/security results. A proposed reviewer '
                     'run is separate and read-only.',
                     'guard': 'Confirmed defects and failed mandatory checks block. Suggestions are advisory. '
                     'Investigate uncertain findings.',
                     'inputs': 'Diff, approved spec, project rules + executed results',
                     'outputs': 'Classified findings and review evidence',
                     'tool': 'Independent reviewer — Planned',
                     'x': '280',
                     'y': '1344'
                 },
                 {
                     'id': 'evidence',
                     'title': 'Assemble review evidence',
                     'owner': 'Evidence agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Bring together the diff, preview, story/AC coverage, rendering comparisons, executed '
                     'test results and review findings.',
                     'guard': 'Identify tested commit/build and applicable spec/config versions. Missing '
                     'configuration and unexecuted required checks cannot appear passed. Changed inputs '
                     'invalidate affected evidence.',
                     'inputs': 'Versioned artifacts, test results and classified findings',
                     'outputs': 'Evidence bundle for the current PR revision',
                     'tool': 'Evidence bundle — Planned',
                     'x': '280',
                     'y': '1508'
                 },
                 {
                     'id': 'final',
                     'title': 'Final human review',
                     'owner': 'PR owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Review the diff, preview, story/AC coverage, rendering comparisons, test results and '
                     'findings together. This is the last human checkpoint before merge.',
                     'guard': 'Evidence must identify the tested commit/build and spec/config versions. Missing '
                     'config or unexecuted required checks cannot appear passed.',
                     'inputs': 'Versioned evidence bundle + PR diff',
                     'outputs': 'Human decision: merge or return for repair',
                     'tool': 'Evidence bundle UI / enforcement — Planned',
                     'x': '280',
                     'y': '1672'
                 },
                 {
                     'id': 'merge',
                     'title': 'Merge',
                     'owner': 'PR owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'The PR owner may merge their own PR after the final review.',
                     'guard': 'All mandatory checks resolved; automated BAU regression completed before merge.',
                     'inputs': 'Reviewed PR + current evidence',
                     'outputs': 'Merged commit',
                     'tool': 'Git provider — Placeholder',
                     'x': '280',
                     'y': '1836'
                 },
                 {
                     'id': 'uat',
                     'title': 'Business-user UAT',
                     'owner': 'Business users',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Business users validate the merged change in the configured UAT environment.',
                     'guard': 'UAT happens after merge. Defects go back through repair and verification; behavior '
                     'changes require approval.',
                     'inputs': 'Merged build + approved behavior',
                     'outputs': 'Acceptance or linked defects',
                     'tool': 'UAT environment — To configure',
                     'x': '280',
                     'y': '2000'
                 },
                 {
                     'id': 'production',
                     'title': 'Production',
                     'owner': 'Release owner',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Promote the accepted build using the project release process.',
                     'guard': 'Business-user acceptance and project release conditions; no proprietary release '
                     'requirements assumed.',
                     'inputs': 'Accepted merged build',
                     'outputs': 'Production release',
                     'tool': 'Release integration — Placeholder',
                     'x': '280',
                     'y': '2164'
                 },
                 {
                     'id': 'repair',
                     'title': 'Investigate + repair',
                     'owner': 'Repair agent',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Investigate failures and uncertain findings. Fix confirmed defects, adjust '
                     'implementation tasks and add tests. Re-run all affected mandatory checks and retain '
                     'every attempt.',
                     'guard': 'Separate project-capped repair-round and pilot/developer-exchange limits. Do not '
                     'change approved behavior, required checks or visual expectations without asking.',
                     'inputs': 'Failed checks / review findings + executed evidence',
                     'outputs': 'Repaired commit, new evidence or exception',
                     'tool': 'Repair orchestrator — Planned',
                     'x': '28',
                     'y': '1344'
                 },
                 {
                     'id': 'exception',
                     'title': 'Pause for a decision',
                     'owner': 'User / pilot / developer',
                     'mode': 'Human',
                     'status': 'Manual',
                     'detail': 'Show the unresolved exception, evidence and exact decision needed. Pause for missing '
                     'configuration, exhausted limits or requested baseline changes. Resume from the saved '
                     'checkpoint after resolution.',
                     'guard': 'The QA clock keeps running during clarification, environment blockers and paused '
                     'agents. Blocked time is reported separately. Retries never reset the deadline.',
                     'inputs': 'Exception + history + configured caps',
                     'outputs': 'Explicit decision; resume checkpoint or revised approval',
                     'tool': 'Pause / resume engine — Planned',
                     'x': '532',
                     'y': '1672'
                 },
                 {
                     'id': 'resume',
                     'title': 'Saved checkpoint',
                     'owner': 'Orchestrator',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Resume the affected story, implementation, QA or review checkpoint after the '
                     'decision; do not restart completed unaffected work.',
                     'guard': 'QA timing and retry history survive the pause. Resume is not a pass.',
                     'inputs': 'Authorized decision and checkpoint',
                     'outputs': 'Resumed run with original QA start time',
                     'tool': 'Checkpoint persistence — Planned',
                     'x': '532',
                     'y': '1836'
                 },
                 {
                     'id': 'fix_story',
                     'title': 'Create linked fix story',
                     'owner': 'Story agent / owner',
                     'mode': 'Automation',
                     'status': 'Planned',
                     'detail': 'Create new linked business work for UAT rejection, including implementation tasks '
                     'and QA scenarios. Use a new PR; do not reopen the merged implementation branch.',
                     'guard': 'Stories are validated before development. Approved behavior changes return to user '
                     'approval.',
                     'inputs': 'UAT rejection + evidence',
                     'outputs': 'Linked new work + trace links',
                     'tool': 'Issue adapter — Placeholder',
                     'x': '28',
                     'y': '2164'
                 }
             ],
             'transitions': [
                 {
                     'source': 'intake',
                     'target': 'design',
                     'label': '',
                     'kind': 'forward'
                 },
                 {'source': 'design', 'target': 'spec', 'label': '', 'kind': 'forward'},
                 {
                     'source': 'approval',
                     'target': 'design',
                     'label': 'Design feedback',
                     'kind': 'return'
                 },
                 {
                     'source': 'spec',
                     'target': 'approval',
                     'label': '',
                     'kind': 'forward'
                 },
                 {
                     'source': 'approval',
                     'target': 'spec',
                     'label': 'Revise baseline',
                     'kind': 'return'
                 },
                 {
                     'source': 'approval',
                     'target': 'stories',
                     'label': 'Approved',
                     'kind': 'forward'
                 },
                 {
                     'source': 'stories',
                     'target': 'dev',
                     'label': 'Validated',
                     'kind': 'forward'
                 },
                 {'source': 'dev', 'target': 'pr', 'label': '', 'kind': 'forward'},
                 {'source': 'pr', 'target': 'qa', 'label': '', 'kind': 'forward'},
                 {
                     'source': 'qa',
                     'target': 'review',
                     'label': 'Executed checks pass',
                     'kind': 'forward'
                 },
                 {
                     'source': 'qa',
                     'target': 'repair',
                     'label': 'Failed checks',
                     'kind': 'forward'
                 },
                 {
                     'source': 'review',
                     'target': 'repair',
                     'label': 'Defect / uncertain',
                     'kind': 'forward'
                 },
                 {
                     'source': 'review',
                     'target': 'evidence',
                     'label': 'All blockers resolved',
                     'kind': 'forward'
                 },
                 {
                     'source': 'repair',
                     'target': 'pr',
                     'label': 'Repair → rebuild + re-test',
                     'kind': 'return'
                 },
                 {
                     'source': 'repair',
                     'target': 'exception',
                     'label': 'Unresolved / limits',
                     'kind': 'forward'
                 },
                 {
                     'source': 'stories',
                     'target': 'exception',
                     'label': 'Unresolved ambiguity',
                     'kind': 'forward'
                 },
                 {
                     'source': 'qa',
                     'target': 'exception',
                     'label': 'Missing configuration',
                     'kind': 'forward'
                 },
                 {
                     'source': 'exception',
                     'target': 'approval',
                     'label': 'Baseline change → approve',
                     'kind': 'return'
                 },
                 {
                     'source': 'exception',
                     'target': 'resume',
                     'label': 'Authorized resume',
                     'kind': 'forward'
                 },
                 {
                     'source': 'resume',
                     'target': 'stories',
                     'label': 'Stories',
                     'kind': 'return'
                 },
                 {
                     'source': 'resume',
                     'target': 'dev',
                     'label': 'Implementation',
                     'kind': 'return'
                 },
                 {
                     'source': 'resume',
                     'target': 'qa',
                     'label': 'QA / review',
                     'kind': 'return'
                 },
                 {
                     'source': 'final',
                     'target': 'repair',
                     'label': 'Changes requested',
                     'kind': 'return'
                 },
                 {
                     'source': 'evidence',
                     'target': 'final',
                     'label': 'Current evidence',
                     'kind': 'forward'
                 },
                 {
                     'source': 'final',
                     'target': 'merge',
                     'label': 'Human agrees',
                     'kind': 'forward'
                 },
                 {'source': 'merge', 'target': 'uat', 'label': '', 'kind': 'forward'},
                 {
                     'source': 'uat',
                     'target': 'production',
                     'label': 'Accepted',
                     'kind': 'forward'
                 },
                 {
                     'source': 'uat',
                     'target': 'fix_story',
                     'label': 'Rejected',
                     'kind': 'forward'
                 },
                 {
                     'source': 'fix_story',
                     'target': 'stories',
                     'label': 'New linked work → validate',
                     'kind': 'return'
                 },
                 {
                     'source': 'fix_story',
                     'target': 'approval',
                     'label': 'Behavior change → approve',
                     'kind': 'return'
                 }
             ],
             'policies': COMMON_POLICIES,
             'configuration': DEMO_CONFIGURATION
         }
     ];
