"""A 14px chevron for pill buttons and menus: down, left or right."""

def:pub Chevron(facing: str = "down") -> JsxElement {
    path = "m4.5 6.5 3.5 3.5 3.5-3.5";
    if facing == "left" {
        path = "m9.5 4.5-3.5 3.5 3.5 3.5";
    } elif facing == "right" {
        path = "m6.5 4.5 3.5 3.5-3.5 3.5";
    }
    return
        <svg
            width={14}
            height={14}
            viewBox="0 0 16 16"
            aria-hidden="true"
            className="shrink-0"
        >
            <path
                d={path}
                fill="none"
                stroke="currentColor"
                strokeWidth={1.6}
                strokeLinecap="round"
                strokeLinejoin="round"
            />
        </svg>;
}
