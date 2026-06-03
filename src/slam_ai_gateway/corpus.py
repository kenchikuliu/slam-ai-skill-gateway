from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .config import GatewayConfig


def read_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8-sig", errors="replace"))


def safe_int(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def normalize_text(value: str) -> str:
    return re.sub(r"\s+", " ", value or "").strip()


@dataclass
class DailyRunResult:
    started: bool
    command: list[str]
    pid: int | None = None
    exit_code: int | None = None
    stdout: str = ""
    stderr: str = ""


class CorpusGateway:
    def __init__(self, config: GatewayConfig):
        self.config = config

    def health(self) -> dict[str, Any]:
        return {
            "ok": self.config.corpus_root.exists(),
            "corpus_root": str(self.config.corpus_root),
            "merged_graph_exists": self.config.merged_graph_path.exists(),
            "daily_loop_script_exists": self.config.daily_loop_script.exists(),
        }

    def status(self) -> dict[str, Any]:
        root = self.config.corpus_root
        root_pdfs = len(list(root.glob("*.pdf"))) if root.exists() else 0
        markdown_dir = root / "extracted_markdown"
        root_markdown = len(list(markdown_dir.glob("*.md"))) if markdown_dir.exists() else 0
        daily_state = read_json(self.config.daily_state_path, {})
        root_graph = read_json(self.config.root_graph_summary_path, {})
        merged_review = read_json(self.config.merged_review_summary_path, {})
        merged_dedup = read_json(self.config.merged_dedup_summary_path, {})
        merged_neo4j = read_json(self.config.merged_neo4j_summary_path, {})

        return {
            "corpus_root": str(root),
            "root_pdf_count": root_pdfs,
            "root_markdown_count": root_markdown,
            "pending_markdown_count": max(0, root_pdfs - root_markdown),
            "daily_state": daily_state,
            "root_graph_summary": root_graph,
            "merged_review": {
                "generated_at": merged_review.get("generated_at"),
                "copied_main_markdown": merged_review.get("copied_main_markdown"),
                "copied_reference_markdown": merged_review.get("copied_reference_markdown"),
                "citation_graph_summary": merged_review.get("citation_graph_summary", {}),
            },
            "merged_dedup_summary": merged_dedup,
            "merged_neo4j_summary": merged_neo4j,
        }

    def graph_summary(self) -> dict[str, Any]:
        return {
            "root_graph": read_json(self.config.root_graph_summary_path, {}),
            "merged_analysis": read_json(self.config.merged_analysis_path, {}),
            "merged_dedup": read_json(self.config.merged_dedup_summary_path, {}),
            "merged_neo4j": read_json(self.config.merged_neo4j_summary_path, {}),
        }

    def load_graph(self) -> dict[str, Any]:
        return read_json(self.config.merged_graph_path, {"nodes": [], "edges": [], "hyperedges": []})

    def list_papers(self, query: str = "", category: str = "", limit: int = 25) -> dict[str, Any]:
        query_lower = query.lower().strip()
        category_lower = category.lower().strip()
        graph = self.load_graph()
        rows = []
        for node in graph.get("nodes", []):
            if node.get("file_type") != "document":
                continue
            haystack = " ".join(
                str(node.get(key, "")) for key in ("id", "label", "category", "source_file")
            ).lower()
            if query_lower and query_lower not in haystack:
                continue
            if category_lower and str(node.get("category", "")).lower() != category_lower:
                continue
            rows.append(
                {
                    "id": node.get("id", ""),
                    "label": node.get("label", ""),
                    "category": node.get("category", ""),
                    "source_file": node.get("source_file", ""),
                }
            )
        rows.sort(key=lambda row: (row["category"], row["label"]))
        limit = max(1, min(limit, 200))
        return {"count": len(rows), "limit": limit, "papers": rows[:limit]}

    def get_paper(self, paper_id: str, include_text: bool = False, max_chars: int = 6000) -> dict[str, Any]:
        graph = self.load_graph()
        target = None
        for node in graph.get("nodes", []):
            candidates = {
                str(node.get("id", "")),
                str(node.get("source_file", "")),
                str(node.get("label", "")),
            }
            if paper_id in candidates:
                target = node
                break
        if not target:
            return {"found": False, "paper_id": paper_id}

        markdown_path = self.find_markdown(str(target.get("source_file", "")))
        payload: dict[str, Any] = {
            "found": True,
            "paper": target,
            "markdown_path": str(markdown_path) if markdown_path else "",
        }
        if include_text and markdown_path:
            text = markdown_path.read_text(encoding="utf-8", errors="replace")
            payload["text"] = text[: max(1, min(max_chars, 50000))]
            payload["text_truncated"] = len(text) > len(payload["text"])
        return payload

    def find_markdown(self, source_file: str) -> Path | None:
        if not source_file:
            return None
        source_name = Path(source_file).name
        candidates = [source_name]
        if source_name.lower().endswith(".pdf"):
            candidates.append(source_name[:-4] + ".md")
        elif not source_name.lower().endswith(".md"):
            candidates.append(source_name + ".md")
        for md_dir in self.config.markdown_dirs:
            for name in candidates:
                path = md_dir / name
                if path.exists():
                    return path
        return None

    def search_text(self, query: str, limit: int = 10, context_chars: int = 320) -> dict[str, Any]:
        query = query.strip()
        if not query:
            return {"query": query, "count": 0, "matches": []}
        query_lower = query.lower()
        limit = max(1, min(limit, 50))
        context_chars = max(80, min(context_chars, 1200))
        matches = []
        seen: set[Path] = set()
        for md_dir in self.config.markdown_dirs:
            if not md_dir.exists():
                continue
            for path in sorted(md_dir.glob("*.md")):
                resolved = path.resolve()
                if resolved in seen:
                    continue
                seen.add(resolved)
                text = path.read_text(encoding="utf-8", errors="replace")
                idx = text.lower().find(query_lower)
                if idx < 0:
                    continue
                start = max(0, idx - context_chars // 2)
                end = min(len(text), idx + len(query) + context_chars // 2)
                snippet = normalize_text(text[start:end])
                matches.append({"file": path.name, "path": str(path), "snippet": snippet})
                if len(matches) >= limit:
                    return {"query": query, "count": len(matches), "matches": matches}
        return {"query": query, "count": len(matches), "matches": matches}

    def run_daily_loop(self, force: bool = False, wait: bool = False, timeout: int = 3600) -> DailyRunResult:
        script = self.config.daily_loop_script
        command = [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(script),
            "-Root",
            str(self.config.corpus_root),
        ]
        if force:
            command.append("-ForceRun")
        if wait:
            completed = subprocess.run(
                command,
                cwd=str(self.config.corpus_root),
                text=True,
                capture_output=True,
                timeout=timeout,
                check=False,
            )
            return DailyRunResult(
                started=True,
                command=command,
                exit_code=completed.returncode,
                stdout=completed.stdout,
                stderr=completed.stderr,
            )
        process = subprocess.Popen(
            command,
            cwd=str(self.config.corpus_root),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        return DailyRunResult(started=True, command=command, pid=process.pid)
