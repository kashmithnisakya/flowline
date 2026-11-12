"""The add buttons under a role: one per catalogue entry it does not hold."""

import from ...ui.button { Button }
import from ..icons { IconPlus }

def:pub AddResponsibility(
    entries: list[dict[str, any]], onAdd: Callable[[str], None]
) -> JsxElement {
    return
        <div className="flex flex-wrap gap-1.5">
            {for c in entries {
                <Button
                    key={c["key"]}
                    size="sm"
                    variant="ghost"
                    className="h-7 px-2 text-[12.5px] text-muted-foreground"
                    onClick={lambda { onAdd(c["key"]); }}
                >
                    <IconPlus/>
                    {"AI " + c["name"].lower()}
                </Button>
            }}
        </div>;
}
