"""One agent as a row: its name and role, when it wakes, its model, whether it
is on, and its own switch, canvas, edit and delete. The columns fold into a
meta line on a phone. A needs-setup status is dashed (a person has to settle it)."""

import from "@jac/runtime" { Link }
import from ...models { AgentView, RoleView, StepView }
import from ...lib.agents { statusOf, whenText, modelLabel }
import from ..common.AiMark { AiMark }
import from ..ui.button { Button }
import from ..ui.switch { Switch }

def:pub AgentRow(
    agent: AgentView,
    roleName: str,
    steps: list[StepView],
    models: list[list[str]],
    busy: bool,
    onToggle: Callable[[bool], None],
    onEdit: Callable[[], None],
    onDelete: Callable[[], None]
) -> JsxElement {
    status = statusOf(agent, models);
    needs = status[1] == "warn";
    return
        <li
            className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-4 gap-y-1 px-3 py-2.5 hover:bg-accent md:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)_minmax(0,1.2fr)_minmax(0,1fr)_auto] md:py-2"
        >
            <div className="flex min-w-0 items-center gap-2">
                <AiMark/>
                <div className="min-w-0">
                    <div className="truncate text-[13.5px] font-medium">
                        {agent.name}
                    </div>
                    <div className="meta truncate md:hidden">
                        {roleName + " · " + whenText(agent.event, agent.steps, steps)}
                    </div>
                </div>
            </div>
            <span className="hidden truncate text-[13px] md:block">{roleName}</span>
            <span
                className="hidden truncate text-[13px] text-muted-foreground md:block"
            >
                {whenText(agent.event, agent.steps, steps)}
            </span>
            <span
                className="hidden truncate text-[13px] text-muted-foreground md:block"
            >
                {modelLabel(agent.model, models)}
            </span>
            <div
                className="col-start-2 row-span-2 row-start-1 flex items-center justify-self-end gap-2 md:col-start-5 md:row-span-1"
            >
                <span className={"ai-chip " + ("" if needs else "ai-chip-settled")}>
                    {status[0]}
                </span>
                <Switch
                    aria-label={"Turn " + agent.name + " on"}
                    checked={agent.enabled}
                    disabled={busy or needs}
                    onCheckedChange={lambda (v: bool) { onToggle(v); }}
                />
                <Link
                    to={"/agent?id=" + agent.id}
                    className="inline-flex h-7 items-center rounded-sm border px-2 text-[13px] hover:bg-accent"
                >
                    Canvas
                </Link>
                <Button variant="ghost" size="sm" onClick={lambda { onEdit(); }}>
                    Edit
                </Button>
                <Button
                    variant="ghost"
                    size="sm"
                    className="text-destructive"
                    onClick={lambda { onDelete(); }}
                >
                    Delete
                </Button>
            </div>
        </li>;
}
