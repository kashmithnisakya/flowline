"""Spike only: send a run to the review service through the outbox and read
its result back from the shared docs store. Not for merging."""

import json;
import time;
import asyncio;
import logging;
import from jaclang.server.shared_store { shared_store }
import from review.service { ReviewPR, review_pr }

walker:protect SpikeSendReview {
    has run_id: str = "",
        note: str = "";

    can send with Root entry {
        ReviewPR(run_id=self.run_id, root_jid=jid(here), note=self.note);
        report {"queued": self.run_id};
    }
}

walker:protect SpikeReadResult {
    has run_id: str = "";

    can read with Root entry {
        db = shared_store();
        found: list[any] = [];
        if db is not None {
            found = db.rows(
                "SELECT doc FROM jac_docs WHERE collection = 'agent_results' AND id = :i",
                {"i": self.run_id}
            );
        }
        report {
            "found": len(found),
            "doc": json.loads(json.dumps(found[0]["doc"])) if found else {}
        };
    }
}

walker:protect SpikeAskReview {
    has run_id: str = "",
        note: str = "";

    async can ask with Root entry {
        done = await ReviewPR(run_id=self.run_id, root_jid=jid(here), note=self.note);
        report {"answer": done.reports};
    }
}

walker:protect SpikeCallReview {
    has run_id: str = "",
        note: str = "",
        delay: float = 0.0;

    async can ask with Root entry {
        answer = await review_pr(run_id=self.run_id, note=self.note, delay=self.delay);
        report {"answer": answer};
    }
}

glob slog: any = logging.getLogger("flowline.spike");

# Spike: a scheduled function (no request, no user token) calls the service.
@schedule(trigger=ScheduleTrigger.STATIC, interval=20)
def spike_review_tick {
    t0 = time.time();
    try {
        answer = asyncio.run(review_pr(run_id="tick", note="schedule", delay=12.0));
        slog.warning(
            "spike tick: "
                + str(answer)
                + " in "
                + str(round(time.time() - t0, 1))
                + "s"
        );
    } except Exception as e {
        slog.warning("spike tick failed: " + type(e).__name__ + ": " + str(e));
    }
}
