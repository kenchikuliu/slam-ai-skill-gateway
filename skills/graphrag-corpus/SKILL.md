---
name: graphrag-corpus
description: Use when the user wants a reusable enhanced RAG skill over any local knowledge corpus, combining graph artifacts such as Graphify with vector indexes such as turbovec. Applies to PDFs, markdown archives, manuals, research notes, code documentation, paper libraries, product docs, or mixed document folders. Covers corpus profiling, ingestion contracts, graph/vector refresh, hybrid retrieval, graph-expanded evidence packs, agent context bundles, and packaging a corpus as a reusable skill or gateway.
---

# GraphRAG Corpus

## Overview

Use this skill to build or operate a generic graph-plus-vector retrieval layer over a local corpus. The goal is not just "search documents"; it is to return grounded answers with source chunks, document identity, categories, graph neighbors, citations/relations when available, and a compact context bundle an agent can use.

This skill is the orchestration layer above corpus-specific tools such as Graphify, turbovec, LanceDB, Chroma, Neo4j, custom JSON graphs, or existing project scripts.

## Core Model

Treat every corpus as four layers:

1. Source layer: PDFs, markdown, OCR text, manuals, notes, webpages, or code docs.
2. Graph layer: document identity, categories, entities, relations, aliases, provenance, and review state.
3. Vector layer: chunk embeddings and semantic retrieval.
4. Context layer: evidence packs for an agent or user-facing answer.

Prefer a reviewed/deduped graph over a raw graph. Prefer graph-aligned vector metadata over a plain vector index.

## Task Routing

### Profile or Design a Corpus

Read [references/corpus-contract.md](references/corpus-contract.md).

Use this when the user points to a folder or asks whether it can become a GraphRAG corpus. Produce a short profile:

- source path and document types
- extracted text path or missing extraction step
- graph artifacts found or required
- vector artifacts found or required
- refresh command candidates
- query command candidates
- risks: no provenance, no stable ids, no reviewed graph, missing text extraction

Run the helper when useful:

```powershell
python C:\Users\Administrator\.codex\skills\graphrag-corpus\scripts\profile_corpus.py --root <corpus-root>
```

### Build or Refresh GraphRAG

Read [references/refresh-workflow.md](references/refresh-workflow.md).

Use this when a corpus already has extracted text or existing graph/vector scripts. Default order:

1. validate source and extracted text counts
2. build or refresh graph artifacts
3. apply review/dedupe/category cleanup if the corpus supports it
4. rebuild vector index against the intended graph
5. write or refresh summary/report artifacts
6. smoke-test one representative query

Do not overwrite reviewed graph outputs with raw graph outputs unless the user explicitly asks.

### Query or Answer with GraphRAG

Read [references/query-patterns.md](references/query-patterns.md).

Use this when the user asks a domain question against a corpus. Default query flow:

1. choose corpus/profile and answer mode
2. use graph filters when category, entity, relation, time, source, or document type are known
3. run vector retrieval over the graph-aligned index
4. expand results through graph neighbors, citations, aliases, or related documents
5. return an evidence pack, then answer from it

Supported answer modes:

- `lookup`: find exact documents or snippets
- `explain`: answer with cited evidence
- `compare`: contrast documents, methods, products, policies, or notes
- `related-work`: organize literature or background
- `baseline-selection`: choose representative prior work or comparable items
- `gap-analysis`: identify missing coverage, contradictions, or weakly supported areas
- `brief`: compact context bundle for another agent

### Package as a Reusable Skill or Gateway

Read [references/packaging.md](references/packaging.md).

Use this when the user wants a reusable skill, API, MCP server, or remote agent context interface. Keep corpus-specific profiles separate from the generic skill.

## Output Contract

When answering from a GraphRAG corpus, include enough provenance to audit the answer:

- corpus/profile used
- graph path or graph source when available
- vector index path or retrieval backend
- document id/source file for each key claim
- short quoted or paraphrased evidence snippets
- graph relations used, if any
- uncertainty when only vector text matched and no graph-backed document exists

## Working Rules

- Never invent citations, document ids, or graph relations.
- If a corpus has both raw and reviewed graph outputs, prefer reviewed/deduped.
- If graph and vector summaries disagree, stop and verify paths before using results.
- For broad user questions, retrieve first, then synthesize; do not answer from memory.
- Keep generated context bundles compact. Put raw long outputs in files when needed.
- Preserve stable document identity from graph to vector metadata.
- Treat subject-specific corpora as profiles, not hard-coded behavior in this generic skill.

## References

- [references/corpus-contract.md](references/corpus-contract.md): minimum layout and artifact contract
- [references/refresh-workflow.md](references/refresh-workflow.md): graph/vector refresh workflow
- [references/query-patterns.md](references/query-patterns.md): hybrid retrieval and evidence-pack patterns
- [references/packaging.md](references/packaging.md): turning a corpus workflow into a skill, API, or MCP gateway

