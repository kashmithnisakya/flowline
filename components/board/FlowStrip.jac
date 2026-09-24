"""The flow line across the top of the board: every step as a pill with its
count, in order, joined by arrows. A pill scrolls its group into view. It
wraps rather than scrolls, so the whole line is always on screen."""

import from ..common.StepBadge { stepWash, stepInk, stepSolid }

def jump(key: str) {
    el: any = document.querySelector('[data-step="' + key + '"]');
    if el {
        el.scrollIntoView({"behavior": "smooth", "block": "start"});
    }
}

def:pub FlowStrip(
    name: str, keys: list[str], labels: list[str], colors: list[str], counts: list[int]
) -> JsxElement {
    return
        <nav
            aria-label="Flow line"
            className="flex flex-wrap items-center gap-x-1 gap-y-2 rounded-2xl bg-card px-3.5 py-2.5 shadow-xs ring-1 ring-border/70"
        >
            <span
                className="mr-2 text-xs leading-tight text-muted-foreground max-sm:hidden"
            >
                {name}
            </span>
            {for (i, key) in enumerate(keys) {
                <span key={key} className="flex items-center gap-1">
                    {if i > 0 {
                        <svg
                            key="arrow"
                            width={16}
                            height={10}
                            viewBox="0 0 16 10"
                            aria-hidden="true"
                            className="text-wire"
                        >
                            <path
                                d="M1 5h12M9.5 1.5 13 5 9.5 8.5"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={1.5}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            />
                        </svg>
                    }}
                    <button
                        type="button"
                        onClick={lambda { jump(key); }}
                        className={"flex h-8 items-center gap-2 rounded-full pr-3 pl-1 text-[13px] font-semibold whitespace-nowrap "
                            + stepWash(colors[i])
                            + " "
                            + stepInk(colors[i])}
                    >
                        <span
                            className={"flex h-6 min-w-6 items-center justify-center rounded-full px-1.5 font-mono text-xs text-step-solid-fg "
                                + stepSolid(colors[i])}
                        >
                            {str(counts[i])}
                        </span>
                        {labels[i]}
                    </button>
                </span>
            }}
        </nav>;
}
