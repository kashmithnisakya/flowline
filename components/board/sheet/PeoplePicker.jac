"""The People menu: the task's assignees, with those on its project first. It
is shared by the task sheet and the new-task dialog; the trigger is the caller's."""

import from ....models { MemberView }
import from ...ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuCheckboxItem
}

def Pick(m: MemberView, on: bool, onToggle: Callable[[str], None]) -> JsxElement {
    return
        <DropdownMenuCheckboxItem
            checked={on}
            onCheckedChange={lambda { if onToggle { onToggle(m.id); }}}
            onSelect={lambda (e: any) { e.preventDefault(); }}
        >
            {m.name}
        </DropdownMenuCheckboxItem>;
}

def:pub PeoplePicker(
    members: list[MemberView],
    project: str,
    assignees: list[str],
    onToggle: Callable[[str], None],
    triggerClass: str,
    children: any = None
) -> JsxElement {
    inProject = [
        m
        for m in members
        if project and project in m.project_ids
    ];
    outsiders = [
        m
        for m in members
        if m not in inProject
    ];
    return
        <DropdownMenu>
            <DropdownMenuTrigger className={triggerClass} aria-label="Assignees">
                {children}
            </DropdownMenuTrigger>
            <DropdownMenuContent className="w-64" align="start" collisionPadding={16}>
                {if len(inProject) > 0 {
                    <DropdownMenuLabel key="inl">On this project</DropdownMenuLabel>
                }}
                {for m in inProject {
                    <Pick key={m.id} m={m} on={m.id in assignees} onToggle={onToggle}/>
                }}
                {if len(inProject) > 0 and len(outsiders) > 0 {
                    <DropdownMenuSeparator key="sep"/>
                }}
                {if len(outsiders) > 0 {
                    <DropdownMenuLabel key="ol">
                        {"Other people" if project else "People"}
                    </DropdownMenuLabel>
                }}
                {for m in outsiders {
                    <Pick key={m.id} m={m} on={m.id in assignees} onToggle={onToggle}/>
                }}
            </DropdownMenuContent>
        </DropdownMenu>;
}
