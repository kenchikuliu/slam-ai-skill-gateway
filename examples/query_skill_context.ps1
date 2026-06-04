param(
    [string]$Query = "gaussian slam",
    [int]$PaperLimit = 10,
    [int]$TextLimit = 5,
    [switch]$IncludeGraphSummary
)

$Token = if ($env:SLAM_AI_GATEWAY_TOKEN) { $env:SLAM_AI_GATEWAY_TOKEN } else { $env:SLAM_AI_TOKEN }
if (-not $Token) {
    throw "Set SLAM_AI_GATEWAY_TOKEN or SLAM_AI_TOKEN to the SLAM gateway bearer token before calling authenticated endpoints."
}

. (Join-Path $PSScriptRoot "resolve_gateway_base_url.ps1")
$BaseUrl = Resolve-SlamAiGatewayBaseUrl
$Headers = @{ Authorization = "Bearer $Token" }

$Encoded = [uri]::EscapeDataString($Query)
$Graph = if ($IncludeGraphSummary) { "true" } else { "false" }
Invoke-RestMethod `
    -Headers $Headers `
    "$BaseUrl/skill/context?q=$Encoded&paper_limit=$PaperLimit&text_limit=$TextLimit&include_graph_summary=$Graph"
