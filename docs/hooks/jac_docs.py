"""MkDocs hook: a small mkdocstrings for Jac.

mkdocstrings reads Python, so this hook reads the `.jac` sources itself. It
expands `:::` directives into reference blocks, registers a Pygments lexer for
```jac fences, publishes the brand assets from the repo, and (in strict
builds) fails when a walker routed from main.jac is documented nowhere.

Directives, one per line, outside code fences:

    ::: walker <Name> [h2|h3|h4]      one walker (fields, reports, source link)
    ::: walkers <file.jac> [hN]       every walker in a file, in source order
    ::: node <Name> [hN]              a persisted node and its fields
    ::: obj <Name> [hN]               a view object and its fields
    ::: objs <file.jac> [hN]          every obj in a file
    ::: edges <file.jac>              a table of the typed edges
    ::: glob <NAME>                   a glob's declared value, as a jac block
    ::: endpoints                     an index of every routed walker
"""

from __future__ import annotations

import html
import logging
import re
import textwrap
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

import pygments.lexers as _pygments_lexers
from mkdocs.exceptions import PluginError
from mkdocs.structure.files import File, Files
from mkdocs.utils import get_relative_url
from pygments.lexer import RegexLexer, bygroups, words
from pygments.token import (
    Comment,
    Keyword,
    Name,
    Number,
    Operator,
    Punctuation,
    String,
    Whitespace,
)

log = logging.getLogger("mkdocs.hooks.jac_docs")

# Repo root: mkdocs.yml lives in docs/, the sources one level up.
ROOT = Path(__file__).resolve().parents[2]
SOURCE_GLOBS = ["models.jac", "constants.jac", "services/**/*.jac"]
# Files published from the repo rather than copied into docs/content.
REPO_ASSETS = ["assets/brand/*.svg", "gifs/flowline-demo.gif"]


# --------------------------------------------------------------------- lexer


class JacLexer(RegexLexer):
    name = "Jac"
    aliases = ["jac", "jaclang"]
    filenames = ["*.jac"]

    tokens = {
        "root": [
            (r"\s+", Whitespace),
            (r"#\*[\s\S]*?\*#", Comment.Multiline),
            (r"#.*?$", Comment.Single),
            (r'[rbfRBF]{0,2}"""[\s\S]*?"""', String.Doc),
            (r"[rbfRBF]{0,2}'''[\s\S]*?'''", String.Doc),
            (r'[rbfRBF]{0,2}"(\\\\|\\"|[^"\n])*"', String.Double),
            (r"[rbfRBF]{0,2}'(\\\\|\\'|[^'\n])*'", String.Single),
            (r"@[A-Za-z_][\w.]*", Name.Decorator),
            (
                r"(walker|node|edge|obj|enum|class)(\s+)([A-Za-z_]\w*)",
                bygroups(Keyword.Declaration, Whitespace, Name.Class),
            ),
            (
                r"(def|can)(\s+)([A-Za-z_]\w*)",
                bygroups(Keyword.Declaration, Whitespace, Name.Function),
            ),
            (words(("import", "from", "include", "as"), suffix=r"\b"), Keyword.Namespace),
            (
                words(
                    (
                        "has", "glob", "static", "async", "with", "entry", "exit",
                        "visit", "report", "disengage", "spawn", "by", "if", "elif",
                        "else", "for", "in", "while", "return", "try", "except",
                        "finally", "lambda", "and", "or", "not", "is", "del", "await",
                        "match", "case", "test", "impl", "sem", "break", "continue",
                        "raise", "assert", "skip",
                    ),
                    suffix=r"\b",
                ),
                Keyword,
            ),
            (words(("True", "False", "None"), suffix=r"\b"), Keyword.Constant),
            (words(("self", "here", "root", "visitor", "super"), suffix=r"\b"), Name.Builtin.Pseudo),
            (
                words(
                    ("str", "int", "float", "bool", "list", "dict", "tuple", "set", "any", "Root"),
                    suffix=r"\b",
                ),
                Keyword.Type,
            ),
            (r"\+\+>|<\+\+|-->|<--|:\+>|<\+:|->|<-|[-+*/%=<>!&|^~]+", Operator),
            (r"\d+\.\d*|\d*\.\d+|\d+", Number),
            (r"[A-Za-z_]\w*(?=\s*\()", Name.Function),
            (r"[A-Za-z_]\w*", Name),
            (r"[{}()\[\];,.:?]", Punctuation),
        ]
    }


# pymdownx.highlight looks lexers up by alias; seeding the table and the cache
# makes ```jac resolve without a package entry point.
_pygments_lexers._lexer_cache[JacLexer.name] = JacLexer
_pygments_lexers.LEXERS["JacLexer"] = (__name__, JacLexer.name, tuple(JacLexer.aliases), ("*.jac",), ())


# -------------------------------------------------------------------- parser


@dataclass
class Field:
    name: str
    type: str
    default: str | None
    doc: str
    inherited_from: str = ""
    default_src: str = ""


@dataclass
class Decl:
    kind: str  # walker | node | edge | obj | glob
    name: str
    file: str  # repo-relative
    line: int
    base: str = ""  # walker base, or an edge's "From --> To"
    doc: str = ""
    decorators: list[str] = field(default_factory=list)
    fields: list[Field] = field(default_factory=list)
    reports: str = ""
    methods: list[tuple[str, str]] = field(default_factory=list)
    source: str = ""


TOKEN_RE = re.compile(
    r"""
    (?P<comment>\#\*[\s\S]*?\*\#|\#[^\n]*)
   |(?P<string>[rRbBfF]{0,2}(?:\"\"\"[\s\S]*?\"\"\"|'''[\s\S]*?'''|"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'))
   |(?P<word>[A-Za-z_][A-Za-z0-9_]*)
   |(?P<nl>\n)
   |(?P<ws>[ \t\r]+)
   |(?P<op>-->|\+\+>|<--|->|[{}()\[\];,:=@.]|.)
    """,
    re.X,
)

OPEN = {"{": "}", "(": ")", "[": "]"}
DECL_KINDS = {"walker", "node", "edge", "obj"}


@dataclass
class Tok:
    kind: str
    text: str
    start: int
    end: int
    line: int


def tokenize(src: str) -> list[Tok]:
    out: list[Tok] = []
    line = 1
    for m in TOKEN_RE.finditer(src):
        kind = m.lastgroup or "op"
        text = m.group()
        if kind != "ws":
            out.append(Tok(kind, text, m.start(), m.end(), line))
        line += text.count("\n")
    return out


def clean_comment(text: str) -> str:
    if text.startswith("#*"):
        return " ".join(text[2:-2].split())
    return text[1:].strip()


def clean_docstring(text: str) -> str:
    body = re.sub(r"^[rRbBfF]{0,2}(\"\"\"|''')", "", text)[:-3]
    first, _, rest = body.partition("\n")
    return (first.strip() + "\n" + textwrap.dedent(rest)).strip()


def squash(src: str) -> str:
    # One line, single spaces, for types and defaults read out of the source.
    return " ".join(src.split())


def match_close(toks: list[Tok], i: int) -> int:
    """Index of the token closing the bracket at toks[i]."""
    depth = 0
    for j in range(i, len(toks)):
        t = toks[j]
        if t.kind == "op" and t.text in OPEN:
            depth += 1
        elif t.kind == "op" and t.text in ("}", ")", "]"):
            depth -= 1
            if depth == 0:
                return j
    raise ValueError(f"unbalanced bracket at line {toks[i].line}")


def parse_fields(src: str, toks: list[Tok], i: int) -> tuple[list[Field], int]:
    """Parse `name: type = default, ...;` starting at toks[i]; returns the
    fields and the index of the terminating `;`."""
    fields: list[Field] = []
    segment: list[Tok] = []
    depth = 0
    j = i
    prev_field_line = -1

    def flush(seg: list[Tok]) -> None:
        # Only comments above the field describe it; ones inside a default
        # value (a template dict) belong to that value.
        lead = next((k for k, t in enumerate(seg) if t.kind not in ("comment", "nl")), len(seg))
        docs = [clean_comment(t.text) for t in seg[:lead] if t.kind == "comment"]
        body = [t for t in seg if t.kind not in ("comment", "nl")]
        if not body or body[0].kind != "word":
            return
        name = body[0].text
        colon = next((k for k, t in enumerate(body) if t.text == ":"), -1)
        eq = -1
        d = 0
        for k, t in enumerate(body):
            if t.kind == "op" and t.text in OPEN:
                d += 1
            elif t.kind == "op" and t.text in ("}", ")", "]"):
                d -= 1
            elif d == 0 and t.text == "=" and k > colon:
                eq = k
                break
        type_end = eq if eq >= 0 else len(body)
        type_src = src[body[colon + 1].start : body[type_end - 1].end] if colon >= 0 and type_end > colon + 1 else ""
        raw = src[body[eq + 1].start : body[-1].end] if eq >= 0 else ""
        default = squash(raw) if eq >= 0 else None
        fields.append(Field(name, squash(type_src), default, " ".join(docs), default_src=raw))

    while j < len(toks):
        t = toks[j]
        if t.kind == "op" and t.text in OPEN:
            depth += 1
        elif t.kind == "op" and t.text in ("}", ")", "]"):
            depth -= 1
        if depth == 0 and t.kind == "op" and t.text in (",", ";"):
            flush(segment)
            prev_field_line = t.line
            segment = []
            if t.text == ";":
                return fields, j
            j += 1
            continue
        # A trailing comment on the line that ended the previous field is its doc.
        if t.kind == "comment" and t.line == prev_field_line and fields and not segment:
            fields[-1].doc = (fields[-1].doc + " " + clean_comment(t.text)).strip()
        else:
            segment.append(t)
        j += 1
    raise ValueError("unterminated has/glob statement")


def parse_body(decl: Decl, src: str, toks: list[Tok]) -> None:
    """Fill a declaration's docstring, fields and methods from the tokens
    between its braces (exclusive)."""
    i = 0
    stmt_start = True
    pending: list[str] = []
    while i < len(toks):
        t = toks[i]
        if t.kind == "nl":
            if i > 0 and toks[i - 1].kind == "nl":
                pending = []
            i += 1
            continue
        if t.kind == "comment":
            pending.append(clean_comment(t.text))
            i += 1
            continue
        if stmt_start and t.kind == "string" and t.text.lstrip("rRbBfF").startswith(('"""', "'''")) and not decl.doc:
            decl.doc = clean_docstring(t.text)
            pending = []
            i += 1
            continue
        if stmt_start and t.kind == "word" and t.text == "has":
            fields, end = parse_fields(src, toks, i + 1)
            if pending and fields and not fields[0].doc:
                fields[0].doc = " ".join(pending)
            for f in fields:
                if f.name == "reports":
                    m = re.fullmatch(r"list\[(.+)\]", f.type)
                    decl.reports = m.group(1) if m else f.type
                else:
                    decl.fields.append(f)
            pending = []
            i = end + 1
            stmt_start = True
            continue
        if t.kind == "word" and t.text in ("def", "can") and stmt_start:
            name = toks[i + 1].text if i + 1 < len(toks) else ""
            if t.text == "def" and not name.startswith("_"):
                decl.methods.append((name, " ".join(pending)))
            j = i
            while j < len(toks) and not (toks[j].kind == "op" and toks[j].text in ("{", ";")):
                if toks[j].kind == "op" and toks[j].text in ("(", "["):
                    j = match_close(toks, j)
                j += 1
            i = (match_close(toks, j) if j < len(toks) and toks[j].text == "{" else j) + 1
            pending = []
            stmt_start = True
            continue
        if t.kind == "op" and t.text in OPEN:
            i = match_close(toks, i) + 1
            stmt_start = True
            continue
        stmt_start = t.kind == "op" and t.text in (";", "}")
        pending = []
        i += 1


def parse_file(path: Path) -> list[Decl]:
    src = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT).as_posix()
    toks = tokenize(src)
    decls: list[Decl] = []
    sems: list[tuple[str, str]] = []
    pending: list[str] = []
    decorators: list[str] = []
    stmt_start = True
    i = 0
    while i < len(toks):
        t = toks[i]
        if t.kind == "nl":
            if i > 0 and toks[i - 1].kind == "nl":
                pending = []
            i += 1
            continue
        if t.kind == "comment":
            pending.append(clean_comment(t.text))
            i += 1
            continue
        if stmt_start and t.kind == "string" and t.text.lstrip("rRbBfF").startswith(('"""', "'''")):
            # A module docstring is a statement of its own.
            i += 1
            continue
        if stmt_start and t.kind == "op" and t.text == "@":
            j = i
            while j < len(toks) and toks[j].kind != "nl":
                if toks[j].kind == "op" and toks[j].text in ("(", "["):
                    j = match_close(toks, j)
                j += 1
            decorators.append(squash(src[t.start : toks[j - 1].end]))
            i = j
            continue
        word = t.text if t.kind == "word" else ""
        if stmt_start and word == "async" and i + 1 < len(toks) and toks[i + 1].text == "walker":
            i += 1
            continue
        if stmt_start and word in DECL_KINDS and i + 1 < len(toks) and toks[i + 1].kind == "word":
            decl = Decl(word, toks[i + 1].text, rel, t.line, doc=" ".join(pending), decorators=decorators)
            j = i + 2
            if toks[j].text == "(":
                close = match_close(toks, j)
                decl.base = squash(src[toks[j].end : toks[close].start])
                j = close + 1
            elif toks[j].text == ":":
                k = j + 1
                while toks[k].text != "{":
                    k += 1
                decl.base = squash(src[toks[j].end : toks[k].start])
                j = k
            if toks[j].text != "{":
                raise PluginError(f"{rel}:{t.line}: expected '{{' after {word} {decl.name}")
            close = match_close(toks, j)
            body_doc = decl.doc
            decl.doc = ""
            parse_body(decl, src, toks[j + 1 : close])
            decl.doc = decl.doc or body_doc
            decl.source = src[t.start : toks[close].end]
            decls.append(decl)
            pending, decorators = [], []
            i = close + 1
            stmt_start = True
            continue
        if stmt_start and word == "sem":
            # `sem Type = "..."` or `sem Type.field = "..."`: the prompt text
            # byLLM sees, and the best description those declarations have.
            j = i + 1
            while j < len(toks) and toks[j].text != "=":
                j += 1
            target = "".join(t.text for t in toks[i + 1 : j])
            k = j + 1
            while k < len(toks) and toks[k].text != ";":
                k += 1
            text = " ".join(clean_docstring(t.text) if t.text.lstrip("rRbBfF").startswith(('"""', "'''")) else t.text[1:-1] for t in toks[j + 1 : k] if t.kind == "string")
            sems.append((target, " ".join(text.split())))
            pending = []
            i = k + 1
            stmt_start = True
            continue
        if stmt_start and word == "glob":
            fields, end = parse_fields(src, toks, i + 1)
            first = True
            for f in fields:
                doc = f.doc or (" ".join(pending) if first else "")
                g = Decl("glob", f.name, rel, t.line, doc=doc)
                g.fields = [f]
                decls.append(g)
                first = False
            pending = []
            i = end + 1
            stmt_start = True
            continue
        if t.kind == "op" and t.text in OPEN:
            i = match_close(toks, i) + 1
            stmt_start = True
            pending, decorators = [], []
            continue
        stmt_start = t.kind == "op" and t.text in (";", "}")
        pending, decorators = [], []
        i += 1
    by_name = {d.name: d for d in decls if d.kind in DECL_KINDS}
    for target, text in sems:
        owner, _, member = target.partition(".")
        d = by_name.get(owner)
        if d is None:
            continue
        if not member:
            d.doc = d.doc or text
        for f in d.fields:
            if f.name == member and not f.doc:
                f.doc = text
    return decls


def routed_walkers() -> dict[str, str]:
    """Walker name -> module, for every name main.jac imports from services."""
    src = (ROOT / "main.jac").read_text(encoding="utf-8")
    out: dict[str, str] = {}
    for m in re.finditer(r"import\s+from\s+(services[\w.]*)\s*\{([^}]*)\}", src):
        for name in m.group(2).split(","):
            if name.strip():
                out[name.strip()] = m.group(1)
    return out


# ------------------------------------------------------------------ registry


class Registry:
    def __init__(self) -> None:
        self.decls: dict[tuple[str, str], Decl] = {}
        self.by_file: dict[str, list[Decl]] = {}
        self.routed = routed_walkers()
        self.anchors: dict[str, tuple[str, str]] = {}  # name -> (page src_uri, anchor)
        self.documented: set[str] = set()
        for pattern in SOURCE_GLOBS:
            for path in sorted(ROOT.glob(pattern)):
                try:
                    decls = parse_file(path)
                except ValueError as err:
                    raise PluginError(f"jac_docs: cannot parse {path}: {err}") from err
                rel = path.relative_to(ROOT).as_posix()
                self.by_file[rel] = decls
                for d in decls:
                    self.decls.setdefault((d.kind, d.name), d)

    def get(self, kind: str, name: str) -> Decl:
        found = self.decls.get((kind, name))
        if not found:
            raise PluginError(f"jac_docs: no {kind} named {name!r} in {', '.join(SOURCE_GLOBS)}")
        return found

    def fields_of(self, walker: Decl) -> list[Field]:
        # Base walker fields first, the way the runtime merges them.
        inherited: list[Field] = []
        if walker.kind == "walker" and walker.base:
            for base_name in [b.strip() for b in walker.base.split(",")]:
                base = self.decls.get(("walker", base_name))
                if base:
                    for f in self.fields_of(base):
                        inherited.append(Field(f.name, f.type, f.default, f.doc, f.inherited_from or base_name))
        own = {f.name for f in walker.fields}
        return [f for f in inherited if f.name not in own] + walker.fields


REGISTRY: Registry | None = None
CONFIG: dict = {}


# ----------------------------------------------------------------- rendering


def anchor(name: str) -> str:
    return re.sub(r"[^a-z0-9-]", "", name.lower())


def source_url(d: Decl) -> str:
    repo = CONFIG.get("repo_url", "").rstrip("/")
    ref = CONFIG.get("extra", {}).get("source_ref", "dev")
    return f"{repo}/blob/{ref}/{d.file}#L{d.line}"


def cell(text: str) -> str:
    return html.escape(text).replace("|", "&#124;").replace("\n", " ")


def type_html(type_src: str, page, files: Files) -> str:
    """A type as inline code, with known view/node names linked."""
    assert REGISTRY is not None
    parts = re.split(r"([A-Za-z_]\w*)", type_src)
    out = []
    for part in parts:
        target = REGISTRY.anchors.get(part)
        if target and page is not None:
            f = files.get_file_from_path(target[0])
            if f is not None:
                href = get_relative_url(f.url, page.file.url) + "#" + target[1]
                out.append(f'<a href="{href}">{cell(part)}</a>')
                continue
        out.append(cell(part))
    return "<code>" + "".join(out) + "</code>"


def endpoint_of(d: Decl) -> tuple[str, str, str]:
    """(verb, path, auth) for a walker."""
    if any("APIProtocol.WEBHOOK" in dec for dec in d.decorators):
        scheme = re.search(r'scheme\s*=\s*"(\w+)"', " ".join(d.decorators))
        auth = "GitHub signature" if scheme and scheme.group(1) == "github" else "API key + HMAC"
        return "POST", f"/webhook/{d.name}", auth
    return "POST", f"/walker/{d.name}", "Bearer JWT"


def render_fields(fields: list[Field], page, files: Files, label: str) -> list[str]:
    if not fields:
        return [f"<p class='jac-empty'>{label}: none.</p>", ""]
    # A Description column only when some field has something to say.
    described = any(f.doc or f.inherited_from for f in fields)
    head = f"| {label} | Type | Default |" + (" Description |" if described else "")
    lines = [head, "| --- | --- | --- |" + (" --- |" if described else "")]
    for f in fields:
        default = (
            "<span class='jac-required'>required</span>"
            if f.default is None
            else "<code>" + cell(f.default) + "</code>"
        )
        doc = cell(f.doc)
        if f.inherited_from:
            doc = (doc + " " if doc else "") + f"<span class='jac-inherited'>from {cell(f.inherited_from)}</span>"
        row = f"| <code>{cell(f.name)}</code> | {type_html(f.type, page, files)} | {default} |"
        lines.append(row + (f" {doc} |" if described else ""))
    lines.append("")
    return lines


def doc_block(text: str) -> list[str]:
    return [text, ""] if text else []


def render_walker(d: Decl, level: int, page, files: Files) -> list[str]:
    assert REGISTRY is not None
    REGISTRY.documented.add(d.name)
    h = "#" * level
    lookup_base = d.name[:1].islower()
    lines = [f"{h} {d.name} {{ #{anchor(d.name)} .jac-heading }}", ""]
    meta = []
    if lookup_base:
        meta.append("<span class='jac-chip jac-chip--base'>lookup base</span>")
    else:
        verb, path, auth = endpoint_of(d)
        meta.append(f"<span class='jac-verb'>{verb}</span><code class='jac-path'>{path}</code>")
        meta.append(f"<span class='jac-chip'>{auth}</span>")
        if d.name not in REGISTRY.routed and not path.startswith("/webhook/"):
            meta.append("<span class='jac-chip jac-chip--warn'>not routed</span>")
    if d.base:
        meta.append(f"<span class='jac-chip'>extends <code>{cell(d.base)}</code></span>")
    if d.reports:
        meta.append(f"<span class='jac-chip'>reports {type_html(d.reports, page, files)}</span>")
    meta.append(f"<a class='jac-src' href='{source_url(d)}' title='View source'>{d.file}:{d.line}</a>")
    lines += ["<div class='jac-meta'>" + "".join(meta) + "</div>", ""]
    lines += doc_block(d.doc)
    label = "Field" if lookup_base else "Body field"
    lines += render_fields(REGISTRY.fields_of(d), page, files, label)
    return lines


def render_archetype(d: Decl, level: int, page, files: Files) -> list[str]:
    h = "#" * level
    lines = [f"{h} {d.name} {{ #{anchor(d.name)} .jac-heading }}", ""]
    meta = [f"<span class='jac-chip jac-chip--kind'>{d.kind}</span>"]
    if d.base:
        meta.append(f"<span class='jac-chip'><code>{cell(d.base)}</code></span>")
    meta.append(f"<a class='jac-src' href='{source_url(d)}' title='View source'>{d.file}:{d.line}</a>")
    lines += ["<div class='jac-meta'>" + "".join(meta) + "</div>", ""]
    lines += doc_block(d.doc)
    if d.fields:
        lines += render_fields(d.fields, page, files, "Field")
    methods = [m for m in d.methods if m[1]]
    if methods:
        lines += ["| Method | Description |", "| --- | --- |"]
        lines += [f"| <code>{cell(n)}()</code> | {cell(doc)} |" for n, doc in methods]
        lines.append("")
    return lines


def render_edges(rel: str, page, files: Files) -> list[str]:
    assert REGISTRY is not None
    edges = [d for d in REGISTRY.by_file.get(rel, []) if d.kind == "edge"]
    if not edges:
        raise PluginError(f"jac_docs: no edges in {rel}")
    lines = ["| Edge | From | To | Source |", "| --- | --- | --- | --- |"]
    for d in edges:
        ends = [e.strip() for e in re.split(r"-->|<--", d.base)]
        src_, dst = (ends + ["", ""])[:2]
        lines.append(
            f"| <code>{d.name}</code> | {type_html(src_, page, files)} | {type_html(dst, page, files)} "
            f"| <a href='{source_url(d)}'>{d.file}:{d.line}</a> |"
        )
    return lines + [""]


def render_glob(d: Decl) -> list[str]:
    f = d.fields[0]
    lines = []
    if d.doc:
        lines += [d.doc, ""]
    lines += ["```jac", f"glob {f.name}: {f.type} = {pretty_value(f.default_src)};", "```", ""]
    lines.append(f"<p class='jac-src-line'><a class='jac-src' href='{source_url(d)}'>{d.file}:{d.line}</a></p>")
    return lines + [""]


def pretty_value(raw: str) -> str:
    # The value as written, re-indented: continuation lines carry the glob's
    # own hanging indent in the source.
    first, _, rest = raw.partition("\n")
    return first + ("\n" + textwrap.dedent(rest) if rest else "")


def render_endpoints(page, files: Files) -> list[str]:
    assert REGISTRY is not None
    lines = ["| Walker | Endpoint | Summary | Documented in |", "| --- | --- | --- | --- |"]
    for name, module in REGISTRY.routed.items():
        d = REGISTRY.decls.get(("walker", name))
        if d is None:
            continue
        verb, path, _ = endpoint_of(d)
        summary = first_sentence(d.doc)
        where = ""
        target = REGISTRY.anchors.get(name)
        if target:
            f = files.get_file_from_path(target[0])
            if f is not None:
                href = get_relative_url(f.url, page.file.url) + "#" + target[1]
                title = f.page.title if f.page and f.page.title else target[0]
                where = f"<a href='{href}'>{cell(str(title))}</a>"
        lines.append(f"| <code>{name}</code> | <code>{path}</code> | {cell(summary)} | {where} |")
    return lines + [""]


def first_sentence(text: str) -> str:
    flat = " ".join(text.split())
    m = re.match(r"(.+?[.!?])(\s|$)", flat)
    return m.group(1) if m else flat


DIRECTIVE = re.compile(r"^(\s*):::\s+(\w+)(?:\s+(\S+))?(?:\s+(h[2-6]))?\s*$")


def expand(markdown: str, page, files: Files) -> str:
    assert REGISTRY is not None
    out: list[str] = []
    fence = ""
    for raw in markdown.split("\n"):
        stripped = raw.strip()
        fence_match = re.match(r"^(`{3,}|~{3,})", stripped)
        if fence_match:
            if not fence:
                fence = fence_match.group(1)
            elif stripped.startswith(fence):
                fence = ""
        m = DIRECTIVE.match(raw) if not fence else None
        if not m:
            out.append(raw)
            continue
        indent, kind, arg, hlevel = m.group(1), m.group(2), m.group(3) or "", m.group(4)
        level = int(hlevel[1]) if hlevel else 2
        where = f"{page.file.src_uri}: '{raw.strip()}'"
        start = len(out)
        try:
            if kind == "walker":
                out += render_walker(REGISTRY.get("walker", arg), level, page, files)
            elif kind == "walkers":
                for d in [d for d in REGISTRY.by_file.get(arg, []) if d.kind == "walker"]:
                    out += render_walker(d, level, page, files)
            elif kind in ("node", "obj"):
                out += render_archetype(REGISTRY.get(kind, arg), level, page, files)
            elif kind in ("nodes", "objs"):
                decls = [d for d in REGISTRY.by_file.get(arg, []) if d.kind == kind[:-1]]
                if not decls:
                    raise PluginError(f"no {kind} in {arg}")
                for d in decls:
                    out += render_archetype(d, level, page, files)
            elif kind == "edges":
                out += render_edges(arg, page, files)
            elif kind == "glob":
                out += render_glob(REGISTRY.get("glob", arg))
            elif kind == "endpoints":
                out += render_endpoints(page, files)
            else:
                raise PluginError(f"unknown directive '{kind}'")
        except PluginError as err:
            raise PluginError(f"jac_docs: {where}: {err}") from err
        # A directive inside an admonition or tab carries its indent onto
        # every generated line.
        if indent:
            generated = [line for chunk in out[start:] for line in chunk.split("\n")]
            out[start:] = [indent + line if line else line for line in generated]
    return "\n".join(out)


# --------------------------------------------------------------------- hooks


def on_config(config):
    global REGISTRY, CONFIG
    REGISTRY = Registry()
    CONFIG = config
    pin = tomllib.loads((ROOT / "jac.toml").read_text(encoding="utf-8"))["project"]["jac-version"]
    config.extra["jac_version"] = pin.lstrip("=<>~! ")
    return config


def on_files(files: Files, config) -> Files:
    assert REGISTRY is not None
    for pattern in REPO_ASSETS:
        for path in sorted(ROOT.glob(pattern)):
            rel = path.relative_to(ROOT).as_posix()
            if files.get_file_from_path(rel) is None:
                files.append(File.generated(config, rel, abs_src_path=str(path)))
    # Pre-scan every page so a type can link to the page that documents it.
    for f in files.documentation_pages():
        text = Path(f.abs_src_path).read_text(encoding="utf-8")
        for m in re.finditer(r"^\s*:::\s+(walker|node|obj)\s+(\w+)", text, re.M):
            REGISTRY.anchors.setdefault(m.group(2), (f.src_uri, anchor(m.group(2))))
        for m in re.finditer(r"^\s*:::\s+(walkers|nodes|objs)\s+(\S+)", text, re.M):
            for d in REGISTRY.by_file.get(m.group(2), []):
                if d.kind == m.group(1)[:-1]:
                    REGISTRY.anchors.setdefault(d.name, (f.src_uri, anchor(d.name)))
    return files


def on_page_markdown(markdown: str, page, config, files: Files) -> str:
    assert REGISTRY is not None
    markdown = markdown.replace("{{ jac_version }}", config.extra["jac_version"])
    markdown = markdown.replace("{{ walker_count }}", str(len(REGISTRY.routed)))
    if ":::" not in markdown:
        return markdown
    return expand(markdown, page, files)


def on_post_build(config) -> None:
    assert REGISTRY is not None
    missing = [n for n in REGISTRY.routed if n not in REGISTRY.documented]
    if missing:
        log.warning(
            "jac_docs: walkers routed from main.jac but documented on no page: %s "
            "(add a '::: walker <Name>' directive to the matching API page)",
            ", ".join(missing),
        )
