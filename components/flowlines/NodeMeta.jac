"""A step node's second row (geometry META_LH, 18px): the blurb in muted
text, then the owner role, which the lane view leaves out (the lane says it)."""

def:pub NodeMeta(blurb: str, owner: str = "") -> JsxElement {
    who = owner.strip() if owner else "";
    return
        <span className="mt-0.5 flex min-w-0 items-center gap-2 text-xs leading-[18px]">
            <span className="min-w-0 flex-1 truncate text-muted-foreground">
                {blurb}
            </span>
            {if who {
                <span key="owner" className="min-w-0 truncate text-subtle">
                    {"Anyone" if who == "anyone" else who}
                </span>
            }}
        </span>;
}
