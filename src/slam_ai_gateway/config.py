from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


DEFAULT_CORPUS_ROOT = Path("C:/Users/Administrator/Downloads/3DGS-SLAM-Papers")


@dataclass(frozen=True)
class GatewayConfig:
    corpus_root: Path
    token: str

    @classmethod
    def from_env(cls, corpus_root: str | None = None, token: str | None = None) -> "GatewayConfig":
        root_value = corpus_root or os.environ.get("SLAM_AI_CORPUS_ROOT") or str(DEFAULT_CORPUS_ROOT)
        token_value = token if token is not None else os.environ.get("SLAM_AI_GATEWAY_TOKEN", "")
        return cls(corpus_root=Path(root_value), token=token_value)

    @property
    def daily_state_path(self) -> Path:
        return self.corpus_root / "references-out" / "arxiv_daily" / "full_automation_state.json"

    @property
    def daily_loop_script(self) -> Path:
        return self.corpus_root / "run_daily_slam_skill_full_update_if_needed.ps1"

    @property
    def root_graph_summary_path(self) -> Path:
        return self.corpus_root / "graphify-out" / "graphify_summary.json"

    @property
    def merged_review_summary_path(self) -> Path:
        return self.corpus_root / "references-out" / "merged_corpus_review" / "merged_review_pipeline_summary.json"

    @property
    def merged_graph_path(self) -> Path:
        return (
            self.corpus_root
            / "references-out"
            / "merged_corpus_review"
            / "graphify-out"
            / "filtered"
            / "recategorized"
            / "final_reviewed"
            / "final_reviewed_v2"
            / "final_reviewed_v3"
            / "deduped"
            / "graphify_merged_reviewed_deduped.json"
        )

    @property
    def merged_analysis_path(self) -> Path:
        return self.merged_graph_path.parent / "graph_analysis.json"

    @property
    def merged_dedup_summary_path(self) -> Path:
        return self.merged_graph_path.parent / "summary.json"

    @property
    def merged_neo4j_summary_path(self) -> Path:
        return self.merged_graph_path.parent / "neo4j" / "summary.json"

    @property
    def markdown_dirs(self) -> list[Path]:
        return [
            self.corpus_root / "extracted_markdown",
            self.corpus_root / "references-out" / "top_venue_reference_expansion" / "extracted_markdown",
            self.corpus_root / "references-out" / "merged_corpus_review" / "extracted_markdown",
        ]

