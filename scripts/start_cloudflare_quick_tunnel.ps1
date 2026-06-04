param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$CloudflaredExe = "",
    [int]$Port = 8766,
    [string]$LocalHost = "localhost",
    [int]$WaitForGatewaySeconds = 45,
    [switch]$UpdateEndpointManifest,
    [switch]$CommitEndpointManifest,
    [switch]$Foreground
)

$ErrorActionPreference = "Stop"

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

$Stdout = Join-Path $TmpDir "cloudflare_$Port.out.log"
$Stderr = Join-Path $TmpDir "cloudflare_$Port.err.log"
$StatePath = Join-Path $TmpDir "cloudflare_$Port.state.json"

$Existing = Get-CimInstance Win32_Process -Filter "Name = 'cloudflared.exe'" -ErrorAction SilentlyContinue |
    Where-Object {
        $Executable = if ($_.ExecutablePath) { $_.ExecutablePath } else { "" }
        $CommandLine = if ($_.CommandLine) { $_.CommandLine } else { "" }
        ($Executable -eq $CloudflaredExe -or $Executable -eq (Join-Path $RepoRoot "tools\cloudflared.exe")) -and
        ($CommandLine -like "* tunnel *--url *" -or $CommandLine -like "* tunnel --url *")
    }

foreach ($ProcessInfo in @($Existing)) {
    Stop-Process -Id $ProcessInfo.ProcessId -Force -ErrorAction SilentlyContinue
}

$TargetUrl = "http://$LocalHost`:$Port"
$Args = @("tunnel", "--url", $TargetUrl)

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

$UrlPattern = "https://[A-Za-z0-9-]+(?:-[A-Za-z0-9-]+)*\.trycloudflare\.com"
$Urls = @()
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 500
    $Output = ""
    if (Test-Path -LiteralPath $Stdout) {
        $Output += Get-Content -Raw -LiteralPath $Stdout -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $Stderr) {
        $Output += "`n"
        $Output += Get-Content -Raw -LiteralPath $Stderr -ErrorAction SilentlyContinue
    }
    $Urls = @([regex]::Matches($Output, $UrlPattern) | ForEach-Object { $_.Value } | Select-Object -Unique)
    if ($Urls.Count -gt 0) {
        break
    }
    if ($Process.HasExited) {
        break
    }
}

$State = [ordered]@{
    pid = $Process.Id
    started_at = (Get-Date).ToString("s")
    cloudflared_exe = $CloudflaredExe
    cloudflared_version = (& $CloudflaredExe --version 2>$null)
    port = $Port
    local_host = $LocalHost
    target_url = $TargetUrl
    stdout = $Stdout
    stderr = $Stderr
    urls = @($Urls)
    status = if ($Urls.Count -gt 0 -and -not $Process.HasExited) { "running" } elseif ($Process.HasExited) { "exited" } else { "starting" }
}

$State | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $StatePath -Encoding UTF8
Write-Output ($State | ConvertTo-Json -Depth 4)

if ($UpdateEndpointManifest) {
    $ManifestScript = Join-Path $RepoRoot "scripts\update_public_endpoint_manifest.ps1"
    if (-not (Test-Path -LiteralPath $ManifestScript)) {
        throw "Missing endpoint manifest script: $ManifestScript"
    }
    $ManifestArgs = @(
        "-RepoRoot", $RepoRoot
    )
    if ($CommitEndpointManifest) {
        $ManifestArgs += "-CommitAndPush"
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ManifestScript @ManifestArgs
}
