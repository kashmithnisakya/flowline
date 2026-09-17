# Jac gotchas

Traps that already cost real debugging time in this codebase. Most type-check
clean and only fail at runtime, in the browser, or on the deployed build.
{ .fl-lede }

## Compiles to JavaScript differently than it reads

??? bug "A computed key does not survive a dict-literal spread"

    `{**form, key: v}` compiles to JS `{...form, key: v}`, a **literal** `"key"`
    property, so bound inputs freeze.

    ```jac
    updated = {**form};
    updated[key] = v;
    form = updated;
    ```

??? bug "`xs and xs[0].field` is not a safe guard"

    A bare `and` compiles to `&&`, and an empty array is truthy in JS, so the
    guard passes and the index throws at render time. Guard with
    `len(xs) > 0`. (A plain `xs[0] if xs else ...` ternary does get the
    truthiness helper.)

??? bug "`max()` and `min()` over a list are `NaN`"

    They compile to `Math.max(array)`. A guard like `max(xs) > 0` then silently
    fails. Compute peaks with an explicit loop in client code.

??? bug "`len()` on a dict is always false-y"

    It compiles to `.length`, which is `undefined` on a plain object, so
    `len(d) > 0` is never true (and type-checks). Track emptiness with a
    separate `bool`. `len()` on a list is fine.

??? bug "A name first assigned inside an `if` is block-scoped"

    In the compiled JS it is a `ReferenceError` after the branch. Initialise it
    before the branch.

??? bug "Client-side `None` checks"

    `is None` misses `undefined`. Use `params["id"]`, never `.get()`. Rebind
    state rather than mutating it.

## JSX and components

??? bug "A `#` comment among JSX children renders as text"

    Inside the JSX tree a comment becomes a text node and ships to the page.
    Keep notes in the docstring or above the `return`.

??? bug "Elements directly inside `{if ...}` slots need `key` props"

    Give each one an explicit `key`.

??? bug "`{if}` inside a `{for}` body takes no braces"

    Write `if x { <li/> }`, not `{if x {...}}`; the wrapped form is rejected
    (`E2023`).

??? bug "A method named `set<Field>` collides with the state setter"

    `has zoom: float` generates a `setZoom` binding, so a `def setZoom` in the
    same component breaks the Vite build with a 503 at request time
    (`jac check` passes). Worse, an **imported function** named `set<Field>`
    is silently shadowed, so calls update React state instead of doing their
    job. Never declare a `has` whose setter name an import uses.

??? bug "A Radix `Select` shows its placeholder only for `\"\"`"

    A sentinel such as `"none"` with no matching item renders an empty trigger.
    Seed `""` for "nothing picked"; keep a sentinel only where an item carries
    it.

??? bug "A `has` flag cannot arbitrate a shared Escape"

    A Radix dialog flips its own open state during the same keydown that
    reaches a page-level listener. Ask the DOM instead:
    `[role=dialog][data-state=open]`.

## Effects and mounting

??? danger "Nothing reachable from a `useEffect` body may `return None`"

    React skips a cleanup that is `undefined`, but `None` compiles to `null`,
    which it calls: the page dies with "w is not a function" on the effect's
    **next** run. A one-statement effect lambda compiles to an
    expression-bodied arrow that returns its callee's value, so a
    `return None` anywhere in a function an effect calls becomes that effect's
    cleanup. Give early exits a real no-op cleanup.

??? danger "A page mounts once, but keep the double-mount defences"

    The layout reads `jacIsLoggedIn()` at render time, so the first render
    is the real chrome. It used to read it in an effect, which painted a bare
    page first and remounted every page inside the chrome, and the pages
    still carry the defences that made that safe: a one-shot URL parameter
    is read in entry and consumed in the effect that acts on it, and a call
    that must reach the server exactly once (the GitHub install completion)
    strips the parameter and starts the call **before** the first `await`,
    keeps the in-flight promise in module state, and awaits that same
    promise from every mount. A flag or a `Ref` is per instance, so keep
    those patterns.

??? note "The first paint is a placeholder"

    `lib/boot.js` is inlined into `<head>` from `jac.toml` and runs before
    the bundle: it paints the saved theme on `<html>`, preloads the Archivo
    file the header uses (the build keeps asset names) and, on app paths
    with a session, draws `#flowline-boot` before `#root`. The layout removes
    it in a `useLayoutEffect` on its first render. The header paints the
    workspace name and account from the cache `lib/session.jac` keeps, and a
    page renders its loaded frame with skeleton rows on the first data load
    only, sized by per-browser caches of the last visit (session-scoped: the
    keys live in `lib/session.jac` and `forgetSession` clears them), then
    cross-fades to the content through `components/common/Reveal`, which
    shows the frame again if `ready` drops with nothing on screen; a refetch
    keeps the rows and shows `components/common/Busy` after 300ms.

??? note "`has` state is a live cell on 0.37"

    `has x` compiles to a state cell read through `.val`, so a write is
    visible to the next statement, inside helpers and after `await`. Handlers
    written for 0.34 pass new values as arguments or keep them on a `Ref`;
    that is still correct. Build a new list in a local and assign once.

## Server and build

??? danger "`jac check` misses a missing import inside a walker"

    A `glob` or edge name that was never imported still type-checks, then
    raises `name '...' is not defined` at request time and 500s the walker.
    Only calling the endpoint finds it.

??? danger "Walker ability bodies must stay inline on 0.37.14"

    The endpoint effect pass does not follow an ability body into an
    `.impl.jac` annex, so an annexed walker is classified as a read, the
    client caches it, and saves stop invalidating (jaseci-labs/jac#9189).
    Compare `endpointEffects` in the `/board` shell to verify.

??? bug "No Python imports in modules the client imports types from"

    A stray `import datetime` in `models.jac` dragged `@jac/wasm_host` into the
    browser bundle. Server-only helpers live in `services/util.jac`.

??? bug "Never name a module after an npm package it imports"

    `components/ui/sonner.jac` importing `"sonner"` resolved to itself: an
    infinite React mount loop. It lives in `toaster.jac`.

??? bug "`.jac/cache` can serve a stale build after an `.impl.jac` edit"

    If a fix does not appear under `/compiled/...`, delete `.jac/cache` and
    `.jac/client/compiled`, then restart.

??? danger "Write `status` through `Task.set_status`, never by assignment"

    `set_status(status, stamp)` stamps `done_at` when a task enters Done and
    clears it when it leaves (a constructor passes `done_at` itself). The
    Overview's weekly Done count, `TaskHistory` and the snapshot's
    done-in-period read `done_day(t)` and `moved_to_done(t)` from
    `services/util.jac`, so a bare `t.status = ...` makes them disagree.

??? danger "`UpdateTask` overwrites every field it is sent"

    Every page that opens the task sheet (`components/board/TaskDialog.jac`)
    must carry `start_date` and the iteration (a jid or `"none"`) in its form
    and pass them on save, or a save clears them. The checklist is deliberately
    **not** part of the form: only `AddChecklistItem`, `SetChecklistItem` and
    `RemoveChecklistItem` write it, each applied at once, and a page that opens
    the sheet passes `taskId`, `checklist` and an `onChecklist` that swaps the
    reported view into its rows.

??? note "`Root` is not a runtime name in `models.jac`"

    Nothing there may `isinstance(x, Root)`. Inside a `Task` or `LogDay`
    ability, `here` is the task or day and `root` is the caller's root.

## Placement

Since Jac 0.35 placement is inferred and the `cl` and `sv` markers are syntax
errors; `[placement.pins]` in `jac.toml` is the override.

- `models` and every `services.*` module carry a module-level `"server"` pin.
  Without it, a page's plain import of a walker pulls the whole module into
  the browser bundle and the build dies with "Client pathway failed to lower
  this edge reference shape". **A new service module needs its own pin.**
- The `lib.utils` helpers are pinned `"client"`, because an evidence-free
  `def:pub` in a web app is otherwise a server endpoint.
- `[placement] default = "server"` is load-bearing for deploys: at the
  `"native"` default the client build compiles `constants.jac` to wasm and the
  deployed board crashes. `jac run` never reproduces it, so verify with
  `jac build --as client main.jac`.
- `jac check <page> --placements` prints every verdict with its evidence.
