"""Editor panel for the selected step. No save button: name and blurb commit
on blur/Enter, kind, colour and owner on pick (SaveStep's empty-means-keep
makes each a safe partial update). The owner is a dropdown over managed roles
plus Anyone; a legacy free-text owner stays pickable until changed."""

import from ...models { StepView }
import from ...constants { STEP_KINDS }
import from .kinds { KIND_LABEL, KIND_HINT, COLOR_KEYS, DOT_FILL, colorKey }
import from ..common.KindGlyph { KindGlyph }
import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ..common.glyphs { Spinner }


# One connection row: the other step's name, a loop mark on send-backs, and
# the remove button. Shared by the Goes to and Comes from lists.
def:pub TransitionRow(
    label: str, back: bool, onRemove: Callable[[], None] = None
) -> JsxElement {
    return
        <div
            className="flex items-center justify-between gap-2 rounded-md border px-2.5 py-1.5 text-[13px]"
        >
            <span className="flex min-w-0 items-center gap-1.5">
                <span className="truncate">{label}</span>
                {if back {
                    <span key="loop" className="shrink-0 text-xs text-subtle">
                        sends back
                    </span>
                }}
            </span>
            <button
                type="button"
                aria-label={"Remove the transition with " + label}
                className="flex size-6 shrink-0 items-center justify-center rounded-sm text-muted-foreground transition-colors hover:text-destructive"
                onClick={lambda { if onRemove { onRemove(); }}}
            >
                <svg
                    width={12}
                    height={12}
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={2}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    aria-hidden="true"
                >
                    <path d="M18 6 6 18"/>
                    <path d="m6 6 12 12"/>
                </svg>
            </button>
        </div>;
}


def:pub StepInspector(
    step: StepView,
    className: str = "",
    steps: list[StepView] = [],
    form: dict[str, str] = {},
    roleOptions: list[str] = [],
    connecting: bool = False,
    saving: bool = False,
    confirmingDelete: bool = False,
    onField: Callable[[str, str], None] = None,
    onNameCommit: Callable[[], None] = None,
    onConnect: Callable[[], None] = None,
    onCancelConnect: Callable[[], None] = None,
    onDelete: Callable[[], None] = None,
    onUnlink: Callable[[str, str], None] = None
) -> JsxElement {
    byId: dict[str, StepView] = {};
    for s in steps {
        byId[s.id] = s;
    }

    # The pickable owners: the org's roles, plus whatever legacy free-text
    # value this step already carries so it stays visible until changed.
    ownerChoices: list[str] = [];
    for r in roleOptions {
        ownerChoices.append(r);
    }
    currentOwner = (form["owner"] or "").strip();
    if (
        currentOwner and currentOwner != "anyone" and currentOwner not in ownerChoices
    ) {
        ownerChoices.append(currentOwner);
    }
    pickedKind = form["kind"] or "active";

    def rowLabel(sid: str) -> str {
        return byId[sid].name if sid in byId else "?";
    }

    # A send-back points at an earlier step in the flow line, the same rule
    # the canvas dashes its wire by.
    def isBack(fromId: str, toId: str) -> bool {
        if fromId not in byId or toId not in byId {
            return False;
        }
        return byId[toId].sort_order < byId[fromId].sort_order;
    }

    return
        <div className={"flex flex-col gap-4 " + className}>
            <div className="flex flex-col gap-1.5">
                <label className="text-[12.5px] font-semibold" htmlFor="step-name">
                    Step name
                </label>
                <Input
                    id="step-name"
                    value={form["name"] or ""}
                    placeholder="Name this step"
                    onChange={lambda (e: any) { if onField {
                        onField("name", e.target.value);
                    }}}
                    onBlur={lambda { if onNameCommit { onNameCommit(); }}}
                    onKeyDown={lambda (e: any) { if e.key == "Enter" and onNameCommit {
                        onNameCommit();
                    }}}
                />
            </div>
            <div className="flex flex-col gap-1.5">
                <label className="text-[12.5px] font-semibold" htmlFor="step-blurb">
                    What happens here
                </label>
                <Input
                    id="step-blurb"
                    value={form["blurb"] or ""}
                    placeholder="One line, in your words"
                    onChange={lambda (e: any) { if onField {
                        onField("blurb", e.target.value);
                    }}}
                    onBlur={lambda { if onNameCommit { onNameCommit(); }}}
                    onKeyDown={lambda (e: any) { if e.key == "Enter" and onNameCommit {
                        onNameCommit();
                    }}}
                />
                <p className="text-xs text-subtle">
                    Shown with the step's tasks and in the phone list.
                </p>
            </div>
            <div className="flex flex-col gap-1.5">
                <span className="text-[12.5px] font-semibold">Who holds it here</span>
                <Select
                    value={form["owner"] or "__none"}
                    onValueChange={lambda (v: str) { if onField {
                        onField("owner", "" if v == "__none" else v);
                    }}}
                >
                    <SelectTrigger className="w-full" aria-label="Who holds it here">
                        <SelectValue placeholder="Pick a role"/>
                    </SelectTrigger>
                    <SelectContent position="popper">
                        <SelectItem value="__none">No one yet</SelectItem>
                        <SelectItem value="anyone">Anyone</SelectItem>
                        {for r in ownerChoices {
                            <SelectItem key={r} value={r}>{r}</SelectItem>
                        }}
                    </SelectContent>
                </Select>
                <p className="text-xs text-subtle">
                    A role, not a person. Roles live in Workspace.
                </p>
            </div>
            <div className="flex flex-col gap-1.5">
                <span className="text-[12.5px] font-semibold" id="kind-label">
                    Kind
                </span>
                <div
                    role="radiogroup"
                    aria-labelledby="kind-label"
                    className="grid grid-cols-3 gap-1"
                >
                    {for k in STEP_KINDS {
                        <button
                            key={k}
                            type="button"
                            role="radio"
                            aria-checked={pickedKind == k}
                            className={"flex h-8 items-center gap-1.5 rounded-md border px-2 text-[13px] transition-colors "
                                + (
                                    "border-input bg-muted font-semibold text-foreground"
                                        if pickedKind == k
                                        else "border-border text-muted-foreground hover:bg-accent hover:text-foreground"
                                )}
                            onClick={lambda { if onField { onField("kind", k); }}}
                        >
                            <KindGlyph
                                kind={k}
                                size={14}
                                className={"text-destructive"
                                    if k == "blocked"
                                    else "text-subtle"}
                            />
                            {KIND_LABEL[k]}
                        </button>
                    }}
                </div>
                <p className="text-xs text-subtle">
                    {(KIND_LABEL[pickedKind] if pickedKind in KIND_LABEL else "")
                        + ": "
                        + (KIND_HINT[pickedKind] if pickedKind in KIND_HINT else "")
                        + ". The kind is what the app understands; the name is yours."}
                </p>
            </div>
            <div className="flex flex-col gap-1.5">
                <span className="text-[12.5px] font-semibold" id="color-label">
                    Colour
                </span>
                <div
                    role="radiogroup"
                    aria-labelledby="color-label"
                    className="flex gap-2"
                >
                    {for c in COLOR_KEYS {
                        <button
                            key={c}
                            type="button"
                            role="radio"
                            aria-checked={colorKey(form["color"] or "") == c}
                            aria-label={"orchid" if c == "rose" else c}
                            title={"orchid" if c == "rose" else c}
                            className={"size-6 rounded-sm "
                                + DOT_FILL[c]
                                + (
                                    " ring-2 ring-foreground ring-offset-2 ring-offset-card"
                                        if colorKey(form["color"] or "") == c
                                        else ""
                                )}
                            onClick={lambda { if onField { onField("color", c); }}}
                        />
                    }}
                </div>
            </div>
            <div className="flex flex-col gap-1.5 border-t pt-3">
                <span className="text-[12.5px] font-semibold">Goes to</span>
                {if len(step.next_ids) == 0 {
                    <p key="none" className="text-xs text-muted-foreground">
                        Nothing yet. Drag from this step's edge to another step.
                    </p>
                } else {
                    <div key="rows" className="flex flex-col gap-1">
                        {for nid in step.next_ids {
                            <TransitionRow
                                key={nid}
                                label={rowLabel(nid)}
                                back={isBack(step.id, nid)}
                                onRemove={lambda { if onUnlink {
                                    onUnlink(step.id, nid);
                                }}}
                            />
                        }}
                    </div>
                } }
            </div>
            <div className="flex flex-col gap-1.5">
                <span className="text-[12.5px] font-semibold">Comes from</span>
                {if len(step.prev_ids) == 0 {
                    <p key="none" className="text-xs text-muted-foreground">
                        Nothing points here.
                    </p>
                } else {
                    <div key="rows" className="flex flex-col gap-1">
                        {for pid in step.prev_ids {
                            <TransitionRow
                                key={pid}
                                label={rowLabel(pid)}
                                back={isBack(pid, step.id)}
                                onRemove={lambda { if onUnlink {
                                    onUnlink(pid, step.id);
                                }}}
                            />
                        }}
                    </div>
                } }
            </div>
            <div className="flex flex-col gap-2 border-t pt-3">
                {if connecting {
                    <Button
                        key="cancel"
                        variant="outline"
                        onClick={lambda { if onCancelConnect { onCancelConnect(); }}}
                    >
                        Cancel connect
                    </Button>
                } else {
                    <Button
                        key="connect"
                        variant="outline"
                        onClick={lambda { if onConnect { onConnect(); }}}
                    >
                        Connect to another step
                    </Button>
                } }
                <Button
                    variant={"destructive" if confirmingDelete else "ghost"}
                    className={""
                        if confirmingDelete
                        else "text-destructive hover:bg-destructive/10 hover:text-destructive"}
                    disabled={saving}
                    onClick={lambda { if onDelete { onDelete(); }}}
                >
                    {if saving and confirmingDelete {
                        <Spinner key="sp"/>
                    }}
                    {"Click again to delete" if confirmingDelete else "Delete step"}
                </Button>
            </div>
        </div>;
}
