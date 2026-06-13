# Import Policy

## Default Import Choice

When the user asks to "continue import" or "import papers into the corpus", default to:

1. the staged `recent5y_3dgs_slam_reliability` corpus
2. excluding `held_for_review`
3. no automatic Graphify rebuild

Do not bulk-import the full `top_venue_reference_expansion\pdfs` directory into the root unless the user explicitly wants a broad rebuild and accepts the much larger extraction/review surface.

## Recent5Y Import Command

Dry run:

```powershell
python -X utf8 import_recent5y_slam_corpus.py --dry-run
```

Real import:

```powershell
python -X utf8 import_recent5y_slam_corpus.py
```

Include held-for-review only on explicit request:

```powershell
python -X utf8 import_recent5y_slam_corpus.py --include-held-for-review
```

The script writes:

- `references-out\imports\recent5y_root_import\recent5y_import_manifest.json`
- `references-out\imports\recent5y_root_import\recent5y_import_manifest.csv`

## After Import

Importing only copies PDFs into the root corpus. It does not:

- extract markdown
- rebuild Graphify outputs
- update reports or dashboards

If the user wants the corpus truly ingested into the graph pipeline, the next step is:

```powershell
python -X utf8 mineru_batch_processor.py
```

This extractor is resume-safe and skips markdown files that already exist.

## Rebuild Policy

Only after extraction succeeds should you consider:

1. `graphify_batch_processor.py`
2. `export_graphify_formats.py`
3. `export_graphify_neo4j.py`
4. later filtering/review/dedupe/report scripts

Preserve the current reviewed/deduped outputs until the new graph counts look sane.
