"""standup - retired route. The page outgrew its name and lives at /workspace;
kept as a redirect for bookmarks and for a GitHub App still registered against
the old callback URL, whose install round trip is carried across.
"""

import from ...components.ui.skeleton { Skeleton }

def:pub RosterPage -> JsxPage {
    can with entry {
        w: any = window;
        search = str(w.location.search);
        tail = "?" + search[1:] if search else "";
        w.location.replace("/workspace" + tail);
    }

    return <Skeleton className="h-48 w-full"/>;
}
