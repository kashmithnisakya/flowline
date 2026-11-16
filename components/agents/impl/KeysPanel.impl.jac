"""Implementations for the Models and keys tab."""

impl KeysPanel.load -> None {
    try {
        result = root spawn ListAiKeys();
        view = result.reports[0] if result.reports else None;
    } except Exception as e {
        toast.error("Could not load the model keys");
    }
}

# Run one write, then reload. `refused` is the reason to show when it fails.
impl KeysPanel.saveKey(provider: str, key: str, base: str, model: str) -> None {
    busy = True;
    try {
        result = root spawn SaveProviderKey(
            provider=provider, api_key=key, base_url=base, custom_model=model
        );
        answer: any = result.reports[0] if result.reports else None;
        if answer and answer["ok"] {
            toast.success("Key saved. It will not be shown again.");
        } else {
            toast.error(answer["message"] if answer else "Could not save that key");
        }
        await load();
    } except Exception as e {
        toast.error("Could not save that key");
    }
    busy = False;
}

impl KeysPanel.probe(provider: str) -> None {
    busy = True;
    try {
        result = root spawn TestProvider(provider=provider);
        answer: any = result.reports[0] if result.reports else None;
        if answer and answer["ok"] {
            toast.success("The provider answered");
        } else {
            toast.error(
                answer["message"] if answer else "Could not reach the provider"
            );
        }
        await load();
    } except Exception as e {
        toast.error("Could not test that key");
    }
    busy = False;
}

impl KeysPanel.remove(provider: str) -> None {
    busy = True;
    try {
        root spawn RemoveProviderKey(provider=provider);
        forgetWorkspace();
        toast.success("Key removed. Agents using it are off.");
        await load();
    } except Exception as e {
        toast.error("Could not remove that key");
    }
    busy = False;
}

impl KeysPanel.saveLimits(model: str, tokens: int) -> None {
    busy = True;
    try {
        result = root spawn SaveAiLimits(default_model=model, daily_tokens=tokens);
        answer: any = result.reports[0] if result.reports else None;
        if answer and answer["ok"] {
            toast.success("Saved");
        } else {
            toast.error(answer["message"] if answer else "Could not save the limits");
        }
        await load();
    } except Exception as e {
        toast.error("Could not save the limits");
    }
    busy = False;
}
