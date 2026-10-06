"""The first task titles on a step node at high zoom, under a rule, plus how
many more sit there. Rows are geometry's RULE_H and ROW_LH tall."""

def:pub NodeTitles(titles: list[str], more: int = 0) -> JsxElement {
    return
        <span className="mt-1 flex min-w-0 flex-col border-t pt-1">
            {for tt in titles {
                <span key={tt} className="truncate text-xs leading-[17px]">{tt}</span>
            }}
            {if more > 0 {
                <span key="more" className="text-xs leading-[17px] text-subtle">
                    {str(more) + " more"}
                </span>
            }}
        </span>;
}
