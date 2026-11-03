"""Whether the review service answers, and the limits a review runs under. The
service is asked once per page load, and the reason it is down stays in the log."""

import from ...constants { AGENT_LIMITS }
import from ...services.agents.agents { CheckReviewService }

def Row(label: str, children: any = None) -> JsxElement {
    return
        <div
            className="flex min-h-10 items-center gap-3 border-b px-4 py-1.5 text-[13px] last:border-b-0"
        >
            <span className="flex-1">{label}</span>
            {children}
        </div>;
}

def:pub AiStatus -> JsxElement {
    has state: str = "checking";

    async can with entry {
        try {
            result = root spawn CheckReviewService();
            answer: any = result.reports[0] if result.reports else None;
            state = "ready" if answer and answer["ok"] else "down";
        } except Exception as e {
            state = "down";
        }
    }

    return
        <section className="surface bg-bg-elevated" aria-label="Status">
            <div className="flex min-h-11 items-center border-b px-4">
                <h2 className="text-sm font-semibold">Status</h2>
            </div>
            <Row label="Review service">
                <span
                    data-review-service={state}
                    className={"text-[12.5px] "
                        + (
                            "text-success"
                                if state == "ready"
                                else (
                                    "text-danger"
                                        if state == "down"
                                        else "text-text-tertiary"
                                )
                        )}
                >
                    {"Ready"
                        if state == "ready"
                        else ("Not answering" if state == "down" else "Checking")}
                </span>
            </Row>
            <Row label="A review reads at most">
                <span className="num text-[12.5px] text-text-secondary">
                    {str(AGENT_LIMITS["max_changed_lines"]) + " changed lines"}
                </span>
            </Row>
            <Row label="Comments per review">
                <span className="num text-[12.5px] text-text-secondary">
                    {"Up to " + str(AGENT_LIMITS["max_comments"])}
                </span>
            </Row>
        </section>;
}
