"""The API key field and its save button. The key is held here while it is
typed and cleared the moment it is sent; it is never shown again."""

import from ..ui.button { Button }
import from ..ui.input { Input }
import from ..ui.label { Label }
import from ..common.glyphs { Spinner }

def:pub KeyField(
    provider: str, secretsReady: bool, busy: bool, onSave: Callable[[str], None]
) -> JsxElement {
    has apiKey: str = "";
    return
        <div className="flex flex-wrap items-end gap-2">
            <div className="grid min-w-[220px] flex-1 gap-2">
                <Label htmlFor={"key-" + provider}>API key</Label>
                <Input
                    id={"key-" + provider}
                    type="password"
                    autoComplete="off"
                    disabled={not secretsReady}
                    placeholder="Paste your key"
                    value={apiKey}
                    onChange={lambda (e: ChangeEvent) { apiKey = e.target.value; }}
                />
            </div>
            <Button
                disabled={busy or not secretsReady or apiKey == ""}
                onClick={lambda {
                    onSave(apiKey);
                    apiKey = "";
                }}
            >
                {if busy {
                    <Spinner key="sp"/>
                }}
                Save key
            </Button>
        </div>;
}
