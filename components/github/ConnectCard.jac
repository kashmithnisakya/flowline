"""The disconnected state: what connecting buys, and the button that starts it.
No token field anywhere: standup connects through a GitHub App installation,
so the credential is minted per request server-side and never typed or stored.
"""

import from ..ui.button { Button }
import from ..ui.card {
    Card,
    CardHeader,
    CardTitle,
    CardDescription,
    CardContent,
    CardFooter
}
import from ..common.glyphs { Spinner }

def:pub ConnectCard(
    starting: bool, missing: list[str], onInstall: Callable[[], None]
) -> JsxElement {
    return
        <Card
            className="max-w-2xl animate-in fade-in slide-in-from-bottom-2 duration-300"
        >
            <CardHeader>
                <div
                    className="mb-2 flex size-10 items-center justify-center rounded-lg bg-primary/10 text-primary"
                >
                    <svg
                        width={20}
                        height={20}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    >
                        <path
                            d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4"
                        />
                        <path d="M9 18c-4.51 2-5-2-7-2"/>
                    </svg>
                </div>
                <CardTitle className="font-display">Connect GitHub</CardTitle>
                <CardDescription>
                    Install the standup GitHub App and pick the repositories it may see.
                </CardDescription>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-muted-foreground">
                <ul className="space-y-2">
                    <li className="flex items-start gap-2">
                        <svg
                            className="mt-0.5 shrink-0 text-primary"
                            width={14}
                            height={14}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        >
                            <path d="M20 6 9 17l-5-5"/>
                        </svg>
                        <span>
                            Browse issues and pull requests for the repos on this workspace.
                        </span>
                    </li>
                    <li className="flex items-start gap-2">
                        <svg
                            className="mt-0.5 shrink-0 text-primary"
                            width={14}
                            height={14}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        >
                            <path d="M20 6 9 17l-5-5"/>
                        </svg>
                        <span>Import issues onto the board, once each.</span>
                    </li>
                    <li className="flex items-start gap-2">
                        <svg
                            className="mt-0.5 shrink-0 text-primary"
                            width={14}
                            height={14}
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                            strokeWidth={2}
                            strokeLinecap="round"
                            strokeLinejoin="round"
                        >
                            <path d="M20 6 9 17l-5-5"/>
                        </svg>
                        <span>
                            Open a GitHub issue from a task, when you ask for one.
                        </span>
                    </li>
                </ul>
                <p>
                    You choose the repositories on GitHub's install screen. Standup reads only what you grant, nothing is polled in the background, and the one write is an issue somebody explicitly asks for.
                </p>
                {if len(missing) > 0 {
                    <p
                        key="gap"
                        className="rounded-lg border border-destructive/40 bg-destructive/10 p-3 text-destructive"
                    >
                        {"This server is missing " + ", ".join(missing) + ". Set them in the environment (the GitHub section of the " + "README lists each one) and restart, then try again."}
                    </p>
                }}
            </CardContent>
            <CardFooter>
                <Button onClick={onInstall} disabled={starting}>
                    {if starting {
                        <Spinner key="sp"/>
                    }}
                    {"Opening GitHub…" if starting else "Install GitHub App"}
                </Button>
            </CardFooter>
        </Card>;
}
