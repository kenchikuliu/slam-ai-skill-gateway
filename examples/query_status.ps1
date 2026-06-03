$Token = $env:SLAM_AI_GATEWAY_TOKEN
$HostAddress = if ($env:SLAM_AI_GATEWAY_HOST) { $env:SLAM_AI_GATEWAY_HOST } else { "127.0.0.1" }
$Port = if ($env:SLAM_AI_GATEWAY_PORT) { $env:SLAM_AI_GATEWAY_PORT } else { "8765" }
$Headers = @{}
if ($Token) {
    $Headers.Authorization = "Bearer $Token"
}

Invoke-RestMethod -Headers $Headers "http://${HostAddress}:${Port}/status"

