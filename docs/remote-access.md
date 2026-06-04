# Remote Access

This document explains how another computer can use the SLAM AI Skill Gateway
without copying the local PDF corpus.

Do not commit real access keys, bearer tokens, or files under `tmp/`.

## What Other Computers Need

Remote callers need two values:

```text
base URL = read from the published endpoint manifest
token    = SLAM gateway bearer token
```

Current implementation detail:

- All remote computers should read the published endpoint manifest and use
  `active_base_url` instead of hard-coding the HK VPS URL.
- All remote computers use the same SLAM gateway bearer token.
- The gateway does not yet issue per-computer or per-user tokens.
- The Windows host maintains the published endpoint manifest through the
  Cloudflare watchdog scripts; remote computers should treat the manifest URL
  as the stable entry, not the current `trycloudflare.com` URL.
- A Cloudflare Named Tunnel gives a fixed hostname when this host has completed
  `cloudflared tunnel login` and the hostname is routed in a Cloudflare zone.
- A Bandwagon VPS or other VPS gives a stable IP/domain as long as the reverse SSH tunnel is running from this Windows host.
- The Cloudflare Quick Tunnel URL can change after cloudflared restarts.
- The tunnelto base URL can change after tunnelto restarts unless a fixed subdomain is configured.
- The SLAM gateway bearer token stays the same until the host config is changed.

## Token Types

There are two different credentials:

- `Cloudflare account/cert`: not needed for Quick Tunnel; needed only on the
  host for a stable named tunnel.
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
# Prefer the published endpoint manifest instead of hard-coding one public URL.
$manifest = Invoke-RestMethod "https://raw.githubusercontent.com/kenchikuliu/slam-ai-skill-gateway/main/public/slam-ai-endpoints.json"
$base = $manifest.active_base_url
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod "$base/health"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
```

`/skill` is the discovery manifest for the remote skill data interface.
`/skill/context` is the main agent-facing endpoint for paper-writing or
literature-search context. It returns corpus status, paper candidates,
extracted-text snippets when markdown exists, and optional graph summary.

## Published Endpoint Manifest

The public endpoint manifest is tracked in Git and contains no bearer token:

```text
https://raw.githubusercontent.com/kenchikuliu/slam-ai-skill-gateway/main/public/slam-ai-endpoints.json
```

Remote callers should select `active_base_url`, or the first endpoint with
`health_ok=true` and the lowest `priority`. This prevents a remote machine from
getting stuck on the HK VPS path proxy when its reverse SSH upstream is broken.

Host-side maintenance can use two Cloudflare watchdogs:

- `scripts\watch_cloudflare_named_tunnel.ps1`: keeps a configured fixed
  Cloudflare hostname alive and refreshes the manifest.
- `scripts\watch_cloudflare_quick_tunnel.ps1`: keeps the account-less
  `trycloudflare.com` fallback alive and refreshes the manifest.

The manifest prefers the named tunnel when healthy, then Quick Tunnel, then the
HK VPS fallback. HK VPS remains lower priority because it depends on reverse SSH
staying up.

Linux example:

```bash
manifest_url='https://raw.githubusercontent.com/kenchikuliu/slam-ai-skill-gateway/main/public/slam-ai-endpoints.json'
export SLAM_AI_BASE_URL="$(curl -fsSL "$manifest_url" | python3 -c 'import json,sys; print(json.load(sys.stdin)["active_base_url"])')"
export SLAM_AI_TOKEN='paste-the-slam-gateway-bearer-token'

curl "$SLAM_AI_BASE_URL/health"
curl -H "Authorization: Bearer $SLAM_AI_TOKEN" "$SLAM_AI_BASE_URL/skill"
```

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

The Cloudflare Named Tunnel local config and state are stored outside Git:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_named_tunnel.env.json
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_named_tunnel.state.json
```

Read the fixed Cloudflare base URL on the host after configuration:

```powershell
$state = Get-Content -LiteralPath "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_named_tunnel.state.json" -Raw | ConvertFrom-Json
$state.base_url
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

For a computer that is not on the same LAN, prefer the published endpoint
manifest. Use a fixed VPS/domain URL, current Cloudflare Quick Tunnel URL, or
tunnelto public URL only when deliberately bypassing the manifest:

```powershell
$manifest = Invoke-RestMethod "https://raw.githubusercontent.com/kenchikuliu/slam-ai-skill-gateway/main/public/slam-ai-endpoints.json"
$base = $manifest.active_base_url
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
The manifest/watchdog layer makes the changing URL usable for remote agents.
Use a named Cloudflare Tunnel with a Cloudflare account/domain when a fixed
production URL is required.

## Stable Cloudflare Named Tunnel

Use this path when other computers need a fixed public URL that does not change
when `cloudflared` restarts. This requires a Cloudflare account and a hostname
under a Cloudflare-managed zone. The Cloudflare cert and tunnel credentials are
only used on this Windows host; remote computers do not need them.

Authorize once in the browser:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
.\tools\cloudflared.exe tunnel login
```

This creates:

```text
C:\Users\Administrator\.cloudflared\cert.pem
```

Create the ignored local config:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
Copy-Item .\examples\cloudflare_named_tunnel.env.example.json .\tmp\cloudflare_named_tunnel.env.json
notepad .\tmp\cloudflare_named_tunnel.env.json
```

Set `hostname` to the desired fixed hostname, for example:

```json
{
  "tunnel_name": "slam-ai-gateway",
  "hostname": "slam-ai.example.com",
  "local_host": "localhost",
  "port": 8766,
  "origin_cert": "C:\\Users\\Administrator\\.cloudflared\\cert.pem"
}
```

Create or reuse the tunnel and route DNS:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_cloudflare_named_tunnel.ps1 -OverwriteDns
```

Start the named tunnel and publish the manifest:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_cloudflare_named_tunnel.ps1 -UpdateEndpointManifest -CommitEndpointManifest
```

Install or refresh login startup entries with the named tunnel watchdog:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install_windows_startup.ps1 -IncludeCloudflareNamedWatchdog
```

After this, remote computers should still read the GitHub endpoint manifest:

```powershell
$manifest = Invoke-RestMethod "https://raw.githubusercontent.com/kenchikuliu/slam-ai-skill-gateway/main/public/slam-ai-endpoints.json"
$base = $manifest.active_base_url
```

When the fixed hostname is healthy, `active_base_url` will point to the named
tunnel. The SLAM bearer token is still required for `/skill`, `/skill/context`,
`/status`, `/papers`, `/search`, and `/daily/run`.

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
multiple consecutive failures, with a long cooldown to avoid aggressive
reconnect loops when the VPS SSH service is under pressure:

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

Install or refresh the Windows login startup entries:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install_windows_startup.ps1
```

This creates startup entries for the HTTP gateway and the Cloudflare watchdog.
It disables the older direct Cloudflare startup entry by default, so the
watchdog is the single owner of Quick Tunnel lifecycle and manifest publication.

Start or restart the HTTP gateway:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_gateway_from_env.ps1
```

Start or restart Cloudflare Quick Tunnel:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_cloudflare_quick_tunnel.ps1 -UpdateEndpointManifest -CommitEndpointManifest
```

Start the Cloudflare Quick Tunnel watchdog:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\watch_cloudflare_quick_tunnel.ps1
```

Configure and start a fixed Cloudflare Named Tunnel after browser login:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
.\tools\cloudflared.exe tunnel login
Copy-Item .\examples\cloudflare_named_tunnel.env.example.json .\tmp\cloudflare_named_tunnel.env.json
notepad .\tmp\cloudflare_named_tunnel.env.json
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_cloudflare_named_tunnel.ps1 -OverwriteDns
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_cloudflare_named_tunnel.ps1 -UpdateEndpointManifest -CommitEndpointManifest
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install_windows_startup.ps1 -IncludeCloudflareNamedWatchdog
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
