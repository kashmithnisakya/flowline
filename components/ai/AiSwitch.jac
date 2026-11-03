"""The switch for the workspace's AI responsibilities: turning it on asks first
(ConsentDialog says what will be sent), turning it off is immediate and keeps every
setting. The page owns the settings and reloads them through `onChanged`."""

import from ...services.agents.agents { SetAiEnabled }
import from ...lib.dates { prettyDay }
import from ..ui.switch { Switch }
import from ..ui.skeleton { Skeleton }
import from .ConsentDialog { ConsentDialog }
import from "sonner" { toast }

def:pub AiSwitch(
    enabled: bool, enabledAt: str, loading: bool, onChanged: Callable[[], any]
) -> JsxElement {
    has saving: bool = False,
        asking: bool = False;

    async def flip(wanted: bool) -> None {
        if saving {
            return;
        }
        saving = True;
        try {
            result = root spawn SetAiEnabled(enabled=wanted);
            answer: any = result.reports[0] if result.reports else None;
            if answer and answer["ok"] {
                asking = False;
                await onChanged();
                toast.success(
                    "AI responsibilities turned on"
                        if wanted
                        else "AI responsibilities paused. Every setting is kept."
                );
            } else {
                toast.error("Could not change the AI setting");
            }
        } except Exception as e {
            toast.error("Could not change the AI setting");
        }
        saving = False;
    }

    status = ("On since " + prettyDay(enabledAt[:10]))
        if enabled and enabledAt
        else ("On" if enabled else "Off");
    if loading {
        return <Skeleton className="h-5 w-32"/>;
    }
    return
        <div className="flex items-center gap-2.5">
            <span className="text-[12.5px] text-text-tertiary">{status}</span>
            <Switch
                aria-label="AI responsibilities"
                checked={enabled}
                disabled={saving}
                onCheckedChange={lambda (v: bool) { if v {
                    asking = True;
                } else {
                    flip(False);
                } }}
            />
            <ConsentDialog
                open={asking}
                saving={saving}
                onOpenChange={lambda (o: bool) { asking = o; }}
                onConfirm={lambda { flip(True); }}
            />
        </div>;
}
