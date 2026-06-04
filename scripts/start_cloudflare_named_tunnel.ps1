param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$ConfigPath = "",
    [string]$CloudflaredExe = "",
    [int]$WaitForGatewaySeconds = 45,
    [int]$WaitForPublicSeconds = 90,
    [switch]$UpdateEndpointManifest,
    [switch]$CommitEndpointManifest,
    [switch]$SkipIfMissingConfig,
    [switch]$Foreground
)

$ErrorActionPreference = "Stop"

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $RepoRoot "tmp\cloudflare_named_tunnel.env.json"
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    if ($SkipIfMissingConfig) {
        Write-Output "cloudflare_named_tunnel_config_missing path=$ConfigPath"
        exit 0
    }
    throw "Cloudflare named tunnel config not found: $ConfigPath. Run scripts\configure_cloudflare_named_tunnel.ps1 first."
}

if (-not $CloudflaredExe) {
    $LocalTool = Join-Path $RepoRoot "tools\cloudflared.exe"
    $Installed = Get-Command cloudflared -ErrorAction SilentlyContinue
    if ($Installed) {
        $CloudflaredExe = $Installed.Source
    } else {
        $CloudflaredExe = $LocalTool
    }
}

if (-not (Test-Path -LiteralPath $CloudflaredExe)) {
    throw "cloudflared executable not found: $CloudflaredExe"
}

$Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$TunnelName = if ($Config.tunnel_name) { [string]$Config.tunnel_name } else { "slam-ai-gateway" }
$Hostname = if ($Config.hostname) { [string]$Config.hostname } else { "" }
$LocalHost = if ($Config.local_host) { [string]$Config.local_host } else { "localhost" }
$Port = if ($Config.port) { [int]$Config.port } else { 8766 }
$CloudflaredConfigPath = if ($Config.cloudflared_config) { [string]$Config.cloudflared_config } else { Join-Path $RepoRoot "tmp\cloudflare_named_tunnel.yml" }

if (-not $Hostname) {
    throw "Missing hostname in $ConfigPath"
}
$Hostname = $Hostname.Trim().TrimEnd("/")
$Hostname = $Hostname -replace "^https?://", ""
if ($Hostname -eq "slam-ai.example.com" -or $Hostname -like "*.example.com") {
    throw "Hostname is still an example value: $Hostname. Set a real hostname under your Cloudflare zone."
}
if (-not (Test-Path -LiteralPath $CloudflaredConfigPath)) {
    throw "Missing cloudflared config: $CloudflaredConfigPath. Run scripts\configure_cloudflare_named_tunnel.ps1 first."
}

$HealthUrl = "http://$LocalHost`:$Port/health"
$GatewayReady = $false
for ($i = 0; $i -lt [Math]::Max(1, $WaitForGatewaySeconds); $i++) {
    try {
        Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 3 | Out-Null
        $GatewayReady = $true
        break
    } catch {
        Start-Sleep -Seconds 1
    }
}

if (-not $GatewayReady) {
    throw "Local gateway is not reachable at $HealthUrl. Start scripts\start_gateway_from_env.ps1 first."
}

$TmpDir = Join-Path $RepoRoot "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

$Stdout = Join-Path $TmpDir "cloudflare_named_tunnel.out.log"
$Stderr = Join-Path $TmpDir "cloudflare_named_tunnel.err.log"
$StatePath = Join-Path $TmpDir "cloudflare_named_tunnel.state.json"

$Existing = Get-CimInstance Win32_Process -Filter "Name = 'cloudflared.exe'" -ErrorAction SilentlyContinue |
    Where-Object {
        $CommandLine = if ($_.CommandLine) { $_.CommandLine } else { "" }
        ($CommandLine -like "*$CloudflaredConfigPath*" -or $CommandLine -like "* $TunnelName*" -or $CommandLine -like "*`"$TunnelName`"*") -and
        $CommandLine -like "* tunnel *run*"
    }

foreach ($ProcessInfo in @($Existing)) {
    Stop-Process -Id $ProcessInfo.ProcessId -Force -ErrorAction SilentlyContinue
}

$Args = @("tunnel", "--config", $CloudflaredConfigPath, "run")

if ($Foreground) {
    & $CloudflaredExe @Args
    exit $LASTEXITCODE
}

Remove-Item -LiteralPath $Stdout, $Stderr -ErrorAction SilentlyContinue

$Process = Start-Process `
    -FilePath $CloudflaredExe `
    -ArgumentList $Args `
    -WorkingDirectory $RepoRoot `
    -RedirectStandardOutput $Stdout `
    -RedirectStandardError $Stderr `
    -WindowStyle Hidden `
    -PassThru

$BaseUrl = "https://$Hostname"
$PublicHealth = [ordered]@{ ok = $false; status_code = $null; error = "not_checked" }
for ($i = 0; $i -lt [Math]::Max(1, $WaitForPublicSeconds); $i++) {
    Start-Sleep -Seconds 1
    if ($Process.HasExited) {
        break
    }
    try {
        $Response = Invoke-RestMethod -Uri ($BaseUrl.TrimEnd("/") + "/health") -TimeoutSec 5
        $PublicHealth = [ordered]@{ ok = [bool]$Response.ok; status_code = 200; error = "" }
        if ($PublicHealth.ok) {
            break
        }
    } catch {
        $StatusCode = $null
        if ($_.Exception.Response) {
            $StatusCode = [int]$_.Exception.Response.StatusCode
        }
        $PublicHealth = [ordered]@{ ok = $false; status_code = $StatusCode; error = $_.Exception.GetType().Name }
    }
}

$State = [ordered]@{
    pid = $Process.Id
    started_at = (Get-Date).ToString("s")
    cloudflared_exe = $CloudflaredExe
    cloudflared_version = (& $CloudflaredExe --version 2>$null)
    tunnel_name = $TunnelName
    hostname = $Hostname
    base_url = $BaseUrl
    port = $Port
    local_host = $LocalHost
    target_url = "http://$LocalHost`:$Port"
    config_path = $ConfigPath
    cloudflared_config = $CloudflaredConfigPath
    stdout = $Stdout
    stderr = $Stderr
    health_ok = $PublicHealth.ok
    health_status_code = $PublicHealth.status_code
    health_error = $PublicHealth.error
    status = if (-not $Process.HasExited) { "running" } else { "exited" }
}

$State | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StatePath -Encoding UTF8
Write-Output ($State | ConvertTo-Json -Depth 6)

if ($UpdateEndpointManifest) {
    $ManifestScript = Join-Path $RepoRoot "scripts\update_public_endpoint_manifest.ps1"
    if (-not (Test-Path -LiteralPath $ManifestScript)) {
        throw "Missing endpoint manifest script: $ManifestScript"
    }
    $ManifestArgs = @("-RepoRoot", $RepoRoot)
    if ($CommitEndpointManifest) {
        $ManifestArgs += "-CommitAndPush"
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ManifestScript @ManifestArgs
}
