"""The phone tab bar below lg: Overview, Board (with its project's other views),
Processes, Ask and More (Workspace, and the AI page through it)."""

import from "@jac/runtime" { Link }
import from ..common.CommandPalette { PageIcon }
import from ..common.AiMark { AiMark }
import from .SidebarLink { isCurrent }

glob TAB: str = "flex h-14 flex-col items-center justify-center gap-1 text-xs ",
     TAB_ON: str = "font-semibold text-foreground",
     TAB_OFF: str = "font-medium text-muted-foreground";

def:pub TabBar(path: str, askOpen: bool, onAsk: Callable[[], None]) -> JsxElement {
    overview = isCurrent(path, "/overview");
    board = (
        isCurrent(path, "/board")
        or isCurrent(path, "/flowlines")
        or isCurrent(path, "/roadmap")
    );
    more = isCurrent(path, "/workspace") or isCurrent(path, "/ai");
    processes = isCurrent(path, "/processes");
    return
        <nav
            aria-label="Pages"
            className="fixed inset-x-0 bottom-0 z-40 grid grid-cols-5 border-t bg-card pb-[env(safe-area-inset-bottom)] lg:hidden"
        >
            <Link
                to="/overview"
                aria-current={"page" if overview else None}
                className={TAB + (TAB_ON if overview else TAB_OFF)}
            >
                <PageIcon name="overview" size={20}/>
                Overview
            </Link>
            <Link
                to="/board"
                aria-current={"page" if board else None}
                className={TAB + (TAB_ON if board else TAB_OFF)}
            >
                <PageIcon name="board" size={20}/>
                Board
            </Link>
            <Link
                to="/processes"
                aria-current={"page" if processes else None}
                className={TAB + (TAB_ON if processes else TAB_OFF)}
            >
                <PageIcon name="processes" size={20}/>
                Processes
            </Link>
            <button
                type="button"
                data-ask-trigger="true"
                aria-pressed={askOpen}
                onClick={onAsk}
                className={TAB + "font-medium text-ai"}
            >
                <AiMark className="size-5!"/>
                Ask
            </button>
            <Link
                to="/workspace"
                aria-current={"page" if more else None}
                className={TAB + (TAB_ON if more else TAB_OFF)}
            >
                <PageIcon name="more" size={20}/>
                More
            </Link>
        </nav>;
}
