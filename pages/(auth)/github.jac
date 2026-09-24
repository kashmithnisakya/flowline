"""flowline - /github: the GitHub App's callback and setup URL. It renders the
Workspace page, which opens on its GitHub section for this path, so the
install round trip finishes there with its query intact."""

import from .workspace { WorkspacePage }

def:pub GithubPage -> JsxPage {
    return <WorkspacePage/>;
}
