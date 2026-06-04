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
# Prefer the published endpoint manifest instead of hard-coding one public URL.
$manifest = Invoke-RestMethod "https://raw.githubusercontent.com/kenchikuliu/slam-ai-skill-gateway/main/public/slam-ai-endpoints.json"
$base = $manifest.active_base_url
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod "$base/health"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
```

- `/skill` returns the discovery manifest, supported endpoints, corpus counts,
  and usage rules.
- `/skill/context` returns an agent-friendly bundle with status, paper
  candidates, extracted-text snippets when available, and optional graph
  summary.
- Remote computers do not need the PDF corpus if they use these HTTP endpoints.
  They only need the endpoint manifest and the SLAM gateway bearer token.
- The endpoint manifest contains no token. It selects the lowest-priority
  healthy endpoint, preferring a configured Cloudflare Named Tunnel, then
  Cloudflare Quick Tunnel, then the HK VPS path proxy.
- Do not hard-code a `trycloudflare.com` URL on remote computers. Quick Tunnel
  URLs are disposable; remote clients should read the GitHub manifest each time
  they need to connect.

## Resilient Public Endpoint Manifest

The public manifest is the stable handoff point for remote computers:

```text
https://raw.githubusercontent.com/kenchikuliu/slam-ai-skill-gateway/main/public/slam-ai-endpoints.json
```

It contains public base URLs and health status only; it never contains the SLAM
gateway bearer token. The intended selection rule is:

```text
use active_base_url, or the lowest-priority endpoint with health_ok=true
```

On the Windows host, `scripts\watch_cloudflare_named_tunnel.ps1` can maintain a
fixed Cloudflare hostname after named tunnel login/configuration.
`scripts\watch_cloudflare_quick_tunnel.ps1` maintains the account-less
`trycloudflare.com` fallback: it checks the local gateway, restarts it if
needed, checks the current Cloudflare Quick Tunnel `/health`, restarts the
tunnel when needed, and refreshes and pushes `public/slam-ai-endpoints.json`.
HK VPS remains a lower-priority stable fallback because it depends on reverse
SSH staying healthy.

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

## Stable Public URL With Cloudflare Named Tunnel

Use this when a fixed public hostname is required. Unlike Quick Tunnel, a named
Cloudflare Tunnel needs one browser authorization on this host and a Cloudflare
zone/domain that can receive the DNS route.

The Cloudflare login cert and tunnel credentials stay outside Git:

```text
C:\Users\Administrator\.cloudflared\cert.pem
tmp\cloudflare_named_tunnel.env.json
tmp\cloudflare_named_tunnel.credentials.json
tmp\cloudflare_named_tunnel.yml
tmp\cloudflare_named_tunnel.state.json
```

First authorize `cloudflared` once in the browser:

```powershell
cd C:\Users\Administrator\Downloads\slam-ai-skill-gateway
.\tools\cloudflared.exe tunnel login
```

Then create the local named tunnel config:

```powershell
Copy-Item .\examples\cloudflare_named_tunnel.env.example.json .\tmp\cloudflare_named_tunnel.env.json
notepad .\tmp\cloudflare_named_tunnel.env.json
```

Set `hostname` to a real hostname under your Cloudflare zone, for example:

```json
{
  "tunnel_name": "slam-ai-gateway",
  "hostname": "slam-ai.example.com",
  "local_host": "localhost",
  "port": 8766,
  "origin_cert": "C:\\Users\\Administrator\\.cloudflared\\cert.pem"
}
```

Configure or reuse the named tunnel and create the DNS route:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_cloudflare_named_tunnel.ps1 -OverwriteDns
```

Start it and publish the endpoint manifest:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_cloudflare_named_tunnel.ps1 -UpdateEndpointManifest -CommitEndpointManifest
```

Install login startup entries, including the named tunnel watchdog:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install_windows_startup.ps1 -IncludeCloudflareNamedWatchdog
```

When healthy, the public manifest prefers:

```text
cloudflare-named-tunnel priority 5 -> https://<fixed-hostname>
cloudflare-quick-tunnel priority 10 -> https://<random>.trycloudflare.com
hk-vps-path-proxy priority 20 -> http://83.229.126.28/slam-ai
```

Remote callers still need the SLAM gateway bearer token for every endpoint
except `/health`.

## Public Tunnel With Cloudflare Quick Tunnel

Cloudflare Quick Tunnel can expose the local gateway without a Cloudflare
account. The generated `*.trycloudflare.com` URL is temporary and can change
after restart. For a stable production URL, use a named Cloudflare Tunnel with a
Cloudflare account and domain.

Download `cloudflared.exe` into the ignored `tools\` directory, then start the
tunnel:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_cloudflare_quick_tunnel.ps1
```

To refresh the published endpoint manifest after a new Quick Tunnel URL is
created:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_cloudflare_quick_tunnel.ps1 -UpdateEndpointManifest -CommitEndpointManifest
```

The script forwards:

```text
https://<random>.trycloudflare.com -> http://localhost:8766
```

It writes state and logs to:

```text
tmp\cloudflare_8766.state.json
tmp\cloudflare_8766.out.log
tmp\cloudflare_8766.err.log
```

Read the current URL:

```powershell
$state = Get-Content -LiteralPath ".\tmp\cloudflare_8766.state.json" -Raw | ConvertFrom-Json
$state.urls | Select-Object -First 1
```

Remote callers still need the SLAM gateway bearer token for every endpoint
except `/health`.

For login-time resilience on this Windows host, run
`scripts\watch_cloudflare_quick_tunnel.ps1`. It restarts Cloudflare Quick Tunnel
when the current `*.trycloudflare.com` URL stops answering `/health`, starts the
local gateway first if `127.0.0.1:8766` is down, then updates and pushes
`public/slam-ai-endpoints.json`. While healthy, it also periodically refreshes
the manifest so GitHub reflects the current usable endpoint.

## Fixed Public Entry With Bandwagon VPS

Use a VPS when you need a stable public address. The VPS does not store the
paper corpus. It only receives public HTTP/HTTPS traffic and proxies it to a
reverse SSH tunnel back to this Windows host:

```text
remote caller -> VPS nginx -> 127.0.0.1:18766 on VPS -> SSH reverse tunnel -> Windows localhost:8766
```

Create a local config outside Git:

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

Save it as:

```text
tmp\bandwagon_reverse_ssh.env.json
```

Configure nginx on the VPS:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_bandwagon_vps.ps1
```

If the VPS already has websites on port `80`/`443`, prefer a path proxy on an
existing Nginx server instead of replacing the root site:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_bandwagon_path_proxy.ps1 -PathPrefix /slam-ai
```

This forwards:

```text
http://VPS_IP/slam-ai/... -> VPS 127.0.0.1:18766 -> Windows localhost:8766
```

If a domain already points to the VPS and you want HTTPS:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure_bandwagon_vps.ps1 -Domain slam.example.com -Email you@example.com -LetsEncrypt
```

Start the Windows reverse SSH tunnel:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_bandwagon_reverse_tunnel.ps1
```

Optionally run a conservative watchdog on the Windows host. It checks the
public `/slam-ai/health` endpoint and restarts the reverse SSH tunnel after
multiple consecutive failures, with a long restart cooldown to avoid aggressive
reconnect loops when the VPS SSH daemon is under pressure:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\watch_bandwagon_reverse_tunnel.ps1
```

For login-time startup on this Windows host, create a Startup `.cmd` that calls
the same script. It can use `-SkipIfMissingConfig` so login startup stays quiet
until `tmp\bandwagon_reverse_ssh.env.json` exists.

Then remote callers can use:

```powershell
$base = "http://VPS_IP/slam-ai"
# or, after domain/HTTPS setup:
# $base = "https://slam.example.com/slam-ai"
$token = "paste-the-slam-gateway-bearer-token"

Invoke-RestMethod "$base/health"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill"
Invoke-RestMethod -Headers @{ Authorization = "Bearer $token" } "$base/skill/context?q=gaussian%20slam&paper_limit=10&text_limit=5"
```

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

Install or refresh the Windows login startup entries:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install_windows_startup.ps1
```

This creates startup commands for the HTTP gateway and the Cloudflare watchdog.
It disables the older direct Cloudflare startup command by default so the
watchdog is the single owner of Quick Tunnel lifecycle and manifest publication.
Keep the gateway token in the local config file, not in Git.

To also create the Bandwagon watchdog startup entry:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install_windows_startup.ps1 -IncludeBandwagonWatchdog
```
