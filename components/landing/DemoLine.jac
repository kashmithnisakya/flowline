"""A board row's face, as the landing draws it: the step bullet, the title
over its category, due date and GitHub number, the people and the move
arrow. Presentational; the hero wraps it to make it movable."""

import from ..common.Avatar { AvatarStack }
import from ..common.StepBadge { stepIcon }

def:pub DemoLine(task: dict[str, any], color: str, done: bool = False) -> JsxElement {
    meta = task["cat"] + ((" · " + task["gh"]) if task["gh"] else "");
    late = task["late"] and not done;
    return
        <span className="flex min-w-0 items-center gap-3">
            <span
                aria-hidden="true"
                className={"size-2 shrink-0 rounded-full bg-current " + stepIcon(color)}
            />
            <span className="grid min-w-0 flex-1 gap-0.5">
                <span
                    className={"truncate text-[13.5px] leading-snug font-medium "
                        + ("text-muted-foreground" if done else "")}
                >
                    {task["title"]}
                </span>
                <span className="truncate text-xs text-muted-foreground">
                    {meta}
                    {if task["due"] and not done {
                        <span
                            key="due"
                            className={"font-medium text-destructive" if late else ""}
                        >
                            {" · " + task["due"]}
                        </span>
                    }}
                </span>
            </span>
            {if len(task["who"]) > 0 {
                <span key="who" className="inline-flex shrink-0">
                    <AvatarStack names={task["who"]} max={2}/>
                </span>
            }}
            <svg
                width={14}
                height={14}
                viewBox="0 0 16 16"
                aria-hidden="true"
                className="shrink-0 text-subtle"
            >
                <path
                    d="M3 8h9.5M9 4.5 12.5 8 9 11.5"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.6}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                />
            </svg>
        </span>;
}
