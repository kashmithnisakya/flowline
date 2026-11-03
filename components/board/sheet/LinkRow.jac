"""A property row holding a GitHub link: a paste field, the state it reports and
a way to open it in a new tab."""

import from ...ui.input { Input }
import from .PropRow { PropRow, GHOST_INPUT }

def OpenLink(url: str) -> JsxElement {
    return
        <a
            href={url}
            target="_blank"
            rel="noopener"
            title="Open in a new tab"
            aria-label="Open the link in a new tab"
            className="inline-flex size-8 shrink-0 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-foreground"
        >
            <svg
                width={14}
                height={14}
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth={2}
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
            >
                <path d="M15 3h6v6"/>
                <path d="M10 14 21 3"/>
                <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
            </svg>
        </a>;
}

def:pub LinkRow(
    label: str,
    aria: str,
    placeholder: str,
    value: str,
    onChange: Callable[[str], None],
    state: str = ""
) -> JsxElement {
    return
        <PropRow label={label}>
            <div className="flex items-center">
                <Input
                    aria-label={aria}
                    className={GHOST_INPUT + " min-w-0 flex-1 num text-xs md:text-xs"}
                    placeholder={placeholder}
                    value={value}
                    onChange={lambda (e: ChangeEvent) { onChange(e.target.value); }}
                />
                {if state {
                    <span
                        key="state"
                        className="shrink-0 px-1 text-xs text-muted-foreground"
                        title={label + " " + state}
                    >
                        {state}
                    </span>
                }}
                {if value.strip() {
                    <OpenLink key="open" url={value.strip()}/>
                }}
            </div>
        </PropRow>;
}
