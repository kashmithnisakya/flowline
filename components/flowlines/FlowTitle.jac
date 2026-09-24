"""The flow line page's heading: the project it is for (a picker, like the
board's), the flow line's name (an input while renaming) and one line of
what it holds."""

import from ...models { Project }
import from ..common.ProjectLine { ProjectLine }
import from ..ui.input { Input }
import from ..ui.skeleton { Skeleton }

def plural(n: int, noun: str) -> str {
    return str(n) + " " + noun + ("" if n == 1 else "s");
}

def:pub FlowTitle(
    projects: list[Project],
    projectId: str,
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
        + " · "
        + plural(transitions, "transition")
        + " · "
        + plural(roles, "role")
    );
    return
        <div className="flex min-w-0 flex-col gap-1">
            <ProjectLine projects={projects} project={projectId}/>
            {if renaming {
                <Input
                    key="rename"
                    aria-label="Flow line name"
                    className="h-9 w-72 max-w-full text-lg font-semibold"
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
                <h1 key="name" className="page-title min-w-0 truncate">{lineName}</h1>
            } }
            {if pending {
                <Skeleton key="ph" className="my-1 h-3 w-52"/>
            } else {
                <p key="sum" className="text-[13px] text-muted-foreground">{summary}</p>
            } }
        </div>;
}
