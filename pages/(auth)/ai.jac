"""flowline - AI page (/ai): everything AI in one place. The switch, the
workspace's runs, each role's responsibilities and what is sent. It polls while a
run is open. Stateful shell: data here, the parts under components/ai."""

import from ...models {
    AgentRunLine,
    AiSettings,
    ResponsibilityView,
    RoleView,
    StepView
}
import from ...services.agents.agents {
    ListResponsibilities,
    ListAgentRuns,
    RetryRun,
    CancelRun
}
import from ...lib.workspace { loadWorkspace, forgetWorkspace }
import from ...components.ai.AiSwitch { AiSwitch }
import from ...components.ai.RunList { RunList }
import from ...components.ai.RolePanel { RolePanel }
import from ...components.ai.WhatIsSent { WhatIsSent }
import from ...components.ai.AiStatus { AiStatus }
import from ...components.common.LoadFailed { LoadFailed }
import from "sonner" { toast }

glob POLL_MS: int = 5000;

def anyLive(rows: list[AgentRunLine]) -> bool {
    for r in rows {
        if r.status == "queued" or r.status == "running" {
            return True;
        }
    }
    return False;
}

def:pub AiPage -> JsxPage {
    has enabled: bool = False,
        enabledAt: str = "",
        items: list[ResponsibilityView] = [],
        roles: list[RoleView] = [],
        steps: list[StepView] = [],
        rows: list[AgentRunLine] = [],
        hasMore: bool = False,
        page: int = 1,
        attention: bool = False,
        runsToday: int = 0,
        dailyLimit: int = 0,
        loading: bool = True,
        failed: bool = False,
        acting: bool = False,
        tick: int = 0;

    can with entry {
        loadAll();
    }

    # Refetch the pages on screen while a run is open, so a row settles itself.
    can with (rows, tick) entry {
        timer: any = 0;
        if anyLive(rows) {
            timer = window.setTimeout(lambda { refreshRuns(); }, POLL_MS);
        }
        return lambda { if timer { window.clearTimeout(timer); }};
    }

    async def loadAll -> None;
    async def reloadSettings -> None;
    async def refreshRuns -> None;
    async def showMore -> None;
    async def fetchRuns(wanted: bool, upTo: int) -> None;
    async def act(runId: str, retry: bool) -> None;
    async def pickFilter(wanted: bool) -> None;
    async def loadShared -> None;
    async def loadSettings -> None;

    if failed and len(rows) == 0 and len(items) == 0 {
        return
            <LoadFailed
                title="Could not load AI"
                onRetry={loadAll}
                retrying={loading}
            />;
    }
    return
        <div className="flex min-w-0 flex-col gap-4">
            <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
                <h1 className="page-title">AI</h1>
                {if dailyLimit > 0 {
                    <span key="used" className="num text-[12.5px] text-text-tertiary">
                        {str(runsToday) + " of " + str(dailyLimit) + " runs used today"}
                    </span>
                }}
                <div className="ml-auto">
                    <AiSwitch
                        enabled={enabled}
                        enabledAt={enabledAt}
                        loading={loading}
                        onChanged={reloadSettings}
                    />
                </div>
            </div>
            <div className="flex flex-wrap items-start gap-4">
                <div className="min-w-0 flex-[3_1_560px]">
                    <RunList
                        rows={rows}
                        attention={attention}
                        hasMore={hasMore}
                        loading={loading}
                        busy={acting}
                        aiEnabled={enabled}
                        onFilter={pickFilter}
                        onMore={showMore}
                        onRetry={lambda (id: str) { act(id, True); }}
                        onCancel={lambda (id: str) { act(id, False); }}
                    />
                </div>
                <div className="flex min-w-0 flex-[2_1_340px] flex-col gap-4">
                    <RolePanel
                        roles={roles}
                        steps={steps}
                        items={items}
                        aiEnabled={enabled}
                        onChanged={reloadSettings}
                    />
                    <section
                        className="surface bg-bg-elevated"
                        aria-label="What is sent"
                    >
                        <div className="flex min-h-11 items-center border-b px-4">
                            <h2 className="text-sm font-semibold">What is sent</h2>
                        </div>
                        <div className="px-4 py-3">
                            <WhatIsSent/>
                        </div>
                    </section>
                    <AiStatus/>
                </div>
            </div>
        </div>;
}

impl AiPage.loadAll -> None {
    loading = True;
    failed = False;
    w: any = window;
    await w.Promise.all([loadShared(), loadSettings(), fetchRuns(attention, 1)]);
    loading = False;
}

impl AiPage.loadShared -> None {
    shared = await loadWorkspace();
    roles = shared["roles"];
    steps = shared["steps"];
    if not shared["ok"] {
        failed = True;
    }
}

impl AiPage.loadSettings -> None {
    try {
        result = root spawn ListResponsibilities();
        settings: any = result.reports[0] if result.reports else None;
        if settings {
            enabled = settings.enabled;
            enabledAt = settings.enabled_at;
            items = settings.responsibilities;
        }
    } except Exception as e {
        failed = True;
    }
}

impl AiPage.reloadSettings -> None {
    forgetWorkspace();
    await loadSettings();
    if failed {
        toast.error("Could not reload the AI settings");
    }
}

# Every page on screen again, in one read, so a poll keeps what was paged in.
impl AiPage.fetchRuns(wanted: bool, upTo: int) -> None {
    try {
        result = root spawn ListAgentRuns(
            attention=wanted, page=1, page_size=30 * upTo
        );
        answer: any = result.reports[0] if result.reports else None;
        if answer and wanted == attention {
            rows = answer.rows;
            hasMore = answer.has_more;
            runsToday = answer.runs_today;
            dailyLimit = answer.daily_limit;
            page = upTo;
        }
    } except Exception as e {
        failed = True;
    }
}

impl AiPage.refreshRuns -> None {
    await fetchRuns(attention, page);
    tick = tick + 1;
}

impl AiPage.showMore -> None {
    await fetchRuns(attention, page + 1);
}

impl AiPage.pickFilter(wanted: bool) -> None {
    if wanted == attention {
        return;
    }
    attention = wanted;
    rows = [];
    loading = True;
    await fetchRuns(wanted, 1);
    loading = False;
}

impl AiPage.act(runId: str, retry: bool) -> None {
    acting = True;
    try {
        result = (root spawn RetryRun(run_id=runId))
            if retry
            else (root spawn CancelRun(run_id=runId));
        answer: any = result.reports[0] if result.reports else None;
        if answer and not answer["ok"] {
            toast.error(answer["message"]);
        }
        forgetWorkspace();
        await fetchRuns(attention, page);
    } except Exception as e {
        toast.error("Could not change that run");
    }
    acting = False;
}
