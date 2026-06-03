# Remote Access

This document explains how another computer can use the SLAM AI Skill Gateway
without copying the local PDF corpus.

Do not commit real access keys, bearer tokens, or files under `tmp/`.

## What Other Computers Need

Remote callers need two values:

```text
base URL = LAN URL or current tunnelto public URL
token    = SLAM gateway bearer token
```

Current implementation detail:

- All remote computers use the same base URL while the same gateway/tunnel is running.
- All remote computers use the same SLAM gateway bearer token.
- The gateway does not yet issue per-computer or per-user tokens.
- The tunnelto base URL can change after tunnelto restarts unless a fixed subdomain is configured.
- The SLAM gateway bearer token stays the same until the host config is changed.

## Token Types

There are two different credentials:

- `tunnelto access key`: used only on the host machine to open the public tunnel.
- `SLAM gateway bearer token`: used by other computers in the HTTP `Authorization` header.

Do not give the tunnelto access key to remote callers. Remote callers only need
the SLAM gateway bearer token.

## Use This Host As The slam-ai Data Interface

For another computer, the cleanest agent/skill workflow is:

```text
remote slam-ai skill or agent -> HTTP base URL + bearer token -> this host corpus
```

The remote computer does not need to copy the PDF corpus, extracted markdown, or
Graphify outputs. It should call:

```powershell
# Use either the current tunnelto URL or the host LAN URL.
$base = "https://current-tunnelto-url"
# $base = "http://HOST_IP:8766"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
```

`/skill` is the discovery manifest for the remote skill data interface.
`/skill/context` is the main agent-facing endpoint for paper-writing or
literature-search context. It returns corpus status, paper candidates,
extracted-text snippets when markdown exists, and optional graph summary.

## Host-Side State

On the host machine, the gateway config and token are stored in:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\gateway_8766.env.json
```

Read the bearer token on the host:

```powershell
$cfg = Get-Content -LiteralPath "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\gateway_8766.env.json" -Raw | ConvertFrom-Json
$cfg.token
```

The current tunnelto URL is stored in:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\tunnelto_8766.state.json
```

Read the current public URL on the host:

```powershell
$state = Get-Content -LiteralPath "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\tunnelto_8766.state.json" -Raw | ConvertFrom-Json
$state.urls | Where-Object { $_ -like "https://*.tunn.dev*" } | Select-Object -First 1
```

## Outside The LAN

For a computer that is not on the same LAN, use the tunnelto public URL as the
base URL:

```powershell
$base = "https://current-tunnelto-url"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod "$base/health"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/status"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/papers?q=gaussian%20slam&limit=5"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/search?q=loop%20closure&limit=5"
```

Security check:

```powershell
Invoke-WebRequest "$base/status"
```

Expected result without bearer token: HTTP `401 Unauthorized`.

## Same LAN

If the remote computer is on the same network as the host, use:

```text
http://HOST_LAN_IP:8766
```

Find the current LAN IP on the host:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike "127.*" -and $_.PrefixOrigin -ne "WellKnown" } |
  Select-Object IPAddress,InterfaceAlias
```

Remote LAN example:

```powershell
$base = "http://HOST_LAN_IP:8766"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod "$base/health"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/status"
```

If LAN access fails but local access works, run the firewall helper from an
Administrator PowerShell:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\register_firewall_rule.ps1 -Port 8766
```

## Starting The Services

Start or restart the HTTP gateway:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_gateway_from_env.ps1
```

Install the current tunnelto client:

```powershell
cargo install tunnelto --version 0.1.20 --locked
```

Store the tunnelto access key locally on the host:

```powershell
tunnelto set-auth --key "your-tunnelto-access-key"
```

Start or restart the tunnel:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_tunnelto_tunnel.ps1
```

## Useful Endpoints

No auth:

```text
GET /health
```

Bearer token required:

```text
GET /skill
GET /skill/context?q=<query>&category=<category>&paper_limit=10&text_limit=5&include_graph_summary=false
GET /status
GET /graph/summary
GET /papers?q=<query>&category=<category>&limit=25
GET /paper?id=<paper_id>&include_text=true&max_chars=6000
GET /search?q=<query>&limit=10
POST /daily/run?force=false&wait=false&timeout=3600
```

## PDF-Only Corpus Fallback

If the remote machine only has PDFs, such as:

```text
/home/slam/slam_papers
```

and does not have extracted markdown or Graphify/merged graph outputs, the
gateway now falls back to a PDF index:

```text
/papers -> scans SLAM_AI_CORPUS_ROOT recursively for *.pdf
/paper  -> can look up by PDF relative path, file name, or file stem
/search -> still requires extracted markdown and may return no matches
/graph/summary -> still requires Graphify outputs and may be empty
```

Check the active indexing mode:

```powershell
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/status"
```

Expected field for a PDF-only directory:

```json
{
  "paper_index_source": "pdf_fallback"
}
```

Linux example:

```bash
export SLAM_AI_CORPUS_ROOT=/home/slam/slam_papers
export SLAM_AI_GATEWAY_TOKEN='change-this-token'
python -m slam_ai_gateway.http_server --host 0.0.0.0 --port 8766
```

Trigger the daily closed loop remotely:

```powershell
$base = "https://current-tunnelto-url-or-lan-url"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod `
  -Method Post `
  -Headers @{ Authorization = "Bearer $token" } `
  "$base/daily/run?force=false&wait=false"
```

## MCP Boundary

The included MCP server is stdio MCP:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
$env:SLAM_AI_CORPUS_ROOT = "C:\Users\Administrator\Downloads\3DGS-SLAM-Papers"
python -m slam_ai_gateway.mcp_server
```

That works for an MCP client running on the same machine, or on another machine
that has its own repo checkout and corpus access.

For other computers today, use the HTTP API through LAN or tunnelto. Remote MCP
over HTTP/SSE is not implemented yet.
