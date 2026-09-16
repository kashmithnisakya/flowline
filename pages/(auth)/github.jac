"""flowline - GitHub (/github): read issues and pull requests, import work.
Daily work, not configuration, so it has its own nav tab. The App's callback
URL is <HOST>/github and GithubSection finishes an in-flight install on
mount; old /workspace?tab=github links redirect here with their query intact."""

import from ...components.workspace.GithubSection { GithubSection }
import from ...components.ui.button { Button }

def:pub GithubPage -> JsxPage {
    has browseNonce: int = 0;

    return
        <div className="flex w-full flex-col gap-8">
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
