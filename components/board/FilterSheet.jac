"""The phone's filters: every facet as a select in a bottom sheet."""

import from ..ui.button { Button }
import from ..ui.checkbox { Checkbox }
import from ..ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ..ui.sheet { Sheet, SheetContent, SheetHeader, SheetTitle }

def:pub FilterSheet(
    open: bool,
    facets: list[dict[str, any]],
    hideDone: bool,
    doneLabel: str,
    countLabel: str,
    anything: bool,
    onOpenChange: Callable[[bool], None],
    onHideDone: Callable[[], None],
    onClear: Callable[[], None]
) -> JsxElement {
    return
        <Sheet open={open} onOpenChange={onOpenChange}>
            <SheetContent
                side="bottom"
                className="max-h-[85dvh] gap-0 overflow-y-auto rounded-t-xl p-0"
            >
                <SheetHeader className="border-b px-4 py-3">
                    <SheetTitle className="text-base font-semibold">Filters</SheetTitle>
                </SheetHeader>
                <div className="grid gap-3 px-4 py-4">
                    {for f in facets {
                        <label key={f["label"]} className="grid gap-1.5">
                            <span className="text-[13px] font-semibold">
                                {f["label"]}
                            </span>
                            <Select value={f["value"]} onValueChange={f["onChange"]}>
                                <SelectTrigger
                                    className="h-11 w-full"
                                    aria-label={f["label"]}
                                >
                                    <SelectValue/>
                                </SelectTrigger>
                                <SelectContent>
                                    {for o in f["options"] {
                                        <SelectItem key={o[0]} value={o[0]}>
                                            {o[1]}
                                        </SelectItem>
                                    }}
                                </SelectContent>
                            </Select>
                        </label>
                    }}
                    <label className="flex min-h-11 items-center gap-2 text-[13px]">
                        <Checkbox
                            checked={not hideDone}
                            onCheckedChange={lambda { onHideDone(); }}
                        />
                        {doneLabel}
                    </label>
                </div>
                <div
                    className="flex items-center gap-2 border-t px-4 py-3 pb-[calc(0.75rem+env(safe-area-inset-bottom))]"
                >
                    <span className="num text-xs text-muted-foreground">
                        {countLabel}
                    </span>
                    {if anything {
                        <Button
                            key="clear"
                            variant="ghost"
                            className="ml-auto h-11"
                            onClick={lambda { onClear(); }}
                        >
                            Clear filters
                        </Button>
                    }}
                    <Button
                        className={"h-11" if anything else "ml-auto h-11"}
                        onClick={lambda { onOpenChange(False); }}
                    >
                        Show tasks
                    </Button>
                </div>
            </SheetContent>
        </Sheet>;
}
