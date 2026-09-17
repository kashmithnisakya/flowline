# Get started

From a clean machine to a running board in three commands.
Everything past that (sign-in providers, GitHub, the assistant) is optional
and switches on through environment variables.
{ .fl-lede }

## Prerequisites

| Need | Why |
| --- | --- |
| macOS or Linux with `bash` and `curl` | The Jac installer is a shell script that downloads a native binary |
| `git` | To clone the repo (and jachammer bundles the tracked files) |
| Nothing else | The `jac` binary bundles its own Python runtime, and `jac install` fetches the npm packages the client needs |

!!! tip "Optional credentials"

    None of these are needed to run the app. Each one lights up one feature.

    - `OPENAI_API_KEY` for the [assistant](../api/assistant.md)
    - A Google or GitHub OAuth client for [single sign-on](sso.md)
    - A GitHub App for the [GitHub integration](github-app.md)

## Quickstart

1.  **Install the pinned Jac release**

    ```bash
    curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh \
      | bash -s -- --version {{ jac_version }}
    ```

    `{{ jac_version }}` is the release pinned in `jac.toml`. CI formats, checks
    and deploys with exactly that version, so match it locally.
    See [Install Jac](install-jac.md).

2.  **Clone and install dependencies**

    ```bash
    git clone https://github.com/kashmithnisakya/flowline.git
    cd flowline
    jac install
    ```

3.  **Configure and serve**

    ```bash
    cp .env.example .env
    echo "GITHUB_APP_WEBHOOK_SECRET=$(openssl rand -hex 32)" >> .env
    set -a; . ./.env; set +a
    jac run --no-dev main.jac
    ```

    The GitHub webhook receiver refuses to boot with an empty secret and the
    template leaves it empty, so the second line sets a random one. Any value
    works until you [connect a real GitHub App](github-app.md).

4.  **Sign up**

    Open <http://localhost:8000> and choose **Sign up**. The setup wizard asks
    for your organization's name and a flow line to start from.

## Next steps

<div class="grid cards" markdown>

-   :material-console:{ .lg .middle } **[Run locally](run-locally.md)**

    Production versus hot-reload mode, ports, the local database and the
    server hygiene that saves an afternoon.

-   :material-tune-variant:{ .lg .middle } **[Configuration](configuration.md)**

    Every environment variable and every `jac.toml` table, with what each one
    changes.

-   :material-account-key-outline:{ .lg .middle } **[Single sign-on](sso.md)**

    Google and GitHub sign-in, and the callback URLs each provider needs.

-   :material-github:{ .lg .middle } **[Connect GitHub](github-app.md)**

    Create the GitHub App, set its webhook, and test deliveries locally.

</div>
