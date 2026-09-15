# Contributing

How the repo is laid out, how changes land, and the checklist for the most
common change: a new walker.
{ .fl-lede }

## Repository layout

```text
flowline/
├── main.jac                 # entry point; its imports are the router
├── models.jac               # every node, edge and obj, plus graph helpers
├── constants.jac            # vocabularies shared by client and server
├── jac.toml                 # project, dependencies, serve, scale, placement
├── services/                # the walker API, one folder per section
│   ├── projects/  roster/  tasks/  board/  log/
│   ├── flowlines/  iterations/  insights/  assistant/
│   ├── github/    # github.jac, events.jac (webhook), util.jac
│   └── util.jac   # server-only helpers (dates, paging, tags)
├── pages/                   # file-based routes
│   ├── layout.jac           # path-aware app chrome
│   ├── (public)/            # /, /login, /auth/callback
│   └── (auth)/              # /board, /flowlines, /overview, /log, ...
│       └── impl/            # page handler bodies
├── components/              # presentational components by area
│   └── ui/                  # jac-shadcn registry copies: never edit
├── lib/                     # session, dates, theme, utils
├── styles/global.css        # brand and step colour tokens, both palettes
├── brand/logo.jac           # generates every logo into assets/brand/
├── tests/smoke/             # CI gates: deploy, API, webhook, browser
└── docs/                    # this site
```

## Workflow

- **`dev` is the default branch** and the base for pull requests. `main` is
  protected: branch, open a PR, merge. Direct pushes are rejected for everyone,
  including admins, and merged branches are deleted automatically.
- **Format and check with the pinned Jac** (`{{ jac_version }}`), not whatever
  `jac` is on your `PATH`; release lines disagree on formatting.
- **Commit messages** carry no `Co-Authored-By` trailers for AI tools.
- **Product copy describes what the app does.** The original design mock
  carried invented testimonials, metrics, pricing and integrations; none of it
  shipped, and the FAQ gives the honest "not yet" answers.
- `PLAN.md` (the working plan) is gitignored; shipped plans are archived in
  `plan-archive/`.

## Style

- No em dashes in code comments, docs or copy. Use commas, periods or
  parentheses.
- Comments and docstrings are at most three or four lines. Say the one
  non-obvious thing; anything longer belongs in `CLAUDE.md` or a plan.
- A docstring as the first statement of a plain `def` is a parse error: use a
  `#` comment above the `def`.
- `.jac` file names are one lowercase word (`flowlines.jac`), and the route
  slug follows.

## Adding a walker

1. **Write it in the right module** under `services/<section>/`, with its
   ability bodies **inline** (not in an `.impl.jac` annex; see
   [Architecture](../concepts/index.md#walker-patterns)).
2. **Follow the patterns.** A box-scoped walker visits its box. A jid-addressed
   mutation extends the section's lookup base (`find_task` and friends) or calls
   `resolve` plus `owned` itself. A list that grows with history pages.
3. **Import it in `main.jac`.** A walker missing from that list returns 404.
4. **A new module needs a placement pin** in `jac.toml`:
   `"services.<section>.<module>" = "server"`.
5. **Document it.** Add a `::: walker <Name>` directive to the matching page
   under `docs/content/api/` with a line on what it reports. The docs build
   fails until you do ([Writing these docs](docs.md)).
6. **Verify.** `jac check` the file, boot `jac run --no-dev main.jac` (only the
   bundle build sees client codegen failures), and call the walker. `jac check`
   does not catch a name missing from an import inside a walker; only a request
   does.
7. **If it takes an id, gate it.** Add a foreign-account case to the API gate:
   calling it with another account's id must be a no-op.

## Adding a UI primitive

```bash
jac install --shadcn <name>
```

That writes `components/ui/<name>.jac`. Import it; do not edit it, because the
next install rewrites the file. When a registry component ships broken, keep a
fixed copy under a name the installer cannot write to (the toaster lives in
`toaster.jac`, not `sonner.jac`).

## Brand assets

`brand/logo.jac` generates every logo variant into `assets/brand/`. Edit the
generator, then run it:

```bash
jac run brand/logo.jac
```

Reference brand assets as `/static/...`, never `/assets/...` (Vite owns
`/assets/*` at build time). This docs site publishes the same files.
