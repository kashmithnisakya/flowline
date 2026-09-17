# Install Jac

flowline is written entirely in [Jac](https://www.jaseci.org/):
the graph model, the walker API and the React client. Jac ships as a single
native binary with its runtime bundled, so there is no Python, pip or Node to
set up first.
{ .fl-lede }

## Install the pinned release

flowline pins an exact Jac release in `jac.toml`:

```toml title="jac.toml"
[project]
jac-version = "=={{ jac_version }}"
```

Install that version:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh \
  | bash -s -- --version {{ jac_version }}
```

The binary lands in `~/.local/bin/jac`. Make sure that directory is on your
`PATH`, then confirm:

```console
$ jac --version
```

!!! warning "Use the pinned version, not the latest"

    Jac release lines disagree on formatting and on some type-check results.
    CI runs `jac fmt --check` with the version in `jac.toml`, so a newer or
    development `jac` on your `PATH` can produce formatting that CI rejects.
    The jachammer platform also hands each deploy to the pinned version.
    If you keep several binaries around, check which one runs with
    `which -a jac`.

To install the newest release instead (for trying things out, not for this
repo), drop `--version`:

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
```

## Reference guides ship with the compiler

Jac's syntax looks like Python and JSX but is neither. The `jac` binary carries
the authoritative guides, so read them before writing `.jac`:

```bash
jac guide                          # list every guide
jac guide jac-core-cheatsheet      # start here
jac guide jac-types
jac guide --search walker          # search by topic
```

Compiler diagnostics link to the relevant guide with a `-> run 'jac guide ...'`
hint.

## The commands you will use

| Command | What it does |
| --- | --- |
| `jac install` | Installs the Python and npm dependencies declared in `jac.toml` |
| `jac run --no-dev main.jac` | Serves the app the way production does: client and API on one origin (`:8000`) |
| `jac run -w 1 main.jac` | Hot-reload development mode: app on `:8000`, API on `:8001` |
| `jac check <file>` | Type-check and lint one file |
| `jac fmt --lintfix <file>` | Format and auto-fix lint, the form CI enforces |
| `jac install --shadcn <name>` | Adds a UI primitive under `components/ui/` |
| `jac scale deploy --dry-run --show-yaml main.jac` | Renders the Kubernetes manifests without applying anything |

!!! note "`jac start` and `jac dev` are gone"

    Both were removed in Jac 0.37 and now exit with an error that names the
    `jac run` spelling. Server flags go **before** the file:
    `jac run --port 3000 main.jac`.

## Upgrading the pin

1. Change `jac-version` in `jac.toml`.
2. Install that version with the command above.
3. Run `jac fmt --lintfix` over the tracked `.jac` files (except
   `components/ui/`) and commit the formatting diff with the bump.
4. Boot the app (`jac run --no-dev main.jac`) and run the smoke gates. `jac check`
   cannot see client bundle failures; only a real build does.
5. Verify the deploy path too: `jac build --as client main.jac`.

!!! danger "One runtime per database"

    Persisted anchors embed each archetype's module path and the runtime
    reads them with its own class registry. Pointing a different Jac build at
    an existing local store can fail with `unregistered class Root` while
    login still works. Verify an upgrade with a walker call, not a page load.
    See [Operations](../deploy/operations.md#upgrading-jac-on-a-live-deployment).
