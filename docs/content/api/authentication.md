# Authentication

Accounts, tokens and sign-in are provided by the Jac runtime, not
by flowline's walkers. One account is one organization, and its token is what
scopes every walker call to that organization's graph.
{ .fl-lede }

## Register

```bash
curl -X POST http://localhost:8000/user/register \
  -H "Content-Type: application/json" \
  -d '{
    "identities": [{"type": "email", "value": "lead@example.com"}],
    "credential": {"type": "password", "password": "a-long-passphrase"},
    "profile": {"org_name": "Acme Robotics"}
  }'
```

`identities` is a **list** (email or username), and registration returns a
`user_id`, not a token (HTTP 201). The optional `profile` holds the
organization's details; the app's setup wizard writes `org_name` there if
sign-up did not.

```json
{ "ok": true, "data": { "user_id": "550e8400-...", "message": "User registered successfully" } }
```

## Log in

```bash
curl -X POST http://localhost:8000/user/login \
  -H "Content-Type: application/json" \
  -d '{
    "identity": {"type": "email", "value": "lead@example.com"},
    "credential": {"type": "password", "password": "a-long-passphrase"}
  }'
```

`identity` is a **single object** here. The response carries the JWT:

```json
{
  "ok": true,
  "data": { "user_id": "550e8400-...", "token": "eyJ...", "root_id": "a1b2c3d4...", "role": "user" }
}
```

Send it on every walker call:

```http
Authorization: Bearer eyJ...
```

## The organization profile

```bash
curl http://localhost:8000/user/me -H "Authorization: Bearer $TOKEN"
```

`GET /user/me` returns the account's identities, role and `profile`
(credentials are never included). flowline's client wraps it in
`lib/session.jac`, and updates the profile with `PATCH /user/me`, which merges
the given keys into the existing profile:

```bash
curl -X PATCH http://localhost:8000/user/me \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"profile": {"org_name": "Acme Robotics"}}'
```

Profile keys must match `^[a-zA-Z][a-zA-Z0-9_]{0,63}$`, values must be strings,
numbers or booleans, and the whole profile is capped at 8 KB.

## Refresh a token

```bash
curl -X POST http://localhost:8000/user/refresh-token \
  -H "Content-Type: application/json" \
  -d '{"token": "eyJ..."}'
```

Returns a new token with a fresh expiry, or `401` if the old one is invalid or
expired.

## Single sign-on

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/sso/{google,github}/login?client_callback=<origin>/auth/callback` | Start sign-in; redirects to the provider |
| `GET` | `/sso/{google,github}/register` | Same, for sign-up |
| `GET` | `/sso/{google,github}/callback` | The provider's redirect target; ends by redirecting to `/auth/callback?token=<JWT>` |

An unconfigured provider answers `501`. Setup is on
[Single sign-on](../get-started/sso.md).

## Other account endpoints

The runtime also serves password and identity management. flowline's UI does
not use these today, but they work against the same accounts:

| Method | Path | Auth |
| --- | --- | --- |
| `PUT` | `/user/password` | Bearer |
| `POST` | `/user/add-identity` | Bearer |
| `POST` | `/user/send-verification` | Bearer |
| `POST` | `/user/verify-identity` | Token in body |
| `POST` | `/user/forgot-password` | None (always `200`) |
| `POST` | `/user/reset-password` | Token in body |

!!! note "Members are not accounts"

    The people on the roster never sign in. Only the organization's account
    holds credentials; the roster is data in its graph.
