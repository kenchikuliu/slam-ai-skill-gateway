param(
    [string]$ConfigPath = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\gateway_8766.env.json",
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Gateway config not found: $ConfigPath"
}

$Config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$HostAddress = if ($Config.host) { [string]$Config.host } else { "127.0.0.1" }
$Port = if ($Config.port) { [int]$Config.port } else { 8765 }
$CorpusRoot = if ($Config.corpus_root) { [string]$Config.corpus_root } else { "C:\Users\Administrator\Downloads\3DGS-SLAM-Papers" }
$Token = if ($Config.token) { [string]$Config.token } else { "" }
$LogPath = if ($Config.log) { [string]$Config.log } else { Join-Path $RepoRoot "tmp\gateway_$Port.log" }

$Existing = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($Existing) {
    Write-Output "gateway_port_already_listening port=$Port process=$($Existing.OwningProcess -join ',')"
    exit 0
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LogPath) | Out-Null

$env:PYTHONPATH = Join-Path $RepoRoot "src"
$env:SLAM_AI_CORPUS_ROOT = $CorpusRoot
$env:SLAM_AI_GATEWAY_TOKEN = $Token

Set-Location $RepoRoot
python -m slam_ai_gateway.http_server --host $HostAddress --port $Port *> $LogPath
