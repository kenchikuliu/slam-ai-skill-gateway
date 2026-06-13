# Corpus Contract

Use this when profiling a new corpus for GraphRAG.

## Minimal Inputs

A corpus needs at least:

- source documents: PDFs, markdown, text, HTML, code docs, notes, or mixed files
- extracted text: markdown or text files with stable names
- provenance: a way to map chunks back to source documents

Without extracted text, the first task is ingestion/OCR/extraction, not RAG.

## Preferred Artifacts

Graph layer:

- graph JSON with `nodes` and `edges`
- document nodes with stable `id`, `label`, `source_file`, and `category`
- alias or dedupe fields when available
- relation names that are meaningful to the domain

Vector layer:

- chunk index
- chunk metadata JSONL or equivalent
- summary JSON with chunk counts, document counts, graph path, model name
- query command or API

Review layer:

- category overrides
- dedupe manifests
- review queues
- unresolved/unknown category reports

Report layer:

- summary JSON
- HTML report or browseable output
- refresh logs

## Profile Checklist

For a new root path, report:

- `source_count`
- `extracted_text_count`
- `graph_candidates`
- `preferred_graph`
- `vector_candidates`
- `preferred_vector`
- `known_refresh_commands`
- `known_query_commands`
- `missing_steps`
- `risk_notes`

## Path Selection

Preferred graph order:

1. reviewed + identity-deduped graph
2. reviewed + version-deduped graph
3. reviewed graph
4. recategorized filtered graph
5. raw merged graph
6. raw graph

Preferred vector order:

1. graph-aligned vector index whose summary points to the preferred graph
2. graph-aligned vector index whose graph path is stale but fixable
3. plain vector index with source-file metadata
4. full-text search fallback

If the chosen graph and vector summaries disagree, rebuild the vector index or explicitly explain the mismatch before answering.

