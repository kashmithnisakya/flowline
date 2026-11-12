# Verification and CI

Changes are verified by Jac unit tests, the compiler's checks, smoke gates that
drive a real server over HTTP and in a browser, and a deploy dry run.
{ .fl-lede }

## Before you push

```bash
python3 tools/jac.py fmt --lintfix <changed .jac files>
python3 tools/jac.py check <each changed .jac file>
python3 tools/jac.py test tests/unit/runtime_boundaries.jac
python3 tools/jac.py run --no-dev main.jac   # boots and builds the bundle
python3 tests/smoke/api_gate.py http://localhost:8000
```

The wrapper verifies the pinned compiler source and every manifest-listed
backport before running Jac. Use it for local compiler-dependent checks.
These source checks do not update a hosted runtime image.

- Run `jac check` **per file**. `jac check main.jac` does not report errors
  inside imported modules.
- Boot the app after touching imports or placement pins. `jac check` cannot see
  a walker module that lowered into the client bundle; the build can.
- After touching walkers or `owned()`, run a two-account isolation gate (see
  [Tenancy and security](../concepts/security.md#verifying-isolation)).

## Before opening or updating a PR

Start a bug fix with a regression that asserts the intended behavior, fails on
the old code and passes with the fix. A diagnostic that passes by observing
duplicates is evidence of the defect. Keep its diagnostic result separate from
the corrected regression result.

For persistence and retry changes, inject failures before commit, during callback
writes and after nested or explicit commits. Read the durable rows through a
separate database connection and count body/callback executions. Check shared and
independent sessions, retry exhaustion, cancellation and idempotent responses.
Cover callbacks that only stage graph changes, callbacks that flush graph writes,
and callbacks that issue opaque SQL. Test keyed read-tier requests as well as
writers. A successful return must agree with the committed rows; an unreplayable
partial failure must remain final and must not repeat the body or callback.
Webhook queue acknowledgements must wait for the graph commit. The runtime
contracts force that commit to conflict and verify the delivery is applied
once and acknowledged only after its row is durable.
The local runtime contract command above checks the pinned backport directly;
upstream test totals alone do not establish that the app uses the corrected code.

Record the exact tested commit, runtime version, compiler manifest and commands.
After changing the code, rerun affected checks at the final head. For PRs that
share models or endpoints, make a disposable trial merge and run their combined
integration gate. Preserve the existing branches and test accounts.

A clean Git merge means the diff has no textual conflicts. Before claiming merge
readiness, verify the current target branch is included, correctness findings are
addressed, required final-head CI has passed, and supported hosted-runtime and
deployed integration prerequisites are satisfied. Missing, queued or
approval-required checks are pending. Local source-handoff results and a deploy
dry run do not establish what a hosted image contains.

## What CI runs

`.github/workflows/ci.yml` runs on every pull request and on pushes to `main`
and `dev`. Both jobs prepare the same verified compiler source through
`python3 tools/jac.py --github-env "$GITHUB_ENV"` before installing dependencies.
The Jac commands below inherit that compiler handoff. This does not change the
compiler used by a hosted runtime image.

=== "jac: fmt / lint / check"

    1. Reads the exact pin from `jac.toml` and installs that release.
       Runs `tests/unit/runtime_boundaries.jac` with the verified backports to
       check callback write retries and refusal to replay durable nested work.
    2. `jac fmt --check --lintfix` over every tracked `.jac` except
       `components/ui/` (registry copies are rewritten by
       `jac install --shadcn`).
    3. `jac check --lint` over every tracked `.jac`.
    4. A per-file `jac check`, run twice on purpose: a warm-up pass seeds
       `.jac/cache` (older releases reported cold-cache `E5082` false
       positives) and the second pass is the one that counts.

=== "serve: app serves / API / browser"

    1. Installs the pinned Jac and runs `jac install`.
    2. **Deploy gate:** renders the manifests with
       `jac scale deploy --dry-run --show-yaml` and runs
       `tests/smoke/deploy_gate.py`, which asserts the deploy builds a client
       bundle, runs two workers and bounds the gateway.
    3. Starts `tests/smoke/github_stub.py`, a local stand-in for the GitHub
       endpoints the app calls, and exports App variables pointing at it
       (`GITHUB_API_BASE`, `GITHUB_WEB_BASE`, a generated private key).
    4. Boots `jac run --no-dev --port 8000 main.jac`.
    5. **API gate** (`tests/smoke/api_gate.py`): the shell and bundle are
       served, anonymous calls are `401`, register and login work, core walkers
       answer, 16 concurrent reads succeed.
    6. **Webhook gate** (`tests/smoke/webhook_gate.py`): the connect round
       trip binds the installation, the poll back-fills, signed deliveries are
       queued by the receiver and applied by the drain, and three workspaces
       stay isolated.
    7. Checks the log for two supervised workers.
    8. **Browser gate** (`tests/smoke/browser_gate.py`, Playwright): sign up,
       finish the three-step setup on the Simple template, land on the board
       with the new-task dialog open and the template's steps applied, create a
       task from the board and see the row survive a reload, turn on AI
       responsibilities and give a role code review, check a proposal from Ask
       is drawn dashed until it is applied, then land on GitHub's install redirect against the stub and check the page
       completes it with exactly one `CompleteGithubInstall` request.
    9. **Flow canvas gate** (`tests/smoke/flow_canvas_gate.py`, Playwright):
       create a custom flow, drag through all four quadrants, and verify the
       saved positions after reload. Its `flow_motion_cases.py` regressions
       cover overlapping steps, clicks, delayed and failed saves, canceled
       drags and wires, coordinate boundaries, negative-position labels,
       panning, zoom, lane switches, navigation with queued drops, recovery
       after failed or invalidated reads, and phone and mixed mouse/touch input.

=== "docs: build"

    `.github/workflows/docs.yml` builds this site with `--strict` on pull
    requests that touch `docs/`, the Jac sources the reference reads, or
    `jac.toml`, and deploys it to GitHub Pages from `dev`. See
    [Writing these docs](docs.md).

## Flow canvas regressions

After changing canvas geometry, gestures or position persistence, start the
app and run the existing browser gate from the repository root:

```bash
python3 tools/jac.py run --no-dev --port 8000 main.jac
# In another terminal, with Playwright and Chromium installed:
python3 tests/smoke/flow_canvas_gate.py http://localhost:8000
```

The gate creates its own test account and checks both rendered positions and
fresh API reads. It does not require a GitHub connection or a model key.
Desktop coverage uses 1440 × 1000; phone emulation uses 390 × 844 with Chromium
touch events. These checks do not replace testing on physical touch devices.
Screenshots are written under `.jac/`; the top-level
`browser_gate_failure.png` captures a failed run.

Position writes live in `lib/flowMoves.jac` so app navigation cannot start a
second writer. A flow page owns its active drag preview; a current server
read confirms pending positions only after all writes settle and no drag is
active. The gate holds responses while navigating and switching projects to
exercise those boundaries.

For the Jac Builder preview path, run the same gate against the hot-reload
server, with one worker as required by Jac's development mode:

```bash
python3 tools/jac.py run --dev --workers 1 --port 8000 --api-port 8001 main.jac
```

## Browser QA by hand

Use `agent-browser` (or Playwright) against `jac run --no-dev`.

!!! warning "Typing into React inputs"

    `agent-browser type` sets the value in a way React's change tracking
    ignores, so a working input looks broken. Use `agent-browser keyboard type`
    for real key events.

- Assert on rendered text, not only coordinates. A stale `@eN` ref can produce
  a phantom pass.
- HTML5 drag and drop does not fire from synthetic drags; dispatch a
  `DragEvent` with a `DataTransfer` from `eval` to test the board.
- A page mounts once on a full load (the layout reads the login state at
  render time), but a route change can still remount it. A test that counts
  requests (like the install completion) must expect the deduplicated count.
