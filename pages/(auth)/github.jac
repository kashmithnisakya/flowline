"""standup - retired route.

GitHub moved into the Workspace tab. The GitHub App's callback URL should
now be <HOST>/roster?tab=github, but this redirect carries an in-flight
install round trip over rather than dropping it on the floor, so an app
still registered against the old URL keeps working.
"""

import from ...components.ui.skeleton { Skeleton }

def:pub GithubPage() -> JsxPage {
    can with entry {
        w: any = window;
        search = str(w.location.search);
        tail = "&" + search[1:] if search else "";
        w.location.replace("/roster?tab=github" + tail);
    }

    return <Skeleton className="h-48 w-full" />;
}
