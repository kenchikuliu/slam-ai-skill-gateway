. (Join-Path $PSScriptRoot "..\scripts\remote_access_common.ps1")

Describe "Quick Tunnel URL validation" {
    It "rejects Cloudflare service and reserved hosts" {
        Test-SlamAiQuickTunnelBaseUrl "https://api.trycloudflare.com" | Should Be $false
        Test-SlamAiQuickTunnelBaseUrl "https://www.trycloudflare.com" | Should Be $false
        Get-SlamAiQuickTunnelUrlsFromText 'failed: Post "https://api.trycloudflare.com/tunnel"' |
            Should BeNullOrEmpty
    }

    It "accepts a generated Quick Tunnel hostname" {
        Test-SlamAiQuickTunnelBaseUrl "https://burst-breed-honor-glen.trycloudflare.com" |
            Should Be $true
    }

    It "rejects paths, non-default ports, and single-token hosts" {
        Test-SlamAiQuickTunnelBaseUrl "https://burst-breed-honor-glen.trycloudflare.com/path" |
            Should Be $false
        Test-SlamAiQuickTunnelBaseUrl "https://burst-breed-honor-glen.trycloudflare.com:8443" |
            Should Be $false
        Test-SlamAiQuickTunnelBaseUrl "https://random.trycloudflare.com" | Should Be $false
    }
}

Describe "Running tunnel state validation" {
    It "rejects exited state" {
        $StatePath = Join-Path $TestDrive "state.json"
        @{ status = "exited"; pid = 123; urls = @("https://burst-breed-honor-glen.trycloudflare.com") } |
            ConvertTo-Json | Set-Content -LiteralPath $StatePath
        Get-SlamAiRunningQuickTunnelUrl -StatePath $StatePath -ProcessResolver {
            [pscustomobject]@{ ProcessName = "cloudflared" }
        } | Should BeNullOrEmpty
    }

    It "rejects a live non-cloudflared PID" {
        $StatePath = Join-Path $TestDrive "state.json"
        @{ status = "running"; pid = 123; urls = @("https://burst-breed-honor-glen.trycloudflare.com") } |
            ConvertTo-Json | Set-Content -LiteralPath $StatePath
        Get-SlamAiRunningQuickTunnelUrl -StatePath $StatePath -ProcessResolver {
            [pscustomobject]@{ ProcessName = "powershell" }
        } | Should BeNullOrEmpty
    }

    It "returns a generated URL for a live cloudflared process" {
        $StatePath = Join-Path $TestDrive "state.json"
        @{ status = "running"; pid = 123; urls = @("https://burst-breed-honor-glen.trycloudflare.com") } |
            ConvertTo-Json | Set-Content -LiteralPath $StatePath
        Get-SlamAiRunningQuickTunnelUrl -StatePath $StatePath -ProcessResolver {
            [pscustomobject]@{ ProcessName = "cloudflared" }
        } | Should Be "https://burst-breed-honor-glen.trycloudflare.com"
    }
}

Describe "Manifest endpoint selection" {
    It "returns no active endpoint when all endpoints are unhealthy" {
        $Manifest = [pscustomobject]@{
            active_base_url = "https://api.trycloudflare.com"
            endpoints = @(
                [pscustomobject]@{
                    base_url = "https://api.trycloudflare.com"
                    health_ok = $false
                    priority = 80
                }
            )
        }
        Select-SlamAiHealthyEndpoint $Manifest | Should BeNullOrEmpty
    }

    It "selects the lowest-priority healthy endpoint" {
        $Manifest = [pscustomobject]@{
            active_base_url = "https://bad.example"
            endpoints = @(
                [pscustomobject]@{ base_url = "https://fallback.example"; health_ok = $true; priority = 20 },
                [pscustomobject]@{ base_url = "https://preferred.example"; health_ok = $true; priority = 10 }
            )
        }
        (Select-SlamAiHealthyEndpoint $Manifest).base_url | Should Be "https://preferred.example"
    }

    It "keeps the declared active endpoint when it is healthy" {
        $Manifest = [pscustomobject]@{
            active_base_url = "https://fallback.example"
            endpoints = @(
                [pscustomobject]@{ base_url = "https://preferred.example"; health_ok = $true; priority = 10 },
                [pscustomobject]@{ base_url = "https://fallback.example"; health_ok = $true; priority = 20 }
            )
        }
        (Select-SlamAiHealthyEndpoint $Manifest).base_url | Should Be "https://fallback.example"
    }

    It "never selects a plain HTTP endpoint for bearer authentication" {
        $Manifest = [pscustomobject]@{
            active_base_url = "http://83.229.126.28/slam-ai"
            endpoints = @(
                [pscustomobject]@{ base_url = "http://83.229.126.28/slam-ai"; health_ok = $true; priority = 5 },
                [pscustomobject]@{ base_url = "https://safe.example"; health_ok = $true; priority = 20 }
            )
        }
        (Select-SlamAiHealthyEndpoint $Manifest).base_url | Should Be "https://safe.example"
    }

    It "returns no endpoint when only plain HTTP is healthy" {
        $Manifest = [pscustomobject]@{
            active_base_url = "http://83.229.126.28/slam-ai"
            endpoints = @(
                [pscustomobject]@{ base_url = "http://83.229.126.28/slam-ai"; health_ok = $true; priority = 5 }
            )
        }
        Select-SlamAiHealthyEndpoint $Manifest | Should BeNullOrEmpty
    }
}

Describe "Transient watchdog log retention" {
    It "keeps only the configured number of newest files" {
        1..6 | ForEach-Object {
            $Path = Join-Path $TestDrive ("endpoint_manifest_update.{0}.out.log" -f $_)
            Set-Content -LiteralPath $Path -Value $_
            (Get-Item -LiteralPath $Path).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes($_)
        }

        Remove-SlamAiTransientRunLogs -Directory $TestDrive -Prefix "endpoint_manifest_update" -KeepFileCount 2

        @(Get-ChildItem -LiteralPath $TestDrive -Filter "endpoint_manifest_update.*.log").Count |
            Should Be 2
    }
}
