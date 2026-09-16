"""Landing hero: the one idea (draw the steps, the board and the log follow),
the proof bar, then the playable demo at full container width. Left-aligned
at every width; on phones the primary action fills the row.
"""

import from ..ui.button { Button }
import from .HeroBoard { HeroBoard }
import from .ProofStrip { ProofStrip }

glob REPO_URL: str = "https://github.com/kashmithnisakya/flowline",
     TEXT_LINK: str = "rounded-sm text-sm font-semibold text-foreground underline-offset-4 hover:underline";

def:pub Hero(loggedIn: bool) -> JsxElement {
    return
        <section className="mx-auto max-w-[1180px] px-4 sm:px-6">
            <div className="grid max-w-[900px] gap-4 pt-10 pb-5 sm:pt-12">
                <p className="font-mono text-[12.5px] text-subtle">
                    For teams that would rather write than meet
                </p>
                <h1
                    className="max-w-[21ch] text-[clamp(2.125rem,4.4vw,2.875rem)] leading-[1.04] font-extrabold tracking-[-0.02em] text-balance [font-stretch:125%]"
                >
                    Draw how your team works. The board and the daily log follow.
                </h1>
                <p
                    className="max-w-[58ch] text-base leading-relaxed text-muted-foreground"
                >
                    Name your steps once. They become the board's columns, every card that moves writes a line in the log, and linked GitHub issues can move cards when you turn that on.
                </p>
                <div
                    className="flex flex-col gap-4 sm:flex-row sm:flex-wrap sm:items-center sm:gap-6"
                >
                    <Button
                        asChild={True}
                        className="h-11 w-full px-5 text-[15px] font-semibold sm:w-auto"
                    >
                        <a href={"/board" if loggedIn else "/login?mode=signup"}>
                            {"Go to your board"
                                if loggedIn
                                else "Create your workspace"}
                        </a>
                    </Button>
                    <div className="flex flex-wrap items-center gap-x-6 gap-y-2">
                        <a href="#tour" className={TEXT_LINK}>Take the tour</a>
                        <a
                            href={REPO_URL}
                            target="_blank"
                            rel="noopener noreferrer"
                            className={TEXT_LINK}
                        >
                            Source on GitHub
                        </a>
                    </div>
                </div>
            </div>
            <ProofStrip/>
            <HeroBoard loggedIn={loggedIn}/>
        </section>;
}
