"""The recorded product tour (named TourFilm: upstream owns DemoStrip, the
flow line strip across a sample board), between the interactive hero board and the
capability grid. The file is 1.8 MB, so it is lazy and carries its intrinsic
size: nothing is fetched until a reader scrolls near it, and the frame holds
its space before it arrives so the page never jumps.

The asset lives in `assets/`, which is served at `/static/`; `/assets/*` is
Vite's at build time, so the src must be the `/static/` spelling.
"""

glob DEMO_SRC: str = "/static/demo/flowline-demo.gif",
     DEMO_ALT: str = "A recorded tour of Flowline: signing in to the board, opening a task, ticking a checklist item and moving it on, then the flow line behind the board, the tasks table, the roadmap, its travel so far and the Overview.";

def:pub TourFilm -> JsxElement {
    return
        <section id="demo" className="landing-wrap scroll-mt-16 pt-16 sm:pt-24">
            <p className="section-eyebrow">The whole thing, moving</p>
            <h2
                className="mt-3 max-w-[28ch] text-[clamp(1.75rem,3.4vw,2.5rem)] leading-[1.1] font-bold tracking-[-0.025em]"
            >
                One pass through the app
            </h2>
            <p
                className="mt-3 max-w-[62ch] text-base leading-relaxed text-muted-foreground"
            >
                The board, a task and its checklist, the flow line behind it, the tasks table, the roadmap, its travel so far and the Overview.
            </p>
            <figure className="hero-frame reveal mt-8 overflow-hidden border bg-card">
                <img
                    src={DEMO_SRC}
                    alt={DEMO_ALT}
                    width={1280}
                    height={800}
                    loading="lazy"
                    decoding="async"
                    className="block h-auto w-full"
                />
            </figure>
        </section>;
}
