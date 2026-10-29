"""Tenant-owned process storyboards. Installing the examples is additive and
idempotent; reviewing them never changes the operational flow or task status.
The only editable content in this stage is a review note per step."""

import from models {
    ProcessDefinitions,
    ProcessDefinition,
    ProcessView,
    process_view,
    resolve,
    owned,
    on_attached
}
import from services.processes.templates { DEMO_PROCESSES }
import from services.util { now_iso }

walker:protect ListProcesses {
    has reports: list[list[ProcessView]] = [];

    can start with Root entry {
        visit [here-->[?:ProcessDefinitions]] else {
            report [];
        }
    }

    can read with ProcessDefinitions entry {
        rows = [here-->[?:ProcessDefinition]];
        rows.sort(key=lambda (p: ProcessDefinition) { p.template_key; });
        report [process_view(p) for p in rows];
        disengage;
    }
}

walker:protect InstallProcessExamples {
    has reports: list[dict[str, any]] = [];

    can start with Root entry {
        boxes = [here-->[?:ProcessDefinitions]];
        box = boxes[0] if boxes else here ++> ProcessDefinitions();
        on_attached(here, box);
        visit [box];
    }

    can install with ProcessDefinitions entry {
        existing = [here-->[?:ProcessDefinition]];
        keys = [p.template_key for p in existing];
        added = 0;
        for data in DEMO_PROCESSES {
            key = data["template_key"] as str;
            if key in keys {
                continue;
            }
            fresh = here ++> ProcessDefinition(
                template_key=key,
                title=data["title"] as str,
                family=data["family"] as str,
                variant=data["variant"] as str,
                summary=data["summary"] as str,
                steps=data["steps"] as list[dict[str, str]],
                transitions=data["transitions"] as list[dict[str, str]],
                policies=data["policies"] as list[dict[str, str]],
                configuration=data["configuration"] as list[dict[str, str]],
                updated_at=now_iso()
            );
            on_attached(root, fresh);
            keys.append(key);
            added += 1;
        }
        report {"ok": True, "added": added};
        disengage;
    }
}

walker:protect SaveProcessNote {
    has process_id: str,
        step_id: str,
        note: str = "",
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        target = resolve(self.process_id);
        if isinstance(target, ProcessDefinition) and owned(here, target) {
            visit [target];
        } else {
            report {"ok": False, "error": "not_found"};
        }
    }

    can save with ProcessDefinition entry {
        known = [s["id"] for s in here.steps];
        if self.step_id not in known {
            report {"ok": False, "error": "unknown_step"};
        } elif len(self.note) > 6000 {
            report {"ok": False, "error": "note_too_long"};
        } else {
            here.review_notes[self.step_id] = self.note.strip();
            here.updated_at = now_iso();
            report {"ok": True};
        }
        disengage;
    }
}
