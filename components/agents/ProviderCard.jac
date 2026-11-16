"""One model provider's account: its status, a field for the key (never shown
again once saved, only its last four characters) and test and remove. The custom
provider also takes an OpenAI-compatible https address and a model name."""

import from ...models { ProviderView }
import from ..ui.button { Button }
import from .CustomFields { CustomFields }
import from .KeyField { KeyField }

def:pub ProviderCard(
    provider: ProviderView,
    secretsReady: bool,
    busy: bool,
    onSave: Callable[[str, str, str, str], None],
    onTest: Callable[[str], None],
    onRemove: Callable[[str], None]
) -> JsxElement {
    has baseUrl: str = provider.base_url,
        customModel: str = provider.custom_model;
    custom = provider.key == "custom";
    saved = provider.key_last != "";
    return
        <section className="surface flex flex-col gap-3 p-4" aria-label={provider.name}>
            <div className="flex flex-wrap items-center gap-2">
                <h3 className="text-sm font-semibold">{provider.name}</h3>
                <span
                    className={"ai-chip "
                        + ("ai-chip-settled" if provider.connected else "")}
                >
                    {"Connected"
                        if provider.connected
                        else ("Needs setup" if saved else "No key")}
                </span>
                {if provider.tested_at {
                    <span key="tested" className="meta">Last test passed</span>
                }}
                <div className="ml-auto flex gap-2">
                    {if saved {
                        <Button
                            key="test"
                            variant="outline"
                            size="sm"
                            disabled={busy}
                            onClick={lambda { onTest(provider.key); }}
                        >
                            Test connection
                        </Button>
                    }}
                    {if saved {
                        <Button
                            key="rm"
                            variant="ghost"
                            size="sm"
                            className="text-destructive"
                            disabled={busy}
                            onClick={lambda { onRemove(provider.key); }}
                        >
                            Remove key
                        </Button>
                    }}
                </div>
            </div>
            {if custom {
                <CustomFields
                    key="custom"
                    baseUrl={baseUrl}
                    model={customModel}
                    onBase={lambda (v: str) { baseUrl = v; }}
                    onModel={lambda (v: str) { customModel = v; }}
                />
            }}
            {if saved {
                <p key="last" className="num text-[13px] text-muted-foreground">
                    {"Key ending in "
                        + provider.key_last
                        + ". Paste a new one below to replace it."}
                </p>
            }}
            <KeyField
                provider={provider.key}
                secretsReady={secretsReady}
                busy={busy}
                onSave={lambda (k: str) { onSave(
                    provider.key, k, baseUrl, customModel
                ); }}
            />
        </section>;
}
