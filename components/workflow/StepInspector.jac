"""Editor panel for the step selected on the workflow canvas.

No save button on purpose: the name commits on blur or Enter, kind and
color commit on pick — SaveStep's empty-means-keep semantics make each a
safe partial update. Connections are removable rows in both directions.
"""

import from ...models { StepView }
import from ...constants { STEP_KINDS }
import from .kinds { KIND_LABEL, KIND_HINT, COLOR_KEYS, DOT_FILL, colorKey }
import from .geometry { isBackEdge }
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


def:pub StepInspector(
    step: StepView,
    className: str = "",
    steps: list[StepView] = [],
    form: dict[str, str] = {},
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

    def rowLabel(sid: str) -> str {
        return byId[sid].name if sid in byId else "?";
    }

    def isBack(fromId: str, toId: str) -> bool {
        if fromId not in byId or toId not in byId {
            return False;
        }
        # Same call the canvas makes, so a row and its edge always agree.
        return isBackEdge(byId[fromId].x, byId[fromId].y, byId[toId].x, byId[toId].y);
    }

    def rowClass(back: bool) -> str {
        return "flex items-center justify-between rounded-md border bg-muted/40 px-2.5 py-1.5 text-xs";
    }

    return
        <Card className={"overflow-y-auto " + className}>
            <CardContent className="space-y-4 py-4">
                <div className="space-y-1.5">
                    <div
                        className="text-[11px] font-medium uppercase tracking-wider text-muted-foreground"
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
                                    {KIND_LABEL[k] + " — " + KIND_HINT[k]}
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
                        className="text-[11px] font-medium uppercase tracking-wider text-muted-foreground"
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
                        className="text-[11px] font-medium uppercase tracking-wider text-muted-foreground"
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
                                <div
                                    key={nid}
                                    className={rowClass(isBack(step.id, nid))}
                                >
                                    <span>{rowLabel(nid)}</span>
                                    <button
                                        type="button"
                                        title="Remove this transition"
                                        className="text-muted-foreground hover:text-destructive"
                                        onClick={lambda { if onUnlink {
                                            onUnlink(step.id, nid);
                                        }}}
                                    >
                                        ✕
                                    </button>
                                </div>
                            }}
                        </div>
                    } }
                </div>
                <div className="space-y-1.5">
                    <div
                        className="text-[11px] font-medium uppercase tracking-wider text-muted-foreground"
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
                                <div
                                    key={pid}
                                    className={rowClass(isBack(pid, step.id))}
                                >
                                    <span>{rowLabel(pid)}</span>
                                    <button
                                        type="button"
                                        title="Remove this transition"
                                        className="text-muted-foreground hover:text-destructive"
                                        onClick={lambda { if onUnlink {
                                            onUnlink(pid, step.id);
                                        }}}
                                    >
                                        ✕
                                    </button>
                                </div>
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
                            Connect →
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
                        {"Really delete?" if confirmingDelete else "Delete step"}
                    </Button>
                </div>
            </CardContent>
        </Card>;
}
