"""Validate user-supplied process data before workspace-owned writes.
No process definitions are bundled with the application."""

import json;
import math;
import re;
import from constants { FLOW_COORD_LIMIT }

def text_field(
    data: dict[str, any],
    key: str,
    fallback: str = "",
    required: bool = False,
    limit: int = 6000
) -> str {
    value = data.get(key, fallback);
    if not isinstance(value, str) or len(value) > limit {
        raise ValueError("invalid_text");
    }
    if required and not value.strip() {
        raise ValueError("missing_text");
    }
    return value;
}

def record_key(data: dict[str, any], key: str) -> str {
    value = text_field(data, key, required=True, limit=80);
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", value) {
        raise ValueError("invalid_key");
    }
    return value;
}

def text_rows(value: any) -> list[dict[str, str]] {
    if not isinstance(value, list) or len(value) > 200 {
        raise ValueError("invalid_rows");
    }
    rows: list[dict[str, str]] = [];
    for item in value {
        if not isinstance(item, dict) {
            raise ValueError("invalid_row");
        }
        row = item as dict[str, any];
        rows.append(
            {
                "title": text_field(row, "title", required=True, limit=200),
                "detail": text_field(row, "detail"),
                "status": text_field(row, "status", "Defined", limit=100)
            }
        );
    }
    return rows;
}

def normalize_process(value: any) -> dict[str, any] {
    if not isinstance(value, dict) {
        raise ValueError("invalid_process");
    }
    data = value as dict[str, any];
    revision = data.get("revision", 1);
    if not isinstance(revision, int)
        or isinstance(revision, bool)
        or revision < 1
        or revision > 100000 {
        raise ValueError("invalid_revision");
    }
    variant = text_field(data, "variant", required=True, limit=20);
    if variant not in ["current", "proposed"] {
        raise ValueError("invalid_variant");
    }
    raw_steps = data.get("steps", []);
    if not isinstance(raw_steps, list) or not raw_steps or len(raw_steps) > 200 {
        raise ValueError("invalid_steps");
    }
    steps: list[dict[str, str]] = [];
    known: list[str] = [];
    for (index, value_step) in enumerate(raw_steps) {
        if not isinstance(value_step, dict) {
            raise ValueError("invalid_step");
        }
        item = value_step as dict[str, any];
        key = record_key(item, "id");
        if key in known {
            raise ValueError("duplicate_step");
        }
        known.append(key);
        step: dict[str, str] = {
            "id": key,
            "title": text_field(item, "title", required=True, limit=200)
        };
        for field in ["owner", "detail", "guard", "inputs", "outputs", "tool"] {
            step[field] = text_field(item, field);
        }
        step["mode"] = text_field(item, "mode", "manual", limit=100);
        step["status"] = text_field(item, "status", "Defined", limit=100);
        step["kind"] = text_field(item, "kind", "active", limit=20);
        if step["kind"] not in ["start", "active", "handoff", "blocked", "done"] {
            raise ValueError("invalid_kind");
        }
        step["path"] = text_field(item, "path", "main", limit=20);
        if step["path"] not in ["main", "branch"] {
            raise ValueError("invalid_path");
        }
        for field in [
            "stage",
            "short_title",
            "timing",
            "evidence",
            "source_url",
            "source_label",
            "related_url",
            "related_label"
        ] {
            step[field] = text_field(item, field);
        }
        for field in ["source_url", "related_url"] {
            url = step[field];
            if url and not (url.startswith("https://") or url.startswith("http://")) {
                raise ValueError("invalid_source_url");
            }
        }
        for field in ["x", "y"] {
            raw_coordinate = item.get(
                field, float(index) * 240.0 if field == "x" else 0.0
            );
            if isinstance(raw_coordinate, bool) {
                raise ValueError("invalid_coordinate");
            }
            coordinate = float(raw_coordinate);
            if not math.isfinite(coordinate) or abs(coordinate) > FLOW_COORD_LIMIT {
                raise ValueError("invalid_coordinate");
            }
            step[field] = str(coordinate);
        }
        steps.append(step);
    }
    raw_links = data.get("transitions", []);
    if not isinstance(raw_links, list) or len(raw_links) > 1000 {
        raise ValueError("invalid_transitions");
    }
    links: list[dict[str, str]] = [];
    for value_link in raw_links {
        if not isinstance(value_link, dict) {
            raise ValueError("invalid_transition");
        }
        link = value_link as dict[str, any];
        source = record_key(link, "source");
        target = record_key(link, "target");
        kind = text_field(link, "kind", "forward", limit=20);
        if source not in known
            or target not in known
            or source == target
            or kind not in ["forward", "return"] {
            raise ValueError("invalid_transition");
        }
        links.append(
            {
                "source": source,
                "target": target,
                "kind": kind,
                "label": text_field(link, "label", limit=200)
            }
        );
    }
    return {
        "template_key": record_key(data, "template_key"),
        "title": text_field(data, "title", required=True, limit=200),
        "family": text_field(data, "family", required=True, limit=100),
        "variant": variant,
        "summary": text_field(data, "summary"),
        "revision": revision,
        "steps": steps,
        "transitions": links,
        "policies": text_rows(data.get("policies", [])),
        "configuration": text_rows(data.get("configuration", []))
    };
}

def validate_catalog(values: any) -> dict[str, any] {
    try {
        if not isinstance(values, list) or not values or len(values) > 100 {
            raise ValueError("invalid_catalog");
        }
        if len(json.dumps(values, ensure_ascii=False).encode("utf-8")) > 1048576 {
            raise ValueError("catalog_too_large");
        }
        definitions: list[dict[str, any]] = [];
        keys: list[str] = [];
        versions: list[tuple[str, str]] = [];
        for value in values {
            data = normalize_process(value);
            key = data["template_key"] as str;
            version = (data["family"] as str, data["variant"] as str);
            if key in keys or version in versions {
                raise ValueError("duplicate_process");
            }
            keys.append(key);
            versions.append(version);
            definitions.append(data);
        }
        return {"ok": True, "definitions": definitions};
    } except Exception {
        return {"ok": False, "error": "invalid_catalog", "definitions": []};
    }
}
