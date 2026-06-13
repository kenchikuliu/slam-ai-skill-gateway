#!/usr/bin/env python3
"""Lightweight GraphRAG corpus profiler."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


GRAPH_PATTERNS = [
    "**/*merged*reviewed*deduped*.json",
    "**/*final_reviewed*v3*deduped*.json",
    "**/graphify_merged.json",
    "**/graphify_summary.json",
]

VECTOR_PATTERNS = [
    "**/turbovec-out/summary.json",
    "**/chunk_metadata.jsonl",
    "**/chunk_index.tvim",
]

TEXT_SUFFIXES = {".md", ".txt", ".markdown"}
SOURCE_SUFFIXES = {".pdf", ".md", ".txt", ".html", ".htm", ".docx"}


def find_limited(root: Path, pattern: str, limit: int = 25) -> list[str]:
    out: list[str] = []
    for path in root.glob(pattern):
        if path.is_file():
            out.append(str(path))
            if len(out) >= limit:
                break
    return out


def count_files(root: Path, suffixes: set[str]) -> int:
    return sum(1 for p in root.rglob("*") if p.is_file() and p.suffix.lower() in suffixes)


def preferred_vector_for_graph(root: Path, preferred_graph: str, vector_candidates: list[str]) -> str:
    summaries = [Path(p) for p in vector_candidates if p.endswith("summary.json")]
    if not summaries:
        return ""
    if preferred_graph:
        graph_path = Path(preferred_graph)
        for parent in [graph_path.parent, *graph_path.parents]:
            if parent == root.parent:
                break
            candidate = parent / "turbovec-out" / "summary.json"
            if candidate in summaries or candidate.exists():
                return str(candidate)
    return str(summaries[0])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=Path)
    args = parser.parse_args()

    root = args.root.resolve()
    graph_candidates: list[str] = []
    vector_candidates: list[str] = []
    for pattern in GRAPH_PATTERNS:
        graph_candidates.extend(find_limited(root, pattern))
    for pattern in VECTOR_PATTERNS:
        vector_candidates.extend(find_limited(root, pattern))

    extracted_dirs = [str(p) for p in root.rglob("extracted_markdown") if p.is_dir()]
    preferred_graph = graph_candidates[0] if graph_candidates else ""
    payload = {
        "root": str(root),
        "exists": root.exists(),
        "source_like_file_count": count_files(root, SOURCE_SUFFIXES) if root.exists() else 0,
        "text_like_file_count": count_files(root, TEXT_SUFFIXES) if root.exists() else 0,
        "extracted_text_dirs": extracted_dirs[:20],
        "graph_candidates": graph_candidates[:40],
        "preferred_graph": preferred_graph,
        "vector_candidates": vector_candidates[:40],
        "preferred_vector_summary": preferred_vector_for_graph(root, preferred_graph, vector_candidates),
        "missing_steps": [],
    }

    if not extracted_dirs and payload["text_like_file_count"] == 0:
        payload["missing_steps"].append("extract_text")
    if not graph_candidates:
        payload["missing_steps"].append("build_graph")
    if not vector_candidates:
        payload["missing_steps"].append("build_vector_index")

    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
