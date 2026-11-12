"""The new-task dialog's row of chips: project, the step it lands on, people, due
date, priority, and More for the rarer fields."""

import from ....models { Project, MemberView }
import from ...ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ...common.DatePicker { DatePicker }
import from ...common.StepName { StepName }
import from .PeoplePicker { PeoplePicker }

glob CHIP: str = "h-[26px]! w-auto gap-1.5 rounded-md border border-border bg-transparent px-2 text-[12.5px] font-normal shadow-none hover:bg-bg-hover",
     ADD: str = "inline-flex h-[26px] items-center gap-1.5 rounded-md border border-dashed border-border-strong px-2 text-[12.5px] text-text-secondary hover:bg-bg-hover hover:text-text-primary";

def:pub NewTaskChips(
    form: dict[str, str],
    projects: list[Project],
    members: list[MemberView],
    columnKeys: list[str],
    columnLabels: list[str],
    colors: list[str],
    assignees: list[str],
    moreOpen: bool,
    onField: Callable[[str, str], None],
    onToggleAssignee: Callable[[str], None],
    onMore: Callable[[], None]
) -> JsxElement {
    names = [
        m.name
        for m in members
        if m.id in assignees
    ];
    return
        <div className="flex flex-wrap items-center gap-1.5">
            <Select
                value={form["project"]}
                onValueChange={lambda (v: str) { onField("project", v); }}
            >
                <SelectTrigger className={CHIP} aria-label="Project">
                    <SelectValue placeholder="Project"/>
                </SelectTrigger>
                <SelectContent>
                    {for p in projects {
                        <SelectItem key={jid(p)} value={jid(p)}>{p.name}</SelectItem>
                    }}
                </SelectContent>
            </Select>
            <Select
                value={form["status"]}
                onValueChange={lambda (v: str) { onField("status", v); }}
            >
                <SelectTrigger className={CHIP} aria-label="Step">
                    <SelectValue placeholder="Step"/>
                </SelectTrigger>
                <SelectContent>
                    {for (i, k) in enumerate(columnKeys) {
                        <SelectItem key={k} value={k}>
                            <StepName name={columnLabels[i]} color={colors[i]}/>
                        </SelectItem>
                    }}
                </SelectContent>
            </Select>
            <PeoplePicker
                members={members}
                project={form["project"]}
                assignees={assignees}
                onToggle={onToggleAssignee}
                triggerClass={ADD}
            >
                <span className="max-w-44 truncate">
                    {", ".join(names) if len(names) > 0 else "People"}
                </span>
            </PeoplePicker>
            <DatePicker
                value={form["due_date"]}
                clearable={True}
                className={ADD + " w-auto! font-normal!"}
                onChange={lambda (d: str) { onField("due_date", d); }}
            />
            <Select
                value={form["priority"]}
                onValueChange={lambda (v: str) { onField("priority", v); }}
            >
                <SelectTrigger className={CHIP} aria-label="Priority">
                    <SelectValue placeholder="Priority"/>
                </SelectTrigger>
                <SelectContent>
                    <SelectItem value="High">High</SelectItem>
                    <SelectItem value="Medium">Medium</SelectItem>
                    <SelectItem value="Low">Low</SelectItem>
                </SelectContent>
            </Select>
            <button
                type="button"
                aria-expanded={moreOpen}
                className={ADD}
                onClick={lambda { onMore(); }}
            >
                {"Less" if moreOpen else "More"}
            </button>
        </div>;
}
