param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$LocalHealthUrl = "http://127.0.0.1:8766/health",
    [int]$IntervalSeconds = 120,
    [int]$TimeoutSeconds = 12,
    [int]$FailureThreshold = 1,
    [int]$RestartCooldownSeconds = 300,
    [int]$PostRestartReadySeconds = 90,
    [int]$ManifestRefreshSeconds = 900,
    [int]$ManifestUpdateTimeoutSeconds = 120,
    [int]$TunnelRestartTimeoutSeconds = 120,
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
$ManifestPath = Join-Path $RepoRoot "public\slam-ai-endpoints.json"
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

function Invoke-PowerShellScriptWithTimeout {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @(),
        [int]$TimeoutSeconds = 120,
        [string]$Name = "script"
    )

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        return [pscustomobject][ordered]@{ ok = $false; exit_code = $null; timed_out = $false; error = "missing_script"; pid = $null; stdout = ""; stderr = "" }
    }

    function Quote-ProcessArgument {
        param([string]$Value)
        if ($null -eq $Value) {
            return '""'
        }
        if ($Value -notmatch '[\s"]') {
            return $Value
        }
        return '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
    }

    $Stamp = (Get-Date).ToString("yyyyMMdd_HHmmss_fff")
    $StdoutPath = Join-Path $TmpDir "$Name.$Stamp.out.log"
    $StderrPath = Join-Path $TmpDir "$Name.$Stamp.err.log"
    $PowerShellArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ScriptPath)
    foreach ($Argument in @($Arguments)) {
        $PowerShellArgs += $Argument
    }

    try {
        $StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $StartInfo.FileName = "powershell.exe"
        $StartInfo.Arguments = (($PowerShellArgs | ForEach-Object { Quote-ProcessArgument $_ }) -join " ")
        $StartInfo.WorkingDirectory = $RepoRoot
        $StartInfo.UseShellExecute = $false
        $StartInfo.CreateNoWindow = $true
        $StartInfo.RedirectStandardOutput = $true
        $StartInfo.RedirectStandardError = $true

        $Process = [System.Diagnostics.Process]::new()
        $Process.StartInfo = $StartInfo
        [void]$Process.Start()

        $Exited = $Process.WaitForExit([Math]::Max(1, $TimeoutSeconds) * 1000)
        if (-not $Exited) {
            try {
                $Process.Kill()
            } catch {
                Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
            }
            $StdoutText = $Process.StandardOutput.ReadToEnd()
            $StderrText = $Process.StandardError.ReadToEnd()
            [System.IO.File]::WriteAllText($StdoutPath, $StdoutText, [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::WriteAllText($StderrPath, $StderrText, [System.Text.UTF8Encoding]::new($false))
            return [pscustomobject][ordered]@{ ok = $false; exit_code = $null; timed_out = $true; error = "timeout"; pid = $Process.Id; stdout = $StdoutPath; stderr = $StderrPath }
        }

        $StdoutText = $Process.StandardOutput.ReadToEnd()
        $StderrText = $Process.StandardError.ReadToEnd()
        [System.IO.File]::WriteAllText($StdoutPath, $StdoutText, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($StderrPath, $StderrText, [System.Text.UTF8Encoding]::new($false))
        return [pscustomobject][ordered]@{ ok = ($Process.ExitCode -eq 0); exit_code = $Process.ExitCode; timed_out = $false; error = ""; pid = $Process.Id; stdout = $StdoutPath; stderr = $StderrPath }
    } catch {
        return [pscustomobject][ordered]@{ ok = $false; exit_code = $null; timed_out = $false; error = $_.Exception.Message; pid = $null; stdout = $StdoutPath; stderr = $StderrPath }
    }
}

function Get-CurrentManifestBaseUrl {
    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        return ""
    }
    try {
        $Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
        if ($Manifest.active_base_url) {
            return [string]$Manifest.active_base_url
        }
    } catch {
        return ""
    }
    return ""
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
        return [pscustomobject][ordered]@{ ok = $false; exit_code = $null; timed_out = $false; error = "missing_manifest_script"; stdout = ""; stderr = "" }
    }

    $Args = @("-RepoRoot", $RepoRoot)
    if (-not $SkipManifestPush) {
        $Args += "-CommitAndPush"
    }
    return Invoke-PowerShellScriptWithTimeout -ScriptPath $ManifestScript -Arguments $Args -TimeoutSeconds $ManifestUpdateTimeoutSeconds -Name "endpoint_manifest_update"
}

function Restart-CloudflareTunnel {
    if (-not (Test-Path -LiteralPath $StartScript)) {
        throw "Missing Cloudflare start script: $StartScript"
    }
    Write-WatchLog -Status "cloudflare_restart" -Message "Cloudflare health check failed" | Out-Null
    $Result = Invoke-PowerShellScriptWithTimeout -ScriptPath $StartScript -TimeoutSeconds $TunnelRestartTimeoutSeconds -Name "cloudflare_restart"
    Start-Sleep -Seconds 5
    return $Result
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
            $ManifestBaseUrl = Get-CurrentManifestBaseUrl
            $ManifestStale = [bool]($Url -and ($ManifestBaseUrl -ne $Url))
            $ShouldRefreshManifest = (-not $LastManifestRefreshAt)
            if ($LastManifestRefreshAt) {
                $SinceManifestRefresh = ((Get-Date) - $LastManifestRefreshAt).TotalSeconds
                if ($SinceManifestRefresh -ge $ManifestRefreshSeconds) {
                    $ShouldRefreshManifest = $true
                }
            }
            if ($ManifestStale) {
                $ShouldRefreshManifest = $true
            }
            if ($ShouldRefreshManifest) {
                $Manifest = Update-EndpointManifest
                if ($Manifest.ok) {
                    $LastManifestRefreshAt = Get-Date
                }
            }

            Write-WatchLog -Status "ok" -Extra @{
                base_url = $Url
                status_code = $Health.status_code
                local_ok = $Local.ok
                manifest_active_base_url = $ManifestBaseUrl
                manifest_stale = $ManifestStale
                manifest_refresh_ok = if ($Manifest) { $Manifest.ok } else { $null }
                manifest_refresh_exit_code = if ($Manifest) { $Manifest.exit_code } else { $null }
                manifest_refresh_timed_out = if ($Manifest) { $Manifest.timed_out } else { $null }
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
                $Restart = Restart-CloudflareTunnel
                $LastRestartAt = Get-Date
                $Ready = Wait-CloudflareHealthy
                $Manifest = $null
                if ($Ready.ok) {
                    $Manifest = Update-EndpointManifest
                    if ($Manifest.ok) {
                        $LastManifestRefreshAt = Get-Date
                    }
                    $ConsecutiveFailures = 0
                }
                Write-WatchLog -Status $(if ($Ready.ok) { "recovered" } else { "still_failing" }) -Message $Health.error -Extra @{
                    old_base_url = $Url
                    new_base_url = $Ready.base_url
                    consecutive_failures = $ConsecutiveFailures
                    restart_exit_code = $Restart.exit_code
                    restart_timed_out = $Restart.timed_out
                    restart_error = $Restart.error
                    local_ok = $Local.ok
                    after_status_code = $Ready.status_code
                    after_error = $Ready.error
                    manifest_refresh_ok = if ($Manifest) { $Manifest.ok } else { $null }
                    manifest_refresh_exit_code = if ($Manifest) { $Manifest.exit_code } else { $null }
                    manifest_refresh_timed_out = if ($Manifest) { $Manifest.timed_out } else { $null }
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
