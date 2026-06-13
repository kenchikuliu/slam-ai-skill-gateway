# Automation

## Daily Closed-Loop Update

Active full-loop guard:

```text
C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\run_daily_slam_skill_full_update_if_needed.ps1
```

This is the live daily automation entry. It runs at most once per local day after
a successful completion. If the previous attempt failed, it allows a same-day
retry.

Daily loop:

1. stage latest arXiv candidates with `auto_arxiv_slam_skill_sync.py daily`
2. safely import newly downloaded `core_gaussian_slam` daily arXiv PDFs into the root corpus with `import_daily_arxiv_to_root.py`
3. run `mineru_batch_processor.py` only when new PDFs were imported or root markdown is pending
4. rebuild root Graphify outputs and Neo4j exports after extraction
5. rebuild the merged reviewed corpus after Graphify, unless explicitly skipped
6. write full-loop state under `references-out\arxiv_daily`

Run manually:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\run_daily_slam_skill_full_update_if_needed.ps1
```

Force a same-day rerun:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\run_daily_slam_skill_full_update_if_needed.ps1 -ForceRun
```

State:

```text
C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\arxiv_daily\full_automation_state.json
C:\Users\Administrator\.codex\skills\slam-ai\references\daily-loop-state.md
```

The old `run_daily_arxiv_pull_if_needed.ps1` entry is now a compatibility
wrapper that forwards to this full-loop guard.

## Staged arXiv Pull Internals

Script used by the full-loop guard:

```text
C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\auto_arxiv_slam_skill_sync.py
```

Command:

```powershell
python -X utf8 auto_arxiv_slam_skill_sync.py daily --lookback-days 3 --max-results-per-query 50
```

The staged pull records per-query success/failure counts and bucket counts. It
monitors core 3DGS-SLAM plus broader 3DGS and SLAM/VO/mapping/localization
queries. Broad buckets such as `general_3dgs`, `general_slam`, and
`reliability_slam` are staged and reported but are not root-imported by default.
If every arXiv query fails, for example due to HTTP 429 rate limiting, the
command exits non-zero instead of silently writing a false "0 new papers"
success.

Import helper used by the full-loop guard:

```text
C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\import_daily_arxiv_to_root.py
```

This helper imports only valid staged `core_gaussian_slam` daily PDFs from the
latest manifest by default, skips arXiv IDs already present in root, validates
PDF headers, holds broad buckets for review, and writes:

```text
C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\imports\daily_arxiv_root_import\daily_arxiv_import_manifest.json
```

Startup launcher:

```text
C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-daily-arxiv-pull.cmd
```

Output:

```text
C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\arxiv_daily
```

## Top-Venue Reference Expansion

Initial reference harvest:

```powershell
python -X utf8 auto_arxiv_slam_skill_sync.py top-venue-references
```

Output:

```text
C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\top_venue_reference_expansion
```

## Public Completion Passes

Semantic-Scholar-missing-source retry:

```powershell
python -X utf8 aggressive_reference_backfill.py --only-source-refs
```

Final high-confidence OA sweep over unresolved references:

```powershell
python -X utf8 public_oa_reference_sweep.py --oa-only
```

Optional slower title-search retry:

```powershell
python -X utf8 public_oa_reference_sweep.py --oa-only --title-search
```

Do not enable `--title-search` by default. It is slower and may hit ambiguous publisher/title matches.

Official publisher-access retry without proxy:

```powershell
python -X utf8 publisher_access_reference_retry.py --no-resume
```

Use this only when the user explicitly wants to retry through legitimate publisher access on the current network. The script clears proxy environment variables for its process, uses DOI/Crossref and official publisher PDF routes, validates downloaded PDFs against the cited title before keeping them, and does not bypass logins or paywalls.

## Scheduler Status

Windows scheduled-task registration was retried with both `Register-ScheduledTask` and `schtasks /Create`, and both returned `Access is denied` in the current environment.

The live fallback is a Startup-folder launcher that invokes `run_daily_slam_skill_full_update_if_needed.ps1` on login. The guard records `full_automation_state.json`, runs the full loop at most once per local calendar day after success, and permits same-day retry after failure.

If host policy later permits Task Scheduler, `register_daily_arxiv_pull_task.ps1`
now registers the same full-loop guard rather than the old staged-only pull.

## Guardrails

- daily arXiv `core_gaussian_slam` PDFs are explicitly allowed to import into root because the user requested a closed daily loop
- broad daily arXiv buckets are staged/reported and should not be root-imported unless the user explicitly asks for broader import
- keep top-venue reference expansion PDFs under `references-out/` unless the user explicitly asks for broad root import
- do not bypass paywalls or logins
- publisher-access retry is allowed only through official routes and only when direct access returns a valid matching PDF
- extraction/OCR and Graphify run only when new root PDFs arrive or root markdown is pending; they are skipped on no-op days
- the Startup fallback triggers on login, not at a fixed wall-clock time; use Task Scheduler only if the host policy later allows it
