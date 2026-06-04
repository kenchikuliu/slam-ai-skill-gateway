param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$LocalHealthUrl = "http://127.0.0.1:8766/health",
    [int]$IntervalSeconds = 120,
    [int]$TimeoutSeconds = 12,
    [int]$FailureThreshold = 1,
    [int]$RestartCooldownSeconds = 300,
    [int]$PostRestartReadySeconds = 90,
    [int]$ManifestRefreshSeconds = 900,
    [switch]$SkipManifestPush,
    [switch]$Once
)

$ErrorActionPreference = "Stop"

$TmpDir = Join-Path $RepoRoot "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

$StatePath = Join-Path $TmpDir "cloudflare_8766.state.json"
$LogPath = Join-Path $TmpDir "cloudflare_8766_watchdog.log"
$GatewayScript = Join-Path $RepoRoot "scripts\start_gateway_from_env.ps1"
$StartScript = Join-Path $RepoRoot "scripts\start_cloudflare_quick_tunnel.ps1"
$ManifestScript = Join-Path $RepoRoot "scripts\update_public_endpoint_manifest.ps1"
$ConsecutiveFailures = 0
$LastRestartAt = $null
$LastManifestRefreshAt = $null

function Write-WatchLog {
    param(
        [string]$Status,
        [string]$Message = "",
        [hashtable]$Extra = @{}
    )
    $Record = [ordered]@{
        time = (Get-Date).ToString("s")
        status = $Status
        message = $Message
    }
    foreach ($Key in $Extra.Keys) {
        $Record[$Key] = $Extra[$Key]
    }
    $Json = $Record | ConvertTo-Json -Compress -Depth 5
    $Json | Add-Content -LiteralPath $LogPath -Encoding UTF8
    Write-Output $Json
}

function Get-CloudflareUrl {
    if (-not (Test-Path -LiteralPath $StatePath)) {
        return ""
    }
    try {
        $State = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
        return @($State.urls | Where-Object { $_ -like "https://*.trycloudflare.com*" } | Select-Object -First 1)[0]
    } catch {
        return ""
    }
}

function Test-Health {
    param(
        [string]$BaseUrl,
        [string]$HealthUrl = ""
    )
    if (-not $HealthUrl) {
        if (-not $BaseUrl) {
            return [ordered]@{ ok = $false; status_code = $null; error = "missing_url" }
        }
        $HealthUrl = ($BaseUrl.TrimEnd("/")) + "/health"
    }
    try {
        $Response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec $TimeoutSeconds
        return [ordered]@{ ok = $true; status_code = [int]$Response.StatusCode; error = "" }
    } catch {
        $StatusCode = $null
        if ($_.Exception.Response) {
            $StatusCode = [int]$_.Exception.Response.StatusCode
        }
        return [ordered]@{ ok = $false; status_code = $StatusCode; error = $_.Exception.GetType().Name }
    }
}

function Ensure-LocalGateway {
    $Local = Test-Health -BaseUrl "" -HealthUrl $LocalHealthUrl
    if ($Local.ok) {
        return $Local
    }
    if (-not (Test-Path -LiteralPath $GatewayScript)) {
        throw "Missing gateway script: $GatewayScript"
    }

    Write-WatchLog -Status "local_gateway_restart" -Message $Local.error -Extra @{
        local_health_url = $LocalHealthUrl
        status_code = $Local.status_code
    } | Out-Null

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $GatewayScript) `
        -WorkingDirectory $RepoRoot `
        -WindowStyle Hidden | Out-Null

    for ($i = 0; $i -lt 45; $i++) {
        Start-Sleep -Seconds 1
        $Local = Test-Health -BaseUrl "" -HealthUrl $LocalHealthUrl
        if ($Local.ok) {
            return $Local
        }
    }
    return $Local
}

function Update-EndpointManifest {
    if (-not (Test-Path -LiteralPath $ManifestScript)) {
        return [ordered]@{ ok = $false; exit_code = $null; error = "missing_manifest_script" }
    }

    try {
        $Args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ManifestScript, "-RepoRoot", $RepoRoot)
        if (-not $SkipManifestPush) {
            $Args += "-CommitAndPush"
        }
        & powershell.exe @Args | Out-Null
        $ExitCode = $LASTEXITCODE
        return [ordered]@{ ok = ($ExitCode -eq 0 -or $null -eq $ExitCode); exit_code = $ExitCode; error = "" }
    } catch {
        return [ordered]@{ ok = $false; exit_code = $LASTEXITCODE; error = $_.Exception.Message }
    }
}

function Restart-CloudflareTunnel {
    if (-not (Test-Path -LiteralPath $StartScript)) {
        throw "Missing Cloudflare start script: $StartScript"
    }
    Write-WatchLog -Status "cloudflare_restart" -Message "Cloudflare health check failed" | Out-Null
    $Args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $StartScript)
    & powershell.exe @Args | Out-Null
    $ExitCode = $LASTEXITCODE
    Start-Sleep -Seconds 5
    return $ExitCode
}

function Wait-CloudflareHealthy {
    $Deadline = (Get-Date).AddSeconds([Math]::Max(1, $PostRestartReadySeconds))
    $LastUrl = ""
    $LastHealth = [ordered]@{ ok = $false; status_code = $null; error = "not_checked" }
    while ((Get-Date) -lt $Deadline) {
        $LastUrl = Get-CloudflareUrl
        $LastHealth = Test-Health -BaseUrl $LastUrl
        if ($LastHealth.ok) {
            return [ordered]@{
                ok = $true
                base_url = $LastUrl
                status_code = $LastHealth.status_code
                error = ""
            }
        }
        Start-Sleep -Seconds 3
    }

    return [ordered]@{
        ok = $false
        base_url = $LastUrl
        status_code = $LastHealth.status_code
        error = $LastHealth.error
    }
}

while ($true) {
    try {
        $Local = Ensure-LocalGateway
        $Url = Get-CloudflareUrl
        $Health = Test-Health -BaseUrl $Url
        if ($Health.ok) {
            $ConsecutiveFailures = 0
            $Manifest = $null
            $ShouldRefreshManifest = (-not $LastManifestRefreshAt)
            if ($LastManifestRefreshAt) {
                $SinceManifestRefresh = ((Get-Date) - $LastManifestRefreshAt).TotalSeconds
                if ($SinceManifestRefresh -ge $ManifestRefreshSeconds) {
                    $ShouldRefreshManifest = $true
                }
            }
            if ($ShouldRefreshManifest) {
                $Manifest = Update-EndpointManifest
                $LastManifestRefreshAt = Get-Date
            }

            Write-WatchLog -Status "ok" -Extra @{
                base_url = $Url
                status_code = $Health.status_code
                local_ok = $Local.ok
                manifest_refresh_ok = if ($Manifest) { $Manifest.ok } else { $null }
                manifest_refresh_exit_code = if ($Manifest) { $Manifest.exit_code } else { $null }
            }
        } else {
            $ConsecutiveFailures++
            $ShouldRestart = $ConsecutiveFailures -ge $FailureThreshold
            if ($LastRestartAt) {
                $SinceRestart = ((Get-Date) - $LastRestartAt).TotalSeconds
                if ($SinceRestart -lt $RestartCooldownSeconds) {
                    $ShouldRestart = $false
                }
            }

            if ($ShouldRestart) {
                $ExitCode = Restart-CloudflareTunnel
                $LastRestartAt = Get-Date
                $Ready = Wait-CloudflareHealthy
                $Manifest = $null
                if ($Ready.ok) {
                    $Manifest = Update-EndpointManifest
                    $LastManifestRefreshAt = Get-Date
                    $ConsecutiveFailures = 0
                }
                Write-WatchLog -Status $(if ($Ready.ok) { "recovered" } else { "still_failing" }) -Message $Health.error -Extra @{
                    old_base_url = $Url
                    new_base_url = $Ready.base_url
                    consecutive_failures = $ConsecutiveFailures
                    restart_exit_code = $ExitCode
                    local_ok = $Local.ok
                    after_status_code = $Ready.status_code
                    after_error = $Ready.error
                    manifest_refresh_ok = if ($Manifest) { $Manifest.ok } else { $null }
                    manifest_refresh_exit_code = if ($Manifest) { $Manifest.exit_code } else { $null }
                }
            } else {
                Write-WatchLog -Status "failure_observed" -Message $Health.error -Extra @{
                    base_url = $Url
                    status_code = $Health.status_code
                    consecutive_failures = $ConsecutiveFailures
                    local_ok = $Local.ok
                }
            }
        }
    } catch {
        Write-WatchLog -Status "watchdog_error" -Message $_.Exception.Message | Out-Null
    }

    if ($Once) {
        break
    }
    Start-Sleep -Seconds $IntervalSeconds
}
