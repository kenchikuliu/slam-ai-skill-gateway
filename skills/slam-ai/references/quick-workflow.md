# Quick Workflow

Use this when the task is local review, retrieval, or report refresh over the
existing SLAM corpora, especially:

- `references-out\top_venue_reference_expansion`
- `references-out\merged_corpus_review`

This is the default practical path for day-to-day corpus work. It reuses the
unified local CLI:

- `slam_skill_cli.py review-workspace`
- `slam_skill_cli.py refresh`
- `slam_skill_cli.py query`
- `slam_skill_cli.py report`

## Default Corpus

Unless the user explicitly wants root-corpus rebuild work, use:

```text
C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\top_venue_reference_expansion
```

Keep this staged corpus separate from the older root reviewed baseline.

## Fast Loop

### 1. Build or refresh the manual review workspace

```powershell
python slam_skill_cli.py review-workspace --corpus-root C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\top_venue_reference_expansion
```

This writes:

- `unknown_category_review_queue.csv`
- `category_review_packet.md`
- `category_review_packet_medium.md`
- `low_priority_shortlist.md`
- `review_workspace\stage1_manual_overrides.csv`
- `review_workspace\stage1_priority_manual_overrides.csv`
- `review_workspace\stage2_manual_overrides.csv`
- `review_workspace\stage3_manual_overrides.csv`

### 2. Edit the first-pass override file

Start with:

```text
review_workspace\stage1_priority_manual_overrides.csv
```

Fill only:

- `reviewed_category`
- `reason`

Default stage-1 selection rule:

- if `stage1_manual_overrides.csv` has filled rows, `review` and `refresh` use it
- otherwise, if `stage1_priority_manual_overrides.csv` has filled rows, they use that file

Do not fill both stage-1 files at the same time unless you also pass
`--stage1-overrides` explicitly.

### 3. Re-run review, turbovec, and report together

```powershell
python slam_skill_cli.py refresh --corpus-root C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\top_venue_reference_expansion --write-html
```

This does three things in one pass:

1. rebuilds the corpus-local reviewed graph
2. rebuilds turbovec against the reviewed deduped graph
3. refreshes the local report JSON and HTML

Main output:

```text
C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\top_venue_reference_expansion\corpus_report.html
```

### 4. Query the refreshed corpus

```powershell
python slam_skill_cli.py query "gaussian splatting loop closure" --out-dir C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\top_venue_reference_expansion\turbovec-out --category SLAM --top-k 5 --dedupe-papers
```

Use this pattern for:

- Related Work support
- baseline lookup
- topic-specific paper chunk retrieval
- citation hunting before drafting text

## Common Variants

Only refresh the report:

```powershell
python slam_skill_cli.py report --corpus-root C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\top_venue_reference_expansion --write-html
```

Only rebuild the reviewed graph:

```powershell
python slam_skill_cli.py review --corpus-root C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\top_venue_reference_expansion
```

Only rebuild turbovec:

```powershell
python slam_skill_cli.py turbovec-build --root-dir C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\top_venue_reference_expansion
```

## Guardrails

- Prefer the staged top-venue corpus for manual cleanup before touching root reviewed outputs.
- Use `refresh` after override edits instead of stitching separate commands together.
- For import work, switch back to `references/import-policy.md`; this quick workflow is
  for already extracted corpora, not new root ingestion.
