"""Create a GitHub issue from the task, under the Issue row: the repo to use when
the project tracks several, and the button."""

import from ....models { RepoView }
import from ...ui.button { Button }
import from ...ui.select {
    Select,
    SelectTrigger,
    SelectValue,
    SelectContent,
    SelectItem
}
import from ...common.glyphs { Spinner }
import from .PropRow { PropRow }

def:pub IssueMaker(
    repos: list[RepoView],
    choice: str,
    chosen: str,
    busy: bool,
    disabled: bool,
    onChoice: Callable[[str], None],
    onCreate: Callable[[], None]
) -> JsxElement {
    return
        <PropRow label="">
            <div className="grid gap-1.5 px-2 pb-1">
                {if len(repos) > 1 {
                    <Select key="repopick" value={choice} onValueChange={onChoice}>
                        <SelectTrigger className="h-8 w-full">
                            <SelectValue placeholder="Pick a repo"/>
                        </SelectTrigger>
                        <SelectContent>
                            {for r in repos {
                                <SelectItem key={r.id} value={r.id}>
                                    {r.full_name}
                                </SelectItem>
                            }}
                        </SelectContent>
                    </Select>
                }}
                <div className="flex flex-wrap items-center gap-2">
                    <Button
                        variant="outline"
                        size="sm"
                        disabled={disabled or not chosen}
                        onClick={lambda { onCreate(); }}
                    >
                        {if busy {
                            <Spinner key="sp"/>
                        }}
                        {"Opening issue…" if busy else "Create GitHub issue"}
                    </Button>
                    <span className="text-xs text-muted-foreground">
                        From the title and notes, then linked.
                    </span>
                </div>
            </div>
        </PropRow>;
}
