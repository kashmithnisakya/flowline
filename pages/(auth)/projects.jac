"""standup - retired route.

Projects moved into the Workspace tab, where the rest of the configuration
lives. Kept as a redirect so existing bookmarks and links still land
somewhere useful; safe to delete a release from now.
"""

import from ...components.ui.skeleton { Skeleton }

def:pub ProjectsPage() -> JsxPage {
    can with entry {
        window.location.replace("/roster?tab=projects");
    }

    return <Skeleton className="h-48 w-full" />;
}
