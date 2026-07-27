function Test-SlamAiQuickTunnelBaseUrl {
    param([AllowEmptyString()][string]$BaseUrl)

    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        return $false
    }

    try {
        $Uri = [uri]$BaseUrl
    } catch {
        return $false
    }

    if (-not $Uri.IsAbsoluteUri -or $Uri.Scheme -ne "https" -or -not $Uri.IsDefaultPort) {
        return $false
    }
    if ($Uri.AbsolutePath -ne "/" -or $Uri.Query -or $Uri.Fragment) {
        return $false
    }

    $Suffix = ".trycloudflare.com"
    $HostName = $Uri.DnsSafeHost.ToLowerInvariant()
    if (-not $HostName.EndsWith($Suffix, [System.StringComparison]::Ordinal)) {
        return $false
    }

    $Label = $HostName.Substring(0, $HostName.Length - $Suffix.Length)
    if ($Label.Contains(".")) {
        return $false
    }

    $ReservedLabels = @("api", "www", "developers", "dash", "login", "one")
    if ($ReservedLabels -contains $Label) {
        return $false
    }

    # Account-less Quick Tunnel hosts are generated multi-token names.
    return $Label -match '^[a-z0-9]+(?:-[a-z0-9]+){2,}$'
}

function Get-SlamAiQuickTunnelUrlsFromText {
    param([AllowEmptyString()][string]$Text)

    if (-not $Text) {
        return @()
    }

    $Pattern = 'https://[A-Za-z0-9-]+\.trycloudflare\.com'
    return @(
        [regex]::Matches($Text, $Pattern) |
            ForEach-Object { $_.Value.TrimEnd("/") } |
            Where-Object { Test-SlamAiQuickTunnelBaseUrl ([string]$_) } |
            Select-Object -Unique
    )
}

function Get-SlamAiRunningQuickTunnelUrl {
    param(
        [string]$StatePath,
        [scriptblock]$ProcessResolver = {
            param([int]$ProcessId)
            Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        }
    )

    if (-not (Test-Path -LiteralPath $StatePath)) {
        return ""
    }

    try {
        $State = Get-Content -Raw -LiteralPath $StatePath | ConvertFrom-Json
        if ($State.status -ne "running" -or -not $State.pid) {
            return ""
        }
        $Process = & $ProcessResolver ([int]$State.pid)
    } catch {
        return ""
    }

    if (-not $Process -or $Process.ProcessName -ne "cloudflared") {
        return ""
    }

    $Urls = @(
        $State.urls |
            Where-Object { Test-SlamAiQuickTunnelBaseUrl ([string]$_) } |
            Select-Object -First 1
    )
    if ($Urls.Count -eq 0) {
        return ""
    }
    return [string]$Urls[0]
}

function Test-SlamAiGatewayHealth {
    param(
        [string]$HealthUrl,
        [int]$TimeoutSeconds = 10
    )

    try {
        $Response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec $TimeoutSeconds
        $Payload = $null
        if ($Response.Content) {
            try {
                $Payload = $Response.Content | ConvertFrom-Json
            } catch {
                $Payload = $null
            }
        }
        $PayloadOk = ($Payload -and $Payload.ok -eq $true)
        return [ordered]@{
            ok = $PayloadOk
            status_code = [int]$Response.StatusCode
            error = if ($PayloadOk) { "" } else { "unexpected_health_payload" }
        }
    } catch {
        $StatusCode = $null
        if ($_.Exception.Response) {
            try {
                $StatusCode = [int]$_.Exception.Response.StatusCode
            } catch {
                $StatusCode = $null
            }
        }
        return [ordered]@{
            ok = $false
            status_code = $StatusCode
            error = $_.Exception.GetType().Name
        }
    }
}

function Remove-SlamAiTransientRunLogs {
    param(
        [string]$Directory,
        [string]$Prefix,
        [int]$KeepFileCount = 40
    )

    if (-not (Test-Path -LiteralPath $Directory)) {
        return
    }
    if ($Prefix -notmatch '^[A-Za-z0-9_-]+$') {
        throw "Invalid transient log prefix: $Prefix"
    }

    $StaleFiles = @(
        Get-ChildItem -LiteralPath $Directory -File -Filter "$Prefix.*.log" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -Skip ([Math]::Max(0, $KeepFileCount))
    )
    foreach ($File in $StaleFiles) {
        Remove-Item -LiteralPath $File.FullName -Force -ErrorAction SilentlyContinue
    }
}

function Test-SlamAiSecureRemoteBaseUrl {
    param([AllowEmptyString()][string]$BaseUrl)

    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        return $false
    }
    try {
        $Uri = [uri]$BaseUrl
    } catch {
        return $false
    }
    return ($Uri.IsAbsoluteUri -and $Uri.Scheme -eq "https" -and $Uri.IsDefaultPort)
}

function Select-SlamAiHealthyEndpoint {
    param([object]$Manifest)

    if (-not $Manifest) {
        return $null
    }

    $Healthy = @(
        $Manifest.endpoints |
            Where-Object {
                $_.health_ok -eq $true -and
                $_.base_url -and
                (Test-SlamAiSecureRemoteBaseUrl ([string]$_.base_url))
            } |
            Sort-Object @{ Expression = { [int]$_.priority }; Ascending = $true }
    )
    if ($Healthy.Count -eq 0) {
        return $null
    }

    if ($Manifest.active_base_url) {
        $ActiveUrl = ([string]$Manifest.active_base_url).TrimEnd("/")
        $Active = @(
            $Healthy |
                Where-Object { ([string]$_.base_url).TrimEnd("/") -eq $ActiveUrl } |
                Select-Object -First 1
        )
        if ($Active.Count -gt 0) {
            return $Active[0]
        }
    }

    return $Healthy[0]
}
