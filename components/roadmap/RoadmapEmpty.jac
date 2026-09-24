"""Why these weeks are blank, in one sentence, and the one action that fixes
it: back to this week, the board (dates are set in a task's sheet there), a
new task, or a first project."""

import from "@jac/runtime" { Link }
import from ..ui.button { Button }

glob LINKS: dict[str, list[str]] = {
         "board": ["/board", "Open the board"],
         "new": ["/board?new=1", "New task"],
         "project": ["/workspace?tab=projects", "Add a project"]
     };

def:pub RoadmapEmpty(
    text: str, action: str, onToday: Callable[[], None], busy: bool = False
) -> JsxElement {
    return
        <div
            className="flex flex-col items-center gap-4 px-6 py-16 text-center"
            aria-busy={busy}
        >
            <p className="max-w-md text-sm text-muted-foreground">{text}</p>
            {if action == "today" {
                <Button
                    key="today"
                    variant="outline"
                    size="sm"
                    className="h-8 rounded-full px-4"
                    onClick={lambda { onToday(); }}
                >
                    Back to this week
                </Button>
            } elif action in LINKS {
                <Button
                    key="link"
                    size="sm"
                    className="h-8 rounded-full px-4"
                    asChild={True}
                >
                    <Link to={LINKS[action][0]}>{LINKS[action][1]}</Link>
                </Button>
            } }
        </div>;
}
