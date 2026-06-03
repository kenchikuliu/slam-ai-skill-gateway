param(
    [string]$ConfigPath = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\bandwagon_reverse_ssh.env.json",
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$SshExe = "",
    [string]$SshHost = "",
    [string]$SshUser = "",
    [int]$SshPort = 22,
    [string]$IdentityFile = "",
    [int]$LocalPort = 8766,
    [int]$RemotePort = 18766,
    [switch]$SkipIfMissingConfig,
    [switch]$Foreground
)

$ErrorActionPreference = "Stop"

if ($ConfigPath -and (Test-Path -LiteralPath $ConfigPath)) {
    $Config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
    if (-not $SshExe -and $Config.ssh_exe) { $SshExe = [string]$Config.ssh_exe }
    if (-not $SshHost -and $Config.ssh_host) { $SshHost = [string]$Config.ssh_host }
    if (-not $SshUser -and $Config.ssh_user) { $SshUser = [string]$Config.ssh_user }
    if ($Config.ssh_port) { $SshPort = [int]$Config.ssh_port }
    if (-not $IdentityFile -and $Config.identity_file) { $IdentityFile = [string]$Config.identity_file }
    if ($Config.local_port) { $LocalPort = [int]$Config.local_port }
    if ($Config.remote_port) { $RemotePort = [int]$Config.remote_port }
}

if (-not $SshExe) {
    $SshCommand = Get-Command ssh -ErrorAction SilentlyContinue
    if ($SshCommand) {
        $SshExe = $SshCommand.Source
    }
}

if (-not $SshExe -or -not (Test-Path -LiteralPath $SshExe)) {
    throw "ssh executable not found"
}
if (-not $SshHost -and $SkipIfMissingConfig) {
    $State = [ordered]@{
        started_at = (Get-Date).ToString("s")
        status = "skipped"
        reason = "missing ssh_host"
        config_path = $ConfigPath
    }
    $TmpDir = Join-Path $RepoRoot "tmp"
    New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
    $StatePath = Join-Path $TmpDir "bandwagon_reverse_ssh_$RemotePort.state.json"
    $State | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    Write-Output ($State | ConvertTo-Json -Depth 4)
    exit 0
}
if (-not $SshHost) {
    throw "Missing ssh_host. Add tmp\bandwagon_reverse_ssh.env.json or pass -SshHost."
}
if (-not $SshUser) {
    $SshUser = "root"
}

$HealthUrl = "http://127.0.0.1:$LocalPort/health"
try {
    Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 5 | Out-Null
} catch {
    throw "Local gateway is not reachable at $HealthUrl. Start scripts\start_gateway_from_env.ps1 first."
}

$TmpDir = Join-Path $RepoRoot "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

$Stdout = Join-Path $TmpDir "bandwagon_reverse_ssh_$RemotePort.out.log"
$Stderr = Join-Path $TmpDir "bandwagon_reverse_ssh_$RemotePort.err.log"
$StatePath = Join-Path $TmpDir "bandwagon_reverse_ssh_$RemotePort.state.json"

$ForwardSpec = "127.0.0.1:$RemotePort`:127.0.0.1:$LocalPort"
$Existing = Get-CimInstance Win32_Process -Filter "Name = 'ssh.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*$ForwardSpec*" }

if ($Existing) {
    $Existing | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
}

$Target = "$SshUser@$SshHost"
$Args = @(
    "-N",
    "-T",
    "-p", "$SshPort",
    "-o", "ExitOnForwardFailure=yes",
    "-o", "ServerAliveInterval=30",
    "-o", "ServerAliveCountMax=3",
    "-o", "StrictHostKeyChecking=accept-new",
    "-R", $ForwardSpec,
    $Target
)
if ($IdentityFile) {
    $Args = @("-i", $IdentityFile) + $Args
}

if ($Foreground) {
    & $SshExe @Args
    exit $LASTEXITCODE
}

Remove-Item -LiteralPath $Stdout, $Stderr -ErrorAction SilentlyContinue

$Process = Start-Process `
    -FilePath $SshExe `
    -ArgumentList $Args `
    -WorkingDirectory $RepoRoot `
    -RedirectStandardOutput $Stdout `
    -RedirectStandardError $Stderr `
    -WindowStyle Hidden `
    -PassThru

for ($Attempt = 0; $Attempt -lt 10; $Attempt++) {
    Start-Sleep -Seconds 1
    $Process.Refresh()
    if ($Process.HasExited) {
        break
    }
}

$Status = if ($Process.HasExited) { "exited" } else { "running" }
$ExitCode = if ($Process.HasExited) { $Process.ExitCode } else { $null }
$StderrTail = ""
if (Test-Path -LiteralPath $Stderr) {
    $StderrTail = (Get-Content -LiteralPath $Stderr -Tail 20 -ErrorAction SilentlyContinue) -join "`n"
}

$State = [ordered]@{
    pid = $Process.Id
    started_at = (Get-Date).ToString("s")
    ssh_exe = $SshExe
    ssh_host = $SshHost
    ssh_user = $SshUser
    ssh_port = $SshPort
    identity_file = $IdentityFile
    local_port = $LocalPort
    remote_bind = "127.0.0.1:$RemotePort"
    remote_port = $RemotePort
    forward_spec = $ForwardSpec
    stdout = $Stdout
    stderr = $Stderr
    status = $Status
    exit_code = $ExitCode
    stderr_tail = $StderrTail
}

$State | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $StatePath -Encoding UTF8
Write-Output ($State | ConvertTo-Json -Depth 4)

if ($Process.HasExited) {
    exit 1
}
