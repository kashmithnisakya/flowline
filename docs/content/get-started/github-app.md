# Connect GitHub

The GitHub tab needs a GitHub App of its own. Once installed on the
repos you choose, issues and pull requests reach an open board within seconds,
issues import as tasks, and a card can open or close an issue.
{ .fl-lede }

!!! info "The GitHub App is not GitHub sign-in"

    Signing in with GitHub only proves who someone is, and the runtime discards
    that OAuth token. Reading issues and pull requests needs a credential of
    its own, which is what the App provides. flowline stores an
    **installation id, never a token**: each request mints a one-hour
    installation token in memory and drops it.

## 1. Create the App

Open <https://github.com/settings/apps/new> (or your organization's
**Settings, Developer settings, GitHub Apps**) and fill in:

| Field | Value |
| --- | --- |
| Callback URL | `<HOST>/workspace?tab=github` |
| Setup URL | `<HOST>/workspace?tab=github`, with **Redirect on update** ticked |
| Request user authorization (OAuth) during installation | **On** |
| Webhook | **Active**, URL `<HOST>/webhook/GithubEvent`, secret from `openssl rand -hex 32` |
| Webhook content type | `application/json` |
| Subscribe to events | Issues, Pull request, Pull request review, Sub-issues |
| Repository permissions | Issues: read and write, Pull requests: read, Metadata: read |

Installation events (`installation`, `installation_repositories`) are sent to
every App without subscribing.

!!! danger "Two settings that are not optional"

    **OAuth during installation.** Installation ids are small integers, so a
    forged install link could name someone else's installation. Completing a
    connection proves the person who authorized can actually see that
    installation, and that check needs the OAuth code GitHub only sends with
    this box on. With it off, connecting fails with `exchange_failed`.

    **JSON deliveries.** GitHub's default content type,
    `application/x-www-form-urlencoded`, is refused with `415` before any app
    code runs. The failure shows up in the App's delivery log.

## 2. Generate a private key and set the variables

On the App's page, **Generate a private key** downloads a `.pem`. Put it on one
line:

```bash
GITHUB_APP_PRIVATE_KEY=$(base64 -i your-app.private-key.pem | tr -d '\n')
```

Then fill in the rest of the GitHub App block in `.env`:

```bash
GITHUB_APP_ID=123456
GITHUB_APP_SLUG=your-app-slug            # from https://github.com/apps/<slug>
GITHUB_APP_CLIENT_ID=Iv23li...           # the App's own OAuth credentials,
GITHUB_APP_CLIENT_SECRET=...             # not the SSO pair
GITHUB_APP_PRIVATE_KEY=LS0tLS1CRUdJTi... # base64, or a PEM with literal \n
GITHUB_APP_WEBHOOK_SECRET=...            # the same secret the webhook uses
```

| Left empty | What happens |
| --- | --- |
| Any of the first five | The GitHub tab explains which variables are missing instead of failing (`GithubStatus` reports them as `missing_config`). |
| `GITHUB_APP_SLUG` specifically | The receiver cannot recognise the App's own echoes (see [GitHub sync](../concepts/github-sync.md#writing-back-to-github)). |
| `GITHUB_APP_WEBHOOK_SECRET` | The server refuses to boot. |

## 3. Connect a workspace

Restart the server with the variables exported, then open **Workspace, GitHub**
and choose **Connect**. GitHub asks which account and repositories to install
on, then redirects back and the page completes the connection once. After
that, attach repos to projects and decide per repo:

| Toggle | Effect |
| --- | --- |
| Auto-sync | New issues are filed onto the flow line's first start step. Turning it on back-fills the repo's history (closed issues land on Done). |
| Auto-done | A merged pull request or a closed issue moves the linked card to the done step. |
| Close issue on done | A card landing on Done closes its GitHub issue. Off by default; the only automatic write to GitHub. |

## Local development: tunnel the webhook

GitHub cannot reach `localhost`. Point the App's webhook at a
[smee.io](https://smee.io) channel and forward it:

```bash
npx smee-client --url https://smee.io/<your-channel> \
  --target http://localhost:8000/webhook/GithubEvent
```

While iterating, the App's **Advanced** tab lists every delivery with its
response body and a **Redeliver** button. GitHub does not retry a failed
delivery on its own.

## Troubleshooting

| You see | Meaning |
| --- | --- |
| `not_configured` when connecting | One of the five App variables is empty in the server's environment. |
| `bad_state` | The install link was not started from this workspace, or a newer link replaced it. Start again. |
| `expired` | More than 15 minutes passed between starting and finishing the install. |
| `exchange_failed` | GitHub sent no OAuth code: turn on **Request user authorization (OAuth) during installation**. |
| `not_yours` | The GitHub account that authorized cannot see that installation. |
| Delivery response `unknown_installation` | No workspace has completed a connection for that installation id. |
| Delivery response `echo` | The App's own write (closing an issue) coming back. Dropped on purpose. |
| Delivery status `401` | The signature did not match: the App's webhook secret and `GITHUB_APP_WEBHOOK_SECRET` differ. |
| Delivery status `415` | The webhook content type is not `application/json`. |
| A reconnect banner on the board | A GitHub call returned `401` or `404` and the connection was marked invalid. Reconnect from the GitHub tab. |

For the full pipeline (receiver, queue, drain and reconcile poll) read
[GitHub sync](../concepts/github-sync.md). For the walkers, see the
[GitHub API](../api/github.md) and [Webhooks](../api/webhooks.md).
