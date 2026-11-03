"""Request-changes mode sends a task back only along an arrow with the changes
requested trigger. A step in scope without one keeps the task, so say so here,
before the task's log does."""

import from ....models { StepView }

def:pub SendBackNote(picked: list[str], steps: list[StepView]) -> JsxElement {
    stuck: list[str] = [
        s.name
        for s in steps
        if (len(picked) == 0 or s.id in picked)
            and "changes_requested" not in s.next_triggers
    ];
    if len(stuck) == 0 {
        return <></>;
    }
    return
        <p className="text-[12.5px] text-muted-foreground">
            {"No arrow out of "
                + ", ".join(stuck)
                + " sends work back on changes requested, so a blocking problem leaves the task there. Set that trigger on an arrow on the flow line."}
        </p>;
}
