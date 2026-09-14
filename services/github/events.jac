"""GitHub webhook receiver and its drain. The runtime's github signature
scheme verifies a delivery before GithubEvent exists and runs it as the
system identity, which can neither read nor write a workspace's graph (jobj
is owner-gated), so the receiver only queues the delivery in the shared docs
store. DrainGithubEvents applies it in the workspace's own session, and so
does every SyncGithub call, before it touches GitHub."""

import logging;
import from models { GithubConnection }
import from services.util { now_iso }
import from services.github.github {
    DRAIN_LIMIT,
    RECONCILE_PAGES,
    SyncGithub,
    connection_of,
    not_connected,
    drain_deliveries
}
import from services.github.util {
    root_for_installation,
    bot_login,
    enqueue_delivery,
    touch_installation
}

glob log: logging.Logger = logging.getLogger("flowline.github"),
     QUEUED_EVENTS: list[str] = [
         "issues",
         "pull_request",
         "pull_request_review",
         "sub_issues",
         "installation",
         "installation_repositories"
     ];


def outcome(kind: str, detail: str = "") -> dict[str, any] {
    return {"ok": True, "outcome": kind, "detail": detail};
}


@restspec(protocol=APIProtocol.WEBHOOK, scheme="github")
walker GithubEvent {
    """One delivery from the App's webhook. `event` and `delivery` come from
    the X-GitHub-Event and X-GitHub-Delivery headers, the rest are the
    payload's top-level keys. The report lands in GitHub's delivery log."""
    has event: str = "",
        delivery: str = "",
        action: str = "",
        installation: dict[str, any] = {},
        repository: dict[str, any] = {},
        issue: dict[str, any] = {},
        pull_request: dict[str, any] = {},
        sender: dict[str, any] = {},
        review: dict[str, any] = {},
        sub_issue: dict[str, any] = {},
        parent_issue: dict[str, any] = {},
        sub_issue_repo: dict[str, any] = {},
        parent_issue_repo: dict[str, any] = {},
        repositories_removed: list[dict[str, any]] = [],
        reports: list[dict[str, any]] = [];

    def event_kind -> str {
        if self.event {
            return self.event;
        }
        if self.sub_issue {
            return "sub_issues";
        }
        # Before pull_request: a review delivery carries both.
        if self.review {
            return "pull_request_review";
        }
        if self.pull_request {
            return "pull_request";
        }
        if self.issue {
            return "issues";
        }
        return "";
    }

    can receive with Root entry {
        kind = self.event_kind();
        if kind == "ping" {
            report outcome("ping");
            disengage;
        }
        inst = int(self.installation.get("id") or 0);
        if not root_for_installation(inst) {
            log.warning(
                "webhook: no workspace holds installation "
                    + str(inst)
                    + " (delivery "
                    + self.delivery
                    + "); connect it from the Workspace GitHub tab"
            );
            report outcome("unknown_installation", str(inst));
            disengage;
        }
        touch_installation(inst, now_iso());
        bot = bot_login();
        if bot and str(self.sender.get("login") or "") == bot {
            report outcome("echo", bot);
            disengage;
        }
        if kind not in QUEUED_EVENTS {
            report outcome("unsupported", kind + "." + self.action);
            disengage;
        }
        payload: dict[str, any] = {
            "event": kind,
            "action": self.action,
            "repository": {"full_name": str(self.repository.get("full_name") or "")},
            "sender": {"login": str(self.sender.get("login") or "")},
            "issue": self.issue,
            "pull_request": self.pull_request,
            "review": self.review,
            "sub_issue": self.sub_issue,
            "parent_issue": self.parent_issue,
            "sub_issue_repo": self.sub_issue_repo,
            "parent_issue_repo": self.parent_issue_repo,
            "repositories_removed": [
                {"full_name": str(r.get("full_name") or "")}
                for r in self.repositories_removed
                if isinstance(r, dict)
            ]
        };
        state = enqueue_delivery(inst, self.delivery, payload);
        if state == "unavailable" {
            report {"ok": False, "outcome": "unavailable", "detail": self.delivery};
            disengage;
        }
        report outcome(state, self.delivery);
    }
}


@schedule(trigger=ScheduleTrigger.DYNAMIC)
walker ReconcileGithub {
    """The reconcile pass on a timer instead of a board open (#174), so a
    workspace nobody opens still catches up. A workspace creates one job for
    itself when it connects (`lib/jobs.jac`), and the scheduler runs a
    dynamic job as the user who created it, on that user's own root. A
    static schedule could not: it would run as the system identity, which
    reaches a workspace's graph no better here than the receiver does.

    Carries no route of its own: the runtime leaves a scheduled walker out
    of `/walker/`, which is why this is its own walker and not a decorator
    on SyncGithub."""
    has reports: list[dict[str, any]] = [];

    can reconcile with Root entry {
        c = connection_of(here);
        if not isinstance(c, GithubConnection) or c.installation_id == 0 {
            report not_connected();
            disengage;
        }
        result = here spawn SyncGithub(page_budget=RECONCILE_PAGES);
        payload = result.reports[0] if result.reports else {};
        log.info(
            "reconcile tick for installation "
                + str(c.installation_id)
                + ": "
                + str(payload)
        );
        report payload;
    }
}


walker DrainGithubEvents {
    """Apply the deliveries queued for this workspace, oldest first, without
    calling GitHub. The board runs it on open through SyncGithub; this is
    the GitHub-free way to run it alone."""
    has reports: list[dict[str, any]] = [];

    can drain with Root entry {
        c = connection_of(here);
        if not isinstance(c, GithubConnection) or c.installation_id == 0 {
            report not_connected();
            disengage;
        }
        counts = drain_deliveries(here, c, DRAIN_LIMIT);
        counts["ok"] = True;
        report counts;
    }
}
