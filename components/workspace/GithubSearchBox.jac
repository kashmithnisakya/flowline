"""The list's search box. A search commits only on Enter (GitHub's search API
allows about 30 requests a minute), so the box shows a key hint while the draft
is ahead of the committed query.
"""

import from ...components.ui.input { Input }
import from .icons { IconSearch, IconX }

def:pub GithubSearchBox(
    label: str,
    draft: str,
    committed: str,
    onDraft: Callable[[str], None],
    onRun: Callable[[], None],
    onClear: Callable[[], None]
) -> JsxElement {
    return
        <div className="relative ml-auto w-full sm:w-56">
            <IconSearch
                className="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-subtle"
            />
            <Input
                value={draft}
                className={"h-8 pl-8 " + ("pr-14" if draft != committed else "pr-8")}
                placeholder={label}
                aria-label={label}
                onChange={lambda (e: ChangeEvent) { onDraft(e.target.value); }}
                onKeyDown={lambda (e: KeyboardEvent) { if e.key == "Enter" {
                    onRun();
                }}}
            />
            {if draft != committed {
                <span
                    key="enter"
                    aria-hidden="true"
                    className="kbd pointer-events-none absolute top-1/2 right-8 -translate-y-1/2"
                >
                    ↵
                </span>
            }}
            {if committed or draft {
                <button
                    key="clear"
                    type="button"
                    aria-label="Clear search"
                    className="absolute top-1/2 right-2 -translate-y-1/2 rounded-sm p-1 text-subtle transition-colors duration-150 hover:bg-accent hover:text-foreground"
                    onClick={lambda { onClear(); }}
                >
                    <IconX/>
                </button>
            }}
        </div>;
}
