# Current State

## Workspace

- Root corpus: `C:\Users\Administrator\Downloads\3DGS-SLAM-Papers`
- Current date anchor: `2026-06-12`
- Unified local corpus CLI: `slam_skill_cli.py`
- Local CLI subcommands:
  - `review`
  - `review-workspace`
  - `refresh`
  - `turbovec-build`
  - `turbovec-build-all`
  - `query`
  - `report`

## Root Corpus Snapshot

- Root PDFs: `945`
- Extracted markdown files: `945`
- Pending markdown extractions after the latest import: `0`

The raw Graphify snapshot has already been refreshed after the latest import:

- `graphify-out\graphify_summary.json`
  - `source_markdown_count`: `945`
  - `node_count`: `1113`
  - `edge_count`: `13097`
  - `hyperedge_count`: `12`

The reviewed filtered/deduped graph and report chain is still the older curated baseline until a deliberate re-review pass is run.

## Merged Reviewed Corpus

- Workspace: `references-out\merged_corpus_review`
- Driver script: `run_merged_corpus_review_pipeline.py`
- Inputs merged on `2026-06-12`:
  - main markdown: `945`
  - staged top-venue markdown: `848`
  - combined markdown: `1793`
- Combined reference layer:
  - `references-out\merged_corpus_review\references-out\summary.json`
  - `total_reference_entries`: `89053`
  - `unique_reference_entries`: `75815`
- Standardized reference layer:
  - `references-out\merged_corpus_review\references-out\standardized\summary.json`
  - `unique_standardized_references`: `44798`
  - `references_with_arxiv_id`: `4332`
  - `references_with_doi`: `1117`
- Local citation recovery:
  - `references-out\merged_corpus_review\references-out\citation-graph\summary.json`
  - accepted high-confidence citation edges added into graph merge: `1380`
  - source papers with local citations: `1269`
  - target local papers cited: `371`
- Merged raw graph:
  - `references-out\merged_corpus_review\graphify-out\graphify_merged_summary.json`
  - `merged_nodes`: `1961`
  - `merged_edges`: `24111`
- Recategorization result:
  - `unknown_document_count_before`: `1122`
  - `unknown_document_count_after`: `0`
- Final reviewed + deduped output:
  - `references-out\merged_corpus_review\graphify-out\filtered\recategorized\final_reviewed\final_reviewed_v2\final_reviewed_v3\deduped\graphify_merged_reviewed_deduped.json`
  - document nodes after full dedupe: `1768`
  - total nodes: `1877`
  - total edges: `5289`
  - hyperedges: `9`
- Neo4j export:
  - `references-out\merged_corpus_review\graphify-out\filtered\recategorized\final_reviewed\final_reviewed_v2\final_reviewed_v3\deduped\neo4j`
  - `node_rows`: `1877`
  - `edge_rows`: `5289`
  - `hyperedge_member_rows`: `1775`
- Identity dedupe outcome:
  - cross-corpus identity merges: `27`
  - breakdown: `26` title-based, `1` arXiv-based
- Version dedupe outcome:
  - alias/version merges: `27`

Merged turbovec output:

- `references-out\merged_corpus_review\turbovec-out\summary.json`
- graph path: `references-out\merged_corpus_review\graphify-out\filtered\recategorized\final_reviewed\final_reviewed_v2\final_reviewed_v3\deduped\graphify_merged_reviewed_deduped.json`
- papers after identity dedupe: `1768`
- chunks: `58852`
- unmapped files: `0`
- category chunk counts:
  - `SLAM`: `15115`
  - `Robotics`: `9942`
  - `General`: `29754`
  - `SLAM-Supplement`: `4041`

## Recent5Y Staged Corpus

- Path: `references-out\recent5y_3dgs_slam_reliability`
- Staged PDFs: `180`
- Source window: `2021-06-02` to `2026-06-02`
- Buckets:
  - `core_gaussian_slam`: `92`
  - `reliability_slam`: `88`

Latest root import manifest:

- `references-out\imports\recent5y_root_import\recent5y_import_manifest.json`

Import result on `2026-06-03`:

- Selected rows: `180`
- Imported into root: `128`
- Already in root: `52`
- Held-for-review remains excluded

## Top-Venue Reference Expansion

- Path: `references-out\top_venue_reference_expansion`
- Final staged reference PDFs: `848`
- Total bytes: `8997744859` (`8.38 GiB`)
- Verified: `0` bad PDF headers, `0` tiny fake files
- OCR/markdown output path: `references-out\top_venue_reference_expansion\extracted_markdown`
- Staged markdown files: `848`
- Staged Graphify output path: `references-out\top_venue_reference_expansion\graphify-out`
- Staged Graphify summary:
  - `source_markdown_count`: `848`
  - `node_count`: `885`
  - `edge_count`: `9634`
  - `hyperedge_count`: `1`
- Corpus-local reviewed pipeline summary:
  - `references-out\top_venue_reference_expansion\review_pipeline_summary.json`
- Corpus-local reviewed + deduped graph:
  - `references-out\top_venue_reference_expansion\graphify-out\filtered\recategorized\final_reviewed\final_reviewed_v2\final_reviewed_v3\deduped\graphify_final_reviewed_v3_deduped.json`
  - reviewed documents: `848`
  - reviewed nodes: `868`
  - reviewed edges: `1544`
  - category counts:
    - `SLAM`: `296`
    - `Robotics`: `275`
    - `General`: `179`
    - `SLAM-Supplement`: `98`
- Review workspace:
  - `references-out\top_venue_reference_expansion\graphify-out\filtered\recategorized\review_workspace`
  - total queue items: `848`
  - high priority: `403`
  - medium priority: `116`
  - low priority: `329`
  - low shortlist: `25`
- Local turbovec output:
  - `references-out\top_venue_reference_expansion\turbovec-out\summary.json`
  - graph path points at the reviewed deduped graph above
  - papers: `848`
  - chunks: `13595`
  - category chunk counts:
    - `SLAM`: `5067`
    - `Robotics`: `3961`
    - `General`: `2884`
    - `SLAM-Supplement`: `1683`
- Local HTML report:
  - `references-out\top_venue_reference_expansion\corpus_report.html`
- Staged Neo4j export:
  - `node_rows`: `885`
  - `edge_rows`: `9634`
  - `hyperedge_member_rows`: `848`
- OCR-aware pipeline wrapper:
  - `run_top_venue_reference_ocr_graphify.py`
- Latest extraction pass on `2026-06-03`:
  - `OK-LOCAL`: `848`
  - `OK-OCR`: `0`
  - `OK-API`: `0`
  - `FAIL`: `0`

Important manifests:

- `reference_download_manifest.json`
- `aggressive_backfill\aggressive_backfill_manifest.json`
- `public_oa_sweep\public_oa_sweep_manifest.json`
- `public_oa_sweep\materialize_skipped_manifest.json`
- `publisher_access_retry\publisher_access_retry_manifest.json`
- `ocr_graphify_summary.json`

Recommended local workflow for this corpus:

1. `python slam_skill_cli.py review-workspace --corpus-root C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\top_venue_reference_expansion`
2. edit `review_workspace\stage1_priority_manual_overrides.csv` first
3. `python slam_skill_cli.py refresh --corpus-root C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\top_venue_reference_expansion --write-html`
4. `python slam_skill_cli.py query "<topic>" --out-dir C:\Users\Administrator\Downloads\3DGS-SLAM-Papers\references-out\top_venue_reference_expansion\turbovec-out --top-k 5 --dedupe-papers`

See `references/quick-workflow.md` for the shorter reusable version of this path.

Public OA sweep result:

- Processed unresolved references: `642`
- Successful/already present: `67`
- Newly downloaded: `62`
- Remaining misses: `575`

Official publisher-access retry without proxy:

- Script: `publisher_access_reference_retry.py`
- Scope: official DOI / publisher PDF routes only; uses no proxy and does not bypass logins or paywalls
- Input unresolved references: `575`
- Successful/already present after validation: `38`
- Newly downloaded in the final validated rerun: `2`
- Additional usable PDFs retained from the official retry set: `37`
- Validation failed and excluded: `1`
- Remaining unresolved after official retry: `537`
- Common unresolved causes:
  - no official DOI/PDF candidate: `338`
  - IEEE/publisher HTTP `502`: `102`
  - publisher HTTP `403`: `33`

## Daily Automation

- Active full-loop guard: `run_daily_slam_skill_full_update_if_needed.ps1`
- Compatibility guard: `run_daily_arxiv_pull_if_needed.ps1` now forwards to the full-loop guard
- Staged arXiv pull script: `auto_arxiv_slam_skill_sync.py`
- Daily root import helper: `import_daily_arxiv_to_root.py`
- Startup launcher: `C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-daily-arxiv-pull.cmd`
- Full-loop state: `references-out\arxiv_daily\full_automation_state.json`
- Daily loop behavior:
  - pull latest arXiv candidates across core 3DGS-SLAM, broad 3DGS, and broad SLAM/VO/mapping/localization
  - import valid newly downloaded `core_gaussian_slam` daily arXiv PDFs into root
  - hold `general_3dgs`, `general_slam`, and `reliability_slam` daily buckets for review
  - run extraction/OCR only when new root PDFs arrive or markdown is pending
  - rebuild root Graphify and Neo4j exports after extraction
  - rebuild the merged reviewed graph after Graphify
  - skip heavy ingest steps on no-op days
- Latest full-loop state:
  - `last_attempt_local_date`: `2026-06-12`
  - `last_result`: `success`
  - `last_candidate_count`: `12`
  - `last_download_count`: `6`
  - `last_imported_count`: `0`
  - `last_pending_markdown_count`: `0`
  - `last_extraction_ran`: `false`
  - `last_graphify_ran`: `false`
  - `last_merged_review_ran`: `false`
- Latest widened daily validation on `2026-06-12T00:54:39`:
  - candidates: `12`
  - downloads/staged: `6`
  - skipped existing arXiv IDs: `6`
  - `general_3dgs`: `10` candidates, `5` downloads/staged
  - `reliability_slam`: `2` candidates, `1` download/staged
  - default root-import eligible candidates: `0`
  - held for review by default: `12`
- Latest manual daily staging review on `2026-06-12T14:50:48`:
  - review note: `references-out\arxiv_daily\reviews\2026-06-12_daily_staging_review.md`
  - reviewed downloads: `6`
  - manually approved root import: `1`
  - imported paper: `2606.11880` SG2Loc: Sequential Visual Localization on 3D Scene Graphs
  - import manifest: `references-out\imports\daily_arxiv_root_import\daily_arxiv_import_manifest.json`
  - held after review: `5`
  - extraction result: root markdown refreshed to `945` files with `0` pending
  - raw Graphify refreshed after extraction: `945` markdown, `1113` nodes, `13097` edges, `12` hyperedges
- Latest merged review and turbovec full refresh on `2026-06-12T15:20:15`:
  - merged reviewed corpus rebuilt from `945` root markdown + `848` top-venue markdown
  - merged final identity-dedup graph: `1768` document nodes, `1877` total nodes, `5289` edges, `9` hyperedges
  - merged Neo4j export: `1877` node rows, `5289` edge rows, `1775` hyperedge-member rows
  - turbovec corpora refreshed: `3`
  - root turbovec: `945` markdown, `817` graph-backed papers, `45257` chunks
  - merged turbovec: `1793` markdown, `1768` identity-dedup papers, `58852` chunks, `0` unmapped files
  - top-venue turbovec: `848` markdown, `848` papers, `13595` chunks
  - merged query smoke test: `SG2Loc scene graph visual localization` returns `2606.11880` as rank `1`
  - all-summary manifest: `turbovec-corpora-summary.json`
  - refreshed HTML reports: `corpus_report.html`, `references-out\merged_corpus_review\corpus_report.html`, `references-out\top_venue_reference_expansion\corpus_report.html`
- Retry policy: after success the guard skips repeat runs on the same local day; after failure it allows same-day retry.
- Windows scheduled-task registration was attempted, but task creation returned `Access is denied`. The active fallback is the Startup-folder launcher, which runs the full-loop guard on login.

## Remote Gateway

- Gateway repo: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway`
- GitHub repo: `https://github.com/kenchikuliu/slam-ai-skill-gateway`
- Latest gateway commits:
  - `5912431` Add startup remote access self-check
  - `8b66aa1` Add manifest-first remote examples
  - `8f289aa` Add Cloudflare named tunnel support
  - `9d1a7de` Update public SLAM AI endpoint manifest
  - `5502dd8` Wait for Cloudflare readiness before publishing endpoint
  - `b549960` Add self-healing public endpoint watchdog
  - `8dfa52f` Add resilient public endpoint manifest
  - `45ef6e9` Add reverse tunnel watchdog
  - `57cd28b` Improve reverse tunnel startup status
  - `62d5394` Add Bandwagon VPS fixed tunnel setup
  - `ed76973` Add Cloudflare quick tunnel helper
  - `a7baea5` Add remote skill context interface
- Public endpoint manifest:
  - tracked file: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\public\slam-ai-endpoints.json`
  - raw URL: `https://raw.githubusercontent.com/kenchikuliu/slam-ai-skill-gateway/main/public/slam-ai-endpoints.json`
  - token policy: `token_included=false`; do not put bearer tokens in Git
  - remote-client rule: use `active_base_url`, or the lowest-priority endpoint with `health_ok=true`
  - remote-client examples: `examples\query_status.ps1`, `examples\search_papers.ps1`, and `examples\query_skill_context.ps1` now resolve `active_base_url` from the GitHub manifest by default
  - base URL override: set `SLAM_AI_BASE_URL` only to force a specific LAN/VPS/tunnel endpoint; set `SLAM_AI_ENDPOINT_MANIFEST_URL` only to use a different manifest
  - current active base URL on `2026-06-04`: `https://daisy-limousines-brunswick-park.trycloudflare.com`
  - current priority order after Named Tunnel support:
    - Cloudflare Named Tunnel priority `5` when configured and healthy
    - Cloudflare Quick Tunnel priority `10` when healthy
    - HK VPS path proxy priority `20` when healthy
- HTTP gateway:
  - host: `0.0.0.0`
  - port: `8766`
  - config/token state: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\gateway_8766.env.json`
  - login startup: `C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-gateway-8766.cmd`
  - remote access startup self-check: `C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-remote-access-check.cmd`
  - self-check script: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\check_remote_access_on_startup.ps1`
  - self-check state/log:
    - `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\remote_access_startup_check.state.json`
    - `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\remote_access_startup_check.log`
  - self-check behavior: reads GitHub raw manifest, resolves `active_base_url`, checks public `/health`, verifies unauthenticated `/skill` is `401`, loads the local bearer token from `tmp\gateway_8766.env.json`, calls authenticated `/skill/context`, and runs the Cloudflare Quick Tunnel watchdog once before retrying if remote access fails
  - remote skill data endpoints:
    - `GET /skill`
    - `GET /skill/context?q=<query>&paper_limit=10&text_limit=5`
- tunnelto:
  - client: `C:\Users\Administrator\.cargo\bin\tunnelto.exe`
  - version used: `0.1.20`
  - auth source: local `tunnelto set-auth` store
  - tunnel state: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\tunnelto_8766.state.json`
  - earlier observed public URL on `2026-06-03`: `https://t-sn1ckacz.tunn.dev`
  - latest tunnelto status after gateway restart: server terminated connection because the free trial expired
  - login startup: `C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-tunnelto-8766.cmd`
- Cloudflare Quick Tunnel:
  - client: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tools\cloudflared.exe`
  - version used: `2026.5.2`
  - script: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\start_cloudflare_quick_tunnel.ps1`
  - watchdog: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\watch_cloudflare_quick_tunnel.ps1`
  - tunnel state: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_8766.state.json`
  - current verified public URL on `2026-06-04`: `https://daisy-limousines-brunswick-park.trycloudflare.com`
  - login startup: `C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-cloudflare-watchdog.cmd`
  - disabled old direct startup: `C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-cloudflare-8766.cmd.disabled`
  - watchdog behavior: checks local `127.0.0.1:8766/health`, starts the gateway if needed, checks Cloudflare `/health`, restarts Quick Tunnel when needed, and periodically refreshes plus pushes the public endpoint manifest
  - note: Quick Tunnel URLs can change after restart; remote machines should read the GitHub raw endpoint manifest rather than hard-code the current URL
- Cloudflare Named Tunnel:
  - client: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tools\cloudflared.exe`
  - version used: `2026.5.2`
  - config script: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\configure_cloudflare_named_tunnel.ps1`
  - start script: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\start_cloudflare_named_tunnel.ps1`
  - watchdog: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\watch_cloudflare_named_tunnel.ps1`
  - config template: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\examples\cloudflare_named_tunnel.env.example.json`
  - local config path outside Git: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_named_tunnel.env.json`
  - credential/state paths outside Git:
    - `C:\Users\Administrator\.cloudflared\cert.pem`
    - `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_named_tunnel.credentials.json`
    - `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_named_tunnel.yml`
    - `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_named_tunnel.state.json`
  - current status on `2026-06-04`: not configured because `C:\Users\Administrator\.cloudflared\cert.pem` is absent
  - required one-time host action: run `.\tools\cloudflared.exe tunnel login` in the gateway repo and authorize a Cloudflare zone in the browser
  - after login: copy the example config to `tmp\cloudflare_named_tunnel.env.json`, replace `hostname` with a real Cloudflare-zone hostname, run `configure_cloudflare_named_tunnel.ps1 -OverwriteDns`, run `start_cloudflare_named_tunnel.ps1 -UpdateEndpointManifest -CommitEndpointManifest`, and refresh startup with `install_windows_startup.ps1 -IncludeCloudflareNamedWatchdog`
  - Quick Tunnel compatibility: `start_cloudflare_quick_tunnel.ps1` now only stops `cloudflared tunnel --url ...` Quick Tunnel processes and should not kill a future `cloudflared tunnel --config ... run` Named Tunnel process
- Bandwagon/VPS fixed public entry:
  - fixed public base URL: `http://83.229.126.28/slam-ai`
  - VPS: HK `83.229.126.28`
  - configured scripts:
    - `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\configure_bandwagon_vps.ps1`
    - `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\configure_bandwagon_path_proxy.ps1`
    - `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\start_bandwagon_reverse_tunnel.ps1`
    - `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\setup_bandwagon_nginx.sh`
    - `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\setup_bandwagon_nginx_path_proxy.sh`
  - config template: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\examples\bandwagon_reverse_ssh.env.example.json`
  - local config path outside Git: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\bandwagon_reverse_ssh.env.json`
  - reverse tunnel state: `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\bandwagon_reverse_ssh_18766.state.json`
  - architecture: public VPS Nginx -> VPS `127.0.0.1:18766` -> reverse SSH tunnel -> Windows `127.0.0.1:8766`
  - login startup: `C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-bandwagon-reverse-ssh.cmd`
  - startup behavior: runs with `-SkipIfMissingConfig`, so it safely skips if the local VPS config is absent
  - SSH key login from this Windows host to the VPS is installed and verified
  - reverse SSH process is managed by `scripts\start_bandwagon_reverse_tunnel.ps1`; latest observed failures are VPS-side `Connection reset by 83.229.126.28 port 22`
  - watchdog process added on `2026-06-03`: `scripts\watch_bandwagon_reverse_tunnel.ps1`, with Windows Startup entry `slam-ai-bandwagon-watchdog.cmd`
  - watchdog is now conservative by default: checks every `300` seconds, restarts only after `3` consecutive failures, and uses `1800` seconds restart cooldown
  - Nginx integration: existing BT/aaPanel default site path proxy at `/slam-ai/`; the VPS root site was not replaced
  - external port `8766` timed out from Windows, so the stable public entry uses port `80` plus `/slam-ai`
- Latest verification:
  - `python -m compileall src` succeeded in the gateway repo
  - PDF-only smoke test returned `/skill` and `/skill/context` with `paper_index_source: pdf_fallback`
  - full local corpus direct call returned `paper_index_source: merged_graph`, `944` PDFs, `944` markdown files
  - live local `http://127.0.0.1:8766/skill` returned `remote_skill_data_interface`
  - live local `/skill/context?q=gaussian%20slam&paper_limit=5&text_limit=2` returned paper candidates and text snippets
  - unauthenticated live local `GET /skill` returned HTTP `401`
  - public tunnelto access is currently unavailable until tunnelto quota/account is fixed or another tunnel provider is configured
  - public Cloudflare `GET /health` succeeded
  - public Cloudflare authenticated `GET /skill` returned `remote_skill_data_interface`
  - public Cloudflare authenticated `/skill/context?q=gaussian%20slam&paper_limit=5&text_limit=2` returned paper candidates and text snippets
  - public Cloudflare unauthenticated `GET /skill` returned HTTP `401`
  - Cloudflare Named Tunnel scripts parse successfully
  - Named Tunnel start script with `-SkipIfMissingConfig` exits cleanly when `tmp\cloudflare_named_tunnel.env.json` is absent
  - Named Tunnel watchdog with `-Once -SkipManifestPush` logs `config_missing` and exits cleanly when unconfigured
  - endpoint manifest update on `2026-06-04` kept Cloudflare Quick Tunnel active and marked the HK VPS path proxy healthy
  - Bandwagon PowerShell scripts parse successfully
  - Bandwagon Nginx shell script passes `bash -n`
  - reverse tunnel outage on `2026-06-03` was diagnosed as VPS SSH resetting the connection; rerunning `scripts\start_bandwagon_reverse_tunnel.ps1` restores the tunnel only when SSH is accepting connections
  - gateway commit `57cd28b` improved reverse-tunnel startup status detection so short-lived SSH failures no longer leave stale `running` state
  - gateway commit `45ef6e9` added a conservative Windows watchdog that checks public `/slam-ai/health` and restarts the reverse tunnel after consecutive failures
  - HK VPS Nginx `/slam-ai/` config was verified: `proxy_pass http://127.0.0.1:18766/`
  - VPS-side upstream was verified while the tunnel was healthy: `curl http://127.0.0.1:18766/health` returned HTTP `200` from the Windows gateway
  - Current failure mode when broken: VPS root `/` returns HTTP `200`, but `/slam-ai/health` times out or returns `502` because the reverse SSH tunnel is absent or stale
  - Existing VPS root service still responds at `http://83.229.126.28/`; the root site was not overwritten
  - `scripts\install_windows_startup.ps1 -IncludeBandwagonWatchdog` was run on `2026-06-04`; it installed/refreshed the gateway, Cloudflare watchdog, remote access self-check, and Bandwagon watchdog Startup entries and disabled the older direct Cloudflare startup entry
  - remote access startup self-check on `2026-06-04` succeeded: GitHub raw manifest reachable, `active_base_url` Cloudflare, `token_included=false`, local gateway OK, public `/health` OK, unauthenticated `/skill` returned `401`, authenticated `/skill/context?q=gaussian%20slam&paper_limit=3&text_limit=1` returned `paper_index_source=merged_graph`, `root_pdf_count=944`, `root_markdown_count=944`, and `pending_markdown_count=0`
  - after commit `b549960`, current Cloudflare and Bandwagon watchdog processes were restarted from the updated scripts
  - GitHub raw endpoint manifest smoke test succeeded: `active_base_url` was Cloudflare, `token_included=false`, endpoint count `2`, `/health` returned OK, authenticated `/skill` returned `slam-ai`, authenticated `/skill/context?q=gaussian%20slam&paper_limit=5&text_limit=2` returned `paper_index_source=merged_graph`, `root_pdf_count=944`, `root_markdown_count=944`, and unauthenticated `/skill` returned HTTP `401`

See `references/remote-access.md` before answering remote-access or other-computer usage questions. Do not write tunnel keys, Cloudflare account tokens, or SLAM bearer tokens into skill docs or Git.
