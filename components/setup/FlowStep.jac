"""Step 3: how work moves. The templates are a radio group; Draw my own leaves for
the flow line designer instead, writing nothing here."""

import from ...constants { FLOW_LINE_TEMPLATES }
import from ..ui.button { Button }
import from ..common.glyphs { Spinner }
import from .SetupParts { StepTitle, SaveError }
import from .TemplateCard { TemplateCard }

def:pub FlowStep(
    choice: str,
    keys: list[str],
    saveError: str,
    busy: bool,
    onPick: Callable[[str], None],
    onKey: Callable[[KeyboardEvent, int, list[str]], None],
    onSubmit: Callable[[FormEvent], any],
    onBack: Callable[[], None],
    onDraw: Callable[[], None]
) -> JsxElement {
    return
        <form onSubmit={onSubmit} noValidate={True} className="flex flex-col gap-5">
            <StepTitle
                title="How does work move?"
                sub="The board opens with a new task ready to type. You can change the steps at any time."
            />
            <div
                role="radiogroup"
                aria-label="How work moves"
                className="flex flex-col gap-3"
            >
                {for (i, t) in enumerate(FLOW_LINE_TEMPLATES) {
                    <TemplateCard
                        key={t["key"]}
                        template={t}
                        selected={choice == t["key"]}
                        onPick={lambda { onPick(t["key"]); }}
                        onKey={lambda (e: KeyboardEvent) { onKey(e, i, keys); }}
                    />
                }}
            </div>
            {if saveError {
                <SaveError key="err" message={saveError}/>
            }}
            <div className="flex flex-wrap items-center gap-2">
                <Button type="button" variant="ghost" onClick={lambda { onBack(); }}>
                    Back
                </Button>
                <Button
                    type="button"
                    variant="ghost"
                    disabled={busy}
                    className="ml-auto text-muted-foreground"
                    onClick={lambda { onDraw(); }}
                >
                    Draw my own
                </Button>
                <Button
                    type="submit"
                    disabled={busy}
                    className="h-10 px-4 font-semibold"
                >
                    {if busy {
                        <Spinner key="sp"/>
                    }}
                    Open the board
                </Button>
            </div>
        </form>;
}
