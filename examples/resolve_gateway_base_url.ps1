function Resolve-SlamAiGatewayBaseUrl {
    param(
        [string]$ManifestUrl = "",
        [string]$FallbackLocalBaseUrl = "http://127.0.0.1:8766"
    )

    if ($env:SLAM_AI_BASE_URL) {
        return $env:SLAM_AI_BASE_URL.TrimEnd("/")
    }

    if (-not $ManifestUrl) {
        $ManifestUrl = if ($env:SLAM_AI_ENDPOINT_MANIFEST_URL) {
            $env:SLAM_AI_ENDPOINT_MANIFEST_URL
        } else {
            "https://raw.githubusercontent.com/kenchikuliu/slam-ai-skill-gateway/main/public/slam-ai-endpoints.json"
        }
    }

    if ($env:SLAM_AI_GATEWAY_HOST -or $env:SLAM_AI_GATEWAY_PORT) {
        $HostAddress = if ($env:SLAM_AI_GATEWAY_HOST) { $env:SLAM_AI_GATEWAY_HOST } else { "127.0.0.1" }
        $Port = if ($env:SLAM_AI_GATEWAY_PORT) { $env:SLAM_AI_GATEWAY_PORT } else { "8766" }
        return "http://${HostAddress}:${Port}"
    }

    try {
        $Manifest = Invoke-RestMethod -Uri $ManifestUrl -TimeoutSec 20
        if ($Manifest.active_base_url) {
            return ([string]$Manifest.active_base_url).TrimEnd("/")
        }

        $Healthy = @($Manifest.endpoints |
            Where-Object { $_.health_ok } |
            Sort-Object @{ Expression = { [int]$_.priority }; Ascending = $true } |
            Select-Object -First 1)
        if ($Healthy.Count -gt 0 -and $Healthy[0].base_url) {
            return ([string]$Healthy[0].base_url).TrimEnd("/")
        }
    } catch {
        Write-Warning "Could not read endpoint manifest; falling back to $FallbackLocalBaseUrl. Error: $($_.Exception.Message)"
    }

    return $FallbackLocalBaseUrl.TrimEnd("/")
}
