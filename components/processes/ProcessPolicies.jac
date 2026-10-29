"""Read-only requirements in Flowline's shared settings-row layout."""

import from ...models { ProcessView }
import from ..workspace.SettingRow { SettingRow }

glob BUILD_STAGES: list[dict[str, str]] = [
         {
             "title": "Process review library",
             "status": "Working locally",
             "detail": "Four saved definitions, flow selection, comparison, step inspection and review notes. Operational tasks stay separate."
         },
         {
             "title": "Versioned delivery records",
             "status": "Planned",
             "detail": "Spec, story, acceptance criteria, implementation task and QA scenario traceability. Approvals identify the actor and applicable versions."
         },
         {
             "title": "QA and evidence",
             "status": "Planned",
             "detail": "Execute checks, identify the tested build, detect layout defects, retain retries and preserve the original QA deadline."
         },
         {
             "title": "Review, repair and readiness",
             "status": "Planned",
             "detail": "Independent read-only review, bounded repair, separate exchange limits, exception decisions and the final PR-owner evidence bundle."
         },
         {
             "title": "Adapters and pilot",
             "status": "Placeholder",
             "detail": "Generic git, preview and test-runner adapters. Reactinator, developer agent sets, Spark and proprietary Ally integrations remain placeholders."
         }
     ];

def:pub ProcessPolicies(process: ProcessView, section: str) -> JsxElement {
    rows: list[dict[str, str]] = BUILD_STAGES;
    if section == "rules" {
        rows = [
            {
                "title": r["title"],
                "status": "Planned enforcement",
                "detail": r["detail"]
            } for r in process.policies
        ];
    } elif section == "setup" {
        rows = process.configuration;
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
