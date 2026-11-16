"""The default model for new agents and the daily token budget every agent run
counts against. The budget protects the workspace's own provider bill."""

import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.label { Label }

def:pub LimitsCard(
    models: list[list[str]],
    defaultModel: str,
    dailyTokens: int,
    tokensToday: int,
    busy: bool,
    onSave: Callable[[str, int], None]
) -> JsxElement {
    has model: str = defaultModel,
        budget: str = str(dailyTokens);
    return
        <section
            className="surface flex flex-col gap-3 p-4"
            aria-label="Defaults and limits"
        >
            <h3 className="text-sm font-semibold">Defaults and limits</h3>
            <div className="grid gap-3 sm:grid-cols-2">
                <div className="grid gap-2">
                    <Label htmlFor="lim-model">Default model for new agents</Label>
                    <select
                        id="lim-model"
                        className="h-8 rounded-sm border bg-card px-2 text-[13px]"
                        value={model}
                        onChange={lambda (e: ChangeEvent) { model = e.target.value; }}
                    >
                        <option value="">None</option>
                        {for m in models {
                            <option key={m[0]} value={m[0]}>{m[1]}</option>
                        }}
                    </select>
                </div>
                <div className="grid gap-2">
                    <Label htmlFor="lim-budget">Daily token budget</Label>
                    <Input
                        id="lim-budget"
                        type="number"
                        value={budget}
                        onChange={lambda (e: ChangeEvent) { budget = e.target.value; }}
                    />
                    <p className="num meta">
                        {str(tokensToday)
                            + " used today. Runs stop for the day at the budget."}
                    </p>
                </div>
            </div>
            <div>
                <Button
                    variant="outline"
                    disabled={busy}
                    onClick={lambda { onSave(model, int(budget)); }}
                >
                    Save limits
                </Button>
            </div>
        </section>;
}
