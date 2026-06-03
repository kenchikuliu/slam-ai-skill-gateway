param(
    [string]$ConfigPath = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\tunnelto_8766.env.json",
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$TunneltoExe = "",
    [int]$Port = 8766,
    [string]$LocalHost = "localhost",
    [string]$Token = "",
    [string]$Subdomain = "",
    [switch]$Foreground
)

$ErrorActionPreference = "Stop"

if ($ConfigPath -and (Test-Path -LiteralPath $ConfigPath)) {
    $Config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
    if (-not $TunneltoExe -and $Config.tunnelto_exe) { $TunneltoExe = [string]$Config.tunnelto_exe }
    if ($Config.port) { $Port = [int]$Config.port }
    if ($Config.local_host) { $LocalHost = [string]$Config.local_host }
    if (-not $Token -and $Config.tunnelto_key) { $Token = [string]$Config.tunnelto_key }
    if (-not $Subdomain -and $Config.subdomain) { $Subdomain = [string]$Config.subdomain }
}

if (-not $Token -and $env:TUNNELTO_KEY) {
    $Token = $env:TUNNELTO_KEY
}

if (-not $TunneltoExe) {
    $TunneltoExe = Join-Path $RepoRoot "tools\tunnelto-windows.exe"
}

if (-not (Test-Path -LiteralPath $TunneltoExe)) {
    throw "tunnelto executable not found: $TunneltoExe"
}

if (-not $Token) {
    throw "Missing tunnelto access key. Set TUNNELTO_KEY or add tunnelto_key to $ConfigPath. Get one from https://dashboard.tunnelto.dev"
}

$TmpDir = Join-Path $RepoRoot "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

$Stdout = Join-Path $TmpDir "tunnelto_$Port.out.log"
$Stderr = Join-Path $TmpDir "tunnelto_$Port.err.log"
$StatePath = Join-Path $TmpDir "tunnelto_$Port.state.json"

$Existing = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $TunneltoExe }

if ($Existing) {
    $Existing | Stop-Process -Force
}

$Args = @("--port", "$Port", "--host", $LocalHost, "--key", $Token)
if ($Subdomain) {
    $Args += @("--subdomain", $Subdomain)
}

if ($Foreground) {
    & $TunneltoExe @Args
    exit $LASTEXITCODE
}

Remove-Item -LiteralPath $Stdout, $Stderr -ErrorAction SilentlyContinue

$Process = Start-Process `
    -FilePath $TunneltoExe `
    -ArgumentList $Args `
    -WorkingDirectory $RepoRoot `
    -RedirectStandardOutput $Stdout `
    -RedirectStandardError $Stderr `
    -WindowStyle Hidden `
    -PassThru

Start-Sleep -Seconds 5

$Output = ""
if (Test-Path -LiteralPath $Stdout) {
    $Output += Get-Content -Raw -LiteralPath $Stdout
}
if (Test-Path -LiteralPath $Stderr) {
    $Output += "`n"
    $Output += Get-Content -Raw -LiteralPath $Stderr
}

$UrlPattern = "https?://[A-Za-z0-9.-]+(?:\:[0-9]+)?"
$Urls = [regex]::Matches($Output, $UrlPattern) | ForEach-Object { $_.Value } | Select-Object -Unique

$State = [ordered]@{
    pid = $Process.Id
    started_at = (Get-Date).ToString("s")
    port = $Port
    local_host = $LocalHost
    subdomain = $Subdomain
    stdout = $Stdout
    stderr = $Stderr
    urls = @($Urls)
}

$State | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $StatePath -Encoding UTF8
$State | ConvertTo-Json -Depth 4
