"""AI reviews: one task's newest run in the sheet, with the earlier ones a click
away. Polls while a run is queued or running, and calls `onSettled` when the last
open run settles, so the page can refresh the row's chip. Nothing with no runs."""

import from ...models { AgentRunView }
import from ...constants { AI_RESPONSIBILITIES }
import from ...services.agents.agents { ListRuns, RetryRun, CancelRun }
import from .AgentRunRow { AgentRunRow }

glob POLL_RUNS_MS: int = 5000;

def runName(key: str) -> str {
    for known in AI_RESPONSIBILITIES {
        if known["key"] == key {
            return known["name"];
        }
    }
    return key;
}

def anyOpen(list_: list[AgentRunView]) -> bool {
    for r in list_ {
        if r.status == "queued" or r.status == "running" {
            return True;
        }
    }
    return False;
}

def:pub AgentRuns(
    taskId: str, refreshKey: str = "", onSettled: Callable[[], None] = None
) -> JsxElement {
    has runs: list[AgentRunView] = [],
        tick: int = 0,
        busy: bool = False,
        wasOpen: bool = False,
        showAll: bool = False;

    async can with (taskId, refreshKey, tick) entry {
        got: list[AgentRunView] = [];
        try {
            result = root spawn ListRuns(task_id=taskId);
            got = result.reports[0] if result.reports else [];
        } except Exception as e {
            got = runs;
        }
        runs = got;
        live = anyOpen(got);
        if wasOpen and not live and onSettled {
            onSettled();
        }
        wasOpen = live;
    }

    can with (runs) entry {
        timer: any = 0;
        if anyOpen(runs) {
            timer = window.setTimeout(lambda { tick = tick + 1; }, POLL_RUNS_MS);
        }
        return lambda { if timer { window.clearTimeout(timer); }};
    }

    async def act(runId: str, retry: bool) {
        busy = True;
        sent = True;
        try {
            if retry {
                root spawn RetryRun(run_id=runId);
            } else {
                root spawn CancelRun(run_id=runId);
            }
        } except Exception as e {
            sent = False;
        }
        busy = False;
        # Either way the run moved off or onto the queue: settle the chip later.
        if sent {
            wasOpen = True;
        }
        tick = tick + 1;
    }

    shown = runs if showAll else runs[:1];
    return
        <section className="grid gap-2" hidden={len(runs) == 0} aria-label="AI reviews">
            <ul className="grid gap-2">
                {for run in shown {
                    <AgentRunRow
                        key={run.id}
                        run={run}
                        name={runName(run.key)}
                        busy={busy}
                        onRetry={lambda (id: str) { act(id, True); }}
                        onCancel={lambda (id: str) { act(id, False); }}
                    />
                }}
            </ul>
            {if len(runs) > 1 {
                <button
                    key="more"
                    type="button"
                    className="justify-self-start text-[12.5px] text-text-secondary underline underline-offset-2 hover:text-text-primary"
                    onClick={lambda { showAll = not showAll; }}
                >
                    {"Show only the latest"
                        if showAll
                        else "Show " + str(len(runs) - 1) + " earlier"}
                </button>
            }}
        </section>;
}
