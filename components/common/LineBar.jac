"""The line bar under a project's header: its steps joined by one line, each
with its status icon, name and count. A step scrolls its group into view, and
a step an AI responsibility runs on carries the AI mark."""

import from .StepBadge { StepIcon }
import from .AiMark { AiMark }

def jump(key: str) {
    el: any = document.querySelector('[data-step="' + key + '"]');
    if el {
        el.scrollIntoView({"behavior": "smooth", "block": "start"});
    }
}

def:pub LineBar(
    name: str,
    keys: list[str],
    labels: list[str],
    kinds: list[str],
    colors: list[str],
    counts: list[int],
    ai: list[bool] = []
) -> JsxElement {
    return
        <ol aria-label={name or "Flow line"} className="line-bar list-none">
            {for (i, key) in enumerate(keys) {
                <li key={key} className="line-step">
                    <button
                        type="button"
                        onClick={lambda { jump(key); }}
                        className="flex h-[30px] items-center gap-1.5 rounded-md px-2 text-[13px] font-medium whitespace-nowrap outline-none hover:bg-bg-hover focus-visible:ring-2 focus-visible:ring-ring"
                    >
                        <StepIcon color={colors[i]} kind={kinds[i]} size={14}/>
                        {labels[i]}
                        <span className="num font-normal text-text-tertiary">
                            {str(counts[i])}
                        </span>
                        {if i < len(ai) and ai[i] {
                            <span
                                key="ai"
                                className="flex"
                                title="An AI responsibility runs on this step"
                            >
                                <AiMark/>
                            </span>
                        }}
                    </button>
                </li>
            }}
        </ol>;
}
