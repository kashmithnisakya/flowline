# Writing these docs

This site is [MkDocs](https://www.mkdocs.org/) with the
[Material](https://squidfunk.github.io/mkdocs-material/) theme. A small build
hook reads the `.jac` sources so the reference cannot drift from the code, and
GitHub Pages hosts the result.
{ .fl-lede }

## Build locally

```bash
python3 -m venv .venv-docs
.venv-docs/bin/pip install -r docs/requirements.txt
.venv-docs/bin/mkdocs serve -f docs/mkdocs.yml     # http://127.0.0.1:8000
```

Stop `jac run` first or pass `-a 127.0.0.1:8100`: both default to port 8000.
`mkdocs serve` rebuilds when a page, the hook, or any Jac source the reference
reads changes. Before pushing, build the way CI does:

```bash
.venv-docs/bin/mkdocs build -f docs/mkdocs.yml --strict
```

## Layout

```text
docs/
├── mkdocs.yml            # site config, theme, navigation
├── requirements.txt      # pinned build dependencies
├── hooks/jac_docs.py     # the Jac reference generator
├── overrides/home.html   # the home page hero
└── content/              # the pages; one folder per nav section
    └── assets/stylesheets/flowline.css
```

Brand assets are not copied into `docs/`: the hook publishes
`assets/brand/*.svg` and `gifs/flowline-demo.gif` straight from the repo.

## The reference directives

mkdocstrings reads Python, so `docs/hooks/jac_docs.py` does the same job for
Jac. A directive on its own line expands into a reference block at build time:

| Directive | Renders |
| --- | --- |
| `::: walker <Name> [h2-h6]` | Endpoint, auth, base walker, report type, source link, docstring, and a table of body fields (inherited ones marked) |
| `::: walkers <file.jac>` | Every walker in a file, in source order |
| `::: node <Name>`, `::: obj <Name>` | The archetype's doc and fields |
| `::: objs <file.jac>` | Every `obj` in a file |
| `::: edges <file.jac>` | A table of the typed edges |
| `::: glob <NAME>` | The glob's declared value as a `jac` code block |
| `::: endpoints` | An index of every walker `main.jac` routes |

Field descriptions come from the comments above each field (or on its line),
docstrings, and `sem` strings. Type names that are documented elsewhere on the
site link to their page. Two placeholders, `jac_version` and `walker_count`
wrapped in double curly braces, expand to the pin in `jac.toml` and the number
of routed walkers.

!!! tip "Improve the reference by improving the source"

    A walker's table is only as good as its comments. A one-line comment above
    a field is the cheapest documentation in the repo: it helps the next reader
    of the code and this site at once.

A directive inside an admonition or tab works; indent it with the block.

## Guard rails

The build runs with `--strict`, so every warning fails it:

- **An undocumented walker.** When `main.jac` routes a walker that no page
  names with `::: walker`, the build warns and lists it.
- **A renamed or removed declaration.** A directive naming something that no
  longer exists stops the build with the page and the directive.
- **Broken links and anchors.** Every internal link and `#anchor` is checked.

## Syntax highlighting

The hook registers a Pygments lexer for Jac, so fenced blocks tagged `jac`
highlight keywords, archetypes, abilities and the edge operators (`++>`,
`-->`, `<--`).

## Writing style

- No em dashes. Use commas, periods or parentheses.
- Describe what the app does today; no invented features, numbers or
  testimonials.
- Lead a page with a one-paragraph summary marked `{ .fl-lede }`.
- Prefer a table to a long list when readers compare options.
- Put a diagram where it shows a real mechanism (Mermaid fences render
  natively).

## Publishing

`.github/workflows/docs.yml` builds with `--strict` on pull requests that touch
the docs, `models.jac`, `constants.jac`, `main.jac`, `services/` or `jac.toml`,
and on pushes to `dev` it deploys to GitHub Pages at
<https://kashmithnisakya.github.io/flowline/>.

GitHub Pages must be set to deploy from **GitHub Actions** once, under
**Settings, Pages, Build and deployment, Source**, or with:

```bash
gh api -X POST repos/kashmithnisakya/flowline/pages -f build_type=workflow
```
