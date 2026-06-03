param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$PublicBaseUrl = "http://83.229.126.28/slam-ai",
    [string]$LocalHealthUrl = "http://127.0.0.1:8766/health",
    [int]$IntervalSeconds = 300,
    [int]$TimeoutSeconds = 12,
    [int]$FailureThreshold = 3,
    [int]$RestartCooldownSeconds = 1800,
    [switch]$Once
)

$ErrorActionPreference = "Stop"

$TmpDir = Join-Path $RepoRoot "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

$LogPath = Join-Path $TmpDir "bandwagon_reverse_ssh_watchdog.log"
$GatewayScript = Join-Path $RepoRoot "scripts\start_gateway_from_env.ps1"
$TunnelScript = Join-Path $RepoRoot "scripts\start_bandwagon_reverse_tunnel.ps1"
$PublicHealthUrl = ($PublicBaseUrl.TrimEnd("/")) + "/health"
$ForwardSpec = "127.0.0.1:18766:127.0.0.1:8766"
$ConsecutiveFailures = 0
$LastRestartAt = $null

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

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $TunnelScript | Out-Null
    $ExitCode = $LASTEXITCODE
    Start-Sleep -Seconds 15

    return [ordered]@{
        exit_code = $ExitCode
        tunnel_processes = @(Get-TunnelProcesses | ForEach-Object { $_.ProcessId })
    }
}

while ($true) {
    $Public = Test-HttpUrl -Url $PublicHealthUrl
    if ($Public.ok) {
        $ConsecutiveFailures = 0
        Write-WatchLog -Status "ok" -Extra @{
            status_code = $Public.status_code
            tunnel_processes = @(Get-TunnelProcesses | ForEach-Object { $_.ProcessId })
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
            if ($After.ok) {
                $ConsecutiveFailures = 0
            }
            Write-WatchLog -Status $(if ($After.ok) { "recovered" } else { "still_failing" }) -Message $Public.error -Extra @{
                consecutive_failures = $ConsecutiveFailures
                public_status_code = $Public.status_code
                local_ok = $Local.ok
                restart_exit_code = $Restart.exit_code
                tunnel_processes = $Restart.tunnel_processes
                after_status_code = $After.status_code
                after_error = $After.error
            }
        } else {
            Write-WatchLog -Status "failure_observed" -Message $Public.error -Extra @{
                consecutive_failures = $ConsecutiveFailures
                status_code = $Public.status_code
                tunnel_processes = @(Get-TunnelProcesses | ForEach-Object { $_.ProcessId })
            }
        }
    }

    if ($Once) {
        break
    }
    Start-Sleep -Seconds $IntervalSeconds
}
