"""The flow line across the top of a sample board: every step as a pill with
its count, joined by arrows, and a note for the loop back. It wraps rather
than scrolls, so a phone sees the whole line."""

import from ..common.StepBadge { stepWash, stepInk, stepSolid }

def:pub DemoStrip(
    steps: list[dict[str, any]], counts: list[int], loop: str = ""
) -> JsxElement {
    return
        <div className="flex flex-wrap items-center gap-x-1 gap-y-2">
            {for (i, step) in enumerate(steps) {
                <span key={step["name"]} className="flex items-center gap-1">
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
                    <span
                        className={"flex h-8 items-center gap-2 rounded-full pr-3 pl-1 text-[13px] font-semibold whitespace-nowrap "
                            + stepWash(step["color"])
                            + " "
                            + stepInk(step["color"])}
                    >
                        <span
                            className={"flex h-6 min-w-6 items-center justify-center rounded-full px-1.5 font-mono text-xs text-step-solid-fg "
                                + stepSolid(step["color"])}
                        >
                            {str(counts[i])}
                        </span>
                        {step["name"]}
                    </span>
                </span>
            }}
            {if loop {
                <span
                    key="loop"
                    className="ml-2 inline-flex items-center gap-1.5 font-mono text-xs whitespace-nowrap text-subtle"
                >
                    <i
                        aria-hidden="true"
                        className="inline-block w-[22px] border-t-2 border-dashed border-wire"
                    ></i>
                    {loop}
                </span>
            }}
        </div>;
}
