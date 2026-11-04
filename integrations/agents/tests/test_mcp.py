"""Exercise the real MCP SDK over stdio, including discovery and failures."""

import asyncio
import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


@pytest.mark.parametrize("allow_write", [False, True])
def test_stdio_discovery_http_and_failed_write(allow_write, tmp_path):
    seen = []

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            seen.append((self.path, self.headers.get("Authorization"), body))
            result = (
                {"ok": False, "error": "conflict"}
                if self.path.endswith("SaveProcessDefinition")
                else {"title": "Remote workspace"}
            )
            data = json.dumps({"ok": True, "data": {"reports": [result]}}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    async def run():
        params = StdioServerParameters(
            command=sys.executable,
            args=[
                "-m",
                "flowline_agent.mcp_server",
                *(["--allow-write"] if allow_write else []),
            ],
            env={
                **os.environ,
                "FLOWLINE_URL": f"http://127.0.0.1:{server.server_port}",
                "FLOWLINE_TOKEN": "mcp-test-token",
                "FLOWLINE_CONFIG": str(tmp_path / "credentials.json"),
            },
        )
        async with (
            stdio_client(params) as (read, write),
            ClientSession(read, write) as session,
        ):
            await session.initialize()
            tools = (await session.list_tools()).tools
            names = {t.name for t in tools}
            assert {
                "get_workspace",
                "get_process",
                "list_processes",
                "diff_process",
                "list_tasks",
            } <= names
            assert ("save_process" in names) is allow_write
            assert ("create_task" in names) is allow_write
            result = await session.call_tool("get_workspace", {})
            assert not result.isError
            assert result.structuredContent["title"] == "Remote workspace"
            if allow_write:
                count = len(seen)
                invalid_move = await session.call_tool(
                    "move_task", {"task_id": "task-id", "status": "Misspelled status"}
                )
                assert invalid_move.isError
                assert len(seen) == count, "invalid statuses must never reach the API"
                result = await session.call_tool(
                    "save_process", {"document": {}, "request_id": "attempt-1"}
                )
                assert result.isError
                assert "conflict" in result.content[0].text
            else:
                count = len(seen)
                result = await session.call_tool(
                    "save_process", {"document": {}, "request_id": "read-only-attempt"}
                )
                assert result.isError
                assert len(seen) == count, (
                    "read-only mode must refuse an explicit write call"
                )

    try:
        asyncio.run(run())
        assert seen[0][1] == "Bearer mcp-test-token"
        assert seen[0][0] == "/walker/GetWorkspace"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
