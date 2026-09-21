"""flowline - GitHub (/github): read issues and pull requests, import work.
Daily work, not configuration, so it has its own nav tab. The App's callback
URL is <HOST>/github and GithubSection finishes an in-flight install on mount;
old /workspace?tab=github links redirect here with their query intact. The
section owns the page header, so the connection can sit beside the title."""

import from ...components.workspace.GithubSection { GithubSection }

def:pub GithubPage -> JsxPage {
    return <GithubSection/>;
}
