. (Join-Path $PSScriptRoot "..\scripts\remote_access_common.ps1")

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
            "https://github.com/kenchikuliu/slam-ai-skill-gateway/raw/refs/heads/main/public/slam-ai-endpoints.json"
        }
    }

    if ($env:SLAM_AI_GATEWAY_HOST -or $env:SLAM_AI_GATEWAY_PORT) {
        $HostAddress = if ($env:SLAM_AI_GATEWAY_HOST) { $env:SLAM_AI_GATEWAY_HOST } else { "127.0.0.1" }
        $Port = if ($env:SLAM_AI_GATEWAY_PORT) { $env:SLAM_AI_GATEWAY_PORT } else { "8766" }
        return "http://${HostAddress}:${Port}"
    }

    try {
        $Manifest = Invoke-RestMethod `
            -Uri $ManifestUrl `
            -Headers @{ "Cache-Control" = "no-cache" } `
            -TimeoutSec 20
        $Candidates = @(
            $Manifest.endpoints |
                Where-Object {
                    $_.health_ok -eq $true -and
                    $_.base_url -and
                    (Test-SlamAiSecureRemoteBaseUrl ([string]$_.base_url))
                } |
                Sort-Object @{ Expression = { [int]$_.priority }; Ascending = $true }
        )
        foreach ($Candidate in $Candidates) {
            $BaseUrl = ([string]$Candidate.base_url).TrimEnd("/")
            $Health = Test-SlamAiGatewayHealth `
                -HealthUrl "$BaseUrl/health" `
                -TimeoutSeconds 10
            if ($Health.ok) {
                return $BaseUrl
            }
        }
        throw "Endpoint manifest contains no currently reachable secure endpoint."
    } catch {
        Write-Warning "Could not read endpoint manifest; falling back to $FallbackLocalBaseUrl. Error: $($_.Exception.Message)"
    }

    return $FallbackLocalBaseUrl.TrimEnd("/")
}
