from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlparse

from .config import GatewayConfig
from .corpus import CorpusGateway


def json_bytes(payload: Any) -> bytes:
    return json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")


class GatewayHandler(BaseHTTPRequestHandler):
    gateway: CorpusGateway
    token: str

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002
        print("%s - - [%s] %s" % (self.client_address[0], self.log_date_time_string(), format % args))

    def send_json(self, status: int, payload: Any) -> None:
        body = json_bytes(payload)
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:  # noqa: N802
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def authorized(self) -> bool:
        if not self.token:
            return True
        header = self.headers.get("Authorization", "")
        return header == f"Bearer {self.token}"

    def require_auth(self) -> bool:
        if self.authorized():
            return True
        self.send_json(401, {"error": "unauthorized"})
        return False

    def do_GET(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)
        try:
            if parsed.path == "/health":
                self.send_json(200, self.gateway.health())
                return
            if not self.require_auth():
                return
            if parsed.path == "/status":
                self.send_json(200, self.gateway.status())
            elif parsed.path == "/graph/summary":
                self.send_json(200, self.gateway.graph_summary())
            elif parsed.path == "/papers":
                self.send_json(
                    200,
                    self.gateway.list_papers(
                        query=first(qs, "q"),
                        category=first(qs, "category"),
                        limit=int(first(qs, "limit", "25")),
                    ),
                )
            elif parsed.path == "/paper":
                paper_id = first(qs, "id")
                if not paper_id:
                    self.send_json(400, {"error": "missing id"})
                    return
                self.send_json(
                    200,
                    self.gateway.get_paper(
                        paper_id=paper_id,
                        include_text=first(qs, "include_text").lower() in {"1", "true", "yes"},
                        max_chars=int(first(qs, "max_chars", "6000")),
                    ),
                )
            elif parsed.path == "/search":
                self.send_json(
                    200,
                    self.gateway.search_text(
                        query=first(qs, "q"),
                        limit=int(first(qs, "limit", "10")),
                    ),
                )
            else:
                self.send_json(404, {"error": "not found", "path": parsed.path})
        except Exception as exc:  # noqa: BLE001
            self.send_json(500, {"error": type(exc).__name__, "message": str(exc)})

    def do_POST(self) -> None:  # noqa: N802
        parsed = urlparse(self.path)
        qs = parse_qs(parsed.query)
        try:
            if not self.require_auth():
                return
            if parsed.path != "/daily/run":
                self.send_json(404, {"error": "not found", "path": parsed.path})
                return
            payload = self.read_body_json()
            force = bool_arg(first(qs, "force", str(payload.get("force", "false"))))
            wait = bool_arg(first(qs, "wait", str(payload.get("wait", "false"))))
            timeout = int(first(qs, "timeout", str(payload.get("timeout", "3600"))))
            result = self.gateway.run_daily_loop(force=force, wait=wait, timeout=timeout)
            self.send_json(
                200,
                {
                    "started": result.started,
                    "pid": result.pid,
                    "exit_code": result.exit_code,
                    "command": result.command,
                    "stdout": result.stdout[-8000:],
                    "stderr": result.stderr[-8000:],
                },
            )
        except Exception as exc:  # noqa: BLE001
            self.send_json(500, {"error": type(exc).__name__, "message": str(exc)})

    def read_body_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length <= 0:
            return {}
        raw = self.rfile.read(length).decode("utf-8", errors="replace")
        return json.loads(raw) if raw.strip() else {}


def first(qs: dict[str, list[str]], key: str, default: str = "") -> str:
    values = qs.get(key)
    return values[0] if values else default


def bool_arg(value: str) -> bool:
    return str(value).lower() in {"1", "true", "yes", "y", "on"}


def build_handler(gateway: CorpusGateway, token: str) -> type[GatewayHandler]:
    class BoundGatewayHandler(GatewayHandler):
        pass

    BoundGatewayHandler.gateway = gateway
    BoundGatewayHandler.token = token
    return BoundGatewayHandler


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="HTTP API for the local SLAM AI corpus.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--corpus-root", default=None)
    parser.add_argument("--token", default=None)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = GatewayConfig.from_env(corpus_root=args.corpus_root, token=args.token)
    gateway = CorpusGateway(config)
    if args.host not in {"127.0.0.1", "localhost"} and not config.token:
        print("WARNING: binding to a non-localhost address without SLAM_AI_GATEWAY_TOKEN.")
    server = ThreadingHTTPServer((args.host, args.port), build_handler(gateway, config.token))
    print(f"SLAM AI HTTP gateway listening on http://{args.host}:{args.port}")
    print(f"Corpus root: {config.corpus_root}")
    server.serve_forever()


if __name__ == "__main__":
    main()

