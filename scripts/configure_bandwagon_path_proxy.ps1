param(
    [string]$ConfigPath = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\bandwagon_reverse_ssh.env.json",
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$SshHost = "",
    [string]$SshUser = "",
    [int]$SshPort = 22,
    [string]$IdentityFile = "",
    [int]$RemotePort = 18766,
    [string]$NginxConf = "/www/server/panel/vhost/nginx/0.default.conf",
    [string]$PathPrefix = "/slam-ai",
    [string]$NginxBin = "/www/server/nginx/sbin/nginx"
)

$ErrorActionPreference = "Stop"

function Quote-Sh([string]$Value) {
    return "'" + ($Value -replace "'", "'\''") + "'"
}

if ($ConfigPath -and (Test-Path -LiteralPath $ConfigPath)) {
    $Config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
    if (-not $SshHost -and $Config.ssh_host) { $SshHost = [string]$Config.ssh_host }
    if (-not $SshUser -and $Config.ssh_user) { $SshUser = [string]$Config.ssh_user }
    if ($Config.ssh_port) { $SshPort = [int]$Config.ssh_port }
    if (-not $IdentityFile -and $Config.identity_file) { $IdentityFile = [string]$Config.identity_file }
    if ($Config.remote_port) { $RemotePort = [int]$Config.remote_port }
}

if (-not $SshHost) {
    throw "Missing ssh_host. Add tmp\bandwagon_reverse_ssh.env.json or pass -SshHost."
}
if (-not $SshUser) {
    $SshUser = "root"
}

$Ssh = (Get-Command ssh -ErrorAction Stop).Source
$Scp = (Get-Command scp -ErrorAction Stop).Source
$Remote = "$SshUser@$SshHost"
$LocalScript = Join-Path $RepoRoot "scripts\setup_bandwagon_nginx_path_proxy.sh"
if (-not (Test-Path -LiteralPath $LocalScript)) {
    throw "Missing local setup script: $LocalScript"
}

$TmpDir = Join-Path $RepoRoot "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
$UploadScript = Join-Path $TmpDir "setup_bandwagon_nginx_path_proxy.upload.sh"
$ScriptText = (Get-Content -LiteralPath $LocalScript -Raw) -replace "`r`n", "`n"
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($UploadScript, $ScriptText, $Utf8NoBom)

$CommonArgs = @("-P", "$SshPort")
if ($IdentityFile) {
    $CommonArgs += @("-i", $IdentityFile)
}

& $Scp @CommonArgs $UploadScript "$Remote`:/tmp/setup_bandwagon_nginx_path_proxy.sh"

$SshArgs = @("-p", "$SshPort", "-o", "StrictHostKeyChecking=accept-new")
if ($IdentityFile) {
    $SshArgs += @("-i", $IdentityFile)
}

$RemoteScript = "/tmp/setup_bandwagon_nginx_path_proxy.sh"
$RemoteArgs = @(
    "--conf", (Quote-Sh $NginxConf),
    "--path-prefix", (Quote-Sh $PathPrefix),
    "--remote-port", "$RemotePort",
    "--nginx-bin", (Quote-Sh $NginxBin)
) -join " "

$RemoteCommand = "chmod +x $RemoteScript && bash $RemoteScript $RemoteArgs"
& $Ssh @SshArgs $Remote $RemoteCommand
