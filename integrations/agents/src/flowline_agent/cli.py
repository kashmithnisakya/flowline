"""A hosted-API CLI. All normal output is JSON; credentials are never printed."""

from __future__ import annotations

import argparse
import getpass
import json
import os
import sys
from pathlib import Path

from . import operations as ops
from .client import FlowlineClient, FlowlineError, read_config, save_token


def load_document(filename: str) -> dict:
    try:
        if filename == "-":
            text = sys.stdin.read(262145)
        else:
            with Path(filename).open(encoding="utf-8") as stream:
                text = stream.read(262145)
        if len(text.encode("utf-8")) > 262144:
            raise FlowlineError("invalid_document", "Document exceeds 256 KiB")
        value = json.loads(
            text,
            parse_constant=lambda _: (_ for _ in ()).throw(
                ValueError("Non-finite JSON")
            ),
        )
        # An exponent such as 1e999 also becomes infinity in Python, without
        # invoking parse_constant. Refuse it before the HTTP encoder runs.
        json.dumps(value, allow_nan=False)
    except (ValueError, OSError, UnicodeError) as exc:
        raise FlowlineError(
            "invalid_document", "Provide a UTF-8 JSON object, or '-' for stdin"
        ) from exc
    if not isinstance(value, dict):
        raise FlowlineError(
            "invalid_document", "A process document must be a JSON object"
        )
    return value


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(
        prog="flowline", description="Use a hosted Flowline API; no local app required"
    )
    root.add_argument(
        "--url", help="Hosted HTTPS URL; defaults to FLOWLINE_URL or saved login"
    )
    commands = root.add_subparsers(dest="command", required=True)
    login = commands.add_parser(
        "login", help="Authenticate to a hosted instance and save a private token"
    )
    login.add_argument("--email", required=True)
    login.add_argument(
        "--password-stdin",
        action="store_true",
        help="Read password from stdin, never an argument",
    )
    for name in ("workspace", "projects", "flow"):
        commands.add_parser(name)
    process = commands.add_parser("process").add_subparsers(
        dest="action", required=True
    )
    process.add_parser(
        "example", help="Print a starter JSON document; no connection required"
    )
    listing = process.add_parser("list")
    listing.add_argument("--page", type=int, default=1)
    listing.add_argument("--page-size", type=int, default=25)
    get = process.add_parser("get", aliases=["export"])
    get.add_argument("process_id")
    get.add_argument("--history", action="store_true")
    process.add_parser("validate").add_argument(
        "file", help="JSON document, or '-' for stdin"
    )
    diff = process.add_parser("diff")
    diff.add_argument("process_id")
    diff.add_argument("file")
    for action in ("create", "update"):
        save = process.add_parser(action)
        if action == "update":
            save.add_argument("process_id")
            save.add_argument(
                "--etag",
                required=True,
                help="Exact etag from get/diff; stale edits fail",
            )
        save.add_argument("file")
        save.add_argument(
            "--request-id",
            required=True,
            help="Reuse this ID only when retrying the identical save",
        )
    tasks = commands.add_parser("task").add_subparsers(dest="action", required=True)
    listing = tasks.add_parser("list")
    listing.add_argument("--project-id", default="")
    listing.add_argument("--page", type=int, default=1)
    listing.add_argument("--page-size", type=int, default=25)
    tasks.add_parser("get").add_argument("task_id")
    create = tasks.add_parser("create")
    create.add_argument("--title", required=True)
    create.add_argument("--project-id", required=True)
    create.add_argument("--notes", default="")
    create.add_argument("--step-id", default="")
    move = tasks.add_parser("move")
    move.add_argument("task_id")
    target = move.add_mutually_exclusive_group(required=True)
    target.add_argument("--step-id", default="")
    target.add_argument(
        "--status",
        choices=ops.TASK_STATUSES,
        default="",
        help="Legacy status move; clears the current step. Use --step-id for flow entry rules",
    )
    return root


def dispatch(args: argparse.Namespace, client: FlowlineClient) -> dict:
    if args.command in ("workspace", "projects", "flow"):
        return client.walker(
            {
                "workspace": "GetWorkspace",
                "projects": "ListProjects",
                "flow": "GetFlowLine",
            }[args.command]
        )
    if args.command == "process":
        if args.action == "list":
            return ops.process_list(client, args.page, args.page_size)
        if args.action in ("get", "export"):
            result = ops.process_get(client, args.process_id, args.history)
            return result["process"]["document"] if args.action == "export" else result
        document = load_document(args.file)
        if args.action == "validate":
            return ops.process_validate(client, document)
        if args.action == "diff":
            return ops.process_diff(client, args.process_id, document)
        return ops.process_save(
            client,
            document,
            args.request_id,
            getattr(args, "process_id", ""),
            getattr(args, "etag", ""),
        )
    if args.action == "list":
        return ops.tasks_list(client, args.page, args.page_size, args.project_id)
    if args.action == "get":
        return ops.task_get(client, args.task_id)
    if args.action == "create":
        return ops.task_create(
            client, args.title, args.project_id, args.notes, args.step_id
        )
    return ops.task_move(client, args.task_id, args.step_id, args.status)


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    client = None
    try:
        if args.command == "process" and args.action == "example":
            result = ops.process_example()
        elif args.command == "login":
            url = (
                args.url
                or os.environ.get("FLOWLINE_URL")
                or read_config().get("default_url", "")
            )
            client = FlowlineClient(url)
            password = (
                sys.stdin.readline().rstrip("\r\n")
                if args.password_stdin
                else getpass.getpass("Flowline password: ")
            )
            if not password:
                raise FlowlineError("invalid_credentials", "A password is required")
            token = client.login(args.email, password)
            save_token(client.url, token)
            result = {"ok": True, "url": client.url, "authenticated": True}
        else:
            client = FlowlineClient.configured(args.url)
            result = dispatch(args, client)
        print(json.dumps(result, ensure_ascii=True, allow_nan=False))
        return 0 if result.get("ok", True) else 1
    except FlowlineError as exc:
        print(json.dumps(exc.result(), ensure_ascii=True, allow_nan=False))
        return 1
    except (OSError, EOFError):
        print(
            json.dumps(
                {
                    "ok": False,
                    "error": "client_io_error",
                    "message": "Cannot read input or write private credentials; check permissions and stdin",
                }
            )
        )
        return 1
    finally:
        if client:
            client.close()


if __name__ == "__main__":
    sys.exit(main())
