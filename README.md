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
- extracted markdown text search
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
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "http://HOST_IP:8765/papers?q=gaussian%20slam&limit=5"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "http://HOST_IP:8765/search?q=loop%20closure&limit=5"
```

Trigger the daily loop remotely:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Headers @{ Authorization = "Bearer $token" } `
  "http://HOST_IP:8765/daily/run?force=false&wait=false"
```

## Endpoints

- `GET /health`
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
New-NetFirewallRule `
  -DisplayName "SLAM AI Gateway 8765" `
  -Direction Inbound `
  -Action Allow `
  -Protocol TCP `
  -LocalPort 8765
```

Use a token when binding to `0.0.0.0`.

