"""The AI mark: a dashed ring around a dot, turning while AI is working. It is
the one sign of AI in the app, so a person is never mistaken for it."""

def:pub AiMark(
    running: bool = False, large: bool = False, className: str = ""
) -> JsxElement {
    return
        <span
            aria-hidden="true"
            className={"ai-mark"
                + (" ai-mark-run" if running else "")
                + (" ai-mark-lg" if large else "")
                + (" " + className if className else "")}
        />;
}
