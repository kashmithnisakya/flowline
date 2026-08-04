"""The disconnected state: what connecting buys, and the button that starts it.

There is no token field anywhere in this flow. Standup connects through a
GitHub App installation, so the credential is minted per request on the
server and never typed, pasted, or stored by a person.
"""

import from ..ui.button { Button }
import from ..ui.card {
    Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter
}

def:pub ConnectCard(
    starting: bool,
    missing: list[str],
    onInstall: Callable[[], None]
) -> JsxElement {
    return <Card className="max-w-2xl">
        <CardHeader>
            <CardTitle className="font-display">Connect GitHub</CardTitle>
            <CardDescription>
                Install the standup GitHub App and pick the repositories it may see.
            </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3 text-sm text-muted-foreground">
            <ul className="space-y-1.5">
                <li>Browse issues and pull requests for the repos on this workspace.</li>
                <li>Import issues onto the board, once each.</li>
                <li>Open a GitHub issue from a task, when you ask for one.</li>
            </ul>
            <p>
                You choose the repositories on GitHub's install screen. Standup reads
                only what you grant, nothing is polled in the background, and the one
                write is an issue somebody explicitly asks for.
            </p>
            {if len(missing) > 0 {
                <p
                    key="gap"
                    className="rounded-lg border border-destructive/40 bg-destructive/10 p-3 text-destructive"
                >
                    {
                        "This server is missing " + ", ".join(missing)
                        + ". Set them in the environment (the GitHub section of the "
                        + "README lists each one) and restart, then try again."
                    }
                </p>
            }}
        </CardContent>
        <CardFooter>
            <Button onClick={onInstall} disabled={starting}>
                {"Opening GitHub…" if starting else "Install GitHub App"}
            </Button>
        </CardFooter>
    </Card>;
}
