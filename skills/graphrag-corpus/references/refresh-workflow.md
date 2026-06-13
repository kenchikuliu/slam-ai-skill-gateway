# Refresh Workflow

Use this when updating a GraphRAG corpus after new documents, new extracted text, or graph-review changes.

## Default Order

1. Count source documents and extracted text.
2. Run missing extraction only if needed.
3. Rebuild raw graph from extracted text.
4. Rebuild or preserve reviewed graph according to local policy.
5. Apply manual category/dedupe overrides.
6. Export graph formats if the corpus supports them.
7. Rebuild vector index against the intended reviewed graph.
8. Refresh summary/report artifacts.
9. Smoke-test a representative query.
10. Write status back to the corpus profile or skill state file.

## Guardrails

- Do not replace a curated graph with a raw graph.
- Prefer resume-safe extraction.
- Keep staged or experimental corpora separate from canonical corpora.
- Store import manifests and refresh summaries.
- If a graph path changed, verify vector metadata points to the new graph.

## Validation

A refresh is complete only when:

- source/extracted counts are plausible
- graph summary exists and points to the intended corpus
- vector summary exists and points to the intended graph
- at least one domain query returns expected results
- report output exists if the corpus has a report layer
- status files are updated

## Common Commands

Use local wrappers when they exist. Examples:

```powershell
python corpus_cli.py refresh --corpus-root <root> --write-html
python corpus_cli.py turbovec-build --root-dir <root> --graph-path <reviewed-graph>
python corpus_cli.py query "topic" --out-dir <root>\turbovec-out --top-k 5
```

Do not assume these exact names. Inspect the repository first.

