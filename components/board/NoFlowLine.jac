"""The board of a workspace with no flow line and no tasks: what the board
will show once there is one, and the two ways to make it, over a faint
picture of stacked step groups."""

import from "@jac/runtime" { navigate }
import from ..ui.button { Button }

def:pub NoFlowLine -> JsxElement {
    return
        <div className="flex min-w-0 flex-col gap-8 pt-2">
            <div className="flex max-w-lg flex-col items-start gap-3">
                <h2 className="section-title text-lg">
                    Your board follows your flow line
                </h2>
                <p className="text-sm text-muted-foreground">
                    Each group here is a step your team moves work through, in the order you draw them. Start from a template, or draw the steps yourself.
                </p>
                <div className="flex flex-wrap items-center gap-2 pt-1">
                    <Button
                        className="rounded-md"
                        onClick={lambda { navigate("/flowlines"); }}
                    >
                        Pick a template
                    </Button>
                    <Button
                        variant="ghost"
                        className="rounded-md"
                        onClick={lambda { navigate("/flowlines"); }}
                    >
                        Draw the steps yourself
                    </Button>
                </div>
            </div>
            <div aria-hidden="true" className="flex max-w-3xl flex-col gap-5">
                {for i in [0, 1, 2] {
                    <div key={"ghost" + str(i)} className="flex flex-col gap-2">
                        <div
                            className="flex h-12 items-center rounded-2xl bg-muted/70 px-3"
                        >
                            <span className="h-6 w-24 rounded-full bg-muted"/>
                        </div>
                        {for j in range(2 - (i % 2)) {
                            <div
                                key={"r" + str(j)}
                                className="flex h-10 items-center gap-3 px-3"
                            >
                                <span className="size-2 rounded-full bg-muted"/>
                                <span className="h-2.5 w-2/5 rounded-xs bg-muted"/>
                            </div>
                        }}
                    </div>
                }}
            </div>
        </div>;
}
