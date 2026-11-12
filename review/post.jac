"""Post the review on the pull request: one review on the reviewed commit,
inline comments on the lines they name, the summary as its body. A review
GitHub refuses for a comment's line (422) is posted again with the findings
written into the body instead, so the team still gets it."""

import from review.github { gh }

glob LABEL: dict[str, str] = {
         "blocking": "Blocking",
         "warning": "Warning",
         "nit": "Nit"
     },
     APPROVE_HINT: str = (
         "GitHub refused the review (403). The GitHub App needs Pull requests: read and "
         + "write; ask an organization owner to approve the updated permissions in "
         + "Settings > GitHub Apps."
     );

def comment_body(f: any) -> str {
    return "**" + LABEL.get(f.severity, "Note") + ": " + f.title + "**\n\n" + f.body;
}

def review_body(
    summary: str, findings: list[any], skipped: list[str], model: str, inline: bool
) -> str {
    lines: list[str] = ["### AI code review", "", summary];
    if not inline and findings {
        lines.extend(["", "**Findings**", ""]);
        for f in findings {
            lines.append(
                "- `"
                    + f.path
                    + ":"
                    + str(f.line)
                    + "` "
                    + comment_body(f).replace("\n\n", " · ")
            );
        }
    }
    if skipped {
        lines.extend(["", "Not reviewed: " + "; ".join(skipped) + "."]);
    }
    lines.extend(["", "<sub>Flowline AI responsibility · " + model + "</sub>"]);
    return "\n".join(lines);
}

# {"ok": True, "url"} or {"ok": False, "error", "retryable"}.
def post_review(
    token: str,
    repo: str,
    pr_number: int,
    head_sha: str,
    summary: str,
    findings: list[any],
    skipped: list[str],
    model: str,
    event: str
) -> dict[str, any] {
    path = "/repos/" + repo + "/pulls/" + str(pr_number) + "/reviews";
    payload: dict[str, any] = {
        "commit_id": head_sha,
        "event": event,
        "body": review_body(summary, findings, skipped, model, True),
        "comments": [
            {"path": f.path, "line": f.line, "side": "RIGHT", "body": comment_body(f)}
            for f in findings
        ]
    };
    res = gh(token, "POST", path, None, payload);
    if not res["ok"] and res["status"] == 422 and findings {
        payload["comments"] = [];
        payload["body"] = review_body(summary, findings, skipped, model, False);
        res = gh(token, "POST", path, None, payload);
    }
    if res["ok"] {
        data = res["data"] or {};
        return {"ok": True, "url": str(data.get("html_url") or "")};
    }
    if res["status"] == 403 and not res["retryable"] {
        return {"ok": False, "error": APPROVE_HINT, "retryable": False};
    }
    return {"ok": False, "error": res["error"], "retryable": res["retryable"]};
}
