"""The site footer. The bracketed items are placeholders for pages that do not
exist yet, shown as plain text on purpose: they are not links."""

import from .SiteMenu { DOCS_URL, REPO_URL }
import from .Wordmark { RouteMark }

glob FOOT_LINK: str = "transition-colors hover:text-foreground";

def:pub SiteFooter -> JsxElement {
    return
        <footer className="border-t">
            <div
                className="lp-wrap flex flex-wrap items-center gap-x-6 gap-y-3 pt-6 pb-8"
            >
                <span className="flex items-center gap-2">
                    <RouteMark size={22}/>
                    <span className="text-[12.5px] text-text-tertiary">
                        MIT licensed. Built with Jac.
                    </span>
                </span>
                <nav
                    aria-label="Footer"
                    className="flex flex-wrap gap-x-5 gap-y-1 text-sm text-text-secondary sm:ml-auto"
                >
                    <a
                        href={DOCS_URL}
                        target="_blank"
                        rel="noopener noreferrer"
                        className={FOOT_LINK}
                    >
                        Docs
                    </a>
                    <a
                        href={REPO_URL}
                        target="_blank"
                        rel="noopener noreferrer"
                        className={FOOT_LINK}
                    >
                        GitHub
                    </a>
                    <a href="#faq" className={FOOT_LINK}>FAQ</a>
                    <span>[Privacy policy link]</span>
                    <span>[Terms link]</span>
                    <span>[Contact link]</span>
                </nav>
            </div>
        </footer>;
}
