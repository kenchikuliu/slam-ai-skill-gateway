param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [int]$IntervalSeconds = 120,
    [int]$TimeoutSeconds = 12,
    [int]$RestartCooldownSeconds = 300,
    [switch]$Once
)

$ErrorActionPreference = "Stop"

$TmpDir = Join-Path $RepoRoot "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

$StatePath = Join-Path $TmpDir "cloudflare_8766.state.json"
$LogPath = Join-Path $TmpDir "cloudflare_8766_watchdog.log"
$StartScript = Join-Path $RepoRoot "scripts\start_cloudflare_quick_tunnel.ps1"
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
    param([string]$BaseUrl)
    if (-not $BaseUrl) {
        return [ordered]@{ ok = $false; status_code = $null; error = "missing_url" }
    }
    try {
        $Response = Invoke-WebRequest -Uri (($BaseUrl.TrimEnd("/")) + "/health") -UseBasicParsing -TimeoutSec $TimeoutSeconds
        return [ordered]@{ ok = $true; status_code = [int]$Response.StatusCode; error = "" }
    } catch {
        $StatusCode = $null
        if ($_.Exception.Response) {
            $StatusCode = [int]$_.Exception.Response.StatusCode
        }
        return [ordered]@{ ok = $false; status_code = $StatusCode; error = $_.Exception.GetType().Name }
    }
}

function Restart-CloudflareTunnel {
    if (-not (Test-Path -LiteralPath $StartScript)) {
        throw "Missing Cloudflare start script: $StartScript"
    }
    Write-WatchLog -Status "cloudflare_restart" -Message "Cloudflare health check failed" | Out-Null
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $StartScript -UpdateEndpointManifest -CommitEndpointManifest | Out-Null
    $ExitCode = $LASTEXITCODE
    Start-Sleep -Seconds 5
    return $ExitCode
}

while ($true) {
    $Url = Get-CloudflareUrl
    $Health = Test-Health -BaseUrl $Url
    if ($Health.ok) {
        Write-WatchLog -Status "ok" -Extra @{
            base_url = $Url
            status_code = $Health.status_code
        }
    } else {
        $ShouldRestart = $true
        if ($LastRestartAt) {
            $SinceRestart = ((Get-Date) - $LastRestartAt).TotalSeconds
            if ($SinceRestart -lt $RestartCooldownSeconds) {
                $ShouldRestart = $false
            }
        }

        if ($ShouldRestart) {
            $ExitCode = Restart-CloudflareTunnel
            $LastRestartAt = Get-Date
            $NewUrl = Get-CloudflareUrl
            $After = Test-Health -BaseUrl $NewUrl
            Write-WatchLog -Status $(if ($After.ok) { "recovered" } else { "still_failing" }) -Message $Health.error -Extra @{
                old_base_url = $Url
                new_base_url = $NewUrl
                restart_exit_code = $ExitCode
                after_status_code = $After.status_code
                after_error = $After.error
            }
        } else {
            Write-WatchLog -Status "failure_observed" -Message $Health.error -Extra @{
                base_url = $Url
                status_code = $Health.status_code
            }
        }
    }

    if ($Once) {
        break
    }
    Start-Sleep -Seconds $IntervalSeconds
}
