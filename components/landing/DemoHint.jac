"""The line under the hero demo: how to try it, then, after a move, a nudge
to make a workspace of your own."""

def:pub DemoHint(moved: bool, loggedIn: bool) -> JsxElement {
    return
        <p className="mt-2.5 text-xs text-subtle">
            {if moved {
                <span key="after">
                    {"That line wrote itself when the task moved. "}
                    <a
                        href={"/board" if loggedIn else "/login?mode=signup"}
                        className="font-semibold text-foreground underline underline-offset-2"
                    >
                        {"Open your board" if loggedIn else "Create your workspace"}
                    </a>
                </span>
            } else {
                <span key="hint">
                    {"Sample data. "}
                    <span className="sm:hidden">Tap a task to move it along.</span>
                    <span className="hidden sm:inline">
                        Drag a task onto another step, or click it to move it along.
                    </span>
                </span>
            } }
        </p>;
}
