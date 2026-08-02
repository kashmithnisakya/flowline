# standup — v2.1 Plan: Brand, Simplified Org Model & Input Fixes (SHIPPED)

> Archived. All five milestones delivered:
> M1 frozen inputs (#3) · M2 the account is the organization (#4) ·
> M3 brand, logo generator and fonts (#5) · M4 auth page rebuild + Google
> and GitHub SSO (#6) · M5 public landing page, board moved to /board (#7).
> Google and GitHub credentials are wired through `.env` into
> `[scale.sso.*]` via `${VAR}` interpolation.

v2 shipped auth, organizations, projects and people (archived in
`plan-archive/PLAN-V2.md`, merged as PR #2). v2.1 is a **correction and
polish release** — no new product surface. Three themes:

1. **Fix what's broken** — several form inputs are frozen; you cannot type.
2. **Simplify the org model** — the account *is* the organization. Drop the
   `Organization` node; keep org details in the `/user/me` profile.
3. **Apply the Standup brand** — the design system from
   `Standup.dc.html`: warm paper background, ember accent, Bricolage
   Grotesque + Space Grotesk, and the bar-chart logo.

---

## 1. Frozen inputs — root cause found

**Symptom:** in the task dialog, member dialog and log form you can't type;
the field appears dead. Login/signup inputs work fine.

**Cause:** the dict-backed form setter

```jac
form = {**form, key: value};        # key is a variable
```

compiles to the JavaScript object literal

```js
setForm({...form, key: value});     // sets a LITERAL "key" property
```

so every keystroke writes `form["key"]` instead of `form["title"]`. The bound
`value={form["title"]}` never changes, React re-renders the same value, and
the input looks frozen. Login is unaffected because it assigns `has` fields
directly.

**Fix** (3 call sites — `impl/index`, `impl/roster`, `impl/log`):

```jac
updated = {**form};
updated[key] = value;               # subscript assignment survives to JS
form = updated;                     # rebind so the setter fires
```

> Already applied to the three `setField` implementations while diagnosing;
> `jac check` passes. Re-verify in the browser as the M1 gate.

**Also audit in the same pass:** every `{**dict, <variable>: value}` in the
codebase (grep for `**` followed by a non-quoted key), and confirm each of
the ~20 inputs across the app accepts real keystrokes.

**Add to the Jac gotchas list in the README:** computed keys do not survive
dict-literal spread — build a copy and subscript it.

---

## 2. The account is the organization

Today: `root ++> Organization{name, created_at, pm_root_ids}`, created by a
`CreateOrganization` walker and read by `GetMe`, gated behind a wizard step.

**That node is redundant.** A PM account is created *for* an organization —
one account, one org, forever. The runtime already gives us a per-account
profile store:

| Endpoint | Behaviour (verified in `jac/jaclang/scale/tests/server/test_serve.jac`) |
| --- | --- |
| `GET /user/me` | returns `{user_id, role, status, profile, identities}`; never leaks credentials |
| `PATCH /user/me` | **merges** the given `profile` keys into the existing profile |
| `jacSignup(identity, credential, profile)` | accepts a `profile` dict **at registration** |

### Decisions

- **Delete `node Organization`**, `CreateOrganization`, and the `GetMe`
  walker. Org name (and later logo, timezone, standup time) live in the
  account profile under `/user/me`.
- **Capture the organization name on the signup form.** `jacSignup` takes the
  profile, so signup writes `{"org_name": "..."}` in one call — no separate
  org step, no wizard gate, no "no org yet" redirect.
- **Everything hangs off `root`** — `root ++> Project / Member / Repo / Task /
  LogDay`. Walkers already run on the caller's own root, so isolation is
  unchanged.
- **Parentage checks stay, retargeted to root.** `jobj()` still resolves
  foreign ids, so `owned()` becomes "is this node attached to *my* root":
  compare `jid` of the node's incoming parent against `jid(here)` in the
  `Root entry` ability. This is the one piece of v2 security that must not
  regress — the foreign-jid attack tests stay green.
- **`pm_root_ids` disappears with the node.** The v3 multi-PM path becomes:
  invited PM's account profile stores the owner's `root_id`, and the owner
  grants their subtree — a v3 concern, unblocked either way.
- **No client helper exists for `/user/me`** (`client_runtime.jac` exports
  only signup/login/logout/isLoggedIn/ssoLogin/setToken). Wrap it once in
  `lib/session.jac`: `fetchMe()` and `patchProfile(dict)` doing a `fetch`
  with `Authorization: Bearer ${localStorage["jac_token"]}`.

### Wording

Drop "Create a PM account" everywhere. The signup card is about standing up
an organization's workspace. Use the design's own copy:

- Login title: **"Welcome back."**
- Signup title: **"Start your first standup."**
- Fields: **Work email**, **Password**, **Organization name** (signup only)
- Toggle: "New to standup? Create your workspace" / "Already have a
  workspace? Sign in"

---

## 3. Brand design system

Source: `~/Downloads/Standup SaaS Landing & Auth Design/` — `Standup.dc.html`
(markup + inline CSS), `support.js`, `standup-logo.svg`.

### Tokens (map onto the jac-shadcn CSS variables in `styles/global.css`)

| Token | Value | Role |
| --- | --- | --- |
| Ink | `#14120F` | foreground, logo mark, headings |
| Paper | `#F6F2EB` | app background (`body`) |
| Surface | `#FFFDFA` | cards, panels |
| Ember | `#E8552F` | primary / accent, CTA buttons, active bars |
| Muted ink | `#5E574B` | body copy |
| Subtle ink | `#8A8275` | secondary text, placeholders |
| Faint ink | `#6B6459` | tertiary |
| Line | `#EFE9DE` / `rgba(20,18,15,.11)` | borders |
| Pine | `#2C5545` | success / done |
| Amber | `#E8A22F` | warning / blocked accent |

- **Fonts** (Google Fonts): `Bricolage Grotesque` 400/600/700/800 for display
  and headings (tight negative letter-spacing, e.g. `-1.5px` at 33px);
  `Space Grotesk` 400/500/600/700 for UI and body. Self-host or add the
  stylesheet link — a strict CSP would block a remote font, so prefer
  `@fontsource` packages via npm.
- **Radii**: 11–13px for controls and cards, 20–22px for large panels,
  `999px` for pills and badges.
- **Elevation**: soft, long shadows on panels (`0 30px 60px -...`), no hard
  borders on primary surfaces.
- **Buttons**: ember fill with paper text (`#E8552F` / `#F6F2EB`).

### Where it lands

- `styles/global.css` — override the jac-shadcn token block (`--background`,
  `--foreground`, `--primary`, `--card`, `--border`, `--muted-foreground`,
  `--radius`) with the values above, in both light and dark blocks. Keep using
  Tailwind utility classes; **do not** hand-edit `components/ui/*`.
- Consider `jac retheme` for the base palette, then hand-tune the tokens.
- Auth page gets the design's split layout and headline treatment; the app
  shell (nav, board columns, cards) picks the palette up automatically once
  the tokens change.

### Logo — `brand/` generator

Create `brand/logo.jac`: a small Jac script that **emits** the mark rather
than us pasting SVG around.

- A `def` that returns the SVG string, parameterised by variant
  (`full` wordmark vs `mark` only), size, and dark/light fills.
- Geometry from `standup-logo.svg`: rounded square `#14120F` (56×56, r16),
  three ascending bars (`#F6F2EB`, `#F6F2EB`, `#E8552F`) at x=12/24.5/37 with
  heights 12/19/26 and r3.5, plus an ember dot (r4.5) above the tallest bar —
  a standup "rising" bar chart with a status dot.
- `jac run brand/logo.jac` writes the outputs into `assets/brand/`:
  `logo-full.svg`, `logo-mark.svg`, `logo-full-dark.svg`, plus a `favicon.svg`
  and PNG raster at 2× for anywhere SVG isn't accepted.
- The nav imports the mark; the auth page uses the full wordmark. Committing
  the generated files means the FE has a plain static path and the generator
  stays the single source of truth.

---

## Build order (one PR each, app deployable throughout)

1. **M1 — Input fixes.** Land the `setField` correction, audit every
   computed-key dict spread, and add the gotcha to the README.
   *Gate:* real keystrokes reach state in **every** input across board, log,
   people and projects dialogs — verified in a visible browser, not just a
   headless assertion.
2. **M2 — Org model simplification.** Delete `Organization`,
   `CreateOrganization`, `GetMe`; add `lib/session.jac` around `/user/me`;
   move org name into the signup profile; re-root every walker traversal and
   retarget `owned()` to the caller's root; delete the org step from the
   wizard (keep project + people, or drop the wizard entirely if signup
   already suffices).
   *Gate:* signup with an org name → straight into the app, name in the nav;
   the full 18-check API suite still passes, especially the foreign-jid
   attacks; a second account still sees nothing of the first.
3. **M3 — Brand tokens + logo.** `brand/logo.jac` generator and generated
   assets; fonts wired; `styles/global.css` retokenised; nav and auth page
   restyled.
   *Gate:* board, log, people, projects and login all render in the brand
   palette with no leftover neutral-grey chrome; screenshots refreshed.
4. **M4 — Auth page rebuild.** Apply the design's layout and copy; remove
   "PM account" wording; add the session-expired notice.
   *Gate:* login and signup match the design; wording review passes.
5. **M5 — Landing page.** The marketing site from the design becomes the
   public root, so hitting the server (e.g. `localhost:8000`) sells the
   product instead of bouncing to a login form. **Routing moves:**
   `/` → landing (public), `/board` → the kanban (auth), `/login` unchanged;
   logged-in visitors to `/` get a "Go to your board" CTA instead of "Sign
   up". Sections: hero, product, how-it-works, pricing, FAQ, footer CTA.
   *Gate:* `/` renders the landing page logged out **and** logged in; every
   in-app link still resolves after the board's route change; nav/footer CTAs
   route correctly.

Estimated: 4–5 working days.

## Decisions (answered)

- **Fonts:** self-host via `@fontsource/bricolage-grotesque` +
  `@fontsource/space-grotesk`.
- **Wizard:** keep it — it guides a new PM through the first project and
  people. Revisit in v2.2 if it reads as friction.
- **Landing page:** in scope for v2.1 (M5 above).

## Explicitly out of scope for v2.1

- Fix the bug mention in the Plan
- Landing page / marketing site (hero, pricing, FAQ) — v2.1

## Open questions

- **Fonts**: self-host via `@fontsource/bricolage-grotesque` +
  `@fontsource/space-grotesk`, or link Google Fonts? Self-hosting is the safer
  default and works offline.
A - Self-hosting 

- **Wizard**: once the org name moves to signup, is a projects+people wizard
  still worth it, or should a fresh account land straight on an empty board
  with inline empty-state prompts? Recommendation: **drop the wizard**, use
  empty states — fewer screens to brand and maintain.
  A- Keep the wizard for now, It is easy to guide the user through the process of creating a project and adding people. We can revisit this in v2.2 if we get feedback that it's too much friction.

- **Landing page**: the design includes a full marketing site (hero, pricing,
  FAQ). Not in v2.1 — flag if you want it as v2.2.
A - I need it now i mean in (V2.1) because we need to have a landing page for the product. So what ever the post we state the server (ex: localhost:8000) we need to have a landing page for the product. So I think we can use the design of the landing page and implement it in v2.1.
