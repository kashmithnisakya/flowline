"""The Overview's panel: a solid surface, a title row (`aside` sits at its
right) over a hairline, then the body, flush for a list of rows. `EmptyLine` is
a panel's one-line empty state with a link to where the missing thing is added."""

import from "@jac/runtime" { Link }

glob:pub PANEL_LINK: str = "meta underline decoration-border-strong underline-offset-[3px] hover:text-text-primary";

def:pub Panel(
    id: str,
    title: str,
    aside: any = None,
    busy: bool = False,
    className: str = "",
    flush: bool = False,
    children: any = None
) -> JsxElement {
    return
        <section
            className={"surface min-w-0 rounded-xl " + className}
            aria-labelledby={id}
            aria-busy={busy}
        >
            <div
                className="flex min-h-11 flex-wrap items-center gap-x-3 gap-y-1 border-b border-border-subtle px-4 py-2"
            >
                <h2 id={id} className="section-title mr-auto text-sm">{title}</h2>
                {aside}
            </div>
            <div className={"" if flush else "p-4"}>{children}</div>
        </section>;
}

def:pub EmptyLine(text: str, action: str, to: str) -> JsxElement {
    return
        <p className="text-[13px] text-text-secondary">
            {text + " "}
            <Link to={to} className={PANEL_LINK}>{action}</Link>
        </p>;
}
