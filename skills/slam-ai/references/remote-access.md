# Remote Access

## Purpose

Use this when another computer needs to query the local SLAM AI corpus without
copying the PDF corpus. The remote access layer is the lightweight gateway repo:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway
```

The gateway exposes HTTP API endpoints backed by:

```text
C:\Users\Administrator\Downloads\3DGS-SLAM-Papers
```

Do not commit access tokens, tunnel keys, or local `tmp/` files.

## Skill vs Data

The `slam-ai` skill is an instruction/workflow layer, not the paper database
itself. Installing or invoking the skill alone does not copy PDFs, extracted
markdown, Graphify outputs, or the merged reviewed graph to another computer.

The skill can access SLAM papers only through one of these data backends:

1. a local corpus path, such as `C:\Users\Administrator\Downloads\3DGS-SLAM-Papers`;
2. a lightweight PDF-only local corpus path, such as `/home/slam/slam_papers`;
3. the HTTP gateway, selected from the published endpoint manifest, LAN, Cloudflare Named Tunnel, Cloudflare Quick Tunnel, fixed VPS/domain URL, or tunnelto;
4. a local stdio MCP server configured on a machine that can see the corpus.

For another computer without the full corpus, the intended setup is:

```text
remote skill / agent -> HTTP API base URL + SLAM gateway bearer token -> host corpus
```

Do not tell the user that "the skill alone contains the papers." It contains the
rules for using the corpus and gateway.

For computers outside the LAN, prefer the published endpoint manifest instead
of hard-coding the HK VPS URL:

```text
https://raw.githubusercontent.com/kenchikuliu/slam-ai-skill-gateway/main/public/slam-ai-endpoints.json
```

Use `active_base_url`, or the first endpoint with `health_ok=true` and the
lowest `priority`. The manifest contains no bearer token.

The Windows host maintains this manifest through Cloudflare watchdog scripts:

- `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\watch_cloudflare_named_tunnel.ps1`
  for a configured fixed Cloudflare hostname;
- `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\watch_cloudflare_quick_tunnel.ps1`
  for the account-less `trycloudflare.com` fallback.

The manifest should prefer the named tunnel when healthy, then Quick Tunnel,
then the HK VPS path proxy. Remote machines should treat the GitHub raw
manifest as the stable entry point, not the current random `trycloudflare.com`
URL.

Cloudflare Named Tunnel is optional. If it is not configured, remote computers
can still use this host by reading the published endpoint manifest before every
call or run. The current Quick Tunnel URL may change, but the GitHub raw
manifest is the stable rendezvous point.

## Remote Skill Data Interface

The gateway exposes two agent-facing endpoints specifically for using this host
as the remote data backend for `slam-ai`:

```text
GET /skill
GET /skill/context?q=<query>&category=<category>&paper_limit=10&text_limit=5&include_graph_summary=false
```

Use `/skill` for discovery and `/skill/context` for the main paper-writing or
literature-search context bundle. A remote agent should call `/skill/context`
before drafting SLAM / 3DGS-SLAM related work so it can ground citations in the
local corpus.

Remote computer example:

```powershell
$manifest = Invoke-RestMethod "https://raw.githubusercontent.com/kenchikuliu/slam-ai-skill-gateway/main/public/slam-ai-endpoints.json"
$base = $manifest.active_base_url
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod "$base/health"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
```

Gateway repo examples now use this manifest-first behavior by default:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
$env:SLAM_AI_GATEWAY_TOKEN = "paste-the-slam-gateway-bearer-token"

.\examples\query_status.ps1
.\examples\search_papers.ps1 -Query "gaussian slam" -Limit 5
.\examples\query_skill_context.ps1 -Query "gaussian slam" -PaperLimit 10 -TextLimit 5
```

Set `SLAM_AI_BASE_URL` only when deliberately forcing a LAN, VPS, or tunnel
endpoint. Set `SLAM_AI_ENDPOINT_MANIFEST_URL` only when using a different
manifest location.

`/skill/context` returns:

- corpus status and daily-loop state;
- paper candidates from the merged graph, or PDF fallback entries if graph
  outputs are absent;
- extracted markdown snippets when available;
- optional graph summary when `include_graph_summary=true`.

## Active Local Gateway

The active HTTP gateway listens on:

```text
0.0.0.0:8766
```

Local config and token state:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\gateway_8766.env.json
```

There are two different tokens/keys:

- `Cloudflare account/cert`: not needed for Quick Tunnel; needed only on the
  host for a stable named tunnel.
- `tunnelto access key`: used only on the host machine to open the public
  tunnel. Do not give this to remote users or put it in API calls.
- `SLAM gateway bearer token`: used by other computers when calling the HTTP
  API through fixed VPS/domain URL, LAN, Cloudflare Named Tunnel, Cloudflare
  Quick Tunnel, or tunnelto.

With the current gateway implementation, all remote computers use the same
SLAM gateway bearer token. The API does not yet issue a different token per
remote computer. Remote computers should get the base URL from the endpoint
manifest so they can fall back from HK VPS to Cloudflare Quick Tunnel when the
reverse SSH tunnel is unhealthy.

The Cloudflare Quick Tunnel URL can change after `cloudflared` restarts. A
Cloudflare Named Tunnel URL stays fixed once the host has a Cloudflare login
cert and the hostname is routed in a Cloudflare zone. The tunnelto base URL can
change after tunnelto restarts unless a fixed tunnelto subdomain is configured.
The bearer token stays the same until `tmp\gateway_8766.env.json` is changed or
the gateway is reconfigured.

Read the current bearer token on the host machine:

```powershell
$cfg = Get-Content -LiteralPath "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\gateway_8766.env.json" -Raw | ConvertFrom-Json
$cfg.token
```

Start or restart the local gateway:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_gateway_from_env.ps1
```

The Windows login startup entry is:

```text
C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-gateway-8766.cmd
```

Refresh the gateway and Cloudflare watchdog startup entries with:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install_windows_startup.ps1
```

This also creates the remote access startup self-check:

```text
C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-remote-access-check.cmd
```

The self-check runs after a short login delay. It reads the GitHub raw endpoint
manifest, resolves `active_base_url`, checks public `/health`, confirms
unauthenticated `/skill` returns `401`, loads the local SLAM bearer token from
`tmp\gateway_8766.env.json`, and verifies authenticated `/skill/context`. If
the public route fails, it runs the Cloudflare Quick Tunnel watchdog once and
retries. It logs only status codes and corpus counts, not bearer tokens:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\remote_access_startup_check.log
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\remote_access_startup_check.state.json
```

The install script disables the older direct Cloudflare startup entry by
default and lets the Cloudflare watchdog own the tunnel lifecycle and endpoint
manifest publication.

## Same-LAN Usage

For another computer on the same network, use the host machine's LAN IP and
port `8766`.

Current observed WLAN IP on 2026-06-03:

```text
172.25.16.122
```

The IP can change. Re-check it on the host with:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike "127.*" -and $_.PrefixOrigin -ne "WellKnown" } |
  Select-Object IPAddress,InterfaceAlias
```

Remote computer test:

```powershell
$base = "http://172.25.16.122:8766"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod "$base/health"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/status"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/papers?q=gaussian%20slam&limit=5"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/search?q=loop%20closure&limit=5"
```

If LAN access fails but local access works, check Windows Firewall. The helper is:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\register_firewall_rule.ps1 -Port 8766
```

This may require an Administrator PowerShell.

## Fixed Bandwagon VPS Usage

Use this when the user wants a stable public address. The VPS does not store
the paper corpus or the SLAM gateway bearer token. It runs Nginx and proxies to
a reverse SSH tunnel back to this Windows host:

```text
remote caller -> VPS nginx -> 127.0.0.1:18766 on VPS -> SSH reverse tunnel -> Windows localhost:8766
```

Gateway repo scripts:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\configure_bandwagon_vps.ps1
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\configure_bandwagon_path_proxy.ps1
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\start_bandwagon_reverse_tunnel.ps1
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\setup_bandwagon_nginx.sh
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\scripts\setup_bandwagon_nginx_path_proxy.sh
```

Local config path outside Git:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\bandwagon_reverse_ssh.env.json
```

Template:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\examples\bandwagon_reverse_ssh.env.example.json
```

Required values before actually configuring the VPS:

```text
ssh_host, ssh_user, ssh_port, identity_file or SSH password, optional domain, optional email for Let's Encrypt
```

Configure Nginx on the VPS after the config file exists:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_bandwagon_vps.ps1
```

If the VPS already has sites on port `80`/`443`, use a path proxy on the
existing Nginx site instead of replacing the root site:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_bandwagon_path_proxy.ps1 -PathPrefix /slam-ai
```

Start the Windows reverse SSH tunnel:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_bandwagon_reverse_tunnel.ps1
```

Remote caller example:

```powershell
$base = "http://VPS_IP/slam-ai"
# or, if domain/HTTPS is configured:
# $base = "https://slam.example.com/slam-ai"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod "$base/health"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
```

Current verified HK VPS deployment:

```text
base URL = http://83.229.126.28/slam-ai
VPS      = 83.229.126.28
Nginx    = existing BT/aaPanel Nginx default site path proxy
Tunnel   = VPS 127.0.0.1:18766 -> Windows 127.0.0.1:8766
```

Key facts:

- SSH key login from this Windows host to the VPS is installed and verified.
- The reverse SSH state file is
  `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\bandwagon_reverse_ssh_18766.state.json`.
- The local config file is outside Git at
  `C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\bandwagon_reverse_ssh.env.json`.
- The VPS public root site was not replaced; only the `/slam-ai/` path proxy was
  inserted into the existing BT/aaPanel Nginx default site.
- `GET /health` succeeds without auth through the HK URL.
- Authenticated `GET /skill` returns `remote_skill_data_interface`.
- Authenticated `/skill/context?q=gaussian%20slam&paper_limit=5&text_limit=2`
  returns merged-graph paper candidates from the 944-PDF root corpus.
- Unauthenticated `GET /skill` returns HTTP `401`.

## Public Cloudflare Quick Tunnel Usage

Cloudflare Quick Tunnel is currently the working public tunnel for computers
outside the current LAN.

The working client is:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tools\cloudflared.exe
```

Current version on 2026-06-03:

```text
cloudflared version 2026.5.2
```

Start or restart the public Cloudflare Quick Tunnel and refresh the public
endpoint manifest:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_cloudflare_quick_tunnel.ps1 -UpdateEndpointManifest -CommitEndpointManifest
```

The tunnel state and current public URL are written to:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_8766.state.json
```

Read the current Cloudflare public URL on the host:

```powershell
$state = Get-Content -LiteralPath "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_8766.state.json" -Raw | ConvertFrom-Json
$state.urls | Where-Object { $_ -like "https://*.trycloudflare.com*" } | Select-Object -First 1
```

Current verified Cloudflare public URL on 2026-06-03:

```text
https://displays-touring-vancouver-pan.trycloudflare.com
```

This URL is a Quick Tunnel URL and can change after restart. Always check
the published endpoint manifest before telling a remote machine which public
base URL to use. For stable production access, use a named Cloudflare Tunnel
with a Cloudflare account/domain.

Remote computer public test:

```powershell
$base = "https://displays-touring-vancouver-pan.trycloudflare.com"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod "$base/health"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/status"
```

Latest Cloudflare verification:

- `GET /health` over Cloudflare succeeded.
- authenticated `GET /skill` over Cloudflare returned `remote_skill_data_interface`.
- authenticated `/skill/context?q=gaussian%20slam&paper_limit=5&text_limit=2`
  returned paper candidates and text snippets.
- unauthenticated `GET /skill` over Cloudflare returned HTTP `401`.

The Windows login startup entry for the active Cloudflare supervisor is:

```text
C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-cloudflare-watchdog.cmd
```

The older direct one-shot startup entry has been disabled as
`slam-ai-cloudflare-8766.cmd.disabled` so it does not race with the watchdog.

## Stable Cloudflare Named Tunnel Usage

Use this when other computers need a fixed public URL. This requires a
Cloudflare account and a hostname under a Cloudflare-managed zone. The
Cloudflare login cert and tunnel credentials stay on this Windows host; remote
computers only need the published endpoint manifest and the SLAM gateway bearer
token.

Current blocker if the named tunnel is not configured:

```text
C:\Users\Administrator\.cloudflared\cert.pem does not exist
```

Authorize once in the browser:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
.\tools\cloudflared.exe tunnel login
```

Create the ignored local config:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
Copy-Item .\examples\cloudflare_named_tunnel.env.example.json .\tmp\cloudflare_named_tunnel.env.json
notepad .\tmp\cloudflare_named_tunnel.env.json
```

Set `hostname` to the real fixed hostname, for example:

```json
{
  "tunnel_name": "slam-ai-gateway",
  "hostname": "slam-ai.example.com",
  "local_host": "localhost",
  "port": 8766,
  "origin_cert": "C:\\Users\\Administrator\\.cloudflared\\cert.pem"
}
```

Configure or reuse the tunnel and route DNS:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_cloudflare_named_tunnel.ps1 -OverwriteDns
```

Start the named tunnel and publish the endpoint manifest:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_cloudflare_named_tunnel.ps1 -UpdateEndpointManifest -CommitEndpointManifest
```

Install or refresh Windows login startup entries with the named tunnel watchdog:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install_windows_startup.ps1 -IncludeCloudflareNamedWatchdog
```

Named tunnel state is outside Git:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_named_tunnel.env.json
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_named_tunnel.credentials.json
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_named_tunnel.yml
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\cloudflare_named_tunnel.state.json
```

After it is healthy, the GitHub endpoint manifest should expose
`cloudflare-named-tunnel` with priority `5`; Quick Tunnel remains the fallback
with priority `10`.

## Public tunnelto Usage

tunnelto is used for computers outside the current LAN. The working client is
the crates.io build:

```text
C:\Users\Administrator\.cargo\bin\tunnelto.exe
```

The older GitHub release `0.1.18` was rejected by tunnelto's service with an
upgrade message. Use:

```powershell
cargo install tunnelto --version 0.1.20 --locked
```

The tunnelto access key is stored locally with:

```powershell
tunnelto set-auth --key <key>
```

The key store path is:

```text
C:\Users\Administrator\.tunnelto\key.token
```

Do not write the tunnelto key into this skill, Git, README files, or chat
summaries.

Start or restart the public tunnel:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_tunnelto_tunnel.ps1
```

The tunnel state and current public URL are written to:

```text
C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\tunnelto_8766.state.json
```

Earlier observed public URL on 2026-06-03:

```text
https://t-sn1ckacz.tunn.dev
```

This URL is not guaranteed to be stable unless a fixed tunnelto subdomain is
configured. Always check `tmp\tunnelto_8766.state.json` and verify `/health`
before reporting the current public URL.

Latest tunnelto check on 2026-06-03 after the gateway restart returned:

```text
Server terminated connection: Free trial expired.
```

That means outside-LAN access through tunnelto is currently blocked until the
tunnelto account/key has usable quota or another tunnel provider is configured.
LAN access and the local HTTP gateway still work.

Remote computer public test:

```powershell
$base = "https://t-sn1ckacz.tunn.dev"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod "$base/health"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/status"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/papers?q=gaussian%20slam&limit=5"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/search?q=loop%20closure&limit=5"
```

For a computer that is not on the same LAN, the full pattern is:

```text
base URL = fixed VPS/domain URL, current Cloudflare Quick Tunnel URL, tunnelto public URL, or LAN URL
token    = SLAM gateway bearer token from tmp\gateway_8766.env.json
header   = Authorization: Bearer <SLAM gateway bearer token>
```

Security check:

```powershell
Invoke-WebRequest "$base/status"
```

Expected result without bearer token: HTTP `401 Unauthorized`.

The Windows login startup entry is:

```text
C:\Users\Administrator\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\slam-ai-tunnelto-8766.cmd
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

Trigger the daily closed loop remotely:

```powershell
$base = "https://current-public-or-lan-base-url"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod `
  -Method Post `
  -Headers @{ Authorization = "Bearer $token" } `
  "$base/daily/run?force=false&wait=false"
```

## MCP Boundary

The gateway repo includes a stdio MCP server:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
$env:SLAM_AI_CORPUS_ROOT = "C:\Users\Administrator\Downloads\3DGS-SLAM-Papers"
python -m slam_ai_gateway.mcp_server
```

This is local stdio MCP. It works for an MCP client running on the same machine
or on a machine that has its own repo checkout and corpus access.

For other computers today, use the HTTP API through a fixed VPS/domain URL,
LAN, Cloudflare Quick Tunnel, or tunnelto. Do not claim remote MCP is available
until an HTTP-to-MCP bridge or hosted MCP transport is added.
