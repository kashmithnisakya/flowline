"""A project's colour as a 10px rounded square, the only place a project
colour is allowed to appear. The colour is positional (the project's index in
the sidebar), from a muted eight, so two projects next to each other never
read as the same thing.
"""

glob DOTS: list[str] = [
         "bg-project-1",
         "bg-project-2",
         "bg-project-3",
         "bg-project-4",
         "bg-project-5",
         "bg-project-6",
         "bg-project-7",
         "bg-project-8"
     ];

# The fill class for the nth project.
def:pub projectDot(i: int) -> str {
    return DOTS[i % len(DOTS)];
}


def:pub ProjectDot(i: int = 0, className: str = "") -> JsxElement {
    return
        <span
            aria-hidden="true"
            className={"size-2.5 shrink-0 rounded-[3px] "
                + projectDot(i)
                + " "
                + className}
        />;
}
