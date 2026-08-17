"""Editor panel for the selected step. No save button: the name commits on
blur/Enter, kind, colour and owner commit on pick (SaveStep's empty-means-keep
makes each a safe partial update). The owner is a dropdown over managed roles
plus Anyone; a legacy free-text owner stays pickable until changed."""

import from ...models { StepView }
import from ...constants { STEP_KINDS }
import from .kinds { KIND_LABEL, KIND_HINT, COLOR_KEYS, DOT_FILL, colorKey }
import from ..ui.button { Button }
import from ..ui.card { Card, CardContent }
import from ..ui.input { Input }
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ..common.glyphs { Spinner }


# One connection row: the other step's name, a loop glyph on send-backs, and
# the remove button. Shared by the Goes to and Comes from lists.
def:pub TransitionRow(
    label: str, back: bool, onRemove: Callable[[], None] = None
) -> JsxElement {
    return
        <div
            className={"flex items-center justify-between gap-2 rounded-lg border px-2.5 py-1.5 text-xs "
                + ("border-warning/40 bg-warning/10" if back else "bg-muted/40")}
        >
            <span className="flex min-w-0 items-center gap-1.5">
                {if back {
                    <svg
                        key="loop"
                        className="shrink-0 text-warning"
                        width={12}
                        height={12}
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth={2}
                        strokeLinecap="round"
                        strokeLinejoin="round"
                    >
                        <path d="m17 2 4 4-4 4"/>
                        <path d="M3 11v-1a4 4 0 0 1 4-4h14"/>
                        <path d="m7 22-4-4 4-4"/>
                        <path d="M21 13v1a4 4 0 0 1-4 4H3"/>
                    </svg>
                }}
                <span className="truncate">{label}</span>
            </span>
            <button
                type="button"
                title="Remove this transition"
                className="shrink-0 text-muted-foreground transition-colors hover:text-destructive"
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
    # "Anyone" and "No one yet" are fixed choices rendered above these.
    ownerChoices: list[str] = [];
    for r in roleOptions {
        ownerChoices.append(r);
    }
    currentOwner = (form["owner"] or "").strip();
    if (
        currentOwner
        and currentOwner != "anyone"
        and currentOwner not in ownerChoices
    ) {
        ownerChoices.append(currentOwner);
    }

    def rowLabel(sid: str) -> str {
        return byId[sid].name if sid in byId else "?";
    }

    def isBack(fromId: str, toId: str) -> bool {
        if fromId not in byId or toId not in byId {
            return False;
        }
        # Same rule the canvas uses (geometry.isBackEdge), inlined here because
        # the standalone export keeps vanishing from the compiled client
        # bundle on a cold start; duplicating the arithmetic is cheap and
        # removes the cross-module dependency that triggers the bug.
        fx = byId[fromId].x;
        fy = byId[fromId].y;
        tx = byId[toId].x;
        ty = byId[toId].y;
        dx = tx - fx;
        dy = ty - fy;
        ax = dx if dx >= 0.0 else 0.0 - dx;
        ay = dy if dy >= 0.0 else 0.0 - dy;
        if ax >= ay {
            return dx < 0.0;
        }
        return dy < 0.0;
    }

    return
        <Card className={"overflow-y-auto " + className}>
            <CardContent className="space-y-4 py-4">
                <div className="space-y-1.5">
                    <div
                        className="text-xs font-medium uppercase tracking-wider text-muted-foreground"
                    >
                        Step name
                    </div>
                    <Input
                        value={form["name"] or ""}
                        placeholder="Name this step"
                        onChange={lambda (e: any) { if onField {
                            onField("name", e.target.value);
                        }}}
                        onBlur={lambda { if onNameCommit { onNameCommit(); }}}
                        onKeyDown={lambda (e: any) { if e.key == "Enter"
                            and onNameCommit {
                            onNameCommit();
                        }}}
                    />
                </div>
                <div className="space-y-1.5">
                    <div
                        className="text-xs font-medium uppercase tracking-wider text-muted-foreground"
                    >
                        Who holds it here
                    </div>
                    <Select
                        value={form["owner"] or "__none"}
                        onValueChange={lambda (v: str) { if onField {
                            onField("owner", "" if v == "__none" else v);
                        }}}
                    >
                        <SelectTrigger className="w-full">
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
                    <p className="text-[11px] text-muted-foreground">
                        A role, not a person. The list is managed on the Workspace's Roles tab.
                    </p>
                </div>
                <div className="space-y-1.5">
                    <div
                        className="text-[11px] font-medium uppercase tracking-wider text-muted-foreground"
                    >
                        Kind
                    </div>
                    <Select
                        value={form["kind"] or "active"}
                        onValueChange={lambda (v: str) { if onField {
                            onField("kind", v);
                        }}}
                    >
                        <SelectTrigger className="w-full">
                            <SelectValue placeholder="Kind"/>
                        </SelectTrigger>
                        <SelectContent position="popper">
                            {for k in STEP_KINDS {
                                <SelectItem key={k} value={k}>
                                    {KIND_LABEL[k] + ", " + KIND_HINT[k]}
                                </SelectItem>
                            }}
                        </SelectContent>
                    </Select>
                    <p className="text-xs text-muted-foreground">
                        The kind is what the app understands; the name is yours.
                    </p>
                </div>
                <div className="space-y-1.5">
                    <div
                        className="text-xs font-medium uppercase tracking-wider text-muted-foreground"
                    >
                        Color
                    </div>
                    <div className="flex gap-2">
                        {for c in COLOR_KEYS {
                            <button
                                key={c}
                                type="button"
                                title={c}
                                className={"h-5 w-5 rounded-full "
                                    + DOT_FILL[c]
                                    + (
                                        " ring-2 ring-ring ring-offset-2 ring-offset-card"
                                            if colorKey(form["color"] or "") == c
                                            else ""
                                    )}
                                onClick={lambda { if onField { onField("color", c); }}}
                            />
                        }}
                    </div>
                </div>
                <div className="space-y-1.5 border-t pt-3">
                    <div
                        className="text-xs font-medium uppercase tracking-wider text-muted-foreground"
                    >
                        Goes to
                    </div>
                    {if len(step.next_ids) == 0 {
                        <p key="none" className="text-xs text-muted-foreground">
                            Nothing yet. Drag from this step's border to connect it.
                        </p>
                    } else {
                        <div key="rows" className="flex flex-col gap-1.5">
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
                <div className="space-y-1.5">
                    <div
                        className="text-xs font-medium uppercase tracking-wider text-muted-foreground"
                    >
                        Comes from
                    </div>
                    {if len(step.prev_ids) == 0 {
                        <p key="none" className="text-xs text-muted-foreground">
                            Nothing points here.
                        </p>
                    } else {
                        <div key="rows" className="flex flex-col gap-1.5">
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
                            size="sm"
                            onClick={lambda { if onCancelConnect {
                                onCancelConnect();
                            }}}
                        >
                            Cancel connect
                        </Button>
                    } else {
                        <Button
                            key="connect"
                            variant="outline"
                            size="sm"
                            onClick={lambda { if onConnect { onConnect(); }}}
                        >
                            Connect
                            <svg
                                width={14}
                                height={14}
                                viewBox="0 0 24 24"
                                fill="none"
                                stroke="currentColor"
                                strokeWidth={2}
                                strokeLinecap="round"
                                strokeLinejoin="round"
                            >
                                <path d="M5 12h14"/>
                                <path d="m12 5 7 7-7 7"/>
                            </svg>
                        </Button>
                    } }
                    <Button
                        variant={"destructive" if confirmingDelete else "outline"}
                        className={""
                            if confirmingDelete
                            else "border-destructive/60 text-destructive hover:bg-destructive/10 hover:text-destructive"}
                        size="sm"
                        disabled={saving}
                        onClick={lambda { if onDelete { onDelete(); }}}
                    >
                        {if saving and confirmingDelete {
                            <Spinner key="sp"/>
                        }}
                        {"Really delete?" if confirmingDelete else "Delete step"}
                    </Button>
                </div>
            </CardContent>
        </Card>;
}
