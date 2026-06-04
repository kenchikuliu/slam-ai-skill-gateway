param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$PublicBaseUrl = "http://83.229.126.28/slam-ai",
    [string]$LocalHealthUrl = "http://127.0.0.1:8766/health",
    [int]$IntervalSeconds = 300,
    [int]$TimeoutSeconds = 12,
    [int]$FailureThreshold = 3,
    [int]$RestartCooldownSeconds = 1800,
    [int]$ManifestRefreshSeconds = 900,
    [int]$ManifestUpdateTimeoutSeconds = 120,
    [int]$TunnelRestartTimeoutSeconds = 120,
    [switch]$SkipManifestPush,
    [switch]$Once
)

$ErrorActionPreference = "Stop"

$TmpDir = Join-Path $RepoRoot "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

$LogPath = Join-Path $TmpDir "bandwagon_reverse_ssh_watchdog.log"
$GatewayScript = Join-Path $RepoRoot "scripts\start_gateway_from_env.ps1"
$TunnelScript = Join-Path $RepoRoot "scripts\start_bandwagon_reverse_tunnel.ps1"
$ManifestScript = Join-Path $RepoRoot "scripts\update_public_endpoint_manifest.ps1"
$PublicHealthUrl = ($PublicBaseUrl.TrimEnd("/")) + "/health"
$ForwardSpec = "127.0.0.1:18766:127.0.0.1:8766"
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
        public_health_url = $PublicHealthUrl
    }
    foreach ($Key in $Extra.Keys) {
        $Record[$Key] = $Extra[$Key]
    }
    $Json = $Record | ConvertTo-Json -Compress -Depth 5
    $Json | Add-Content -LiteralPath $LogPath -Encoding UTF8
    Write-Output $Json
}

function Test-HttpUrl {
    param([string]$Url)
    try {
        $Response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSeconds
        return [ordered]@{
            ok = $true
            status_code = [int]$Response.StatusCode
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
            error = $_.Exception.Message
        }
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

function Update-EndpointManifest {
    if (-not (Test-Path -LiteralPath $ManifestScript)) {
        return [pscustomobject][ordered]@{ ok = $false; exit_code = $null; timed_out = $false; error = "missing_manifest_script"; stdout = ""; stderr = "" }
    }

    $Args = @("-RepoRoot", $RepoRoot, "-HkBaseUrl", $PublicBaseUrl)
    if (-not $SkipManifestPush) {
        $Args += "-CommitAndPush"
    }
    return Invoke-PowerShellScriptWithTimeout -ScriptPath $ManifestScript -Arguments $Args -TimeoutSeconds $ManifestUpdateTimeoutSeconds -Name "bandwagon_manifest_update"
}

function Get-TunnelProcesses {
    return @(Get-CimInstance Win32_Process -Filter "Name = 'ssh.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*$ForwardSpec*" })
}

function Ensure-LocalGateway {
    $Local = Test-HttpUrl -Url $LocalHealthUrl
    if ($Local.ok) {
        return $Local
    }
    if (-not (Test-Path -LiteralPath $GatewayScript)) {
        throw "Missing gateway script: $GatewayScript"
    }
    Write-WatchLog -Status "local_gateway_restart" -Message $Local.error | Out-Null
    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $GatewayScript) `
        -WorkingDirectory $RepoRoot `
        -WindowStyle Hidden | Out-Null
    Start-Sleep -Seconds 5
    return (Test-HttpUrl -Url $LocalHealthUrl)
}

function Restart-ReverseTunnel {
    if (-not (Test-Path -LiteralPath $TunnelScript)) {
        throw "Missing reverse tunnel script: $TunnelScript"
    }

    $Existing = Get-TunnelProcesses
    foreach ($Process in $Existing) {
        Stop-Process -Id $Process.ProcessId -Force -ErrorAction SilentlyContinue
    }

    Write-WatchLog -Status "reverse_tunnel_restart" -Message "public health check failed" -Extra @{
        killed_processes = @($Existing | ForEach-Object { $_.ProcessId })
    } | Out-Null

    $Restart = Invoke-PowerShellScriptWithTimeout -ScriptPath $TunnelScript -TimeoutSeconds $TunnelRestartTimeoutSeconds -Name "bandwagon_restart"
    Start-Sleep -Seconds 15

    return [pscustomobject][ordered]@{
        exit_code = $Restart.exit_code
        timed_out = $Restart.timed_out
        error = $Restart.error
        tunnel_processes = @(Get-TunnelProcesses | ForEach-Object { $_.ProcessId })
    }
}

while ($true) {
    $Public = Test-HttpUrl -Url $PublicHealthUrl
    if ($Public.ok) {
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
            if ($Manifest.ok) {
                $LastManifestRefreshAt = Get-Date
            }
        }
        Write-WatchLog -Status "ok" -Extra @{
            status_code = $Public.status_code
            tunnel_processes = @(Get-TunnelProcesses | ForEach-Object { $_.ProcessId })
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
            $Local = Ensure-LocalGateway
            $Restart = Restart-ReverseTunnel
            $LastRestartAt = Get-Date
            $After = Test-HttpUrl -Url $PublicHealthUrl
            $Manifest = Update-EndpointManifest
            if ($Manifest.ok) {
                $LastManifestRefreshAt = Get-Date
            }
            if ($After.ok) {
                $ConsecutiveFailures = 0
            }
            Write-WatchLog -Status $(if ($After.ok) { "recovered" } else { "still_failing" }) -Message $Public.error -Extra @{
                consecutive_failures = $ConsecutiveFailures
                public_status_code = $Public.status_code
                local_ok = $Local.ok
                restart_exit_code = $Restart.exit_code
                restart_timed_out = $Restart.timed_out
                restart_error = $Restart.error
                tunnel_processes = $Restart.tunnel_processes
                after_status_code = $After.status_code
                after_error = $After.error
                manifest_refresh_ok = $Manifest.ok
                manifest_refresh_exit_code = $Manifest.exit_code
                manifest_refresh_timed_out = $Manifest.timed_out
            }
        } else {
            $Manifest = $null
            if ($ConsecutiveFailures -eq 1) {
                $Manifest = Update-EndpointManifest
                if ($Manifest.ok) {
                    $LastManifestRefreshAt = Get-Date
                }
            }
            Write-WatchLog -Status "failure_observed" -Message $Public.error -Extra @{
                consecutive_failures = $ConsecutiveFailures
                status_code = $Public.status_code
                tunnel_processes = @(Get-TunnelProcesses | ForEach-Object { $_.ProcessId })
                manifest_refresh_ok = if ($Manifest) { $Manifest.ok } else { $null }
                manifest_refresh_exit_code = if ($Manifest) { $Manifest.exit_code } else { $null }
                manifest_refresh_timed_out = if ($Manifest) { $Manifest.timed_out } else { $null }
            }
        }
    }

    if ($Once) {
        break
    }
    Start-Sleep -Seconds $IntervalSeconds
}
