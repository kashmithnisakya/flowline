"""Product tour: the flow line, the board and the Overview as three
always-visible rows, each a short statement beside a rendering in the
product's own system."""

import from .TourFlow { TourFlow }
import from .TourBoard { TourBoard }
import from .TourOverview { TourOverview }

def TourRow(title: str, body: str, children: any = None) -> JsxElement {
    return
        <div
            className="reveal grid gap-5 border-t py-10 xl:grid-cols-[minmax(0,1fr)_minmax(0,3fr)] xl:gap-10"
        >
            <div className="grid content-start gap-2">
                <h3 className="text-lg leading-snug font-semibold">{title}</h3>
                <p
                    className="max-w-[54ch] text-[15px] leading-relaxed text-muted-foreground"
                >
                    {body}
                </p>
            </div>
            <div className="min-w-0">{children}</div>
        </div>;
}

def:pub Tour -> JsxElement {
    return
        <section id="tour" className="landing-wrap scroll-mt-16 pt-14 sm:pt-20">
            <h2
                className="max-w-[28ch] text-[clamp(1.625rem,3vw,2.125rem)] leading-tight font-bold tracking-[-0.012em]"
            >
                One flow line, three views of the same work
            </h2>
            <p
                className="mt-3 max-w-[62ch] text-base leading-relaxed text-muted-foreground"
            >
                You draw the steps once. The board and the Overview read from them, so the three can never disagree.
            </p>
            <div className="mt-8">
                <TourRow
                    title="Flow line"
                    body="Name the steps your team really uses and connect them the way work moves, branches and loops included. Each step says what it means (start, active, handoff, blocked or done) and can name who owns it; a connection can say whether it carries an issue or a pull request."
                >
                    <TourFlow/>
                    <p className="mt-2 text-xs text-subtle min-[792px]:hidden">
                        Scroll sideways to see the whole flow line.
                    </p>
                </TourRow>
                <TourRow
                    title="Board"
                    body="The board shows one project at a time as those steps, stacked in order, each over its tasks. Move a task from its row, by dragging it onto another step, or with the M key. Moving a task to Review can ask for a reviewer and a pull request; a blocked task asks for a note. Every move is kept on the task as its travel so far."
                >
                    <TourBoard/>
                </TourRow>
                <TourRow
                    title="Overview"
                    body="What needs someone now (overdue, blocked, waiting on review), this week's figures, burn-up, done per week, and each project and person, all counted from the board rather than typed in."
                >
                    <TourOverview/>
                </TourRow>
            </div>
        </section>;
}
