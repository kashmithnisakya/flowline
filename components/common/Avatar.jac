"""Initials avatars. The hue is a hash of the name, so the same person (or
project) gets the same color on every page. Light keeps the initials in ink
(the pale chart tints cannot carry 8px text); dark lets them take the hue.
Class strings are whole literals so Tailwind's scanner keeps them.
"""

glob HUES: list[str] = [
         "bg-chart-1/25 text-foreground/85 dark:bg-chart-1/15 dark:text-chart-1",
         "bg-chart-2/25 text-foreground/85 dark:bg-chart-2/15 dark:text-chart-2",
         "bg-chart-3/25 text-foreground/85 dark:bg-chart-3/15 dark:text-chart-3",
         "bg-chart-4/25 text-foreground/85 dark:bg-chart-4/15 dark:text-chart-4",
         "bg-chart-5/25 text-foreground/85 dark:bg-chart-5/15 dark:text-chart-5"
     ],
     DOTS: list[str] = [
         "bg-chart-1",
         "bg-chart-2",
         "bg-chart-3",
         "bg-chart-4",
         "bg-chart-5"
     ],
     SIZES: dict[str, str] = {
         "xs": "h-5 w-5 text-[8px]",
         "sm": "h-6 w-6 text-[10px]",
         "md": "h-8 w-8 text-xs"
     };

def hashOf(name: str) -> int {
    total = 0;
    for ch in name {
        total = total + ord(ch);
    }
    return total % 5;
}

# Soft fill plus matching text, for an avatar circle.
def:pub hueFor(name: str) -> str {
    return HUES[hashOf(name)];
}

# Solid fill, for a small identity dot next to a name.
def:pub dotFor(name: str) -> str {
    return DOTS[hashOf(name)];
}

# "Amara Perera" -> "AP", "Priya" -> "P".
def:pub initials(name: str) -> str {
    parts = [
        p
        for p in name.split()
        if p
    ];
    if len(parts) == 0 {
        return "?";
    }
    last = parts[1][:1] if len(parts) > 1 else "";
    return (parts[0][:1] + last).upper();
}

def:pub Avatar(name: str, size: str = "sm", className: str = "") -> JsxElement {
    return
        <span
            className={"inline-flex shrink-0 select-none items-center justify-center rounded-full font-bold " + SIZES.get(
                size, SIZES["sm"]
            ) + " " + hueFor(name) + ((" " + className) if className else "")}
            title={name}
            aria-label={name}
            role="img"
        >
            {initials(name)}
        </span>;
}

# Overlapping avatars with a "+n" tail; the full name list lives in the title.
def:pub AvatarStack(names: list[str], max: int = 3, size: str = "xs") -> JsxElement {
    shown = names[:max];
    extra = len(names) - len(shown);
    return
        <span
            className="inline-flex shrink-0 items-center -space-x-1"
            title={", ".join(names)}
        >
            {for (i, n) in enumerate(shown) {
                <Avatar key={str(i)} name={n} size={size} className="ring-1 ring-card"/>
            }}
            {if extra > 0 {
                <span
                    key="more"
                    className={"inline-flex shrink-0 items-center justify-center rounded-full bg-muted font-semibold text-muted-foreground ring-1 ring-card " + SIZES.get(
                        size, SIZES["xs"]
                    )}
                >
                    {"+" + str(extra)}
                </span>
            }}
        </span>;
}
