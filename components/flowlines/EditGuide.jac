"""The edit column with nothing selected: how to edit, then the line's advisory
checks. The checks are advice, so saving is never blocked."""

import from ..common.glyphs { WarnIcon }

glob HOW_TO: list[str] = [
         "Drag a step to move it. Drag empty canvas to pan.",
         "Drag from a step's edge (the dots) to another step to connect them.",
         "Click an arrow to label it, or a step to rename it, change its kind or remove it."
     ];

def:pub EditGuide(issues: list[str]) -> JsxElement {
    return
        <div className="flex flex-col gap-4 overflow-y-auto p-5">
            <section className="flex flex-col gap-2.5">
                <h2 className="section-title text-sm">How to edit</h2>
                <ol className="flex flex-col gap-2 text-[13px]">
                    {for (i, line) in enumerate(HOW_TO) {
                        <li key={str(i)} className="flex gap-2.5">
                            <span className="num w-4 shrink-0 text-text-tertiary">
                                {str(i + 1)}
                            </span>
                            <span>{line}</span>
                        </li>
                    }}
                </ol>
            </section>
            <section className="flex flex-col gap-2 border-t pt-3">
                <h2 className="section-title text-sm">Checks</h2>
                {if len(issues) == 0 {
                    <p key="ok" className="text-[13px] text-text-secondary">
                        Every step can be reached from a start step and can reach a done step.
                    </p>
                } else {
                    <ul key="issues" className="flex flex-col gap-1.5">
                        {for msg in issues {
                            <li
                                key={msg}
                                className="flex items-start gap-2 text-[13px] text-warning"
                            >
                                <WarnIcon size={14} className="mt-0.5 shrink-0"/>
                                <span>{msg}</span>
                            </li>
                        }}
                    </ul>
                } }
                <p className="meta">Checks are advice. Saving is never blocked.</p>
            </section>
        </div>;
}
