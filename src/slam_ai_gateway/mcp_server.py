from __future__ import annotations

import argparse
import json
import sys
from typing import Any

from .config import GatewayConfig
from .corpus import CorpusGateway


def read_message() -> dict[str, Any] | None:
    first = sys.stdin.buffer.readline()
    if not first:
        return None
    if first.lstrip().startswith(b"{"):
        return json.loads(first.decode("utf-8"))

    headers: dict[str, str] = {}
    line = first
    while line not in {b"\r\n", b"\n", b""}:
        text = line.decode("ascii", errors="replace").strip()
        if ":" in text:
            key, value = text.split(":", 1)
            headers[key.lower()] = value.strip()
        line = sys.stdin.buffer.readline()

    length = int(headers.get("content-length", "0"))
    if length <= 0:
        return None
    payload = sys.stdin.buffer.read(length)
    return json.loads(payload.decode("utf-8"))


def write_message(payload: dict[str, Any]) -> None:
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    sys.stdout.buffer.write(f"Content-Length: {len(body)}\r\n\r\n".encode("ascii"))
    sys.stdout.buffer.write(body)
    sys.stdout.buffer.flush()


def text_result(value: Any) -> dict[str, Any]:
    return {"content": [{"type": "text", "text": json.dumps(value, ensure_ascii=False, indent=2)}]}


def tool_schema() -> list[dict[str, Any]]:
    return [
        {
            "name": "slam_status",
            "description": "Return SLAM AI corpus counts, daily-loop state, and graph summaries.",
            "inputSchema": {"type": "object", "properties": {}},
        },
        {
            "name": "slam_search_papers",
            "description": "Search paper nodes by title, source file, category, or id.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "category": {"type": "string"},
                    "limit": {"type": "integer", "default": 25},
                },
            },
        },
        {
            "name": "slam_get_paper",
            "description": "Get a paper node and optional markdown excerpt by id, title, or source file.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "id": {"type": "string"},
                    "include_text": {"type": "boolean", "default": False},
                    "max_chars": {"type": "integer", "default": 6000},
                },
                "required": ["id"],
            },
        },
        {
            "name": "slam_search_text",
            "description": "Search extracted markdown text and return snippets.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "limit": {"type": "integer", "default": 10},
                },
                "required": ["query"],
            },
        },
        {
            "name": "slam_run_daily_loop",
            "description": "Trigger the daily closed-loop update. Use wait=false for async runs.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "force": {"type": "boolean", "default": False},
                    "wait": {"type": "boolean", "default": False},
                    "timeout": {"type": "integer", "default": 3600},
                },
            },
        },
    ]


class McpGateway:
    def __init__(self, gateway: CorpusGateway):
        self.gateway = gateway

    def handle(self, message: dict[str, Any]) -> dict[str, Any] | None:
        method = message.get("method")
        message_id = message.get("id")
        try:
            if method == "initialize":
                return {
                    "jsonrpc": "2.0",
                    "id": message_id,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "slam-ai-skill-gateway", "version": "0.1.0"},
                    },
                }
            if method == "notifications/initialized":
                return None
            if method == "tools/list":
                return {"jsonrpc": "2.0", "id": message_id, "result": {"tools": tool_schema()}}
            if method == "tools/call":
                params = message.get("params", {})
                return {"jsonrpc": "2.0", "id": message_id, "result": self.call_tool(params)}
            return {
                "jsonrpc": "2.0",
                "id": message_id,
                "error": {"code": -32601, "message": f"unknown method: {method}"},
            }
        except Exception as exc:  # noqa: BLE001
            return {
                "jsonrpc": "2.0",
                "id": message_id,
                "error": {"code": -32000, "message": f"{type(exc).__name__}: {exc}"},
            }

    def call_tool(self, params: dict[str, Any]) -> dict[str, Any]:
        name = params.get("name", "")
        args = params.get("arguments", {}) or {}
        if name == "slam_status":
            return text_result(self.gateway.status())
        if name == "slam_search_papers":
            return text_result(
                self.gateway.list_papers(
                    query=str(args.get("query", "")),
                    category=str(args.get("category", "")),
                    limit=int(args.get("limit", 25)),
                )
            )
        if name == "slam_get_paper":
            return text_result(
                self.gateway.get_paper(
                    paper_id=str(args["id"]),
                    include_text=bool(args.get("include_text", False)),
                    max_chars=int(args.get("max_chars", 6000)),
                )
            )
        if name == "slam_search_text":
            return text_result(
                self.gateway.search_text(query=str(args["query"]), limit=int(args.get("limit", 10)))
            )
        if name == "slam_run_daily_loop":
            result = self.gateway.run_daily_loop(
                force=bool(args.get("force", False)),
                wait=bool(args.get("wait", False)),
                timeout=int(args.get("timeout", 3600)),
            )
            return text_result(result.__dict__)
        raise ValueError(f"unknown tool: {name}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="MCP stdio server for the local SLAM AI corpus.")
    parser.add_argument("--corpus-root", default=None)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    gateway = McpGateway(CorpusGateway(GatewayConfig.from_env(corpus_root=args.corpus_root)))
    while True:
        message = read_message()
        if message is None:
            break
        response = gateway.handle(message)
        if response is not None:
            write_message(response)


if __name__ == "__main__":
    main()
