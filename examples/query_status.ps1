$Token = if ($env:SLAM_AI_GATEWAY_TOKEN) { $env:SLAM_AI_GATEWAY_TOKEN } else { $env:SLAM_AI_TOKEN }
if (-not $Token) {
    throw "Set SLAM_AI_GATEWAY_TOKEN or SLAM_AI_TOKEN to the SLAM gateway bearer token before calling authenticated endpoints."
}

. (Join-Path $PSScriptRoot "resolve_gateway_base_url.ps1")
$BaseUrl = Resolve-SlamAiGatewayBaseUrl
$Headers = @{ Authorization = "Bearer $Token" }

Invoke-RestMethod -Headers $Headers "$BaseUrl/status"
