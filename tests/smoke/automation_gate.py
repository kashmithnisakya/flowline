#!/usr/bin/env python3
"""Smoke test for the flow line's own automation against a running server and
github_stub.py: the Software team template's steps, entry rules and triggers,
a step's rule turning a manual move away, and GitHub labels, a linked PR, a
review and a merge moving one issue down the line. Reuses webhook_gate's
helpers. Usage: automation_gate.py [base_url] [stub_url]"""
import json
import sys

import webhook_gate as wg
from webhook_gate import check, walker, connect, project, iso, push, req

REPO = "ci-org/flow-repo"
INST = 777
STEPS = ["Incoming", "Ready", "Building", "Design",
         "In review", "Final check", "Done"]


def issue(number, updated, labels=(), title="probe"):
    return {"number": number, "title": title, "state": "open", "body": "",
            "labels": [{"name": n} for n in labels], "assignees": [],
            "html_url": f"https://github.com/{REPO}/issues/{number}",
            "repository_url": f"https://api.github.com/repos/{REPO}",
            "created_at": "2026-09-01T00:00:00Z", "updated_at": updated, "closed_at": None}


def pull(number, updated, body="", labels=(), merged_at=None):
    return {"number": number, "title": "PR", "state": "closed" if merged_at else "open",
            "body": body, "labels": [{"name": n} for n in labels],
            "html_url": f"https://github.com/{REPO}/pull/{number}",
            "updated_at": updated, "merged_at": merged_at}


def envelope(action, **kw):
    p = {"action": action, "installation": {"id": INST}, "repository": {"full_name": REPO},
         "sender": {"login": "octocat", "type": "User"}}
    p.update(kw)
    return p


def task(number):
    return wg.full_task(next((r for r in wg.tasks_all()
                              if r.get("gh_repo") == REPO and r.get("gh_issue_number") == number), None)) or {}


def update(t, **changes):
    """UpdateTask overwrites every field, so a save carries the task's own."""
    body = {k: t.get(k, "") for k in ("title", "category", "priority", "status", "step_id",
                                      "due_date", "start_date", "notes", "issue_link",
                                      "pr_link", "reviewer_id", "review_due", "project_id")}
    body.update({"task_id": t["id"], "tags": t.get("tags", []), "estimate": t.get("estimate", 0.0),
                 "assignee_ids": t.get("assignee_ids", [])})
    body.update(changes)
    return walker("UpdateTask", body)


def main() -> int:
    if not check("server ready within timeout", wg.wait_ready()):
        return 2
    status, _ = req(wg.STUB, "POST", "/_stub/reset", {"installations": [INST], "repos": {REPO: [
        issue(10, "2026-09-02T10:00:00Z", title="Plain issue"),
        issue(11, "2026-09-02T11:00:00Z", labels=["validated"], title="Labelled issue"),
    ]}}, auth=False)
    if not check("github stub reachable", status == 200, status):
        return 2
    wg.login("auto")
    check("connect", connect(INST).get("ok"))
    pid = project()

    # ------------------------------------------------------------ template
    walker("ApplyTemplate", {"template_key": "jaseci"})
    _, raw = req(wg.BASE, "POST", "/walker/GetFlowLine", {"project_id": pid})
    steps = (json.loads(raw).get("data") or {}).get("reports", [[]])[0]
    by = {s["name"]: s for s in steps}
    check("template seeds the seven steps in order", [s["name"] for s in steps] == STEPS, [s["name"] for s in steps])
    check("  Ready needs a due date, In review a linked PR",
          by["Ready"]["needs_due_date"] and by["In review"]["needs_pr"]
          and not by["Building"]["needs_due_date"], (by["Ready"], by["In review"]))

    def trig(a, b):
        s = by[a]
        i = s["next_ids"].index(by[b]["id"])
        return (s["next_triggers"][i], s["next_trigger_labels"][i])
    check("  label, merge and review triggers on the right arrows",
          trig("Incoming", "Ready") == ("label", "validated")
          and trig("Building", "In review") == ("label", "ready-to-review")
          and trig("In review", "Building") == ("changes_requested", "")
          and trig("In review", "Final check") == ("pr_merged", "")
          and trig("Final check", "Done") == ("", ""), [trig("Incoming", "Ready")])

    # ------------------------------------------------ manual moves and rules
    rid = walker("AddRepo", {"full_name": REPO, "project_id": pid}).get("id", "")
    walker("SetRepoAutoSync", {"repo_id": rid, "enabled": True})
    walker("SetRepoAutoDone", {"repo_id": rid, "enabled": True})
    s = walker("SyncGithub")
    check("poll files both issues", s.get("auto_added") == 2, s)
    t10, t11 = task(10), task(11)
    check("  they land on Incoming", t10.get("step_id") == by["Incoming"]["id"], t10.get("step_id"))
    check("  a validated label with no due date stays, and the log says why",
          t11.get("step_id") == by["Incoming"]["id"]
          and any(r.get("activity") == "Stayed on Incoming · Ready needs a due date"
                  for r in wg.log_rows()), t11.get("step_id"))
    moved = walker("MoveTask", {"task_id": t10["id"], "step_id": by["Ready"]["id"]})
    check("MoveTask into Ready without a due date is refused",
          moved.get("refused") == "Ready needs a due date" and moved.get("step_id") == by["Incoming"]["id"], moved)
    saved = update(t10, step_id=by["Ready"]["id"], due_date="2026-10-01")
    check("  a save that brings the due date moves it", saved.get("step_id") == by["Ready"]["id"] and not saved.get("refused"), saved)
    check("  and the log names the step", any(r.get("activity") == "Moved to Ready" for r in wg.log_rows()))
    made = walker("CreateTask", {"title": "Straight to review", "project_id": pid, "step_id": by["In review"]["id"]})
    check("CreateTask on a step that needs a PR creates nothing", not made.get("id"), made)
    moved = walker("MoveTask", {"task_id": t10["id"], "step_id": by["In review"]["id"]})
    check("MoveTask into In review without a PR is refused", moved.get("refused") == "In review needs a linked PR", moved)

    # ----------------------------------------------------- GitHub triggers
    update(t11, due_date="2026-10-02")
    push("issues", envelope("unlabeled", issue=issue(11, iso(1), labels=[])))
    push("issues", envelope("labeled", issue=issue(11, iso(2), labels=["validated"])))
    check("a validated label on the issue moves it to Ready", task(11).get("step_id") == by["Ready"]["id"], task(11).get("step_id"))
    walker("MoveTask", {"task_id": t11["id"], "step_id": by["Building"]["id"]})
    push("pull_request", envelope("opened", pull_request=pull(20, iso(3), body="Adds the thing.\n\nCloses #11")))
    t = task(11)
    check("a PR that closes the issue is linked to its task",
          t.get("pr_number") == 20 and t.get("pr_link") == f"https://github.com/{REPO}/pull/20", (t.get("pr_number"), t.get("pr_link")))
    push("pull_request", envelope("labeled", pull_request=pull(20, iso(4), labels=["Ready-To-Review"])))
    check("a ready-to-review label on the PR moves it to In review",
          task(11).get("step_id") == by["In review"]["id"], task(11).get("step_id"))
    push("pull_request_review", envelope("submitted", review={"state": "changes_requested", "submitted_at": iso(5)},
                                         pull_request=pull(20, iso(5), labels=["Ready-To-Review"])))
    check("a review requesting changes sends it back to Building", task(11).get("step_id") == by["Building"]["id"], task(11).get("step_id"))
    push("pull_request", envelope("labeled", pull_request=pull(20, iso(6), labels=["Ready-To-Review"])))
    check("  a label it already had does not move it", task(11).get("step_id") == by["Building"]["id"])
    push("pull_request", envelope("unlabeled", pull_request=pull(20, iso(7), labels=[])))
    push("pull_request", envelope("labeled", pull_request=pull(20, iso(8), labels=["ready-to-review"])))
    check("  labelled again, it goes back to review", task(11).get("step_id") == by["In review"]["id"])
    push("pull_request", envelope("closed", pull_request=pull(20, iso(9), labels=["ready-to-review"], merged_at=iso(9))))
    t = task(11)
    check("the merge lands on Final check, not Done, with auto-done on",
          t.get("step_id") == by["Final check"]["id"] and t.get("status") == "Review" and t.get("pr_state") == "merged",
          (t.get("step_id"), t.get("status")))
    check("  every move is logged with its reason", all(any(r.get("activity") == a for r in wg.log_rows()) for a in (
        "Moved to Ready · labelled validated", f"Linked PR {REPO} #20",
        "Moved to In review · labelled Ready-To-Review", "Moved to Building · changes requested",
        "Moved to Final check · PR merged")), [r.get("activity") for r in wg.log_rows()][:12])
    moved = walker("MoveTask", {"task_id": t["id"], "step_id": by["Done"]["id"]})
    check("oversight marks it Done by hand", moved.get("status") == "Done", moved)

    # ------------------------------------------------------ editing triggers
    r = walker("LabelTransition", {"from_id": by["Building"]["id"], "to_id": by["In review"]["id"],
                                   "label": "ready", "carries": "pr", "trigger": "label", "trigger_label": ""})
    check("a label trigger without a label is refused", r.get("error") == "match_required", r)
    r = walker("LabelTransition", {"from_id": by["Building"]["id"], "to_id": by["In review"]["id"],
                                   "label": "ready", "carries": "pr", "trigger": "bogus", "trigger_label": "x"})
    check("  an unknown trigger is stored as none", r.get("ok") and r.get("trigger") == "" and r.get("trigger_label") == "", r)
    r = walker("SetStepRules", {"step_id": by["Ready"]["id"], "needs_due_date": False, "needs_pr": True})
    check("SetStepRules writes both rules", r.get("needs_due_date") is False and r.get("needs_pr") is True, r)

    print(f"\n{len(wg.FAILS)} failed" if wg.FAILS else "\nall automation checks passed")
    return 1 if wg.FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
