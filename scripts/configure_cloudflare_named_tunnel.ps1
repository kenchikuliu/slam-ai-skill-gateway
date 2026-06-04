param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$ConfigPath = "",
    [string]$CloudflaredExe = "",
    [string]$TunnelName = "",
    [string]$Hostname = "",
    [string]$LocalHost = "",
    [int]$Port = 0,
    [string]$OriginCert = "",
    [switch]$Login,
    [switch]$OverwriteDns
)

$ErrorActionPreference = "Stop"

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $RepoRoot "tmp\cloudflare_named_tunnel.env.json"
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

$TmpDir = Join-Path $RepoRoot "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

$Config = $null
if (Test-Path -LiteralPath $ConfigPath) {
    $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
}

function Get-ConfigString {
    param(
        [object]$ConfigObject,
        [string]$Name,
        [string]$Fallback = ""
    )
    if ($ConfigObject -and $ConfigObject.PSObject.Properties.Name -contains $Name -and $ConfigObject.$Name) {
        return [string]$ConfigObject.$Name
    }
    return $Fallback
}

function Get-ConfigInt {
    param(
        [object]$ConfigObject,
        [string]$Name,
        [int]$Fallback
    )
    if ($ConfigObject -and $ConfigObject.PSObject.Properties.Name -contains $Name -and $ConfigObject.$Name) {
        return [int]$ConfigObject.$Name
    }
    return $Fallback
}

$TunnelName = if ($TunnelName) { $TunnelName } else { Get-ConfigString -ConfigObject $Config -Name "tunnel_name" -Fallback "slam-ai-gateway" }
$Hostname = if ($Hostname) { $Hostname } else { Get-ConfigString -ConfigObject $Config -Name "hostname" }
$LocalHost = if ($LocalHost) { $LocalHost } else { Get-ConfigString -ConfigObject $Config -Name "local_host" -Fallback "localhost" }
$Port = if ($Port -gt 0) { $Port } else { Get-ConfigInt -ConfigObject $Config -Name "port" -Fallback 8766 }
$OriginCert = if ($OriginCert) { $OriginCert } else { Get-ConfigString -ConfigObject $Config -Name "origin_cert" }
if (-not $OriginCert -and $env:TUNNEL_ORIGIN_CERT) {
    $OriginCert = $env:TUNNEL_ORIGIN_CERT
}
if (-not $OriginCert) {
    $OriginCert = Join-Path $env:USERPROFILE ".cloudflared\cert.pem"
}

if (-not $Hostname) {
    throw "Missing hostname. Copy examples\cloudflare_named_tunnel.env.example.json to tmp\cloudflare_named_tunnel.env.json and set hostname, or pass -Hostname."
}

$Hostname = $Hostname.Trim().TrimEnd("/")
$Hostname = $Hostname -replace "^https?://", ""
if ($Hostname -eq "slam-ai.example.com" -or $Hostname -like "*.example.com") {
    throw "Hostname is still an example value: $Hostname. Set a real hostname under your Cloudflare zone."
}

if ($Login) {
    & $CloudflaredExe tunnel login
    if ($LASTEXITCODE -ne 0) {
        throw "cloudflared tunnel login failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Path -LiteralPath $OriginCert)) {
    throw "Missing Cloudflare origin cert: $OriginCert. Run: `"$CloudflaredExe`" tunnel login"
}

$CredentialPath = Get-ConfigString -ConfigObject $Config -Name "credentials_file" -Fallback (Join-Path $TmpDir "cloudflare_named_tunnel.credentials.json")
$CloudflaredConfigPath = Get-ConfigString -ConfigObject $Config -Name "cloudflared_config" -Fallback (Join-Path $TmpDir "cloudflare_named_tunnel.yml")
$StatePath = Join-Path $TmpDir "cloudflare_named_tunnel.state.json"

$ListOutput = & $CloudflaredExe tunnel --origincert $OriginCert list --output json --name $TunnelName 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "cloudflared tunnel list failed: $($ListOutput -join "`n")"
}

$Tunnel = $null
try {
    $Listed = $ListOutput | Out-String | ConvertFrom-Json
    $Tunnel = @($Listed | Where-Object { $_.name -eq $TunnelName -and -not $_.deletedAt } | Select-Object -First 1)[0]
} catch {
    $Tunnel = $null
}

if (-not $Tunnel) {
    $CreateOutput = & $CloudflaredExe tunnel --origincert $OriginCert create --credentials-file $CredentialPath --output json $TunnelName 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "cloudflared tunnel create failed: $($CreateOutput -join "`n")"
    }
    $Tunnel = $CreateOutput | Out-String | ConvertFrom-Json
} elseif (-not (Test-Path -LiteralPath $CredentialPath)) {
    $TokenOutput = & $CloudflaredExe tunnel --origincert $OriginCert token --cred-file $CredentialPath $TunnelName 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "cloudflared tunnel token failed: $($TokenOutput -join "`n")"
    }
}

$TunnelId = if ($Tunnel.id) { [string]$Tunnel.id } elseif ($Tunnel.ID) { [string]$Tunnel.ID } else { [string]$TunnelName }

$RouteArgs = @("tunnel", "--origincert", $OriginCert, "route", "dns")
if ($OverwriteDns) {
    $RouteArgs += "--overwrite-dns"
}
$RouteArgs += @($TunnelName, $Hostname)
$RouteOutput = & $CloudflaredExe @RouteArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "cloudflared tunnel route dns failed: $($RouteOutput -join "`n")"
}

$CredentialYaml = $CredentialPath.Replace("\", "\\")
$ServiceUrl = "http://$LocalHost`:$Port"
$Yaml = @"
tunnel: $TunnelId
credentials-file: "$CredentialYaml"
ingress:
  - hostname: $Hostname
    service: $ServiceUrl
  - service: http_status:404
"@
$Yaml | Set-Content -LiteralPath $CloudflaredConfigPath -Encoding ASCII

$PersistedConfig = [ordered]@{
    tunnel_name = $TunnelName
    hostname = $Hostname
    local_host = $LocalHost
    port = $Port
    origin_cert = $OriginCert
    credentials_file = $CredentialPath
    cloudflared_config = $CloudflaredConfigPath
}
$PersistedConfig | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8

$State = [ordered]@{
    status = "configured"
    configured_at = (Get-Date).ToString("s")
    tunnel_name = $TunnelName
    tunnel_id = $TunnelId
    hostname = $Hostname
    base_url = "https://$Hostname"
    target_url = $ServiceUrl
    origin_cert = $OriginCert
    credentials_file = $CredentialPath
    cloudflared_config = $CloudflaredConfigPath
    config_path = $ConfigPath
}
$State | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StatePath -Encoding UTF8
$State | ConvertTo-Json -Depth 6
