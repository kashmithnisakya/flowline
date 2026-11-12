"""The chips under the task sheet's properties: one per field that is empty and
hidden, each revealing its row. A field with a value always shows its row."""

def:pub AddFields(
    labels: list[list[str]], onReveal: Callable[[str], None]
) -> JsxElement {
    if len(labels) == 0 {
        return <span hidden={True}/>;
    }
    return
        <div className="flex flex-wrap gap-1.5">
            {for f in labels {
                <button
                    key={f[0]}
                    type="button"
                    onClick={lambda { onReveal(f[0]); }}
                    className="inline-flex h-[26px] items-center rounded-md border border-dashed border-border-strong px-2 text-[12.5px] text-text-secondary transition-colors hover:bg-bg-hover hover:text-text-primary"
                >
                    {f[1]}
                </button>
            }}
        </div>;
}
