param(
    [int]$Port = 8766,
    [string]$DisplayName = "SLAM AI Gateway 8766"
)

$ErrorActionPreference = "Stop"

$Existing = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue
if ($Existing) {
    Set-NetFirewallRule -DisplayName $DisplayName -Enabled True -Direction Inbound -Action Allow
}
else {
    New-NetFirewallRule `
        -DisplayName $DisplayName `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort $Port | Out-Null
}

Get-NetFirewallRule -DisplayName $DisplayName | Select-Object DisplayName, Enabled, Direction, Action

