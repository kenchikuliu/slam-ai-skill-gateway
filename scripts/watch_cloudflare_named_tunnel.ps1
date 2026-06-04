param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$ConfigPath = "",
    [string]$LocalHealthUrl = "http://127.0.0.1:8766/health",
    [int]$IntervalSeconds = 120,
    [int]$TimeoutSeconds = 12,
    [int]$FailureThreshold = 1,
    [int]$RestartCooldownSeconds = 300,
    [int]$ManifestRefreshSeconds = 900,
    [switch]$SkipManifestPush,
    [switch]$Once
)

$ErrorActionPreference = "Stop"

if (-not $ConfigPath) {
    $ConfigPath = Join-Path $RepoRoot "tmp\cloudflare_named_tunnel.env.json"
}

$TmpDir = Join-Path $RepoRoot "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

$StatePath = Join-Path $TmpDir "cloudflare_named_tunnel.state.json"
$LogPath = Join-Path $TmpDir "cloudflare_named_tunnel_watchdog.log"
$GatewayScript = Join-Path $RepoRoot "scripts\start_gateway_from_env.ps1"
$StartScript = Join-Path $RepoRoot "scripts\start_cloudflare_named_tunnel.ps1"
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

function Get-NamedTunnelBaseUrl {
    if (Test-Path -LiteralPath $StatePath) {
        try {
            $State = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
            if ($State.base_url) {
                return [string]$State.base_url
            }
        } catch {
        }
    }
    if (Test-Path -LiteralPath $ConfigPath) {
        try {
            $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
            if ($Config.hostname) {
                $HostName = ([string]$Config.hostname).Trim().TrimEnd("/")
                $HostName = $HostName -replace "^https?://", ""
                return "https://$HostName"
            }
        } catch {
        }
    }
    return ""
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

function Restart-NamedTunnel {
    if (-not (Test-Path -LiteralPath $StartScript)) {
        throw "Missing Cloudflare named tunnel start script: $StartScript"
    }
    Write-WatchLog -Status "named_tunnel_restart" -Message "Named tunnel health check failed" | Out-Null
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $StartScript -RepoRoot $RepoRoot -ConfigPath $ConfigPath -SkipIfMissingConfig | Out-Null
    $ExitCode = $LASTEXITCODE
    Start-Sleep -Seconds 5
    return $ExitCode
}

while ($true) {
    try {
        if (-not (Test-Path -LiteralPath $ConfigPath)) {
            Write-WatchLog -Status "config_missing" -Message "Named tunnel is not configured" -Extra @{
                config_path = $ConfigPath
            }
            if ($Once) {
                break
            }
            Start-Sleep -Seconds $IntervalSeconds
            continue
        }

        $Local = Ensure-LocalGateway
        $BaseUrl = Get-NamedTunnelBaseUrl
        $Health = Test-Health -BaseUrl $BaseUrl
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
                base_url = $BaseUrl
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
                $ExitCode = Restart-NamedTunnel
                $LastRestartAt = Get-Date
                $NewBaseUrl = Get-NamedTunnelBaseUrl
                $After = Test-Health -BaseUrl $NewBaseUrl
                $Manifest = $null
                if ($After.ok) {
                    $ConsecutiveFailures = 0
                    $Manifest = Update-EndpointManifest
                    $LastManifestRefreshAt = Get-Date
                }
                Write-WatchLog -Status $(if ($After.ok) { "recovered" } else { "still_failing" }) -Message $Health.error -Extra @{
                    old_base_url = $BaseUrl
                    new_base_url = $NewBaseUrl
                    consecutive_failures = $ConsecutiveFailures
                    restart_exit_code = $ExitCode
                    local_ok = $Local.ok
                    after_status_code = $After.status_code
                    after_error = $After.error
                    manifest_refresh_ok = if ($Manifest) { $Manifest.ok } else { $null }
                    manifest_refresh_exit_code = if ($Manifest) { $Manifest.exit_code } else { $null }
                }
            } else {
                Write-WatchLog -Status "failure_observed" -Message $Health.error -Extra @{
                    base_url = $BaseUrl
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
