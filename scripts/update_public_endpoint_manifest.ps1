param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$OutputPath = "",
    [string]$HkBaseUrl = "http://83.229.126.28/slam-ai",
    [int]$TimeoutSeconds = 10,
    [switch]$CommitAndPush
)

$ErrorActionPreference = "Stop"

if (-not $OutputPath) {
    $OutputPath = Join-Path $RepoRoot "public\slam-ai-endpoints.json"
}

function Test-Health {
    param([string]$BaseUrl)
    $HealthUrl = ($BaseUrl.TrimEnd("/")) + "/health"
    try {
        $Response = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec $TimeoutSeconds
        return [ordered]@{
            ok = [bool]$Response.ok
            status_code = 200
            error = ""
        }
    } catch {
        $StatusCode = $null
        if ($_.Exception.Response) {
            $StatusCode = [int]$_.Exception.Response.StatusCode
        }
        return [ordered]@{
            ok = $false
            status_code = $StatusCode
            error = $_.Exception.GetType().Name
        }
    }
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
    $CloudflareState = Get-Content -LiteralPath $CloudflareStatePath -Raw | ConvertFrom-Json
    foreach ($Url in @($CloudflareState.urls)) {
        if ($Url -and $Url -like "https://*.trycloudflare.com*") {
            Add-Endpoint `
                -Endpoints $Endpoints `
                -Name "cloudflare-quick-tunnel" `
                -Kind "cloudflare_quick_tunnel" `
                -BaseUrl $Url `
                -Stable $false `
                -HealthyPriority 10 `
                -UnhealthyPriority 80 `
                -Note "Best current public fallback. URL can change after cloudflared restarts."
        }
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
    -Note "Stable address, but depends on the Windows-to-VPS reverse SSH tunnel."

$SortedEndpoints = @($Endpoints | Sort-Object @{Expression = { $_.priority }; Ascending = $true}, @{Expression = { $_.name }; Ascending = $true})
$Active = $SortedEndpoints | Where-Object { $_.health_ok } | Select-Object -First 1
if (-not $Active) {
    $Active = $SortedEndpoints | Select-Object -First 1
}

$Manifest = [ordered]@{
    schema = "slam-ai-endpoints.v1"
    token_required = $true
    token_included = $false
    bearer_header = "Authorization: Bearer <SLAM_AI_TOKEN>"
    active_base_url = if ($Active) { $Active.base_url } else { "" }
    selection_rule = "Use the lowest-priority endpoint with health_ok=true. If none are healthy, retry later or use the local host."
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
