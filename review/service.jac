"""The PR review service: its own app ([apps.pr_review]), so a deploy gives it
its own pod. The web app awaits its def:protect functions; a call with no user
(the scheduled runner) carries JAC_BRIDGE_TOKEN and runs as `__bridge__`, so
nothing here reads or writes a workspace's graph."""

import os;
import time;
import from review.github { gh }
import from review.engine { run_review }
import from review.post { post_review }

# What a review reports back. `retryable` tells the runner to try again later
# rather than fail the run (a GitHub 5xx, a model timeout).
obj ReviewOutcome {
    has ok: bool,
        verdict: str = "",
        summary: str = "",
        comments: int = 0,
        blocking: int = 0,
        review_url: str = "",
        head_sha: str = "",
        model: str = "",
        tokens_in: int = 0,
        tokens_out: int = 0,
        cost_usd: float = 0.0,
        error: str = "",
        retryable: bool = False;
}

# The service is up and answering; what the web app's status check calls.
def:protect review_ping -> dict[str, any] {
    return {
        "ok": True,
        "service": "pr_review",
        "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    };
}

def failed(answer: dict[str, any], head_sha: str = "") -> ReviewOutcome {
    return ReviewOutcome(
        ok=False,
        error=str(answer.get("error") or "GitHub refused the call."),
        retryable=bool(answer.get("retryable")),
        head_sha=head_sha
    );
}

# Review one pull request at its current head with an installation token the
# web app minted. `reviewed` lists the head commits this responsibility has
# already reviewed on this task, so a commit is reviewed once.
def:protect review_pr(
    token: str,
    repo: str,
    pr_number: int,
    intent: str = "",
    instructions: str = "",
    mode: str = "comment",
    model: str = "",
    reviewed: list[str] = []
) -> ReviewOutcome {
    pr = gh(token, "GET", "/repos/" + repo + "/pulls/" + str(pr_number));
    if not pr["ok"] {
        return failed(pr);
    }
    data: dict[str, any] = pr["data"];
    head = str((data.get("head") or {}).get("sha") or "");
    if str(data.get("state") or "") != "open" {
        return ReviewOutcome(
            ok=True,
            verdict="skipped",
            summary="The pull request is closed.",
            head_sha=head
        );
    }
    if head and head in reviewed {
        return ReviewOutcome(
            ok=True,
            verdict="skipped",
            summary="This commit was already reviewed.",
            head_sha=head
        );
    }
    done = run_review(token, repo, pr_number, intent, instructions, model);
    if not done["ok"] {
        return ReviewOutcome(
            ok=False,
            error=str(done["error"]),
            retryable=bool(done["retryable"]),
            head_sha=head
        );
    }
    found = done["findings"];
    blocking = len(
        [
            f
            for f in found
            if f.severity == "blocking"
        ]
    );
    posted = post_review(
        token,
        repo,
        pr_number,
        head,
        str(done["summary"]),
        found,
        done["skipped"],
        str(done["model"]),
        "REQUEST_CHANGES" if mode == "request_changes" and blocking else "COMMENT"
    );
    if not posted["ok"] {
        return ReviewOutcome(
            ok=False,
            error=str(posted["error"]),
            retryable=bool(posted["retryable"]),
            head_sha=head
        );
    }
    return ReviewOutcome(
        ok=True,
        verdict="request_changes" if blocking else "comment",
        summary=str(done["summary"]),
        comments=len(found),
        blocking=blocking,
        review_url=str(posted["url"]),
        head_sha=head,
        model=str(done["model"]),
        tokens_in=int(done["tokens_in"]),
        tokens_out=int(done["tokens_out"]),
        cost_usd=float(done["cost_usd"])
    );
}
