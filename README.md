# SLAM AI Skill Gateway

HTTP and MCP access layer for the local SLAM AI literature corpus.

This repository does not store the PDF corpus. It exposes the corpus already
present on a workstation, by default:

```text
C:\Users\Administrator\Downloads\3DGS-SLAM-Papers
```

## What It Exposes

- corpus health and counts
- daily-loop state
- root and merged Graphify summaries
- paper-node search
- PDF-only fallback search when a machine has PDFs but no extracted markdown or Graphify outputs
- extracted markdown text search
- remote `slam-ai` skill manifest and agent context bundles
- optional daily closed-loop trigger
- MCP tools for agent clients

## HTTP API

Start on localhost:

```powershell
$env:SLAM_AI_CORPUS_ROOT = "C:\Users\Administrator\Downloads\3DGS-SLAM-Papers"
python -m slam_ai_gateway.http_server --host 127.0.0.1 --port 8765
```

Start for LAN access:

```powershell
$env:SLAM_AI_CORPUS_ROOT = "C:\Users\Administrator\Downloads\3DGS-SLAM-Papers"
$env:SLAM_AI_GATEWAY_TOKEN = "change-this-token"
python -m slam_ai_gateway.http_server --host 0.0.0.0 --port 8765
```

On another computer on the same network:

```powershell
$token = "change-this-token"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } http://HOST_IP:8765/status
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } http://HOST_IP:8765/skill
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "http://HOST_IP:8765/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "http://HOST_IP:8765/papers?q=gaussian%20slam&limit=5"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "http://HOST_IP:8765/search?q=loop%20closure&limit=5"
```

## Remote Skill Data Interface

Use these endpoints when another computer should treat this host as the data
backend for its `slam-ai` skill workflow:

```powershell
# Use either the current tunnelto URL or the host LAN URL.
$base = "https://current-tunnelto-url"
# $base = "http://HOST_IP:8766"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
```

- `/skill` returns the discovery manifest, supported endpoints, corpus counts,
  and usage rules.
- `/skill/context` returns an agent-friendly bundle with status, paper
  candidates, extracted-text snippets when available, and optional graph
  summary.
- Remote computers do not need the PDF corpus if they use these HTTP endpoints.
  They only need the current base URL and the SLAM gateway bearer token.

Trigger the daily loop remotely:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Headers @{ Authorization = "Bearer $token" } `
  "http://HOST_IP:8765/daily/run?force=false&wait=false"
```

## Endpoints

- `GET /health`
- `GET /skill`
- `GET /skill/context?q=<query>&category=<category>&paper_limit=10&text_limit=5&include_graph_summary=false`
- `GET /status`
- `GET /graph/summary`
- `GET /papers?q=<query>&category=<category>&limit=25`
- `GET /paper?id=<paper_id>&include_text=true&max_chars=6000`
- `GET /search?q=<query>&limit=10`
- `POST /daily/run?force=false&wait=false&timeout=3600`

If `SLAM_AI_GATEWAY_TOKEN` is set, every endpoint except `/health` requires:

```text
Authorization: Bearer <token>
```

## PDF-Only Corpus Fallback

The full corpus layout includes extracted markdown and Graphify outputs. If a
machine only has a small PDF directory, for example `/home/slam/slam_papers`,
the gateway still works in a reduced mode:

- `/status` reports `paper_index_source: "pdf_fallback"`
- `/papers` scans `SLAM_AI_CORPUS_ROOT` recursively for `*.pdf`
- `/paper?id=<pdf-file-or-stem>` returns the PDF fallback entry
- `/search` remains empty until extracted markdown exists
- `/graph/summary` remains empty until Graphify outputs exist

Start a PDF-only directory on Linux:

```bash
export SLAM_AI_CORPUS_ROOT=/home/slam/slam_papers
export SLAM_AI_GATEWAY_TOKEN='change-this-token'
python -m slam_ai_gateway.http_server --host 0.0.0.0 --port 8766
```

## MCP Server

Run stdio MCP:

```powershell
$env:SLAM_AI_CORPUS_ROOT = "C:\Users\Administrator\Downloads\3DGS-SLAM-Papers"
python -m slam_ai_gateway.mcp_server
```

Example MCP client config:

```json
{
  "mcpServers": {
    "slam-ai": {
      "command": "python",
      "args": ["-m", "slam_ai_gateway.mcp_server"],
      "env": {
        "SLAM_AI_CORPUS_ROOT": "C:\\Users\\Administrator\\Downloads\\3DGS-SLAM-Papers"
      }
    }
  }
}
```

Tools:

- `slam_status`
- `slam_skill_manifest`
- `slam_skill_context`
- `slam_search_papers`
- `slam_get_paper`
- `slam_search_text`
- `slam_run_daily_loop`

## Install

Editable install:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
python -m pip install -e .
```

Without install, use `PYTHONPATH`:

```powershell
$env:PYTHONPATH = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\src"
python -m slam_ai_gateway.http_server
```

## Windows Firewall

For LAN access, allow the port on the host machine if needed:

```powershell
.\scripts\register_firewall_rule.ps1 -Port 8766 -DisplayName "SLAM AI Gateway 8766"
```

Use a token when binding to `0.0.0.0`.

## Public Tunnel With tunnelto

This can expose the local gateway to computers outside the current LAN. The
public tunnel still forwards to the token-protected SLAM API, so keep both the
tunnelto access key and the gateway bearer token out of Git.

For complete other-computer usage, including where to read the current public
base URL and gateway bearer token on the host machine, see
[`docs/remote-access.md`](docs/remote-access.md).

Install the current tunnelto client:

```powershell
cargo install tunnelto --version 0.1.20 --locked
```

Store your tunnelto access key locally:

```powershell
tunnelto set-auth --key "your-tunnelto-access-key"
```

Optionally create a local tunnel config under `tmp\tunnelto_8766.env.json`:

```json
{
  "port": 8766,
  "local_host": "localhost",
  "subdomain": ""
}
```

Then start the tunnel:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_tunnelto_tunnel.ps1
```

The script writes tunnel state and logs to `tmp\tunnelto_8766.*`. It uses the
stored tunnelto key by default. You can also supply `TUNNELTO_KEY` or
`tunnelto_key` in the local config if you do not want to use `set-auth`.

## Startup On Windows

Create a local config file outside Git, for example:

```json
{
  "host": "0.0.0.0",
  "port": 8766,
  "token": "change-this-token",
  "corpus_root": "C:\\Users\\Administrator\\Downloads\\3DGS-SLAM-Papers",
  "log": "C:\\Users\\Administrator\\Downloads\\slam-ai-skill-gateway\\tmp\\gateway_8766.log"
}
```

Then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_gateway_from_env.ps1
```

For login-time startup, create a `.cmd` in the Windows Startup folder that calls
the same script. Keep the token in the local config file, not in Git.

To also restart the public tunnel at login, create another Startup `.cmd` that
calls `scripts\start_tunnelto_tunnel.ps1`. The tunnelto key should stay in the
local `set-auth` store.
