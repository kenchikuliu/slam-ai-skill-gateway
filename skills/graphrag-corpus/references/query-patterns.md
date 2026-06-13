# Query Patterns

Use this when answering questions from a GraphRAG corpus.

## Evidence Pack

Return or internally build this structure:

```json
{
  "query": "...",
  "mode": "explain",
  "corpus": "...",
  "graph_path": "...",
  "vector_index": "...",
  "results": [
    {
      "document_id": "...",
      "source_file": "...",
      "category": "...",
      "score": 0.0,
      "snippet": "...",
      "graph_neighbors": [
        {"relation": "cites", "document_id": "..."}
      ]
    }
  ]
}
```

The final answer should cite source files or document ids, not just say "the corpus says".

## Retrieval Patterns

Lookup:

- use exact title/source/id filters first
- then vector search for synonyms

Explain:

- retrieve top chunks
- group by document
- include only evidence-backed claims

Compare:

- retrieve each item separately
- build a table of dimensions from the graph and snippets

Related work or background:

- retrieve broadly
- expand via graph relations
- group by technical role, not chronology

Gap analysis:

- retrieve positive matches
- inspect categories and missing graph coverage
- call out weak evidence explicitly

Brief for another agent:

- keep only high-signal snippets
- include query, corpus, graph/vector paths, and caveats

## Reranking Heuristics

Prefer results that have:

- graph-backed document identity
- reviewed category
- direct phrase match in title or section
- strong vector score
- useful graph neighbors
- recent or canonical status when the domain cares about recency

Do not over-rank a result merely because it is highly connected in the graph.

