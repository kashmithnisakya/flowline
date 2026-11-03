"""Landing hero: the one idea, one lead sentence, one primary action, a way to
read on, and the facts line. On phones the primary action fills the row."""

import from .PrimaryCta { PrimaryCta }
import from .SiteMenu { REPO_URL }

def:pub Hero(loggedIn: bool) -> JsxElement {
    return
        <section
            className="lp-wrap flex flex-col gap-6 pt-12 pb-10 sm:pt-[72px] sm:pb-12"
        >
            <h1 className="lp-h1">
                Draw how your team works.{" "}
                <span className="block text-text-tertiary">The board follows.</span>
            </h1>
            <p className="lp-lead">
                Name your steps once. The board stacks your work under them, every move lands in the task's own history, and GitHub and AI act only where you switch them on.
            </p>
            <div className="flex flex-wrap items-center gap-x-5 gap-y-3">
                <PrimaryCta loggedIn={loggedIn} className="w-full sm:w-auto"/>
                <a href="#draw" className="lp-link text-[15px] font-medium">
                    See how it works
                </a>
            </div>
            <ul aria-label="Facts about Flowline" className="lp-facts">
                <li>MIT licensed</li>
                <li>Run your own server</li>
                <li>Each workspace is its own isolated graph</li>
                <li>
                    <a
                        href={REPO_URL}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="lp-link"
                    >
                        Source on GitHub
                    </a>
                </li>
            </ul>
        </section>;
}
