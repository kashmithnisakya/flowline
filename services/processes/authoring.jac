"""Headless, tenant-owned definition authoring; never executes a process.

The MCP bridge and CLI share these protected walkers. Mutations run in
Jac's serializable request transaction; stale etags and reused request IDs
are checked inside that transaction, including after a serialization retry.
"""

import json;
import hashlib;
import math;
import re;
import uuid;
import from urllib.parse { urlsplit }
import from models {
    ProcessDefinitions,
    ProcessDefinition,
    ProcessAuthoringRequests,
    ProcessAuthoringRequest,
    resolve,
    owned,
    on_attached
}
import from services.util { now_iso, page_bounds }
import from constants { STEP_KINDS }

glob DOCUMENT_FIELDS: list[str] = [
         "title",
         "family",
         "variant",
         "summary",
         "steps",
         "transitions",
         "policies",
         "configuration"
     ],
     STEP_FIELDS: list[str] = [
         "id",
         "title",
         "owner",
         "mode",
         "status",
         "detail",
         "guard",
         "inputs",
         "outputs",
         "tool",
         "x",
         "y",
         "kind",
         "path",
         "stage",
         "short_title",
         "source_url",
         "source_label",
         "related_url",
         "related_label",
         "evidence",
         "timing"
     ];

def canonical(value: any) -> str {
    return json.dumps(value, sort_keys=True, ensure_ascii=True, allow_nan=False) as str;
}

def fingerprint(value: any) -> str {
    return hashlib.sha256(canonical(value).encode()).hexdigest() as str;
}

def definition_document(p: ProcessDefinition) -> dict[str, any] {
    return {
        "title": p.title,
        "family": p.family,
        "variant": p.variant,
        "summary": p.summary,
        "steps": p.steps,
        "transitions": p.transitions,
        "policies": p.policies,
        "configuration": p.configuration
    };
}

def definition_etag(p: ProcessDefinition) -> str {
    # Include the snapshot generation and notes, so changes by the review UI
    # or example updater also invalidate an agent's previously read version.
    return fingerprint(
        {
            "document": definition_document(p),
            "revision": p.revision,
            "notes": p.review_notes,
            "history_count": len(getattr(p, "history", [])),
            "updated_at": p.updated_at
        }
    );
}

def definition_result(
    p: ProcessDefinition, include_history: bool = False
) -> dict[str, any] {
    out: dict[str, any] = {
        "id": jid(p),
        "template_key": p.template_key,
        "etag": definition_etag(p),
        "revision": p.revision,
        "updated_at": p.updated_at,
        "document": definition_document(p),
        "review_notes": p.review_notes
    };
    if include_history {
        out["history"] = getattr(p, "history", []);
    }
    return out;
}

def family_variant_in_use(
    holder: Root, family: str, variant: str, except_id: str = ""
) -> bool {
    for p in [holder-->[?:ProcessDefinitions]-->[?:ProcessDefinition]] {
        if p.family == family and p.variant == variant and jid(p) != except_id {
            return True;
        }
    }
    return False;
}

def validate_definition(document: dict[str, any]) -> list[str] {
    errors: list[str] = [];
    try {
        if len(canonical(document)) > 262144 {
            return ["document exceeds 256 KiB"];
        }
    } except (ValueError, TypeError) {
        return ["document must contain finite JSON values"];
    }
    if set(document.keys()) != set(DOCUMENT_FIELDS) {
        return ["document must contain exactly: " + ", ".join(DOCUMENT_FIELDS)];
    }
    for key in ["title", "family", "variant", "summary"] {
        value = document[key];
        if not isinstance(value, str) or len(value) > 8000 {
            errors.append(key + " must be a string of at most 8000 characters");
        }
    }
    if errors {
        return errors;
    }
    if not str(document["title"]).strip() or len(str(document["title"])) > 200 {
        errors.append("title must have 1–200 characters");
    }
    if not str(document["family"]).strip() or len(str(document["family"])) > 100 {
        errors.append("family must have 1–100 characters");
    }
    if document["variant"] not in ["current", "proposed"] {
        errors.append("variant must be current or proposed");
    }
    for key in ["steps", "transitions", "policies", "configuration"] {
        if not isinstance(document[key], list) or len(document[key]) > 500 {
            errors.append(key + " must be a list of at most 500 records");
        }
    }
    if errors {
        return errors;
    }
    ids: list[str] = [];
    for item in document["steps"] as list[any] {
        if not isinstance(item, dict) {
            errors.append("each step must be an object");
            continue;
        }
        step = item as dict[str, any];
        if not set(step.keys()).issubset(set(STEP_FIELDS)) {
            errors.append("step contains unsupported fields");
        }
        if not all(isinstance(v, str) and len(v) <= 8000 for v in step.values()) {
            errors.append("step values must be strings of at most 8000 characters");
            continue;
        }
        key = str(step.get("id", ""));
        if re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,79}", key) is None
            or key in ids {
            errors.append(
                "step IDs must be unique identifiers of at most 80 characters"
            );
        }
        ids.append(key);
        for field in [
            "title",
            "owner",
            "mode",
            "status",
            "detail",
            "guard",
            "inputs",
            "outputs",
            "tool",
            "x",
            "y"
        ] {
            if field not in step {
                errors.append("step " + key + " is missing " + field);
            }
        }
        if not str(step.get("title", "")).strip() {
            errors.append("step title must not be empty");
        }
        if "kind" in step and step["kind"] not in STEP_KINDS {
            errors.append("step kind must be start, active, handoff, blocked or done");
        }
        if "path" in step and step["path"] not in ["main", "branch"] {
            errors.append("step path must be main or branch");
        }
        for field in ["x", "y"] {
            try {
                coordinate = float(step.get(field, ""));
                if not math.isfinite(coordinate) or abs(coordinate) > 20000 {
                    errors.append("step coordinates must be finite and within ±20000");
                }
            } except (ValueError, TypeError) {
                errors.append("step coordinates must be numeric strings");
            }
        }
        for field in ["source_url", "related_url"] {
            if step.get(field, "") {
                try {
                    link_url = str(step[field]);
                    parsed = urlsplit(link_url);
                    _ = parsed.port;
                    if parsed.scheme not in ["http", "https"]
                        or not parsed.hostname
                        or parsed.username is not None
                        or parsed.password is not None
                        or any(ch.isspace() for ch in link_url) {
                        errors.append(
                            "step links must be HTTP(S) URLs without credentials"
                        );
                    }
                } except ValueError {
                    errors.append("step link is not a valid URL");
                }
            }
        }
    }
    if not ids {
        errors.append("at least one step is required");
    }
    for item in document["transitions"] as list[any] {
        if not isinstance(item, dict) {
            errors.append("each transition must be an object");
            continue;
        }
        link = item as dict[str, any];
        if set(link.keys()) != {"source", "target", "label", "kind"}
            or not all(isinstance(v, str) and len(v) <= 8000 for v in link.values()) {
            errors.append("transitions require string source, target, label and kind");
            continue;
        }
        if link["source"] not in ids or link["target"] not in ids {
            errors.append("transition endpoints must name existing steps");
        }
        if link["source"] == link["target"]
            or link["kind"] not in ["forward", "return"] {
            errors.append(
                "transitions require distinct endpoints and forward/return kind"
            );
        }
    }
    for field in ["policies", "configuration"] {
        for item in document[field] as list[any] {
            if not isinstance(item, dict) {
                errors.append(field + " records must be objects");
                continue;
            }
            record = item as dict[str, any];
            required = {"title", "detail", "status"}
                if field == "configuration"
                else {"title", "detail"};
            if not required.issubset(set(record.keys()))
                or not set(record.keys()).issubset(required | {"status"})
                or not all(
                    isinstance(v, str) and len(v) <= 8000 for v in record.values()
                ) {
                errors.append(field + " records have invalid fields or values");
            }
        }
    }
    return errors;
}

walker:protect ValidateProcessDefinition {
    has document: dict[str, any],
        reports: list[dict[str, any]] = [];

    can validate with Root entry {
        errors = validate_definition(self.document);
        report {"ok": not errors, "errors": errors};
    }
}

walker:protect ListProcessDefinitions {
    has page: int = 1,
        page_size: int = 25,
        reports: list[dict[str, any]] = [];

    can read with Root entry {
        rows = [here-->[?:ProcessDefinitions]-->[?:ProcessDefinition]];
        rows.sort(key=lambda (p: ProcessDefinition) { jid(p); });
        (page, size, start, stop) = page_bounds(self.page, self.page_size, 25, 100);
        report {
            "ok": True,
            "page": page,
            "page_size": size,
            "total": len(rows),
            "has_more": stop < len(rows),
            "rows": [
                {
                    "id": jid(p),
                    "title": p.title,
                    "family": p.family,
                    "variant": p.variant,
                    "revision": p.revision,
                    "etag": definition_etag(p),
                    "updated_at": p.updated_at
                } for p in rows[start:stop]
            ]
        };
    }
}

walker:protect GetProcessDefinition {
    has process_id: str,
        include_history: bool = False,
        reports: list[dict[str, any]] = [];

    can read with Root entry {
        p = resolve(self.process_id);
        if isinstance(p, ProcessDefinition) and owned(here, p) {
            report {"ok": True, "process": definition_result(p, self.include_history)};
        } else {
            report {"ok": False, "error": "not_found"};
        }
    }
}

walker:protect SaveProcessDefinition {
    has document: dict[str, any],
        request_id: str,
        process_id: str = "",
        expected_etag: str = "",
        reports: list[dict[str, any]] = [];

    can save with Root entry {
        if re.fullmatch(r"[a-zA-Z0-9_-]{1,128}", self.request_id) is None {
            report {"ok": False, "error": "invalid_request_id"};
            disengage;
        }
        errors = validate_definition(self.document);
        if errors {
            report {"ok": False, "error": "invalid_definition", "errors": errors};
            disengage;
        }
        signature = fingerprint(
            {
                "document": self.document,
                "process_id": self.process_id,
                "expected_etag": self.expected_etag
            }
        );
        requests = [here-->[?:ProcessAuthoringRequests]-->[?:ProcessAuthoringRequest, request_id==self.request_id]];
        for saved in requests {
            if saved.request_id == self.request_id {
                if saved.signature != signature {
                    report {"ok": False, "error": "request_id_reused"};
                } else {
                    report {** saved.result, "replayed": True};
                }
                disengage;
            }
        }
        if self.process_id {
            target = resolve(self.process_id);
            if not isinstance(target, ProcessDefinition) or not owned(here, target) {
                report {"ok": False, "error": "not_found"};
                disengage;
            }
            p = target as ProcessDefinition;
            # Catalogue revisions are controlled by the example updater. A
            # custom edit must not advance that counter and suppress a later
            # template upgrade. Export/create an independent copy instead.
            if not p.template_key.startswith("custom-") {
                report {"ok": False, "error": "template_requires_copy"};
                disengage;
            }
            if not self.expected_etag or self.expected_etag != definition_etag(p) {
                report {
                    "ok": False,
                    "error": "conflict",
                    "current_etag": definition_etag(p)
                };
                disengage;
            }
            if len(getattr(p, "history", [])) >= 200 {
                report {"ok": False, "error": "history_limit"};
                disengage;
            }
            if family_variant_in_use(
                here,
                self.document["family"] as str,
                self.document["variant"] as str,
                jid(p)
            ) {
                report {"ok": False, "error": "family_variant_conflict"};
                disengage;
            }
            snapshot = {
                ** definition_document(p),
                "revision": p.revision,
                "review_notes": {** p.review_notes},
                "updated_at": p.updated_at,
                "actor_root_id": jid(here),
                "request_id": self.request_id
            };
            p.history = [*getattr(p, "history", []), snapshot];
            p.revision += 1;
        } else {
            if self.expected_etag {
                report {"ok": False, "error": "unexpected_etag"};
                disengage;
            }
            if family_variant_in_use(
                here, self.document["family"] as str, self.document["variant"] as str
            ) {
                report {"ok": False, "error": "family_variant_conflict"};
                disengage;
            }
            boxes = [here-->[?:ProcessDefinitions]];
            box = boxes[0] if boxes else here ++> ProcessDefinitions();
            p = box ++> ProcessDefinition(
                template_key="custom-" + uuid.uuid4().hex,
                title="",
                family="",
                variant="proposed",
                summary=""
            );
            on_attached(here, p);
        }
        p.title = str(self.document["title"]).strip();
        p.family = self.document["family"] as str;
        p.variant = self.document["variant"] as str;
        p.summary = self.document["summary"] as str;
        p.steps = self.document["steps"] as list[dict[str, str]];
        p.transitions = self.document["transitions"] as list[dict[str, str]];
        p.policies = self.document["policies"] as list[dict[str, str]];
        p.configuration = self.document["configuration"] as list[dict[str, str]];
        p.updated_at = now_iso();
        result: dict[str, any] = {
            "ok": True,
            "process_id": jid(p),
            "etag": definition_etag(p),
            "revision": p.revision,
            "request_id": self.request_id,
            "replayed": False
        };
        request_boxes = [here-->[?:ProcessAuthoringRequests]];
        request_box = request_boxes[0]
            if request_boxes
            else here ++> ProcessAuthoringRequests();
        receipt = request_box ++> ProcessAuthoringRequest(
            request_id=self.request_id,
            signature=signature,
            result=result,
            actor_root_id=jid(here),
            created_at=p.updated_at
        );
        on_attached(here, receipt);
        report result;
    }
}
