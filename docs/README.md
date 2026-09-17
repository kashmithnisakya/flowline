# flowline docs

Sources for <https://kashmithnisakya.github.io/flowline/>: MkDocs with the
Material theme, published to GitHub Pages by `.github/workflows/docs.yml`.

```bash
python3 -m venv .venv-docs
.venv-docs/bin/pip install -r docs/requirements.txt
.venv-docs/bin/mkdocs serve -f docs/mkdocs.yml -a 127.0.0.1:8100
.venv-docs/bin/mkdocs build -f docs/mkdocs.yml --strict   # what CI runs
```

Pages live in `content/`. The API and data graph reference is generated from
the `.jac` sources by `hooks/jac_docs.py` through `::: walker <Name>` style
directives; see `content/contributing/docs.md` for the directive list and the
guard rails (a walker routed from `main.jac` with no directive fails the build).
