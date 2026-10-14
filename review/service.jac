"""The PR review service: its own app, so `jac scale deploy` gives it its own
pod. The main app hands it a run through the outbox (an un-awaited spawn); it
runs as the service identity, never inside a workspace's graph, and leaves
its result in the shared docs store for the workspace's own session to apply.
Calls from the web app carry JAC_BRIDGE_TOKEN, read when the pod starts.
"""

import json;
import time;
import from jaclang.server.shared_store { shared_store }

glob RESULTS: str = "agent_results";

walker:protect ReviewPR {
    """Spike: record that the run reached this service, keyed by run id."""
    has run_id: str = "",
        root_jid: str = "",
        note: str = "";

    can run with Root entry {
        doc = {
            "run_id": self.run_id,
            "root_jid": self.root_jid,
            "note": self.note,
            "ok": True,
            "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        };
        db = shared_store();
        if db is not None {
            db.rows(
                "INSERT INTO jac_docs (collection, id, doc) "
                    + "VALUES (:c, :i, CAST(:d AS jsonb)) "
                    + "ON CONFLICT (collection, id) DO UPDATE SET doc = EXCLUDED.doc",
                {"c": RESULTS, "i": self.run_id, "d": json.dumps(doc)}
            );
        }
        report {"ok": db is not None, "run_id": self.run_id};
    }
}

# Spike: the review as a function, so its answer comes back on the call in
# both topologies (a colocated walker's reports join the caller's instead).
def:protect review_pr(run_id: str, note: str, delay: float = 0.0) -> dict[str, any] {
    if delay > 0 {
        time.sleep(delay);
    }
    return {"ok": True, "run_id": run_id, "note": note, "by": "pr_review"};
}
