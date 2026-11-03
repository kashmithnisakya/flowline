"""The flow line's name and one line of what it holds, at the right of the
project header (an input while renaming). The project's own name is the title."""

import from ..ui.input { Input }
import from ..ui.skeleton { Skeleton }

def plural(n: int, noun: str) -> str {
    return str(n) + " " + noun + ("" if n == 1 else "s");
}

def:pub FlowTitle(
    lineName: str,
    steps: int = 0,
    transitions: int = 0,
    roles: int = 0,
    renaming: bool = False,
    nameDraft: str = "",
    pending: bool = False,
    onDraft: Callable[[str], None] = None,
    onRename: Callable[[], None] = None
) -> JsxElement {
    summary = (
        plural(steps, "step")
        + ", "
        + plural(transitions, "arrow")
        + ", "
        + plural(roles, "role")
    );
    if pending {
        return <Skeleton className="h-3 w-52"/>;
    }
    return
        <span className="flex min-w-0 items-center gap-1.5 text-xs">
            {if renaming {
                <Input
                    key="rename"
                    aria-label="Flow line name"
                    className="h-7 w-56 max-w-full text-[13px]"
                    value={nameDraft}
                    autoFocus={True}
                    onChange={lambda (e: ChangeEvent) { if onDraft {
                        onDraft(e.target.value);
                    }}}
                    onBlur={lambda { if onRename { onRename(); }}}
                    onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter"
                        and onRename {
                        onRename();
                    }}}
                />
            } else {
                <span key="name" className="truncate font-medium text-text-secondary">
                    {lineName}
                </span>
            } }
            <span className="meta whitespace-nowrap">{summary}</span>
        </span>;
}
