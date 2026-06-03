# Remote Access

This document explains how another computer can use the SLAM AI Skill Gateway
without copying the local PDF corpus.

Do not commit real access keys, bearer tokens, or files under `tmp/`.

## What Other Computers Need

Remote callers need two values:

```text
base URL = fixed VPS/domain URL, LAN URL, current Cloudflare Quick Tunnel URL, or current tunnelto public URL
token    = SLAM gateway bearer token
```

Current implementation detail:

- All remote computers use the same base URL while the same gateway/tunnel is running.
- All remote computers use the same SLAM gateway bearer token.
- The gateway does not yet issue per-computer or per-user tokens.
- A Bandwagon VPS or other VPS gives a stable IP/domain as long as the reverse SSH tunnel is running from this Windows host.
- The Cloudflare Quick Tunnel URL can change after cloudflared restarts.
- The tunnelto base URL can change after tunnelto restarts unless a fixed subdomain is configured.
- The SLAM gateway bearer token stays the same until the host config is changed.

## Token Types

There are two different credentials:

- `Cloudflare account/token`: not needed for Quick Tunnel; needed only for a stable named tunnel.
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
# Use a fixed VPS/domain URL, current Cloudflare/tunnelto URL, or host LAN URL.
$base = "https://your-domain.example"
# $base = "http://VPS_IP/slam-ai"
# $base = "https://current-trycloudflare-or-tunnelto-url"
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

The current Cloudflare Quick Tunnel URL is stored in:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_8766.state.json
```

Read the current Cloudflare public URL on the host:

```powershell
$state = Get-Content -LiteralPath "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_8766.state.json" -Raw | ConvertFrom-Json
$state.urls | Where-Object { $_ -like "https://*.trycloudflare.com*" } | Select-Object -First 1
```

The Bandwagon/VPS reverse SSH config is stored locally outside Git at:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\bandwagon_reverse_ssh.env.json
```

Use this template:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\examples\bandwagon_reverse_ssh.env.example.json
```

The reverse SSH tunnel state is written to:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\bandwagon_reverse_ssh_18766.state.json
```

The current tunnelto URL is stored in:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\tunnelto_8766.state.json
```

Read the current tunnelto public URL on the host:

```powershell
$state = Get-Content -LiteralPath "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\tunnelto_8766.state.json" -Raw | ConvertFrom-Json
$state.urls | Where-Object { $_ -like "https://*.tunn.dev*" } | Select-Object -First 1
```

## Outside The LAN

For a computer that is not on the same LAN, use the fixed VPS/domain URL,
Cloudflare Quick Tunnel URL, or tunnelto public URL as the base URL:

```powershell
$base = "https://your-domain.example"
# $base = "http://VPS_IP/slam-ai"
# $base = "https://current-trycloudflare-or-tunnelto-url"
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

Cloudflare Quick Tunnel note: account-less `trycloudflare.com` tunnels are
useful for remote testing but do not provide a fixed URL or uptime guarantee.
Use a named Cloudflare Tunnel with a Cloudflare account/domain for long-lived
production access.

## Fixed Public Entry With Bandwagon VPS

Use this path when the user wants a stable public address and already has a
Bandwagon VPS or equivalent Linux VPS.

Architecture:

```text
remote caller -> VPS nginx -> 127.0.0.1:18766 on VPS -> SSH reverse tunnel -> Windows localhost:8766
```

The VPS does not store PDFs, extracted markdown, Graphify outputs, or the SLAM
bearer token. It only proxies traffic to the reverse SSH tunnel. The gateway on
this Windows host still enforces `Authorization: Bearer <token>` for every
endpoint except `/health`.

Create local config outside Git:

```powershell
Copy-Item `
  -LiteralPath "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\examples\bandwagon_reverse_ssh.env.example.json" `
  -Destination "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\bandwagon_reverse_ssh.env.json"
```

Edit:

```json
{
  "ssh_host": "VPS_IP_OR_DOMAIN",
  "ssh_user": "root",
  "ssh_port": 22,
  "identity_file": "C:\\Users\\Administrator\\.ssh\\id_ed25519",
  "local_port": 8766,
  "remote_port": 18766,
  "domain": "",
  "email": ""
}
```

Configure nginx on the VPS:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_bandwagon_vps.ps1
```

If the VPS already has a production site on port `80`/`443`, configure a path
proxy on the existing Nginx server instead of replacing the root site:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_bandwagon_path_proxy.ps1 -PathPrefix /slam-ai
```

This forwards:

```text
http://VPS_IP/slam-ai/... -> VPS 127.0.0.1:18766 -> Windows localhost:8766
```

If a domain already points to the VPS and HTTPS is wanted:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_bandwagon_vps.ps1 -Domain slam.example.com -Email you@example.com -LetsEncrypt
```

Start or restart the reverse SSH tunnel from Windows:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_bandwagon_reverse_tunnel.ps1
```

Optionally run the watchdog on the Windows host. It checks the public
`/slam-ai/health` endpoint and restarts the reverse SSH tunnel only after
consecutive failures, with a cooldown to avoid aggressive reconnect loops:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\watch_bandwagon_reverse_tunnel.ps1
```

Windows login startup entry on this host:

```text
C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-bandwagon-reverse-ssh.cmd
C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-bandwagon-watchdog.cmd
```

It calls the reverse-tunnel script with `-SkipIfMissingConfig`, so it stays
quiet until `tmp\bandwagon_reverse_ssh.env.json` is filled with VPS SSH details.

Remote caller examples:

```powershell
$base = "http://VPS_IP/slam-ai"
# or:
# $base = "https://slam.example.com/slam-ai"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod "$base/health"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
```

If the reverse tunnel is down, the VPS public URL may still answer from nginx
but return a gateway/proxy error. Restart `scripts\start_bandwagon_reverse_tunnel.ps1`
on the Windows host.

Current HK VPS deployment:

```text
base URL = http://83.229.126.28/slam-ai
VPS      = 83.229.126.28
Nginx    = existing BT/aaPanel Nginx default site path proxy
Tunnel   = VPS 127.0.0.1:18766 -> Windows 127.0.0.1:8766
```

Remote caller example for the current HK VPS:

```powershell
$base = "http://83.229.126.28/slam-ai"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod "$base/health"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
```

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

Start or restart Cloudflare Quick Tunnel:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_cloudflare_quick_tunnel.ps1
```

Configure Bandwagon/VPS nginx and start the reverse SSH tunnel:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_bandwagon_vps.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_bandwagon_reverse_tunnel.ps1
```

If the VPS already has websites on port `80`/`443`, use the path-proxy helper
instead of replacing the root site:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_bandwagon_path_proxy.ps1 -PathPrefix /slam-ai
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_bandwagon_reverse_tunnel.ps1
```

Install the current tunnelto client:

```powershell
cargo install tunnelto --version 0.1.20 --locked
```

Store the tunnelto access key locally on the host:

```powershell
tunnelto set-auth --key "your-tunnelto-access-key"
```

Start or restart tunnelto:

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
$base = "https://your-domain-or-current-public-or-lan-url"
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

For other computers today, use the HTTP API through the fixed VPS/domain URL,
LAN, Cloudflare Quick Tunnel, or tunnelto. Remote MCP over HTTP/SSE is not
implemented yet.
