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
    $InstalledTunnelto = Join-Path $env:USERPROFILE ".cargo\bin\tunnelto.exe"
    $DownloadedTunnelto = Join-Path $RepoRoot "tools\tunnelto-windows.exe"
    if (Test-Path -LiteralPath $InstalledTunnelto) {
        $TunneltoExe = $InstalledTunnelto
    } else {
        $TunneltoExe = $DownloadedTunnelto
    }
}

if (-not (Test-Path -LiteralPath $TunneltoExe)) {
    throw "tunnelto executable not found: $TunneltoExe"
}

$StoredKeyPath = Join-Path $env:USERPROFILE ".tunnelto\key.token"
$AuthSource = "stored"
if ($Token) {
    $AuthSource = "argument"
} elseif (-not (Test-Path -LiteralPath $StoredKeyPath)) {
    throw "Missing tunnelto access key. Run tunnelto set-auth --key <key>, set TUNNELTO_KEY, or add tunnelto_key to $ConfigPath. Get one from https://dashboard.tunnelto.dev"
}

$TmpDir = Join-Path $RepoRoot "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

$Stdout = Join-Path $TmpDir "tunnelto_$Port.out.log"
$Stderr = Join-Path $TmpDir "tunnelto_$Port.err.log"
$StatePath = Join-Path $TmpDir "tunnelto_$Port.state.json"

$Existing = Get-Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Path -eq $TunneltoExe -or
        $_.Path -eq (Join-Path $RepoRoot "tools\tunnelto-windows.exe") -or
        $_.Path -eq (Join-Path $env:USERPROFILE ".cargo\bin\tunnelto.exe")
    }

if ($Existing) {
    $Existing | Stop-Process -Force
}

$Args = @("--port", "$Port", "--host", $LocalHost)
if ($Token) {
    $Args += @("--key", $Token)
}
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
    tunnelto_exe = $TunneltoExe
    port = $Port
    local_host = $LocalHost
    subdomain = $Subdomain
    auth_source = $AuthSource
    stdout = $Stdout
    stderr = $Stderr
    urls = @($Urls)
}

$State | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $StatePath -Encoding UTF8
$State | ConvertTo-Json -Depth 4
