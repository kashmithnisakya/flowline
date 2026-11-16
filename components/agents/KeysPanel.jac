"""The Models and keys tab: the workspace's own provider accounts. Agents run
on these keys and the provider bills the workspace, never Flowline."""

import from ...models { AiKeys }
import from ...services.agents.keys {
    ListAiKeys,
    SaveProviderKey,
    RemoveProviderKey,
    TestProvider,
    SaveAiLimits
}
import from ...lib.workspace { forgetWorkspace }
import from ..ui.skeleton { Skeleton }
import from .ProviderCard { ProviderCard }
import from .LimitsCard { LimitsCard }
import from "sonner" { toast }

def:pub KeysPanel -> JsxElement {
    has view: AiKeys | None = None,
        busy: bool = False;

    can with entry {
        load();
    }

    async def load -> None;
    async def saveKey(provider: str, key: str, base: str, model: str) -> None;
    async def probe(provider: str) -> None;
    async def remove(provider: str) -> None;
    async def saveLimits(model: str, tokens: int) -> None;

    if view is None {
        return <Skeleton className="h-64 w-full"/>;
    }
    return
        <div className="flex max-w-[860px] flex-col gap-3">
            <p className="text-sm text-muted-foreground">
                Agents use your own provider account. Flowline never runs them on its key, and your provider bills you directly. A key is sealed before it is stored and is never shown again.
            </p>
            {if not view.secrets_ready {
                <p
                    key="nosecrets"
                    className="rounded-md border border-dashed border-ai bg-ai-wash p-3 text-sm"
                >
                    This server cannot store keys yet. Ask whoever runs it to set FLOWLINE_SECRETS_KEY.
                </p>
            }}
            {for p in view.providers {
                <ProviderCard
                    key={p.key + p.key_last}
                    provider={p}
                    secretsReady={view.secrets_ready}
                    busy={busy}
                    onSave={saveKey}
                    onTest={probe}
                    onRemove={remove}
                />
            }}
            <LimitsCard
                key={view.default_model + str(view.daily_tokens)}
                models={view.models}
                defaultModel={view.default_model}
                dailyTokens={view.daily_tokens}
                tokensToday={view.tokens_today}
                busy={busy}
                onSave={saveLimits}
            />
        </div>;
}
