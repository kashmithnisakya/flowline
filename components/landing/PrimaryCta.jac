"""The page's large primary action: the board for a session, otherwise signup."""

import from ..ui.button { Button }

def:pub PrimaryCta(loggedIn: bool, className: str = "") -> JsxElement {
    return
        <Button
            asChild={True}
            className={"h-12 rounded-xl px-[22px] text-[15px] font-semibold "
                + className}
        >
            <a href={"/board" if loggedIn else "/login?mode=signup"}>
                {"Go to your board" if loggedIn else "Create your workspace"}
            </a>
        </Button>;
}
