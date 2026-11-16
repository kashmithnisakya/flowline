"""The custom provider's extra fields: an OpenAI-compatible https address and the
model name to call there."""

import from ..ui.input { Input }
import from ..ui.label { Label }

def:pub CustomFields(
    baseUrl: str,
    model: str,
    onBase: Callable[[str], None],
    onModel: Callable[[str], None]
) -> JsxElement {
    return
        <div className="grid gap-3 sm:grid-cols-2">
            <div className="grid gap-2">
                <Label htmlFor="prov-base">Base URL</Label>
                <Input
                    id="prov-base"
                    placeholder="https://llm.example.com/v1"
                    value={baseUrl}
                    onChange={lambda (e: ChangeEvent) { onBase(e.target.value); }}
                />
            </div>
            <div className="grid gap-2">
                <Label htmlFor="prov-model">Model name</Label>
                <Input
                    id="prov-model"
                    placeholder="my-model"
                    value={model}
                    onChange={lambda (e: ChangeEvent) { onModel(e.target.value); }}
                />
            </div>
        </div>;
}
