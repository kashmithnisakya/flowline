"""Authoring must retain review data and leave managed catalogue revisions alone."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang { JacRuntime as Jac }
import from jaclang.runtime.context { ExecutionContext }
import from models { ProcessDefinitions, ProcessDefinition }
import from services.processes.authoring {
    SaveProcessDefinition,
    GetProcessDefinition,
    definition_etag,
    validate_definition
}


def document -> dict[str, any] {
    return {
        "title": "Updated process",
        "family": "onboarding",
        "variant": "proposed",
        "summary": "A reviewable process",
        "steps": [
            {
                "id": "intake",
                "title": "Intake",
                "owner": "anyone",
                "mode": "human",
                "status": "planned",
                "detail": "",
                "guard": "",
                "inputs": "",
                "outputs": "",
                "tool": "",
                "x": "0",
                "y": "0"
            }
        ],
        "transitions": [],
        "policies": [],
        "configuration": []
    };
}


test "edits retain notes for current and retired steps and snapshot the previous generation" {
    with TemporaryDirectory() as td {
        old = Jac.exec_ctx;
        ctx = ExecutionContext(
            base_path_dir=td, full_target_path=str(Path(td) / "app.jac")
        );
        Jac.exec_ctx = ctx;
        try {
            box = root ++> ProcessDefinitions();
            p = box ++> ProcessDefinition(
                template_key="custom-fixture",
                title="Original",
                family="onboarding",
                variant="proposed",
                summary="Original summary",
                review_notes={
                    "intake": "Keep the intake gate",
                    "retired": "Keep the old rationale"
                }
            );
            ctx.mem.commit();
            previous = definition_etag(p);
            w = SaveProcessDefinition(
                document=document(),
                request_id="edit-with-notes",
                process_id=jid(p),
                expected_etag=previous
            );
            root spawn w;
            assert w.reports[0]["ok"];
            read = GetProcessDefinition(process_id=jid(p), include_history=True);
            root spawn read;
            saved = read.reports[0]["process"];
            assert saved["id"] == jid(p);
            assert saved["review_notes"]
                == {
                    "intake": "Keep the intake gate",
                    "retired": "Keep the old rationale"
                };
            assert saved["history"][0]["review_notes"] == saved["review_notes"];
            assert saved["history"][0]["title"] == "Original";
            assert saved["revision"] == 2 and saved["etag"] != previous;
        } finally {
            Jac.exec_ctx = old;
            ctx.close();
        }
    }
}


test "managed definitions require a custom copy before authoring" {
    with TemporaryDirectory() as td {
        old = Jac.exec_ctx;
        ctx = ExecutionContext(
            base_path_dir=td, full_target_path=str(Path(td) / "app.jac")
        );
        Jac.exec_ctx = ctx;
        try {
            box = root ++> ProcessDefinitions();
            p = box ++> ProcessDefinition(
                template_key="managed-example",
                title="Managed",
                family="onboarding",
                variant="proposed",
                summary="Catalogue",
                revision=4
            );
            ctx.mem.commit();
            previous = definition_etag(p);
            w = SaveProcessDefinition(
                document=document(),
                request_id="refuse-managed-edit",
                process_id=jid(p),
                expected_etag=previous
            );
            root spawn w;
            assert w.reports == [{"ok": False, "error": "template_requires_copy"}];
            assert p.revision == 4 and p.title == "Managed";
            assert definition_etag(p) == previous;
            copy = SaveProcessDefinition(
                document={** document(), "family": "Custom onboarding"},
                request_id="create-custom-copy"
            );
            root spawn copy;
            assert copy.reports[0]["ok"] and copy.reports[0]["process_id"] != jid(p);
        } finally {
            Jac.exec_ctx = old;
            ctx.close();
        }
    }
}

test "library process metadata survives an authored copy" {
    doc = document();
    doc["family"] = "Sample group";
    step = doc["steps"][0] as dict[str, str];
    step["id"] = "1." + "a" * 78;
    step["path"] = "branch";
    step["short_title"] = "Intake";
    step["source_url"] = "https://example.test/reference";
    step["source_label"] = "";
    doc["policies"] = [
        {"title": "Review", "detail": "Keep the rationale", "status": "Defined"}
    ];
    errors = validate_definition(doc);
    assert not errors , f"An exported library definition cannot be copied: {errors}";
    with TemporaryDirectory() as td {
        old = Jac.exec_ctx;
        ctx = ExecutionContext(
            base_path_dir=td, full_target_path=str(Path(td) / "app.jac")
        );
        Jac.exec_ctx = ctx;
        try {
            save = SaveProcessDefinition(document=doc, request_id="library-copy");
            root spawn save;
            assert save.reports[0]["ok"];
            read = GetProcessDefinition(process_id=save.reports[0]["process_id"]);
            root spawn read;
            assert read.reports[0]["process"]["document"] == doc;
        } finally {
            Jac.exec_ctx = old;
            ctx.close();
        }
    }
}

test "family and variant remain unique across authored definitions" {
    with TemporaryDirectory() as td {
        old = Jac.exec_ctx;
        ctx = ExecutionContext(
            base_path_dir=td, full_target_path=str(Path(td) / "app.jac")
        );
        Jac.exec_ctx = ctx;
        try {
            first = SaveProcessDefinition(document=document(), request_id="first");
            root spawn first;
            assert first.reports[0]["ok"];
            duplicate = SaveProcessDefinition(
                document={** document(), "title": "Another title"},
                request_id="duplicate-slot"
            );
            root spawn duplicate;
            assert duplicate.reports
                == [{"ok": False, "error": "family_variant_conflict"}];
            second = SaveProcessDefinition(
                document={** document(), "family": "Another group"},
                request_id="another-group"
            );
            root spawn second;
            assert second.reports[0]["ok"];
            collision = SaveProcessDefinition(
                document=document(),
                process_id=second.reports[0]["process_id"],
                expected_etag=second.reports[0]["etag"],
                request_id="colliding-edit"
            );
            root spawn collision;
            assert collision.reports
                == [{"ok": False, "error": "family_variant_conflict"}];
            read = GetProcessDefinition(
                process_id=second.reports[0]["process_id"], include_history=True
            );
            root spawn read;
            assert read.reports[0]["process"]["document"]["family"] == "Another group";
            assert read.reports[0]["process"]["revision"] == 1;
            assert read.reports[0]["process"]["history"] == [];
        } finally {
            Jac.exec_ctx = old;
            ctx.close();
        }
    }
}
