"""Authoring must retain review data and leave managed catalogue revisions alone."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang { JacRuntime as Jac }
import from jaclang.runtime.context { ExecutionContext }
import from models { ProcessDefinitions, ProcessDefinition }
import from services.processes.authoring {
    SaveProcessDefinition,
    GetProcessDefinition,
    definition_etag
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
                document=document(), request_id="create-custom-copy"
            );
            root spawn copy;
            assert copy.reports[0]["ok"] and copy.reports[0]["process_id"] != jid(p);
        } finally {
            Jac.exec_ctx = old;
            ctx.close();
        }
    }
}
