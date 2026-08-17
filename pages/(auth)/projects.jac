"""standup - retired route. Projects moved into the Workspace tab; kept as a
redirect so bookmarks still land somewhere useful. Safe to delete a release on.
"""

import from ...components.ui.skeleton { Skeleton }

def:pub ProjectsPage() -> JsxPage {
    can with entry {
        window.location.replace("/workspace?tab=projects");
    }

    return <Skeleton className="h-48 w-full" />;
}
