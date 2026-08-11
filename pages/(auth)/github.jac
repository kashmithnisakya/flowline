"""standup - GitHub (/github): read issues and pull requests, import work.

Top-level again: browsing a repo and importing issues onto the board is
daily work, not configuration, so it earns a nav tab rather than a corner
of Workspace. The GitHub App's callback URL is <HOST>/github, and
GithubSection completes an in-flight install round trip on mount, so the
OAuth params land here directly. Old /workspace?tab=github links redirect
back here with their query string intact.
"""

import from ...components.workspace.GithubSection { GithubSection }
import from ...components.ui.button { Button }

def:pub GithubPage -> JsxPage {
    has browseNonce: int = 0;

    return <div className="flex w-full flex-col gap-8">
        <div className="flex items-center justify-between gap-6">
            <div>
                <h1 className="page-title">GitHub</h1>
                <p className="page-subtitle mt-1">
                    Read issues and pull requests, and import issues onto the board.
                </p>
            </div>
            <Button
                className="shrink-0"
                onClick={lambda { browseNonce = browseNonce + 1; }}
            >
                Browse GitHub repos
            </Button>
        </div>
        <GithubSection openNonce={browseNonce}/>
    </div>;
}
