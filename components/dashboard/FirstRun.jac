"""First-run checklist: the page body while nothing can be counted, a side
panel after that. The page computes every item from real state (key, title,
detail, done, action, to, primary); a finished item keeps a quiet link."""

import from "@jac/runtime" { Link }
import from .Panel { Panel }
import from ..common.KindGlyph { KindGlyph }
import from ..ui.button { Button }

def:pub FirstRun(title: str, items: list[dict[str, any]]) -> JsxElement {
    finished = len(
        [
            it
            for it in items
            if it["done"]
        ]
    );
    count = <span className="num text-xs text-muted-foreground">
        {str(finished) + " of " + str(len(items))}
    </span>;
    return
        <Panel id="first-run" title={title} aside={count}>
            <ol className="space-y-1">
                {for it in items {
                    <li
                        key={it["key"]}
                        className="grid grid-cols-[1.25rem_minmax(0,1fr)_auto] items-center gap-3 rounded-xl py-2 text-sm"
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
                            <p className="font-medium">{it["title"]}</p>
                            <p className="text-xs text-muted-foreground">
                                {it["detail"]}
                            </p>
                        </div>
                        {if it["done"] and not it["action"] {
                            <span key="none"/>
                        } elif it["done"] {
                            <Link
                                key="redo"
                                to={it["to"]}
                                className="text-sm text-primary underline underline-offset-[3px] hover:decoration-2"
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
        </Panel>;
}
