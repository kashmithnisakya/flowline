"""Landing hero: the one idea (draw the steps, the board and the log follow)
with the moving figure beside it, then the proof bar and the playable demo at
full container width.

From lg the section is a two column grid: text left, the looping figure right.
Below that it stacks, text first. The text block rises into place in a short
stagger on load; on phones the primary action fills the row.
"""

import from ..ui.button { Button }
import from .HeroBoard { HeroBoard }
import from .HeroMotion { HeroMotion }
import from .ProofStrip { ProofStrip }

glob REPO_URL: str = "https://github.com/kashmithnisakya/flowline",
     TEXT_LINK: str = "rounded-sm text-sm font-semibold text-foreground underline-offset-4 hover:underline";

def:pub Hero(loggedIn: bool) -> JsxElement {
    return
        <div className="relative isolate">
            <div className="hero-atmosphere" aria-hidden="true"/>
            <section className="landing-wrap">
                <div
                    className="grid items-center gap-10 pt-12 pb-7 sm:pt-16 lg:grid-cols-[minmax(0,5fr)_minmax(0,6fr)] lg:gap-12"
                >
                    <div className="grid max-w-[38rem] gap-5">
                        <p
                            className="glass-pill rise rise-1 inline-flex w-fit items-center gap-2 px-3 py-1.5 font-mono text-[12.5px] text-subtle"
                        >
                            <span
                                className="size-1.5 shrink-0 rounded-full bg-primary"
                                aria-hidden="true"
                            />
                            For teams that would rather write than meet
                        </p>
                        <h1
                            className="rise rise-2 max-w-[19ch] text-[clamp(2.25rem,4.4vw,3.75rem)] leading-[1.03] font-extrabold tracking-[-0.038em] text-balance"
                        >
                            Draw how your team works.
                            <span className="block text-muted-foreground">
                                The board and the daily log follow.
                            </span>
                        </h1>
                        <p
                            className="rise rise-3 max-w-[54ch] text-[17px] leading-relaxed text-muted-foreground"
                        >
                            Name your steps once. They become the board's columns, every card that moves writes a line in the log, and linked GitHub issues can move cards when you turn that on.
                        </p>
                        <div
                            className="rise rise-4 mt-1 flex flex-col gap-4 sm:flex-row sm:flex-wrap sm:items-center sm:gap-5"
                        >
                            <Button
                                asChild={True}
                                className="h-12 w-full rounded-full px-7 text-[15px] font-semibold shadow-[var(--float-1)] sm:w-auto"
                            >
                                <a
                                    href={"/board"
                                        if loggedIn
                                        else "/login?mode=signup"}
                                >
                                    {"Go to your board"
                                        if loggedIn
                                        else "Create your workspace"}
                                </a>
                            </Button>
                            <a
                                href="#tour"
                                className="glass-pill inline-flex h-12 w-full items-center justify-center px-6 text-sm font-semibold text-foreground transition-colors hover:text-primary sm:w-auto"
                            >
                                Take the tour
                            </a>
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
                    <div className="rise rise-5">
                        <HeroMotion/>
                    </div>
                </div>
                <div className="rise rise-5">
                    <ProofStrip/>
                </div>
                <div className="rise rise-5">
                    <HeroBoard loggedIn={loggedIn}/>
                </div>
            </section>
        </div>;
}
