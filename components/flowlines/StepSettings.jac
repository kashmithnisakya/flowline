"""The inspector's settings: name, owner, what happens here, then kind and colour.
No save button: name and blurb commit on blur or Enter, the rest on pick. The
owner is a dropdown over managed roles plus Anyone; a legacy free-text owner
stays pickable until changed."""

import from .StepKindPicker { StepKindPicker }
import from ..ui.input { Input }
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}

def:pub StepSettings(
    form: dict[str, str],
    roleOptions: list[str] = [],
    onField: Callable[[str, str], None] = None,
    onNameCommit: Callable[[], None] = None
) -> JsxElement {
    ownerChoices: list[str] = [];
    for r in roleOptions {
        ownerChoices.append(r);
    }
    currentOwner = (form["owner"] or "").strip();
    if currentOwner and currentOwner != "anyone" and currentOwner not in ownerChoices {
        ownerChoices.append(currentOwner);
    }
    return
        <section aria-label="Step settings" className="flex flex-col gap-3">
            <h3 className="text-[13px] font-semibold">Settings</h3>
            <div className="flex flex-col gap-1.5">
                <label className="text-[13px] font-medium" htmlFor="step-name">
                    Name
                </label>
                <Input
                    id="step-name"
                    className="h-8"
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
                <span className="text-[13px] font-medium">Owner</span>
                <Select
                    value={form["owner"] or "__none"}
                    onValueChange={lambda (v: str) { if onField {
                        onField("owner", "" if v == "__none" else v);
                    }}}
                >
                    <SelectTrigger className="h-8 w-full" aria-label="Owner">
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
                <p className="meta">A role, not a person. Roles live in Workspace.</p>
            </div>
            <div className="flex flex-col gap-1.5">
                <label className="text-[13px] font-medium" htmlFor="step-blurb">
                    What happens here
                </label>
                <Input
                    id="step-blurb"
                    className="h-8"
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
                <p className="meta">
                    Shown with the step's tasks and in the phone list.
                </p>
            </div>
            <StepKindPicker
                kind={form["kind"] or "active"}
                color={form["color"] or ""}
                onField={onField}
            />
        </section>;
}
