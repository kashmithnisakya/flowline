"""First-run checklist for a workspace with nothing to count yet. The page
computes every item from real state (key, title, detail, done, action, to,
primary); a finished item keeps a quiet link, an open one gets a button."""

import from "@jac/runtime" { Link }
import from ..common.KindGlyph { KindGlyph }
import from ..ui.button { Button }

def:pub FirstRun(title: str, items: list[dict]) -> JsxElement {
    finished = len(
        [
            it
            for it in items
            if it["done"]
        ]
    );
    return
        <section className="surface min-w-0" aria-labelledby="first-run">
            <div className="flex items-baseline gap-2 px-3.5 pt-3 pb-2">
                <h2 id="first-run" className="section-title text-[15px]">{title}</h2>
                <span className="num text-xs text-subtle">
                    {str(finished) + " of " + str(len(items))}
                </span>
            </div>
            <ol className="px-3.5 pb-1.5">
                {for (i, it) in enumerate(items) {
                    <li
                        key={it["key"]}
                        className={"grid grid-cols-[1.25rem_minmax(0,1fr)_auto] items-center gap-2.5 py-2.5 text-[13.5px] "
                            + ("border-t" if i > 0 else "")}
                    >
                        <span
                            className={"text-success" if it["done"] else "text-input"}
                            role="img"
                            aria-label={"Done" if it["done"] else "Not done yet"}
                        >
                            <KindGlyph
                                kind={"done" if it["done"] else "start"}
                                size={16}
                            />
                        </span>
                        <div className="min-w-0">
                            <p className="font-semibold">{it["title"]}</p>
                            <p className="text-[12.5px] text-muted-foreground">
                                {it["detail"]}
                            </p>
                        </div>
                        {if it["done"] and not it["action"] {
                            <span key="none"/>
                        } elif it["done"] {
                            <Link
                                key="redo"
                                to={it["to"]}
                                className="text-[13px] text-primary underline underline-offset-[3px] hover:decoration-2"
                            >
                                {it["action"]}
                            </Link>
                        } else {
                            <Button
                                key="go"
                                asChild={True}
                                size="sm"
                                variant={"default" if it["primary"] else "outline"}
                            >
                                <Link to={it["to"]}>{it["action"]}</Link>
                            </Button>
                        }  }
                    </li>
                }}
            </ol>
        </section>;
}
