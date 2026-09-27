"""One repository setting: what it does, a line of detail and its switch. A
setting that writes to GitHub leads its detail with a warning so nobody turns
it on without seeing that."""

import from ..ui.switch { Switch }

def:pub AutomationRow(
    id: str,
    title: str,
    detail: str,
    checked: bool,
    onChange: Callable[[bool], None],
    writes: bool = False,
    first: bool = False
) -> JsxElement {
    return
        <div
            className={"grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 px-4 py-3"
                + ("" if first else " border-t")}
        >
            <div>
                <label htmlFor={id} className="text-[13.5px] font-medium">
                    {title}
                </label>
                <p className="mt-0.5 text-[12.5px] text-muted-foreground">
                    {if writes {
                        <span key="writes" className="font-semibold text-warning">
                            Writes to GitHub.{" "}
                        </span>
                    }}
                    {detail}
                </p>
            </div>
            <Switch
                id={id}
                checked={checked}
                onCheckedChange={lambda (v: bool) { onChange(v); }}
            />
        </div>;
}
