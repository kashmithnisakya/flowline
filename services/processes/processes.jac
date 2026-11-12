"""Workspace-owned process reviews, supplied by an authenticated caller.
Import and update are explicit writes, separate from operational task state."""

import from models {
    ProcessDefinitions,
    ProcessDefinition,
    ProcessView,
    process_view,
    resolve,
    owned,
    on_attached
}
import from services.processes.catalog { validate_catalog }
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

walker:protect ImportProcessCatalog {
    has definitions: list[dict[str, any]] = [],
        reports: list[dict[str, any]] = [];

    can start with Root entry {
        catalog = validate_catalog(self.definitions);
        if not catalog["ok"] {
            report {"ok": False, "error": "invalid_catalog"};
            disengage;
        }
        self.definitions = catalog["definitions"] as list[dict[str, any]];
        boxes = [here-->[?:ProcessDefinitions]];
        box = boxes[0] if boxes else here ++> ProcessDefinitions();
        on_attached(here, box);
        visit [box];
    }

    can import_definitions with ProcessDefinitions entry {
        existing = [here-->[?:ProcessDefinition]];
        versions: list[tuple[str, str]] = [];
        for p in existing {
            version = (p.family, p.variant);
            for data in self.definitions {
                if data["template_key"] == p.template_key
                    and int(data["revision"]) > p.revision {
                    version = (data["family"] as str, data["variant"] as str);
                }
            }
            if version in versions {
                report {"ok": False, "error": "catalog_conflict"};
                disengage;
            }
            versions.append(version);
        }
        keys = [p.template_key for p in existing];
        for data in self.definitions {
            if data["template_key"] not in keys {
                version = (data["family"] as str, data["variant"] as str);
                if version in versions {
                    report {"ok": False, "error": "catalog_conflict"};
                    disengage;
                }
                versions.append(version);
            }
        }
        added = 0;
        updated = 0;
        for data in self.definitions {
            known = [
                p
                for p in existing
                if p.template_key == data["template_key"]
            ];
            revision = data["revision"] as int;
            if known {
                p = known[0];
                if p.revision >= revision {
                    continue;
                }
                snapshot: dict[str, any] = {
                    "revision": p.revision,
                    "title": p.title,
                    "family": p.family,
                    "variant": p.variant,
                    "summary": p.summary,
                    "steps": [{** s} for s in p.steps],
                    "transitions": [{** t} for t in p.transitions],
                    "policies": [{** r} for r in p.policies],
                    "configuration": [{** r} for r in p.configuration],
                    "review_notes": {** p.review_notes},
                    "updated_at": p.updated_at
                };
                p.history = [*getattr(p, "history", []), snapshot];
                p.title = data["title"] as str;
                p.family = data["family"] as str;
                p.variant = data["variant"] as str;
                p.summary = data["summary"] as str;
                p.steps = data["steps"] as list[dict[str, str]];
                p.transitions = data["transitions"] as list[dict[str, str]];
                p.policies = data["policies"] as list[dict[str, str]];
                p.configuration = data["configuration"] as list[dict[str, str]];
                p.revision = revision;
                p.updated_at = now_iso();
                updated += 1;
            } else {
                fresh = here ++> ProcessDefinition(
                    template_key=data["template_key"] as str,
                    title=data["title"] as str,
                    family=data["family"] as str,
                    variant=data["variant"] as str,
                    summary=data["summary"] as str,
                    revision=revision,
                    steps=data["steps"] as list[dict[str, str]],
                    transitions=data["transitions"] as list[dict[str, str]],
                    policies=data["policies"] as list[dict[str, str]],
                    configuration=data["configuration"] as list[dict[str, str]],
                    updated_at=now_iso()
                );
                on_attached(root, fresh);
                added += 1;
            }
        }
        report {"ok": True, "added": added, "updated": updated};
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
