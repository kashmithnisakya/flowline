"""The phone header below md: the mark, the current page's name, search,
Ask and the account menu."""

import from "@jac/runtime" { Link }
import from ..common.CommandPalette { PageIcon }
import from .Mark { Mark }
import from .AccountMenu { AccountMenu }

glob BUTTON: str = "inline-flex size-10 items-center justify-center rounded-full text-muted-foreground hover:bg-accent hover:text-foreground";

def:pub PhoneHeader(
    title: str,
    orgName: str,
    account: str,
    themeChoice: str,
    onSearch: Callable[[], None],
    onAsk: Callable[[], None],
    onTheme: Callable[[str], None],
    onSignOut: Callable[[], None]
) -> JsxElement {
    return
        <header
            className="sticky top-0 z-40 flex h-14 items-center gap-2 border-b bg-background/95 pr-2 pl-4 backdrop-blur md:hidden"
        >
            <Link to="/board" aria-label={(orgName or "flowline") + " home"}>
                <Mark/>
            </Link>
            <span className="min-w-0 flex-1 truncate text-base font-semibold">
                {title}
            </span>
            <button
                type="button"
                aria-label="Search or jump"
                className={BUTTON}
                onClick={onSearch}
            >
                <PageIcon name="search" size={18}/>
            </button>
            <button
                type="button"
                data-ask-trigger="true"
                aria-label="Ask about this workspace"
                className={BUTTON}
                onClick={onAsk}
            >
                <PageIcon name="ask" size={18}/>
            </button>
            <AccountMenu
                orgName={orgName}
                account={account}
                themeChoice={themeChoice}
                onTheme={onTheme}
                onSignOut={onSignOut}
            />
        </header>;
}
