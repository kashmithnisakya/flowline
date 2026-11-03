"""The product picture's sidebar, a made-up workspace in plain markup. A phone's
picture drops it, so the board stays legible."""

import from ..common.AiMark { AiMark }
import from .Wordmark { RouteMark }

glob NAV: str = "flex h-[30px] items-center gap-2 rounded-md px-2 text-text-secondary",
     PROJECTS: list[list[str]] = [
         ["Checkout rewrite", "bg-project-1", "10"],
         ["Mobile app", "bg-project-2", "6"],
         ["Docs site", "bg-project-3", "2"]
     ];

def Glyph(d: str) -> JsxElement {
    return
        <svg
            className="size-4 shrink-0"
            viewBox="0 0 16 16"
            fill="none"
            stroke="currentColor"
            strokeWidth={1.5}
            strokeLinecap="round"
            strokeLinejoin="round"
        >
            <path d={d}/>
        </svg>;
}

def:pub ShotSidebar -> JsxElement {
    return
        <div
            className="flex w-[216px] shrink-0 flex-col gap-3 border-r bg-bg-sidebar px-2.5 py-3 max-sm:hidden"
        >
            <div
                className="flex h-8 items-center gap-2 px-1.5 text-[14px] font-semibold"
            >
                <RouteMark size={22}/>
                Harbor Labs
            </div>
            <div
                className="flex h-[30px] items-center gap-2 rounded-md border bg-bg-elevated px-2 text-text-tertiary"
            >
                <Glyph d="M7 2.5a4.5 4.5 0 1 0 0 9 4.5 4.5 0 0 0 0-9ZM10.5 10.5l3 3"/>
                Search
                <span className="kbd ml-auto">⌘K</span>
            </div>
            <div className="flex flex-col gap-px">
                <div className={NAV}>
                    <Glyph d="M2.5 13.5h11M4.5 13.5V8M8 13.5v-11M11.5 13.5V6"/>
                    Overview
                </div>
                <div className={NAV}>
                    <AiMark running={True}/>
                    AI
                    <span className="num ml-auto text-[12px] text-text-tertiary">
                        1 running
                    </span>
                </div>
            </div>
            <div className="flex flex-col gap-px">
                <div className="px-2 py-1 text-[12px] text-text-tertiary">Projects</div>
                {for (i, p) in enumerate(PROJECTS) {
                    <div
                        key={p[0]}
                        className={"flex h-[30px] items-center gap-2 rounded-md px-2 "
                            + (
                                "bg-bg-selected font-medium"
                                    if i == 0
                                    else "text-text-secondary"
                            )}
                    >
                        <span className={"size-2.5 shrink-0 rounded-[3px] " + p[1]}/>
                        {p[0]}
                        <span className="num ml-auto text-[12px] text-text-tertiary">
                            {p[2]}
                        </span>
                    </div>
                }}
            </div>
            <div className="mt-auto flex flex-col gap-px">
                <div
                    className="flex h-[30px] items-center gap-2 px-2 font-medium text-ai"
                >
                    <AiMark/>
                    Ask
                    <span className="kbd ml-auto">⌘J</span>
                </div>
                <div className={NAV}>
                    <Glyph d="M3 4.5h6M12 4.5h1M3 11.5h1M7 11.5h6"/>
                    Workspace
                </div>
            </div>
        </div>;
}
