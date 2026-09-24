"""The Overview's soft panel: a rounded card on a faint ring, a title row
(`aside` sits at its right) and the body. `EmptyLine` is a panel's one-line
empty state with a link to where the missing thing is added."""

import from "@jac/runtime" { Link }

glob PANEL: str = "min-w-0 rounded-[20px] bg-card text-card-foreground shadow-[0_0_0_1px_color-mix(in_oklab,var(--foreground)_7%,transparent),0_1px_3px_color-mix(in_oklab,var(--foreground)_5%,transparent)]";

def:pub Panel(
    id: str,
    title: str,
    aside: any = None,
    busy: bool = False,
    className: str = "",
    children: any = None
) -> JsxElement {
    return
        <section
            className={PANEL + " p-4 sm:p-5 " + className}
            aria-labelledby={id}
            aria-busy={busy}
        >
            <div className="mb-3 flex flex-wrap items-center gap-x-3 gap-y-2">
                <h2 id={id} className="section-title mr-auto">{title}</h2>
                {aside}
            </div>
            {children}
        </section>;
}

def:pub EmptyLine(text: str, action: str, to: str) -> JsxElement {
    return
        <p className="text-sm text-muted-foreground">
            {text + " "}
            <Link
                to={to}
                className="text-primary underline underline-offset-[3px] hover:decoration-2"
            >
                {action}
            </Link>
        </p>;
}
