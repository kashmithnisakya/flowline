"""The sidebar's AI link: the AI mark, turning while runs are open, and how many.
The count comes from the workspace cache, like the projects: no read of its own."""

import from "@jac/runtime" { Link }
import from "react" { useEffect }
import from ...lib.workspace { cachedAiOpen }
import from ..common.AiMark { AiMark }
import from .SidebarLink { ITEM, ITEM_ON, ITEM_OFF, isCurrent }

def:pub SidebarAi(path: str) -> JsxElement {
    has active: int = cachedAiOpen();

    useEffect(
        lambda {
            w: any = window;
            onView = lambda (e: any) { active = cachedAiOpen(); };
            w.addEventListener("flowline:workspace", onView);
            return lambda { w.removeEventListener("flowline:workspace", onView); };
        },
        []
    );

    on = isCurrent(path, "/ai");
    return
        <Link
            to="/ai"
            aria-current={"page" if on else None}
            className={ITEM + (ITEM_ON if on else ITEM_OFF)}
        >
            <AiMark running={active > 0}/>
            AI
            {if active > 0 {
                <span key="n" className="num ml-auto text-[12px] text-text-tertiary">
                    {str(active) + " active"}
                </span>
            }}
        </Link>;
}
