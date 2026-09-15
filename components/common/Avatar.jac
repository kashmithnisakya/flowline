"""Initials avatars. The fill is a hash of the name, so the same person (or
project) gets the same colour on every page; all eight fills carry white
initials at 4.5:1 or better in both themes. A manager-picked colour key maps
onto the same set. Class strings are whole literals for Tailwind's scanner.
"""

glob HUES: list[str] = [
         "bg-[#2E6C97] text-white",
         "bg-[#5550AC] text-white",
         "bg-[#8A5A00] text-white",
         "bg-[#A34B83] text-white",
         "bg-[#387A51] text-white",
         "bg-[#4F5753] text-white",
         "bg-[#B3261E] text-white",
         "bg-[#245A80] text-white"
     ],
     KEY_HUE: dict[str, str] = {
         "sky": "bg-[#2E6C97] text-white",
         "indigo": "bg-[#5550AC] text-white",
         "amber": "bg-[#8A5A00] text-white",
         "rose": "bg-[#A34B83] text-white",
         "emerald": "bg-[#387A51] text-white",
         "slate": "bg-[#4F5753] text-white"
     },
     DOTS: list[str] = [
         "bg-chart-1",
         "bg-chart-2",
         "bg-chart-3",
         "bg-chart-4",
         "bg-chart-5"
     ],
     # Initials never drop below 12px, so the two small sizes share 24px.
     SIZES: dict[str, str] = {
         "xs": "h-6 w-6 text-xs",
         "sm": "h-6 w-6 text-xs",
         "md": "h-8 w-8 text-xs"
     };

def hashOf(name: str, buckets: int) -> int {
    total = 0;
    for ch in name {
        total = total + ord(ch);
    }
    return total % buckets;
}

# Solid fill plus white initials. A manager-picked colour key wins (unknown
# keys read as slate); empty falls back to the fill hashed from the name.
def:pub hueFor(name: str, color: str = "") -> str {
    if color {
        return KEY_HUE[color] if color in KEY_HUE else KEY_HUE["slate"];
    }
    return HUES[hashOf(name, 8)];
}

# Solid fill, for a small identity dot next to a name.
def:pub dotFor(name: str) -> str {
    return DOTS[hashOf(name, 5)];
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

def:pub Avatar(
    name: str, size: str = "sm", className: str = "", color: str = ""
) -> JsxElement {
    return
        <span
            className={"inline-flex shrink-0 select-none items-center justify-center rounded-full font-semibold leading-none tracking-normal "
                + SIZES.get(size, SIZES["sm"])
                + " "
                + hueFor(name, color)
                + ((" " + className) if className else "")}
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
            className="inline-flex shrink-0 items-center -space-x-0.5"
            title={", ".join(names)}
        >
            {for (i, n) in enumerate(shown) {
                <Avatar key={str(i)} name={n} size={size} className="ring-2 ring-card"/>
            }}
            {if extra > 0 {
                <span
                    key="more"
                    className={"inline-flex shrink-0 items-center justify-center rounded-full bg-muted font-mono font-medium text-muted-foreground ring-2 ring-card "
                        + SIZES.get(size, SIZES["xs"])}
                >
                    {"+" + str(extra)}
                </span>
            }}
        </span>;
}
