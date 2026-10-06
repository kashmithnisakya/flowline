"""The flow line under the board title: each step as its status icon, name and
count, separated by chevrons. A step scrolls its group into view.

It used to be a card of washed pills with solid count badges, which competed
with the work below it. It is now one inline line with no card and no
background, so the board leads and the flow line orients.
"""

import from ..common.StepBadge { StepIcon }

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
            aria-label={name or "Flow line"}
            className="flex flex-wrap items-center gap-x-1 gap-y-1"
        >
            {for (i, key) in enumerate(keys) {
                <span key={key} className="flex items-center gap-1">
                    {if i > 0 {
                        <svg
                            key="sep"
                            width={12}
                            height={12}
                            viewBox="0 0 16 16"
                            aria-hidden="true"
                            className="mx-1 shrink-0 text-text-tertiary"
                        >
                            <path
                                d="m6 4 4 4-4 4"
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
                        className="flex h-7 items-center gap-1.5 rounded-md px-1.5 text-[13px] whitespace-nowrap outline-none hover:bg-bg-hover focus-visible:ring-2 focus-visible:ring-ring"
                    >
                        <StepIcon color={colors[i]} kind="" size={14}/>
                        <span className="text-text-secondary">{labels[i]}</span>
                        <span className="num text-text-tertiary">{str(counts[i])}</span>
                    </button>
                </span>
            }}
        </nav>;
}
