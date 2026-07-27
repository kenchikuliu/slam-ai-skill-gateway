param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$OutputPath = "",
    [string]$HkBaseUrl = "http://83.229.126.28/slam-ai",
    [int]$TimeoutSeconds = 10,
    [switch]$CommitAndPush
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "remote_access_common.ps1")

if (-not $OutputPath) {
    $OutputPath = Join-Path $RepoRoot "public\slam-ai-endpoints.json"
}

function Test-Health {
    param([string]$BaseUrl)
    $HealthUrl = ($BaseUrl.TrimEnd("/")) + "/health"
    return Test-SlamAiGatewayHealth -HealthUrl $HealthUrl -TimeoutSeconds $TimeoutSeconds
}

function Add-Endpoint {
    param(
        [System.Collections.Generic.List[object]]$Endpoints,
        [string]$Name,
        [string]$Kind,
        [string]$BaseUrl,
        [bool]$Stable,
        [int]$HealthyPriority,
        [int]$UnhealthyPriority,
        [string]$Note = ""
    )
    if (-not $BaseUrl) {
        return
    }
    $BaseUrl = $BaseUrl.TrimEnd("/")
    if ($Endpoints | Where-Object { $_.base_url -eq $BaseUrl }) {
        return
    }
    $Health = Test-Health -BaseUrl $BaseUrl
    $Endpoints.Add([ordered]@{
        name = $Name
        kind = $Kind
        base_url = $BaseUrl
        health_ok = $Health.ok
        health_status_code = $Health.status_code
        health_error = $Health.error
        stable_url = $Stable
        authentication_safe = Test-SlamAiSecureRemoteBaseUrl -BaseUrl $BaseUrl
        priority = if ($Health.ok) { $HealthyPriority } else { $UnhealthyPriority }
        note = $Note
    }) | Out-Null
}

$Endpoints = [System.Collections.Generic.List[object]]::new()

$NamedTunnelConfigPath = Join-Path $RepoRoot "tmp\cloudflare_named_tunnel.env.json"
$NamedTunnelStatePath = Join-Path $RepoRoot "tmp\cloudflare_named_tunnel.state.json"
$NamedTunnelBaseUrl = ""
if (Test-Path -LiteralPath $NamedTunnelStatePath) {
    try {
        $NamedTunnelState = Get-Content -LiteralPath $NamedTunnelStatePath -Raw | ConvertFrom-Json
        if ($NamedTunnelState.base_url) {
            $NamedTunnelBaseUrl = [string]$NamedTunnelState.base_url
        }
    } catch {
        $NamedTunnelBaseUrl = ""
    }
}
if (-not $NamedTunnelBaseUrl -and (Test-Path -LiteralPath $NamedTunnelConfigPath)) {
    try {
        $NamedTunnelConfig = Get-Content -LiteralPath $NamedTunnelConfigPath -Raw | ConvertFrom-Json
        if ($NamedTunnelConfig.hostname) {
            $HostName = ([string]$NamedTunnelConfig.hostname).Trim().TrimEnd("/")
            $HostName = $HostName -replace "^https?://", ""
            $NamedTunnelBaseUrl = "https://$HostName"
        }
    } catch {
        $NamedTunnelBaseUrl = ""
    }
}

if ($NamedTunnelBaseUrl) {
    $NamedTunnelHost = $NamedTunnelBaseUrl.TrimEnd("/") -replace "^https?://", ""
    if ($NamedTunnelHost -ne "slam-ai.example.com" -and $NamedTunnelHost -notlike "*.example.com") {
        Add-Endpoint `
            -Endpoints $Endpoints `
            -Name "cloudflare-named-tunnel" `
            -Kind "cloudflare_named_tunnel" `
            -BaseUrl $NamedTunnelBaseUrl `
            -Stable $true `
            -HealthyPriority 5 `
            -UnhealthyPriority 70 `
            -Note "Preferred stable Cloudflare Tunnel hostname. Requires local named tunnel config and DNS route."
    }
}

$CloudflareStatePath = Join-Path $RepoRoot "tmp\cloudflare_8766.state.json"
if (Test-Path -LiteralPath $CloudflareStatePath) {
    $QuickTunnelUrl = Get-SlamAiRunningQuickTunnelUrl -StatePath $CloudflareStatePath
    if ($QuickTunnelUrl) {
        Add-Endpoint `
            -Endpoints $Endpoints `
            -Name "cloudflare-quick-tunnel" `
            -Kind "cloudflare_quick_tunnel" `
            -BaseUrl $QuickTunnelUrl `
            -Stable $false `
            -HealthyPriority 10 `
            -UnhealthyPriority 80 `
            -Note "Best current public fallback. URL can change after cloudflared restarts."
    }
}

Add-Endpoint `
    -Endpoints $Endpoints `
    -Name "hk-vps-path-proxy" `
    -Kind "bandwagon_vps_path_proxy" `
    -BaseUrl $HkBaseUrl `
    -Stable $true `
    -HealthyPriority 20 `
    -UnhealthyPriority 90 `
    -Note "Diagnostic fallback only until HTTPS is configured. Do not send bearer tokens over plain HTTP."

$SortedEndpoints = @($Endpoints | Sort-Object @{Expression = { $_.priority }; Ascending = $true}, @{Expression = { $_.name }; Ascending = $true})
$Active = Select-SlamAiHealthyEndpoint -Manifest ([pscustomobject]@{
    active_base_url = ""
    endpoints = $SortedEndpoints
})

$Manifest = [ordered]@{
    schema = "slam-ai-endpoints.v1"
    token_required = $true
    token_included = $false
    bearer_header = "Authorization: Bearer <SLAM_AI_TOKEN>"
    active_base_url = if ($null -ne $Active) { $Active.base_url } else { "" }
    selection_rule = "Use active_base_url or the lowest-priority endpoint with health_ok=true and authentication_safe=true. Never send bearer tokens to plain HTTP endpoints."
    endpoints = $SortedEndpoints
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
$Json = $Manifest | ConvertTo-Json -Depth 8
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($OutputPath, $Json + "`n", $Utf8NoBom)
Write-Output $Json

if ($CommitAndPush) {
    $ResolvedRepo = (Resolve-Path -LiteralPath $RepoRoot).Path.TrimEnd("\")
    $ResolvedOutput = (Resolve-Path -LiteralPath $OutputPath).Path
    if (-not $ResolvedOutput.StartsWith($ResolvedRepo, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Output path is outside repo: $ResolvedOutput"
    }
    $RelativeOutput = $ResolvedOutput.Substring($ResolvedRepo.Length).TrimStart("\", "/")
    & git -C $RepoRoot add $RelativeOutput
    if ($LASTEXITCODE -ne 0) {
        throw "git add failed for $RelativeOutput"
    }
    $Status = & git -C $RepoRoot status --short -- $RelativeOutput
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed for $RelativeOutput"
    }
    if ($Status) {
        & git -C $RepoRoot commit -m "Update public SLAM AI endpoint manifest"
        if ($LASTEXITCODE -ne 0) {
            throw "git commit failed for $RelativeOutput"
        }
    }

    & git -C $RepoRoot push origin main
    if ($LASTEXITCODE -ne 0) {
        throw "git push failed for endpoint manifest"
    }
}
