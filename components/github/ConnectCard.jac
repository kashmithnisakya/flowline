"""The disconnected state: what connecting buys, what the App may touch, and
the one button that starts it. No token field anywhere: flowline connects
through a GitHub App installation, so the credential is minted per request
server-side and never typed or stored.
"""

import from ..ui.button { Button }
import from ..common.glyphs { Spinner }
import from ..workspace.icons { IconGithub, IconCheck, IconLock }

# What the App asks for, in the words of the repository's own setup guide.
glob PERMISSIONS: list[list[str]] = [
         ["read", "Read issues and pull requests in the repositories you pick"],
         ["read", "Receive events when they change, so cards stay current"],
         [
             "write",
             "Write to an issue only when you create, close or reopen one from a task"
         ]
     ];

def:pub ConnectCard(
    starting: bool, missing: list[str], onInstall: Callable[[], None]
) -> JsxElement {
    blocked = len(missing) > 0;
    return
        <div
            className="surface grid gap-8 p-6 md:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)] md:gap-0 md:p-0"
        >
            <div className="flex flex-col items-start gap-4 md:p-7">
                <IconGithub size={28} className="text-foreground"/>
                <h2
                    className="font-display text-[22px] leading-snug font-bold [font-stretch:115%]"
                >
                    Keep the board in step with GitHub
                </h2>
                <ul className="flex list-disc flex-col gap-1.5 pl-5 text-sm">
                    <li>Import a repository's issues as tasks in a project.</li>
                    <li>Link a card to its issue or pull request.</li>
                    <li>
                        Let a merged pull request move its card to Done, if you want it.
                    </li>
                </ul>
                {if blocked {
                    <p key="gap" className="text-[13px] text-muted-foreground">
                        GitHub is not set up on this server yet. Ask whoever runs your flowline instance to finish the GitHub App setup.
                    </p>
                }}
                <div className="flex flex-wrap items-center gap-3">
                    <Button
                        onClick={onInstall}
                        disabled={starting or blocked}
                        size="lg"
                    >
                        {if starting {
                            <Spinner key="sp"/>
                        } else {
                            <IconGithub key="mark" size={16}/>
                        } }
                        {"Opening GitHub…" if starting else "Connect GitHub"}
                    </Button>
                    <span className="text-xs text-subtle">
                        You choose which repositories on GitHub.
                    </span>
                </div>
            </div>
            <div className="border-t pt-6 md:border-t-0 md:border-l md:p-7">
                <h3 className="text-[13px] font-semibold">
                    What flowline will be able to do
                </h3>
                <ul className="mt-2 flex flex-col">
                    {for row in PERMISSIONS {
                        <li
                            key={row[1]}
                            className="flex items-start gap-2.5 border-b py-2.5 text-[13px] last:border-b-0"
                        >
                            {if row[0] == "write" {
                                <IconLock
                                    key="lock"
                                    className="mt-0.5 shrink-0 text-subtle"
                                />
                            } else {
                                <IconCheck
                                    key="check"
                                    className="mt-0.5 shrink-0 text-subtle"
                                />
                            } }
                            <span>{row[1]}</span>
                        </li>
                    }}
                </ul>
                <p className="num mt-3 text-xs text-subtle">
                    Issues: read and write · Pull requests: read · Metadata: read
                </p>
                <p className="mt-1.5 text-xs text-muted-foreground">
                    flowline stores the installation id, never a token.
                </p>
            </div>
        </div>;
}
