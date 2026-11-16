"""A round port on a node's side: click an output port, then another node's input
port, to connect them. It lights while a connection is being made."""

def:pub NodePort(
    side: str, label: str, linking: bool, onClick: Callable[[], None]
) -> JsxElement {
    return
        <button
            type="button"
            aria-label={label}
            className={"absolute top-1/2 size-3.5 -translate-y-1/2 rounded-full border-2 bg-card "
                + ("-left-2 " if side == "in" else "-right-2 ")
                + (
                    "border-ring bg-ring"
                        if linking
                        else "border-muted-foreground hover:border-ring"
                )}
            onClick={lambda (e: any) {
                e.stopPropagation();
                onClick();
            }}
        />;
}
