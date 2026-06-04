param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$StartupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    [switch]$KeepDirectCloudflareStartup,
    [switch]$IncludeCloudflareNamedWatchdog,
    [switch]$IncludeBandwagonWatchdog,
    [switch]$SkipRemoteAccessStartupCheck
)

$ErrorActionPreference = "Stop"

$ResolvedRepo = (Resolve-Path -LiteralPath $RepoRoot).Path.TrimEnd("\")
$ResolvedStartup = if (Test-Path -LiteralPath $StartupDir) {
    (Resolve-Path -LiteralPath $StartupDir).Path
} else {
    New-Item -ItemType Directory -Force -Path $StartupDir | Out-Null
    (Resolve-Path -LiteralPath $StartupDir).Path
}

$TmpDir = Join-Path $ResolvedRepo "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

function Write-StartupCmd {
    param(
        [string]$Name,
        [string[]]$Lines
    )
    $Path = Join-Path $ResolvedStartup $Name
    $Content = ($Lines -join "`r`n") + "`r`n"
    Set-Content -LiteralPath $Path -Value $Content -Encoding ASCII
    return $Path
}

function Disable-StartupCmd {
    param([string]$Name)
    $Path = Join-Path $ResolvedStartup $Name
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    $DisabledPath = $Path + ".disabled"
    Move-Item -LiteralPath $Path -Destination $DisabledPath -Force
    return $DisabledPath
}

$GatewayScript = Join-Path $ResolvedRepo "scripts\start_gateway_from_env.ps1"
$CloudflareWatchdogScript = Join-Path $ResolvedRepo "scripts\watch_cloudflare_quick_tunnel.ps1"
$CloudflareNamedWatchdogScript = Join-Path $ResolvedRepo "scripts\watch_cloudflare_named_tunnel.ps1"
$BandwagonWatchdogScript = Join-Path $ResolvedRepo "scripts\watch_bandwagon_reverse_tunnel.ps1"
$RemoteAccessCheckScript = Join-Path $ResolvedRepo "scripts\check_remote_access_on_startup.ps1"

foreach ($Required in @($GatewayScript, $CloudflareWatchdogScript, $RemoteAccessCheckScript)) {
    if (-not (Test-Path -LiteralPath $Required)) {
        throw "Missing required script: $Required"
    }
}

$Written = [ordered]@{}

$Written.gateway = Write-StartupCmd -Name "slam-ai-gateway-8766.cmd" -Lines @(
    "@echo off",
    "cd /d `"$ResolvedRepo`"",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$GatewayScript`" > `"$TmpDir\gateway_8766.startup.log`" 2>&1"
)

$Written.cloudflare_watchdog = Write-StartupCmd -Name "slam-ai-cloudflare-watchdog.cmd" -Lines @(
    "@echo off",
    "cd /d `"$ResolvedRepo`"",
    "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$CloudflareWatchdogScript`" > `"$TmpDir\cloudflare_8766_watchdog.startup.log`" 2>&1"
)

if (-not $SkipRemoteAccessStartupCheck) {
    $Written.remote_access_startup_check = Write-StartupCmd -Name "slam-ai-remote-access-check.cmd" -Lines @(
        "@echo off",
        "cd /d `"$ResolvedRepo`"",
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RemoteAccessCheckScript`" -StartupDelaySeconds 45 > `"$TmpDir\remote_access_startup_check.startup.log`" 2>&1"
    )
}

if (-not $KeepDirectCloudflareStartup) {
    $Disabled = Disable-StartupCmd -Name "slam-ai-cloudflare-8766.cmd"
    if ($Disabled) {
        $Written.disabled_direct_cloudflare_startup = $Disabled
    }
}

if ($IncludeCloudflareNamedWatchdog) {
    if (-not (Test-Path -LiteralPath $CloudflareNamedWatchdogScript)) {
        throw "Missing Cloudflare named tunnel watchdog script: $CloudflareNamedWatchdogScript"
    }
    $Written.cloudflare_named_watchdog = Write-StartupCmd -Name "slam-ai-cloudflare-named-watchdog.cmd" -Lines @(
        "@echo off",
        "cd /d `"$ResolvedRepo`"",
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$CloudflareNamedWatchdogScript`" > `"$TmpDir\cloudflare_named_tunnel_watchdog.startup.log`" 2>&1"
    )
}

if ($IncludeBandwagonWatchdog) {
    if (-not (Test-Path -LiteralPath $BandwagonWatchdogScript)) {
        throw "Missing Bandwagon watchdog script: $BandwagonWatchdogScript"
    }
    $Written.bandwagon_watchdog = Write-StartupCmd -Name "slam-ai-bandwagon-watchdog.cmd" -Lines @(
        "@echo off",
        "cd /d `"$ResolvedRepo`"",
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$BandwagonWatchdogScript`" > `"$TmpDir\bandwagon_reverse_ssh_watchdog.startup.log`" 2>&1"
    )
}

$Written | ConvertTo-Json -Depth 4
