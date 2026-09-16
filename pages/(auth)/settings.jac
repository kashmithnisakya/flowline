"""flowline - retired route. The theme picker moved into the workspace, which
is where everything else is configured; kept as a redirect so bookmarks and
the account menu's older links still land on it (contract C2).
"""

import from ...components.ui.skeleton { Skeleton }

def:pub SettingsPage -> JsxPage {
    can with entry {
        window.location.replace("/workspace?tab=preferences");
    }

    return <Skeleton className="h-48 w-full"/>;
}
