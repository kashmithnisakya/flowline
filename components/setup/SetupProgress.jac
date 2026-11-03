"""The wizard's progress as the same line bar a project's steps use: a step done,
the one under way and those still to come. Before the resume point is known
(`step` 0) every step reads as still to come, so nothing flips back."""

import from ..common.KindGlyph { KindGlyph }

glob STEPS: list[str] = ["Team", "People", "How work moves"];

def:pub SetupProgress(step: int) -> JsxElement {
    return
        <ol
            aria-label="Setup steps"
            className="line-bar list-none [--kind-knockout:var(--background)]"
        >
            {for (i, label) in enumerate(STEPS) {
                <li
                    key={label}
                    aria-current={"step" if i + 1 == step else None}
                    className="line-step"
                >
                    <span
                        className={"flex h-[30px] items-center gap-1.5 px-2 text-[13px] font-medium whitespace-nowrap "
                            + ("text-text-tertiary" if i + 1 > step else "")}
                    >
                        <KindGlyph
                            kind={"done"
                                if i + 1 < step
                                else ("active" if i + 1 == step else "start")}
                            className="text-primary"
                        />
                        {label}
                    </span>
                </li>
            }}
        </ol>;
}
