"""Prometheus metrics for AI runs. The app's /metrics merges every worker's
metric files when it serves more than one worker (every deployed pod does),
so these appear there; a single-worker server exposes Jac's own only."""

import logging;
import from prometheus_client { Counter, Histogram }

glob RUNS: any = Counter(
         "flowline_ai_runs",
         "AI responsibility runs settled, by outcome.",
         ["key", "outcome"]
     ),
     SECONDS: any = Histogram(
         "flowline_ai_run_seconds",
         "Time the review service took for one run.",
         ["key"],
         buckets=[1, 5, 15, 30, 60, 120, 300]
     ),
     TOKENS: any = Counter(
         "flowline_ai_tokens", "Model tokens used by AI runs.", ["direction"]
     ),
     COST: any = Counter(
         "flowline_ai_cost_usd", "Model cost of AI runs, by workspace.", ["workspace"]
     ),
     log: logging.Logger = logging.getLogger("flowline.agents");

# Count one settled attempt. A metrics failure never touches the run.
def note_run(
    key: str,
    outcome: str,
    ms: int,
    workspace: str,
    tokens_in: int,
    tokens_out: int,
    cost: float
) {
    try {
        RUNS.labels(key=key, outcome=outcome).inc();
        SECONDS.labels(key=key).observe(ms / 1000.0);
        if tokens_in {
            TOKENS.labels(direction="in").inc(tokens_in);
        }
        if tokens_out {
            TOKENS.labels(direction="out").inc(tokens_out);
        }
        if cost > 0 {
            COST.labels(workspace=workspace).inc(cost);
        }
    } except Exception as e {
        log.warning("ai metrics: " + str(e));
    }
}
