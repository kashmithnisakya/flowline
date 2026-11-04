import json
import os
import stat

import httpx
import pytest
from flowline_agent.cli import load_document, main
from flowline_agent.client import (
    FlowlineClient,
    FlowlineError,
    normalize_url,
    save_token,
    settings,
)
from flowline_agent.operations import task_move


def client_for(handler):
    client = FlowlineClient("https://flowline.example.test/team", "private-token")
    client.http.close()
    client.http = httpx.Client(
        transport=httpx.MockTransport(handler), follow_redirects=False
    )
    return client


@pytest.mark.parametrize(
    "url",
    [
        "http://remote.example",
        "https://u:p@remote.example",
        "https://remote.example?token=x",
        "https://remote.example/#x",
        "https://remote.example/ with-space",
        "https://[invalid",
        "https://remote.example/\x00",
        "https://remote.example/\x7f",
    ],
)
def test_reject_unsafe_origins(url):
    with pytest.raises(FlowlineError):
        normalize_url(url)


@pytest.mark.parametrize("number", ["NaN", "1e999"])
def test_invalid_numeric_documents_fail_before_http_encoding(number, tmp_path):
    path = tmp_path / "process.json"
    path.write_text('{"steps": [' + number + "]}")
    with pytest.raises(FlowlineError, match="UTF-8 JSON"):
        load_document(str(path))


def test_hosted_https_and_prefix_are_preserved():
    seen = []

    def handler(request):
        seen.append(request)
        return httpx.Response(
            200, json={"ok": True, "data": {"reports": [{"title": "Hosted workspace"}]}}
        )

    with_client = client_for(handler)
    try:
        assert with_client.walker("GetWorkspace")["title"] == "Hosted workspace"
        assert (
            str(seen[0].url) == "https://flowline.example.test/team/walker/GetWorkspace"
        )
        assert seen[0].headers["authorization"] == "Bearer private-token"
    finally:
        with_client.close()


def test_project_nodes_expose_usable_ids_without_replacing_view_ids():
    client = client_for(
        lambda _: httpx.Response(
            200,
            json={
                "ok": True,
                "data": {
                    "reports": [
                        [
                            {
                                "_jac_archetype": "node",
                                "_jac_id": "project-id",
                                "name": "Project",
                            },
                            {
                                "_jac_archetype": "obj",
                                "_jac_id": "view-handle",
                                "id": "task-id",
                            },
                        ]
                    ]
                },
            },
        )
    )
    try:
        rows = client.walker("ListProjects")["rows"]
        assert rows[0]["id"] == "project-id"
        assert rows[1]["id"] == "task-id"
    finally:
        client.close()


def test_redirect_never_receives_credentials():
    seen = []

    def handler(request):
        seen.append(str(request.url))
        return httpx.Response(
            307, headers={"location": "https://other.example/walker/GetWorkspace"}
        )

    client = client_for(handler)
    with pytest.raises(FlowlineError, match="canonical URL"):
        client.walker("GetWorkspace")
    assert len(seen) == 1
    client.close()


@pytest.mark.parametrize(
    "reports,code",
    [
        ([], "not_found_or_refused"),
        ([{"ok": False, "error": "conflict", "current_etag": "new"}], "conflict"),
        ([{"refused": "A PR is required"}], "transition_refused"),
    ],
)
def test_refusals_are_failures(reports, code):
    client = client_for(
        lambda _: httpx.Response(200, json={"ok": True, "data": {"reports": reports}})
    )
    with pytest.raises(FlowlineError) as caught:
        client.walker("SaveProcessDefinition")
    assert caught.value.code == code
    client.close()


def test_unknown_task_status_is_refused_without_a_write():
    requests = []
    client = client_for(lambda request: requests.append(request))
    try:
        with pytest.raises(FlowlineError, match="Status must be one of"):
            task_move(client, "task-id", status="Misspelled status")
        assert requests == []
    finally:
        client.close()


def test_token_is_bound_to_complete_origin(monkeypatch, tmp_path):
    monkeypatch.setenv("FLOWLINE_CONFIG", str(tmp_path / "credentials.json"))
    monkeypatch.setenv("FLOWLINE_URL", "https://flowline.example.test/team")
    monkeypatch.setenv("FLOWLINE_TOKEN", "secret")
    assert settings() == ("https://flowline.example.test/team", "secret")
    with pytest.raises(FlowlineError, match="matching FLOWLINE_URL"):
        settings("https://other.example")
    with pytest.raises(FlowlineError):
        settings("https://flowline.example.test/another-team")


def test_saved_credentials_private_and_origin_scoped(monkeypatch, tmp_path):
    path = tmp_path / "private" / "credentials.json"
    monkeypatch.setenv("FLOWLINE_CONFIG", str(path))
    monkeypatch.delenv("FLOWLINE_TOKEN", raising=False)
    monkeypatch.delenv("FLOWLINE_URL", raising=False)
    save_token("https://flowline.example.test", "saved-secret")
    assert settings() == ("https://flowline.example.test", "saved-secret")
    if os.name != "nt":
        assert stat.S_IMODE(path.stat().st_mode) == 0o600
        path.chmod(0o644)
        with pytest.raises(FlowlineError, match="private regular file"):
            settings()


def test_cli_uses_hosted_endpoint_without_a_local_app(monkeypatch, tmp_path, capsys):
    monkeypatch.setenv("FLOWLINE_CONFIG", str(tmp_path / "credentials.json"))
    monkeypatch.setenv("FLOWLINE_URL", "https://flowline.example.test/team")
    monkeypatch.setenv("FLOWLINE_TOKEN", "cli-secret")
    seen = []
    real_client = httpx.Client

    def handler(request):
        seen.append(request)
        return httpx.Response(
            200, json={"ok": True, "data": {"reports": [{"ok": True, "rows": []}]}}
        )

    monkeypatch.setattr(
        httpx,
        "Client",
        lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs),
    )
    assert main(["process", "list"]) == 0
    result = json.loads(capsys.readouterr().out)
    assert result == {"ok": True, "rows": []}
    assert seen[0].url.host == "flowline.example.test"
    assert seen[0].url.path == "/team/walker/ListProcessDefinitions"


def test_cli_login_never_prints_token_or_password(monkeypatch, tmp_path, capsys):
    monkeypatch.setenv("FLOWLINE_CONFIG", str(tmp_path / "credentials.json"))
    monkeypatch.setattr(
        "flowline_agent.cli.getpass.getpass", lambda _: "password-secret"
    )
    real_client = httpx.Client

    def handler(request):
        assert "authorization" not in request.headers
        assert (
            json.loads(request.content)["credential"]["password"] == "password-secret"
        )
        return httpx.Response(200, json={"ok": True, "data": {"token": "login-secret"}})

    monkeypatch.setattr(
        httpx,
        "Client",
        lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs),
    )
    assert (
        main(
            [
                "--url",
                "https://flowline.example.test",
                "login",
                "--email",
                "test@example.test",
            ]
        )
        == 0
    )
    output = capsys.readouterr()
    assert "login-secret" not in output.out + output.err
    assert "password-secret" not in output.out + output.err


def test_cli_mutation_failure_is_json_and_nonzero(monkeypatch, tmp_path, capsys):
    monkeypatch.setenv("FLOWLINE_CONFIG", str(tmp_path / "credentials.json"))
    monkeypatch.setenv("FLOWLINE_URL", "https://flowline.example.test")
    monkeypatch.setenv("FLOWLINE_TOKEN", "secret")
    real_client = httpx.Client
    monkeypatch.setattr(
        httpx,
        "Client",
        lambda **kwargs: real_client(
            transport=httpx.MockTransport(
                lambda _: httpx.Response(
                    200,
                    json={
                        "ok": True,
                        "data": {"reports": [{"refused": "PR required"}]},
                    },
                )
            ),
            **kwargs,
        ),
    )
    assert main(["task", "move", "task-id", "--step-id", "step-id"]) == 1
    assert json.loads(capsys.readouterr().out)["error"] == "transition_refused"
