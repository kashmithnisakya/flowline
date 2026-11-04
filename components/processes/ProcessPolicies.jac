"""Read-only requirements in Flowline's shared settings-row layout."""

import from ...models { ProcessView }
import from ..workspace.SettingRow { SettingRow }

glob BUILD_STAGES: list[dict[str, str]] = [
         {
             "title": "Process review",
             "status": "Available",
             "detail": "Import user-supplied definitions, compare versions and inspect steps without changing operational tasks."
         },
         {
             "title": "Notes and history",
             "status": "Available",
             "detail": "Save workspace-owned review notes. Explicit definition updates preserve IDs, notes and earlier snapshots."
         },
         {
             "title": "Process execution",
             "status": "Not implemented",
             "detail": "This library does not run steps or enforce the policies described by a definition."
         }
     ];

def:pub ProcessPolicies(process: ProcessView, section: str) -> JsxElement {
    rows: list[dict[str, str]] = BUILD_STAGES;
    if section == "rules" {
        rows = [
            {
                "title": r["title"],
                "status": r.get("status", "Defined"),
                "detail": r["detail"]
            } for r in process.policies
        ];
    } elif section == "setup" {
        rows = process.configuration;
    } elif section == "history" {
        rows = [];
        for snapshot in process.history {
            old_steps = snapshot["steps"] as list[dict[str, str]];
            old_notes = snapshot["review_notes"] as dict[str, str];
            for step in old_steps {
                note = old_notes.get(step["id"], "");
                rows.append(
                    {
                        "title": "v"
                            + str(snapshot["revision"])
                            + " · "
                            + step["title"],
                        "status": "Earlier definition · saved note"
                            if note
                            else "Earlier definition",
                        "detail": step["detail"]
                            + (" Saved review note: " + note if note else "")
                    }
                );
            }
        }
        if not rows {
            rows = [
                {
                    "title": "No earlier saved definition",
                    "status": "Read only",
                    "detail": "This workspace has not applied a definition update. Current review notes remain on their steps."
                }
            ];
        }
    }
    return
        <div className="surface overflow-hidden" aria-label="Process requirements">
            {for row in rows {
                <SettingRow
                    key={row["title"]}
                    label={row["title"]}
                    hint={row["status"]}
                >
                    <p className="text-[13px] leading-6 text-muted-foreground">
                        {row["detail"]}
                    </p>
                </SettingRow>
            }}
        </div>;
}
