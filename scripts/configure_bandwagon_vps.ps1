param(
    [string]$ConfigPath = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway\tmp\bandwagon_reverse_ssh.env.json",
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$SshHost = "",
    [string]$SshUser = "",
    [int]$SshPort = 22,
    [string]$IdentityFile = "",
    [string]$Domain = "",
    [string]$Email = "",
    [int]$RemotePort = 18766,
    [switch]$LetsEncrypt
)

$ErrorActionPreference = "Stop"

if ($ConfigPath -and (Test-Path -LiteralPath $ConfigPath)) {
    $Config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
    if (-not $SshHost -and $Config.ssh_host) { $SshHost = [string]$Config.ssh_host }
    if (-not $SshUser -and $Config.ssh_user) { $SshUser = [string]$Config.ssh_user }
    if ($Config.ssh_port) { $SshPort = [int]$Config.ssh_port }
    if (-not $IdentityFile -and $Config.identity_file) { $IdentityFile = [string]$Config.identity_file }
    if (-not $Domain -and $Config.domain) { $Domain = [string]$Config.domain }
    if (-not $Email -and $Config.email) { $Email = [string]$Config.email }
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
$LocalScript = Join-Path $RepoRoot "scripts\setup_bandwagon_nginx.sh"
if (-not (Test-Path -LiteralPath $LocalScript)) {
    throw "Missing local setup script: $LocalScript"
}

$TmpDir = Join-Path $RepoRoot "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
$UploadScript = Join-Path $TmpDir "setup_bandwagon_nginx.upload.sh"
$ScriptText = (Get-Content -LiteralPath $LocalScript -Raw) -replace "`r`n", "`n"
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($UploadScript, $ScriptText, $Utf8NoBom)

$CommonArgs = @("-P", "$SshPort")
if ($IdentityFile) {
    $CommonArgs += @("-i", $IdentityFile)
}

& $Scp @CommonArgs $UploadScript "$Remote`:/tmp/setup_bandwagon_nginx.sh"

$RemoteArgs = @("--remote-port", "$RemotePort")
if ($Domain) {
    $RemoteArgs += @("--domain", $Domain)
}
if ($LetsEncrypt) {
    if (-not $Domain -or -not $Email) {
        throw "-LetsEncrypt requires -Domain and -Email."
    }
    $RemoteArgs += @("--letsencrypt", "--email", $Email)
}

$SshArgs = @("-p", "$SshPort", "-o", "StrictHostKeyChecking=accept-new")
if ($IdentityFile) {
    $SshArgs += @("-i", $IdentityFile)
}
$RemoteCommand = "chmod +x /tmp/setup_bandwagon_nginx.sh && bash /tmp/setup_bandwagon_nginx.sh $($RemoteArgs -join ' ')"
& $Ssh @SshArgs $Remote $RemoteCommand
