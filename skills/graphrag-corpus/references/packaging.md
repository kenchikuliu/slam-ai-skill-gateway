# Packaging

Use this when turning a GraphRAG workflow into a reusable skill, API, or MCP gateway.

## Skill Shape

Keep the generic skill separate from corpus profiles:

```text
graphrag-corpus/
  SKILL.md
  references/
  scripts/

domain-corpus-skill/
  SKILL.md
  references/current-state.md
  references/profile.json
```

The generic skill defines workflow. The domain skill defines paths, commands, and policies.

## Profile Manifest

A reusable corpus profile should include:

- corpus name
- root path
- source document paths
- extracted text paths
- preferred graph path
- vector index path
- refresh commands
- query commands
- report paths
- remote API/MCP endpoints if any
- update policy
- safety rules for imports and overwrites

## API Shape

Minimum useful HTTP/MCP surface:

- `status`: corpus counts and freshness
- `query`: graph-aligned semantic retrieval
- `context`: compact evidence pack for an agent
- `graph_summary`: graph counts and category/relation summary
- `refresh`: optional, gated, local-only or authenticated

Prefer `context` over returning raw search results when the caller is another agent.

## Security

- Never commit bearer tokens or tunnel keys.
- Keep local paths and public URLs separate.
- Make refresh endpoints authenticated or local-only.
- Log counts and status, not secret tokens.

