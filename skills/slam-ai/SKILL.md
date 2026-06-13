---
name: slam-ai
description: Use when the user wants to expand, import, refresh, search, cite, or operate the local SLAM literature corpus in C:\Users\Administrator\Downloads\3DGS-SLAM-Papers, especially for 3DGS/Gaussian-Splatting SLAM, daily arXiv pulls, top-venue reference harvesting, public-OA reference completion, staged-PDF imports into the root corpus, paper-writing citations, Related Work support, and follow-on extraction or graph rebuild work.
---

# SLAM AI

## Overview

Use this skill for the local `3DGS-SLAM-Papers` workspace when the task is about maintaining the paper corpus rather than just reading one file. The current setup already includes a daily arXiv closed loop, reference harvesting, public-OA completion, conservative staged imports, extraction/OCR, Graphify rebuilds, and a local Graphify+turbovec workflow unified under `slam_skill_cli.py`.

Start by reading [references/current-state.md](references/current-state.md). For the default local review/query/report loop, then read [references/quick-workflow.md](references/quick-workflow.md). Read the other reference files only for the path you are taking.

## Task Routing

### Daily paper sync or new staged downloads

Read [references/automation.md](references/automation.md).

Use:

- `run_daily_slam_skill_full_update_if_needed.ps1` for the active daily closed loop
- `auto_arxiv_slam_skill_sync.py` for daily arXiv pulls and top-venue reference staging
- `import_daily_arxiv_to_root.py` for safe root import of newly downloaded `core_gaussian_slam` daily arXiv PDFs
- `aggressive_reference_backfill.py` for public-source retries on missing references
- `public_oa_reference_sweep.py` for the final high-confidence public-OA pass

Daily arXiv PDFs are a closed-loop exception only for the conservative `core_gaussian_slam` bucket: the full-loop guard imports new valid core daily arXiv PDFs into the root, runs extraction/OCR, rebuilds root Graphify, and rebuilds the merged reviewed graph when new root PDFs arrive. Broader daily buckets such as `general_3dgs`, `general_slam`, and `reliability_slam` are staged and reported for review by default. Keep top-venue reference expansion outputs in `references-out/` unless the user explicitly asks for broad root import.

### Import staged papers into the root corpus

Read [references/import-policy.md](references/import-policy.md).

Default policy:

- import `recent5y_3dgs_slam_reliability` first
- exclude `held_for_review` unless the user explicitly wants broader coverage
- do not bulk-import the `top_venue_reference_expansion/pdfs` directory into the root by default

Use `import_recent5y_slam_corpus.py` for recent5y imports. It writes manifests under `references-out/imports/`.

### Local review, retrieval, graph rebuild, or report regeneration

Read [references/quick-workflow.md](references/quick-workflow.md) for the default practical path. Use [references/import-policy.md](references/import-policy.md) only when this work follows a new import.

Then use the repo scripts:

- `slam_skill_cli.py review-workspace` to build a corpus-local review queue and override templates
- `slam_skill_cli.py refresh` to rerun review, rebuild turbovec, and refresh report artifacts in one pass
- `slam_skill_cli.py query` for local semantic retrieval over the corpus
- `slam_skill_cli.py report --write-html` for a local HTML report
- `slam_skill_cli.py turbovec-build` for one corpus
- `slam_skill_cli.py turbovec-build-all` for all discovered corpora
- `slam_skill_cli.py review` when the user only wants the reviewed graph pipeline without rebuilding turbovec
- `mineru_batch_processor.py`
- `graphify_batch_processor.py`
- `export_graphify_formats.py`
- `export_graphify_neo4j.py`
- `run_top_venue_reference_ocr_graphify.py` for the staged `top_venue_reference_expansion` corpus
- `refine_graphify_graph.py`
- later review/dedupe/report builders as needed

Default local operating pattern:

- for staged corpora such as `references-out\top_venue_reference_expansion`, prefer the corpus-local reviewed graph rather than touching the root reviewed baseline
- generate `review-workspace` before manual category cleanup
- after editing override CSVs, prefer `refresh` over separate review/build/report commands
- use the lower-level scripts only when the user needs a specific stage or debugging surface

Do not overwrite the existing reviewed/deduped graph outputs unless the user explicitly wants a new graph version. Prefer rerunning extraction first, then validate counts before touching review-stage outputs.

### Merge staged references into a reviewed corpus

Use this path when the user wants the staged `top_venue_reference_expansion` corpus merged with the main root corpus at citation/concept level, followed by category review and dedupe.

Use:

- `run_merged_corpus_review_pipeline.py` for the end-to-end merged workspace build
- `merge_corpus_graphs_with_citations.py` for graph merge plus accepted local citation edges
- `dedupe_merged_graph_by_identity.py` for cross-corpus identity dedupe

Write merged reviewed outputs under `references-out/merged_corpus_review/`. Keep this separate from the older main reviewed baseline unless the user explicitly asks to replace it.

### Remote access, HTTP API, or MCP gateway

Read [references/remote-access.md](references/remote-access.md).

Use this path when the user asks whether other computers can use the SLAM AI corpus, wants LAN/public access, wants a tunnelto URL, wants API examples, or asks about MCP access from another machine.

Current gateway facts:

- Gateway repo: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway`
- HTTP API port: `8766`
- Local gateway config/token file: `tmp\gateway_8766.env.json`
- Public tunnel state file: `tmp\tunnelto_8766.state.json`
- Do not write tunnelto access keys or SLAM bearer tokens into Git or skill docs.
- Stdio MCP is local to the machine running the MCP client. Other computers should use the HTTP API unless a separate HTTP-to-MCP bridge is added.

### Paper writing citations or Related Work support

Use this path when the user writes a SLAM / 3DGS-SLAM / Gaussian Splatting mapping paper and needs citations, baselines, Related Work organization, or recent paper support.

Default behavior:

- Search the local corpus before relying on memory for SLAM citations.
- Prefer `slam_skill_cli.py query` against the relevant corpus before hand-picking citations from memory.
- Prefer current corpus papers for "latest" or recent-work claims, but check `references/current-state.md` and daily-loop state before claiming freshness.
- Do not invent citations. Use only papers found in the local corpus, the user's bibliography, Zotero/library context, or verified external sources.
- Group Related Work by technical role, not by a raw chronological citation list.
- If writing uses `$research-paper-writing`, combine that skill's section structure with this corpus as the citation source.

## Working Rules

- Treat `references-out/` as staging and audit space, except for `core_gaussian_slam` daily arXiv PDFs handled by the full-loop guard.
- Use public/open-access routes only for automated paper acquisition.
- Prefer manifest-driven imports over ad hoc file copies.
- For local review, retrieval, and report tasks, prefer `slam_skill_cli.py` over stitching Graphify and turbovec scripts together by hand.
- After manual category edits in a staged corpus, prefer `slam_skill_cli.py refresh`.
- When the user says "continue import", default to the recent5y staged corpus, not the full 811 staged reference PDFs.
- After importing to the root, report the new root PDF count and the pending markdown extraction count.

## References

- [references/current-state.md](references/current-state.md): current corpus counts, paths, and manifests
- [references/quick-workflow.md](references/quick-workflow.md): shortest local review, refresh, and query loop
- [references/import-policy.md](references/import-policy.md): safe import commands and extraction policy
- [references/automation.md](references/automation.md): daily pull, reference expansion, OA sweep, scheduler status
- [references/remote-access.md](references/remote-access.md): HTTP gateway, tunnelto, other-computer usage, and MCP boundary
