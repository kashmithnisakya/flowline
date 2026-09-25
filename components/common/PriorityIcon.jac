"""Priority as three ascending bars, filled to the level: Low one, Medium two,
High three. Tertiary at every level except High, which is the app's only
"this is a problem" priority and takes the danger colour.

Shape carries the level, so priority never rides on colour alone. The row
used to print the word "Medium", which spent a whole column on the value
that matters least.
"""

glob LEVEL: dict[str, int] = {"High": 3, "Medium": 2, "Low": 1};

def:pub PriorityIcon(priority: str = "Medium", size: int = 14) -> JsxElement {
    n = LEVEL.get(priority, 2);
    tone = "text-danger" if priority == "High" else "text-text-tertiary";
    return
        <svg
            className={"shrink-0 " + tone}
            width={size}
            height={size}
            viewBox="0 0 16 16"
            role="img"
            aria-label={priority + " priority"}
        >
            <rect x={2} y={9} width={3} height={5} rx={1} fill="currentColor" opacity={1}/>
            <rect
                x={6.5}
                y={6}
                width={3}
                height={8}
                rx={1}
                fill="currentColor"
                opacity={1 if n > 1 else 0.28}
            />
            <rect
                x={11}
                y={3}
                width={3}
                height={11}
                rx={1}
                fill="currentColor"
                opacity={1 if n > 2 else 0.28}
            />
        </svg>;
}
