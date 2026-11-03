"""The row under the diagram: the kinds this line uses, how to read its wires, the
first advisory check while viewing, the Roles popover and the pan and fit hint."""

import from .kinds { KIND_LABEL, KIND_TONE }
import from .RolesPopover { RolesPopover }
import from ..common.KindGlyph { KindGlyph }
import from ..common.glyphs { WarnIcon }

def Wire(dash: str = "") -> JsxElement {
    return
        <svg width={22} height={8} aria-hidden="true" className="text-wire">
            <path
                d="M1 4 H21"
                stroke="currentColor"
                strokeWidth={1.6}
                strokeLinecap="round"
                strokeDasharray={dash}
            />
        </svg>;
}

def:pub FlowKey(
    usedKinds: list[str],
    showBack: bool = False,
    issues: list[str] = [],
    roles: list[dict[str, any]] = []
) -> JsxElement {
    extra = len(issues) - 1;
    return
        <div
            aria-label="Key"
            className="flex min-w-0 flex-wrap items-center gap-x-4 gap-y-1.5 border-t bg-card px-4 py-2 text-xs text-text-secondary"
        >
            {for k in usedKinds {
                <span key={k} className="inline-flex items-center gap-1.5">
                    <KindGlyph
                        kind={k}
                        size={14}
                        className={KIND_TONE[k] if k in KIND_TONE else "text-subtle"}
                    />
                    {KIND_LABEL[k]}
                </span>
            }}
            <span className="inline-flex items-center gap-1.5">
                <Wire/>
                Moves forward
            </span>
            {if showBack {
                <span key="back" className="inline-flex items-center gap-1.5">
                    <Wire dash="5 4"/>
                    Sends back, on purpose
                </span>
            }}
            {if len(issues) > 0 {
                <span
                    key="issues"
                    className="inline-flex min-w-0 items-center gap-1.5 text-warning"
                    title={" ".join(issues)}
                >
                    <WarnIcon size={14} className="shrink-0"/>
                    <span className="truncate">
                        {issues[0]
                            + (" (+" + str(extra) + " more)" if extra > 0 else "")}
                    </span>
                </span>
            }}
            <RolesPopover roles={roles}/>
            <span
                className="hidden items-center gap-1 text-text-tertiary md:inline-flex"
            >
                Drag to pan ·
                <span className="kbd">F</span>
                fits
            </span>
        </div>;
}
