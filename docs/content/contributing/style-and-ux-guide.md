# Flowline style and UX guide

Read this before designing or changing an in-app screen.

This guide records Flowline's existing visual language and interaction
patterns, inspected in the application and source on 29 October 2026. It also
records the problems in the first Processes implementation. The process-page
requirements below guide implementation and visual review. They do not
establish that the depicted delivery automation has been implemented.

## Start with the product

Flowline is a working tool for following work through a flow. Its interface
puts the board, diagram or settings in front of the user quickly. The shell,
typography and controls stay quiet around that work.

Before editing UI:

1. Open the closest existing screen and capture its current state.
2. Read `styles/global.css` and the relevant shared components listed below.
3. State the user's task and the smallest visible change that supports it.
4. Reuse the existing layout and controls. Identify any data adapter needed
   before attempting to reuse a component with a different model.
5. Compare the result with the native screen at the same viewport, theme and
   interaction state. Passing functional tests does not establish visual fit.

This guide covers the authenticated application. Landing-page treatments such
as hero headings, glows, glass capsules and capability tiles are not defaults
for work screens. No separate Figma specification or formal brand manual was
supplied for this review.

## Core principles

| Principle | Application |
| --- | --- |
| Work first | Give the main board or canvas most of the useful space. Keep the header and toolbar compact. |
| One product | Retain the existing shell, navigation, project context, typography and control vocabulary. A feature does not introduce another UI kit. |
| Quiet surfaces | Use warm neutral surfaces, subtle rules and restrained emphasis. Avoid a stack of decorated cards around every fragment of information. |
| Deliberate color | Reserve brand orange for primary action and intentional emphasis. Routine hover and selection use neutral surfaces. |
| Details when needed | Show a step's name and useful context in the flow. Reveal rules, dependencies and notes through selection and a contextual panel. |
| Honest capability | Distinguish a reviewable model, manual work, planned automation, unavailable integration and actual executed evidence. |

## Sources to reuse

The paths below are repository-relative. Read the implementation and its
rendered result together; existing comments and individual selectors sometimes
disagree.

| Concern | Source |
| --- | --- |
| Palette, type, radii, surfaces, focus and primitive overrides | `styles/global.css` |
| Light, dark and system preference | `lib/theme.jac` |
| Application shell and content gutters | `pages/layout.jac` |
| Navigation and compact-screen chrome | `components/chrome/Sidebar.jac`, `SidebarLink.jac`, `PhoneHeader.jac`, `TabBar.jac` |
| Page title, context and actions | `components/flowlines/FlowTitle.jac`, `components/board/BoardHeader.jac`, `components/common/ProjectLine.jac` |
| Flow controls | `components/flowlines/controls.jac`, `FlowToolbar.jac`, `ViewSwitches.jac` |
| Diagram, nodes and ordered-list alternative | `pages/(auth)/flowlines.jac`, `components/flowlines/FlowCanvas.jac`, `StepNode.jac`, `StepList.jac` |
| Contextual inspection | `components/flowlines/StepInspector.jac`, `StepTasksPanel.jac`, `components/ui/sheet.jac` |
| Step identity and semantic kind | `components/common/StepBadge.jac`, `KindGlyph.jac`, `components/flowlines/NodeMeta.jac` |
| Settings and secondary navigation | `components/workspace/SettingRow.jac`, `SectionHeader.jac`, `WorkspaceRail.jac` |
| Buttons, fields, menus, dialogs and tabs | `components/ui/` |
| Loading, failures and stale data | `components/common/Reveal.jac`, `LoadFailed.jac`, `ErrorNote.jac`, `components/ui/skeleton.jac` |

`components/ui/` contains generated registry components. Import them; do not
edit their generated files. Theme them through semantic tokens and the
sanctioned `data-slot` overrides in `styles/global.css`. Introduce a shared
wrapper when a repeated product pattern needs composition.

## Color and surface hierarchy

Use the existing semantic tokens. The values here document the inspected
palette; implementation must reference the tokens instead of copying hexes
into a feature stylesheet.

| Role | Token | Light | Dark |
| --- | --- | --- | --- |
| Navigation ground | `--bg-sidebar` | `#F5F5F3` | `#141413` |
| Main work area | `--bg-canvas` | `#FAFAF8` | `#181817` |
| Resting surface | `--bg-surface` | `#F1F1EE` | `#1E1E1C` |
| Floating surface | `--bg-elevated` | `#FFFFFF` | `#232321` |
| Primary text | `--text-primary` | `#1C1C1A` | `#EDEDEA` |
| Secondary text | `--text-secondary` | `#5C5C56` | `#A5A5A0` |
| Tertiary metadata | `--text-tertiary` | `#6A6A63` | `#8A8A84` |
| Brand action | `--accent`, aliased as `--primary` | `#BF3F0B` | `#F07A3A` |
| Text on brand action | `--on-accent` | `#FFFFFF` | `#1B1109` |

Use `--bg-hover` for neutral hover and `--bg-selected` for persistent neutral
selection. Borders use `--border-subtle`, `--border` or `--border-strong`.
The same role must remain legible in both themes.

### The accent naming trap

Flowline's raw CSS `var(--accent)` is the orange brand color. The Tailwind
utility `bg-accent` is deliberately mapped to the neutral `--bg-hover` token
for registry compatibility. They are not interchangeable.

| Intent | Use | Avoid |
| --- | --- | --- |
| Ordinary hover | `bg-bg-hover`, `bg-accent`, or `var(--bg-hover)` | Raw `var(--accent)` as the hover fill |
| Selected navigation or row | `bg-bg-selected` with primary text and an additional selection cue | An orange rectangle behind ordinary row text |
| Main action | Shared primary `Button` with its paired foreground token | A custom orange fill that retains secondary text colors |
| Step kind | Existing colored kind glyph plus a text label | Large status-colored cards, pills or group bands |

Status, step color, project identity and feature availability are different
concepts. Keep those meanings separate. Project colors belong on the existing
small project dot. Step colors primarily identify the kind glyph; the native
selected node can also use its existing colored outline. Do not invent a new
palette for Manual, Planned and Placeholder.

## Typography

Use Geist through `font-sans` and the existing utility classes. Counts and
dates use tabular figures through `.num`, not a different UI font.

| Role | Existing treatment |
| --- | --- |
| In-app page heading | `.page-title`: 20px, semibold, tight line height and tracking |
| Section or panel heading | `.section-title`: 16px, semibold |
| General compact UI | `.ui-base` or the existing 13px row/nav treatment |
| Supporting prose and fields | Existing 13px or `text-sm` treatment, according to the component |
| Metadata | `.meta` or existing 12px treatment |
| Table | `.data-table`: 13.5px cells, 12.5px sentence-case headers |

Use the native regular, medium and semibold hierarchy. Avoid feature-specific
weights such as 550, 580 or 650. Use one descriptive page heading, not a large
promotional heading followed by another page title.

Treat 12px as the reading floor for new metadata and controls. Existing small
keyboard hints and zoomed diagram overviews are exceptions to inspect, not a
reason to introduce 9px or 10px required labels. An overview needs a readable
inspection or list alternative.

## Layout, spacing and shape

- Let the shell supply its gutters: 16px on small screens and 24px from `sm`
  in the inspected layout. Do not add another arbitrary page-width system.
- Match the native title/context/actions row. Keep a single short supporting
  line when it helps the task. Put secondary actions in the existing menu or
  disclosure pattern.
- Use the existing spacing rhythm, commonly 4, 8, 12, 16 and 24px. Copy the
  closest component's spacing instead of inventing 7px, 19px and 22px rules.
- Use `min-w-0`, wrapping and truncation deliberately. Required controls must
  stay reachable; tooltips or the inspector expose truncated node details.
- Use one primary work surface. Add boundaries where a distinct region or
  interaction needs them, rather than wrapping every paragraph in a card.

The radius tokens assign 4px to small details, 6px to ordinary controls and
rows, 8px to menus/popovers and 12px to larger dialogs. Some native components,
including flow nodes and segmented-control groups, have explicit shape
choices. Reuse those components rather than flattening their exceptions into
a new universal rule. Avoid custom 7px and 9px feature radii.

Resting surfaces are flat. Floating menus, sheets and dialogs use the shared
`--shadow-float`. Do not add decorative shadows and selection halos to every
node or panel. Preserve the native interaction treatment for a dragged or
selected flow node.

## Controls and interaction states

| State or action | Treatment |
| --- | --- |
| Main action | Usually one prominent action for the current task, using the primary `Button` |
| Secondary action | Shared outline or secondary button |
| Quiet action | Shared ghost button or an appropriately labelled icon button |
| View choice | Existing `Segmented` pattern with a labelled group and `aria-pressed` |
| Navigation | A real link with the current-page state; preserve open-in-new-tab behavior |
| Tab panel | Shared `Tabs` semantics and keyboard behavior |
| Focus | Shared visible 2px outline; do not add a second decorative focus halo |
| Disabled action | Neutral disabled treatment and a discoverable reason when needed |
| Loading or saving | Component-specific busy state; prevent duplicate submission without hiding useful content |

The native flow controls are 30px high; registry buttons and inputs generally
use the existing 28px, 32px and 36px variants. Select the established size for
the context. Do not create a separate family of controls with unrelated
heights or tiny labels. Ensure compact icon controls remain usable on touch.

Do not confuse hover, selection, focus, error and disabled states. A reviewable
Planned step remains selectable for inspection. An unavailable execution
action must not look enabled or pretend to have run.

## Workflow canvas and inspection

Use the native workflow screen as the structural reference:

1. Project/process context, a compact title and short counts or metadata.
2. One coherent control row for selection, view and diagram navigation.
3. A viewport-aware canvas or ordered list as the main content.
4. A concise key and contextual inspection when a step is selected.

Reuse or extract the presentation patterns from `FlowCanvas`, `StepNode`,
`StepList`, `ZoomControls` and the inspector/sheet components. Storyboard
`ProcessView` and operational `StepView` have different contracts. Adapting
their presentation must not turn a storyboard into an operational task or
enable editing/execution accidentally.

Keep node text brief: name, useful owner/context and a compact capability
label when necessary. Put full decision rules, inputs, outputs and review
notes in the selected-step detail view. Keep text geometry and hit areas in
agreement. Prevent node overlap and route-label collisions.

Prefer the native pan, zoom, Fit, selection and keyboard conventions. New
read-only views must state their available interactions accurately. Do not
advertise dragging, editing or execution before those actions work. Use an
ordered list when a diagram would be too small to read.

### Current/proposed comparison

These are the design requirements for Processes comparison:

- Keep React migration/BAU selection and Current/Proposed/Compare choices in
  the compact native control language. They are views of work, not new
  product projects.
- Start with one readable canvas. Offer comparison explicitly.
- In comparison, keep the two versions labelled and use a comparable scale
  and starting context. Do not land one version halfway through at 50% and
  the other at the start at 100%.
- Preserve selection and unsaved notes when changing view. Never discard
  review input as a side effect of fitting or navigating the diagram.
- When available width cannot support two readable diagrams, use a single
  version or a readable comparison list. Do not squeeze both into clipped
  fixed-width canvases.
- Reveal one contextual inspector using the native panel/sheet pattern.
  Avoid permanently taking a third column from an already narrow comparison.

## Responsive behavior

Follow the existing shell and each feature's actual breakpoint logic. The
inspected sidebar uses `lg:flex`; the header and bottom navigation use
`lg:hidden`. The native flow page separately switches to its compact-screen
behavior at 639px. These are distinct decisions, not one universal breakpoint.

Below the native flow page's diagram breakpoint, its ordered list is the
default. Use progressive disclosure or a sheet for details. Preserve bottom
navigation clearance and safe-area padding. A diagram may deliberately pan
inside its viewport; the whole document must not acquire unintended sideways
scrolling.

Test intermediate widths as well as desktop and phone. A layout that works at
1440px and 390px can still fail at the captured 878px comparison width.
Support text zoom and longer names without hiding required controls.

## Forms, content and feedback

Use `SettingRow`, shared labels, inputs, textareas and selects. Put help beside
the field or beneath its label. Do not build a new settings-card system for
project quality profiles, screen selections or reference configuration.

Use sentence case and direct task language: "Flow line", "Current",
"Proposed", "Compare versions", "Save note" and "Try again". Avoid all-caps
section eyebrows, generic dashboard slogans and long explanatory introductions
before the work area. Follow the repository's copy rule against em dashes.

Keep capability statements brief and accurate:

| Label | Meaning |
| --- | --- |
| Review only | Selection, inspection and notes work; this view does not execute delivery |
| Manual | A person performs the depicted business action |
| Planned | The automation has not been implemented |
| Placeholder | An integration is unavailable or proprietary |
| To configure | A required project/spec value is unset |

Expose the overall review-only boundary once in a compact, persistent context
and show step-specific limitations where relevant. Keep the full explanation
available without repeating an implementation disclaimer in every region.
Never equate a saved review note with an approved spec, or an unexecuted check
with a pass.

Use the existing skeleton/loading frame instead of flashing an empty state.
Use `LoadFailed` for a failed first load and the stale-data pattern when useful
data is already present. Errors explain the recovery action. A failed save
retains the note and provides retry; an empty library offers its real install
action. Do not display a successful empty state after a fetch failure.

## Accessibility and motion

- Retain labelled landmarks, controls and inputs. Icon-only actions need
  accessible names. State must be conveyed by text/shape as well as color.
- Keep every review action keyboard-operable and focus visible. Opening and
  dismissing a panel must manage focus and preserve a route back to the step.
- Preserve native global shortcuts. Scope diagram shortcuts to the correct
  context and do not intercept typing or dialog interaction.
- Check clipping, overlap, hidden controls, focus visibility and actual
  foreground/background pairs in both themes. The token source targets 4.5:1
  for text and 3:1 for relevant icons/control edges; token comments alone do
  not prove the rendered feature meets those targets.
- Respect the shared reduced-motion behavior. Use motion for state changes,
  not decorative activity inside a work screen.

Screenshots do not establish keyboard, screen-reader or full accessibility
compliance. Those require separate interaction and rendered-state checks.

## Problems found in the first Processes implementation

| Finding | Evidence | Required direction |
| --- | --- | --- |
| Another header hierarchy | `styles/processes.css` adds an uppercase eyebrow and a 25-34px heading. The captured rendered heading is 26.34px/580, while native settings uses 20px/600. | Reuse the native page heading and compact contextual header. |
| Too many introductory/control regions | The process page stacks introduction, disclaimer, selectors, another title/summary, section tabs, legend/jump controls and separate zoom rows. | Consolidate the controls and make the working canvas visible sooner. |
| Orange selection/hover fills | `.process-button:hover`, `.process-list-node.is-selected` and selected zoom controls use raw `var(--accent)`. | Use neutral hover/selection and the native primary-action pairing. |
| Another availability palette and type scale | The feature introduces colored badge fills, 9-11px text, custom weights/radii and extra shadows. | Reuse tokens, native text hierarchy and quiet capability labels. |
| Unreadable comparison state | The captured 878px view shows one diagram at 50% and the other at 100%, with tiny labels and clipped nodes. | Use a comparable framing and a readable fallback at constrained widths. |
| Bespoke canvas and inspector layout | Fixed 800px maps, 620px scroll regions and a custom 310px inspector create another interaction system. | Adapt native diagram/list and contextual-panel patterns without changing workflow semantics. |

### Existing inconsistencies to avoid copying

The source itself has drift. The `.page-title` comment says 28px, but its
declaration and captured native heading are 20px. Several shell comments say
`md`, while their actual visibility classes use `lg`. The later outline-button
hover override, `.toolbar-filter:hover` and table-row hover in
`styles/global.css` also use raw `var(--accent)` despite the neutral-hover
token contract. Some native component shapes differ from the general radius
comments.

Treat these as discrepancies to verify and fix deliberately, not precedents
for new styling. Use the semantic token contract, the closest coherent native
pattern and the actual rendered result. Do not broaden a process-page redesign
into an unreviewed global restyle.

## Initial style-guide evidence and limits

The review captured four states, with local screenshots retained in the
ignored `.jac/style-guide-audit/` directory:

1. **Processes comparison: poor fit.** At 878 x 988, comparison scale and
   clipping make the flow hard to read. Source inspection confirms the custom
   type, palette and control system.
2. **Native Flow line: useful structural reference.** At 1280 x 720, title,
   toolbar, canvas and key form one work area. Existing configured node overlap
   is a defect, not a layout pattern to reproduce.
3. **Native Board: mixed.** The title/action hierarchy and compact step glyphs
   are useful references. The 66-step workspace configuration floods the flow
   strip, so this is not a clean reference for normal board content density.
4. **Native Workspace settings: coherent reference.** A neutral section rail,
   20px title and shared label/help/control row demonstrate the intended form
   hierarchy.

These initial captures preceded the UX implementation. They are observations at different viewport widths, not a formal
pixel comparison. Light mode was visually inspected. Dark tokens and responsive
source were reviewed, but a full dark-mode, phone, keyboard and assistive-tech
audit was not performed in that documentation pass. Implementation changes
require their own rendered-state and interaction checks against this guide.

## Design review checklist

Before calling the next UI pass ready:

- [ ] Read this guide and identify the native reference screen/components.
- [ ] Keep one native page-title hierarchy and a compact, coherent toolbar.
- [ ] Reuse shared components or extract a reusable presentation layer.
- [ ] Use semantic tokens; check the raw-accent naming trap and CSS cascade.
- [ ] Keep routine selection neutral and pair primary fills with their text token.
- [ ] Give the canvas/list the main space and reveal details contextually.
- [ ] Make comparison readable at desktop, intermediate and phone widths.
- [ ] Preserve review notes, selection and the agreed business-process rules.
- [ ] Label unfinished capabilities without pretending they execute or pass.
- [ ] Verify loading, empty, error, save, hover, focus and disabled states.
- [ ] Inspect both themes, keyboard behavior, text zoom and reduced motion.
- [ ] Save and inspect screenshots beside the native reference at matching
      viewport/theme/state. Fix visible mismatches before reporting success.
