param(
    [string]$RepoRoot = "C:\Users\Administrator\Downloads\slam-ai-skill-gateway",
    [string]$ManifestUrl = "https://raw.githubusercontent.com/kenchikuliu/slam-ai-skill-gateway/main/public/slam-ai-endpoints.json",
    [string]$GatewayConfigPath = "",
    [string]$LocalHealthUrl = "http://127.0.0.1:8766/health",
    [string]$Query = "gaussian slam",
    [int]$PaperLimit = 3,
    [int]$TextLimit = 1,
    [int]$TimeoutSeconds = 15,
    [int]$StartupDelaySeconds = 20,
    [int]$ReadyWaitSeconds = 180,
    [switch]$SkipRepair
)

$ErrorActionPreference = "Stop"

$ResolvedRepo = (Resolve-Path -LiteralPath $RepoRoot).Path.TrimEnd("\")
$TmpDir = Join-Path $ResolvedRepo "tmp"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

if (-not $GatewayConfigPath) {
    $GatewayConfigPath = Join-Path $TmpDir "gateway_8766.env.json"
}

$LogPath = Join-Path $TmpDir "remote_access_startup_check.log"
$StatePath = Join-Path $TmpDir "remote_access_startup_check.state.json"
$GatewayScript = Join-Path $ResolvedRepo "scripts\start_gateway_from_env.ps1"
$CloudflareWatchdogScript = Join-Path $ResolvedRepo "scripts\watch_cloudflare_quick_tunnel.ps1"

function Write-CheckLog {
    param(
        [string]$Status,
        [string]$Message = "",
        [hashtable]$Extra = @{}
    )
    $Record = [ordered]@{
        time = (Get-Date).ToString("s")
        status = $Status
        message = $Message
    }
    foreach ($Key in $Extra.Keys) {
        $Record[$Key] = $Extra[$Key]
    }
    $Json = $Record | ConvertTo-Json -Compress -Depth 8
    $Json | Add-Content -LiteralPath $LogPath -Encoding UTF8
    Write-Output $Json
}

function Get-StatusCodeFromError {
    param([object]$ErrorRecord)
    if ($ErrorRecord.Exception.Response) {
        try {
            return [int]$ErrorRecord.Exception.Response.StatusCode
        } catch {
            return $null
        }
    }
    return $null
}

function Invoke-JsonGet {
    param(
        [string]$Url,
        [hashtable]$Headers = @{},
        [int[]]$ExpectedStatusCodes = @(200)
    )
    try {
        $Response = Invoke-WebRequest -Uri $Url -Headers $Headers -UseBasicParsing -TimeoutSec $TimeoutSeconds
        $StatusCode = [int]$Response.StatusCode
        $Payload = $null
        if ($Response.Content) {
            try {
                $Payload = $Response.Content | ConvertFrom-Json
            } catch {
                $Payload = $null
            }
        }
        return [ordered]@{
            ok = ($ExpectedStatusCodes -contains $StatusCode)
            status_code = $StatusCode
            payload = $Payload
            error = ""
        }
    } catch {
        $StatusCode = Get-StatusCodeFromError -ErrorRecord $_
        return [ordered]@{
            ok = ($StatusCode -and ($ExpectedStatusCodes -contains $StatusCode))
            status_code = $StatusCode
            payload = $null
            error = $_.Exception.GetType().Name
        }
    }
}

function Ensure-LocalGateway {
    $Local = Invoke-JsonGet -Url $LocalHealthUrl
    if ($Local.ok) {
        return $Local
    }
    if (-not (Test-Path -LiteralPath $GatewayScript)) {
        return $Local
    }

    Write-CheckLog -Status "local_gateway_start" -Message $Local.error -Extra @{
        local_health_url = $LocalHealthUrl
        status_code = $Local.status_code
    } | Out-Null

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $GatewayScript) `
        -WorkingDirectory $ResolvedRepo `
        -WindowStyle Hidden | Out-Null

    $Deadline = (Get-Date).AddSeconds([Math]::Max(1, $ReadyWaitSeconds))
    do {
        Start-Sleep -Seconds 2
        $Local = Invoke-JsonGet -Url $LocalHealthUrl
        if ($Local.ok) {
            return $Local
        }
    } while ((Get-Date) -lt $Deadline)

    return $Local
}

function Read-GatewayToken {
    if (-not (Test-Path -LiteralPath $GatewayConfigPath)) {
        throw "Gateway config not found: $GatewayConfigPath"
    }
    $Config = Get-Content -LiteralPath $GatewayConfigPath -Raw | ConvertFrom-Json
    $Token = if ($Config.token) { [string]$Config.token } else { "" }
    if (-not $Token) {
        throw "Gateway token is empty in local config."
    }
    return $Token
}

function Resolve-ManifestBaseUrl {
    $ManifestResult = Invoke-JsonGet -Url $ManifestUrl
    $Manifest = $ManifestResult.payload
    $BaseUrl = ""
    $EndpointCount = 0
    if ($Manifest) {
        $EndpointCount = @($Manifest.endpoints).Count
        if ($Manifest.active_base_url) {
            $BaseUrl = ([string]$Manifest.active_base_url).TrimEnd("/")
        }
        if (-not $BaseUrl) {
            $Healthy = @($Manifest.endpoints |
                Where-Object { $_.health_ok } |
                Sort-Object @{ Expression = { [int]$_.priority }; Ascending = $true } |
                Select-Object -First 1)
            if ($Healthy.Count -gt 0 -and $Healthy[0].base_url) {
                $BaseUrl = ([string]$Healthy[0].base_url).TrimEnd("/")
            }
        }
    }
    return [ordered]@{
        ok = ($ManifestResult.ok -and [bool]$BaseUrl)
        status_code = $ManifestResult.status_code
        error = $ManifestResult.error
        manifest = $Manifest
        base_url = $BaseUrl
        endpoint_count = $EndpointCount
        token_included = if ($Manifest -and ($null -ne $Manifest.token_included)) { [bool]$Manifest.token_included } else { $null }
    }
}

function Invoke-CloudflareRepairOnce {
    if ($SkipRepair) {
        return [ordered]@{ attempted = $false; ok = $false; exit_code = $null; error = "skip_repair" }
    }
    if (-not (Test-Path -LiteralPath $CloudflareWatchdogScript)) {
        return [ordered]@{ attempted = $false; ok = $false; exit_code = $null; error = "missing_cloudflare_watchdog_script" }
    }
    try {
        $Args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $CloudflareWatchdogScript, "-RepoRoot", $ResolvedRepo, "-Once")
        & powershell.exe @Args | Out-Null
        $ExitCode = $LASTEXITCODE
        return [ordered]@{ attempted = $true; ok = ($ExitCode -eq 0 -or $null -eq $ExitCode); exit_code = $ExitCode; error = "" }
    } catch {
        return [ordered]@{ attempted = $true; ok = $false; exit_code = $LASTEXITCODE; error = $_.Exception.GetType().Name }
    }
}

function Test-RemoteAccess {
    param(
        [string]$BaseUrl,
        [string]$Token
    )
    $Health = Invoke-JsonGet -Url (($BaseUrl.TrimEnd("/")) + "/health")
    $UnauthSkill = Invoke-JsonGet -Url (($BaseUrl.TrimEnd("/")) + "/skill") -ExpectedStatusCodes @(401)
    $Headers = @{ Authorization = "Bearer $Token" }
    $Encoded = [uri]::EscapeDataString($Query)
    $ContextUrl = ($BaseUrl.TrimEnd("/")) + "/skill/context?q=$Encoded&paper_limit=$PaperLimit&text_limit=$TextLimit"
    $Context = Invoke-JsonGet -Url $ContextUrl -Headers $Headers

    $ContextStatus = $null
    $PaperCount = $null
    $TextMatchCount = $null
    if ($Context.payload) {
        $ContextStatus = $Context.payload.status
        if ($Context.payload.papers) {
            $PaperCount = [int]$Context.payload.papers.count
        }
        if ($Context.payload.text_matches) {
            $TextMatchCount = [int]$Context.payload.text_matches.count
        }
    }

    return [ordered]@{
        ok = ($Health.ok -and $UnauthSkill.ok -and $Context.ok -and $ContextStatus)
        health = [ordered]@{
            ok = $Health.ok
            status_code = $Health.status_code
            error = $Health.error
        }
        unauth_skill = [ordered]@{
            ok = $UnauthSkill.ok
            expected_status_code = 401
            status_code = $UnauthSkill.status_code
            error = $UnauthSkill.error
        }
        auth_context = [ordered]@{
            ok = ($Context.ok -and [bool]$ContextStatus)
            status_code = $Context.status_code
            error = $Context.error
            paper_index_source = if ($ContextStatus) { $ContextStatus.paper_index_source } else { "" }
            root_pdf_count = if ($ContextStatus) { $ContextStatus.root_pdf_count } else { $null }
            root_markdown_count = if ($ContextStatus) { $ContextStatus.root_markdown_count } else { $null }
            pending_markdown_count = if ($ContextStatus) { $ContextStatus.pending_markdown_count } else { $null }
            paper_count = $PaperCount
            text_match_count = $TextMatchCount
        }
    }
}

if ($StartupDelaySeconds -gt 0) {
    Start-Sleep -Seconds $StartupDelaySeconds
}

$StartedAt = Get-Date
$Repair = [ordered]@{ attempted = $false; ok = $false; exit_code = $null; error = "" }
$TokenLoaded = $false
$Token = ""

try {
    $LocalGateway = Ensure-LocalGateway
    $Token = Read-GatewayToken
    $TokenLoaded = $true

    $Manifest = Resolve-ManifestBaseUrl
    $Remote = if ($Manifest.ok) {
        Test-RemoteAccess -BaseUrl $Manifest.base_url -Token $Token
    } else {
        [ordered]@{
            ok = $false
            health = $null
            unauth_skill = $null
            auth_context = $null
        }
    }

    if (-not $Remote.ok) {
        Write-CheckLog -Status "repair_start" -Message "Remote access check failed; running Cloudflare watchdog once." -Extra @{
            manifest_ok = $Manifest.ok
            base_url = $Manifest.base_url
            remote_ok = $Remote.ok
        } | Out-Null
        $Repair = Invoke-CloudflareRepairOnce
        Start-Sleep -Seconds 5
        $Manifest = Resolve-ManifestBaseUrl
        $Remote = if ($Manifest.ok) {
            Test-RemoteAccess -BaseUrl $Manifest.base_url -Token $Token
        } else {
            [ordered]@{
                ok = $false
                health = $null
                unauth_skill = $null
                auth_context = $null
            }
        }
    }

    $Succeeded = ($LocalGateway.ok -and $TokenLoaded -and $Manifest.ok -and $Remote.ok -and ($Manifest.token_included -eq $false))
    $State = [ordered]@{
        checked_at = (Get-Date).ToString("s")
        started_at = $StartedAt.ToString("s")
        ok = $Succeeded
        repo_root = $ResolvedRepo
        manifest_url = $ManifestUrl
        manifest = [ordered]@{
            ok = $Manifest.ok
            status_code = $Manifest.status_code
            error = $Manifest.error
            active_base_url = $Manifest.base_url
            endpoint_count = $Manifest.endpoint_count
            token_included = $Manifest.token_included
        }
        local_gateway = [ordered]@{
            ok = $LocalGateway.ok
            health_url = $LocalHealthUrl
            status_code = $LocalGateway.status_code
            error = $LocalGateway.error
        }
        token = [ordered]@{
            source = $GatewayConfigPath
            loaded = $TokenLoaded
            included_in_manifest = $Manifest.token_included
        }
        remote = $Remote
        repair = $Repair
    }

    $State | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    Write-CheckLog -Status $(if ($Succeeded) { "ok" } else { "failed" }) -Extra @{
        active_base_url = $Manifest.base_url
        manifest_ok = $Manifest.ok
        local_gateway_ok = $LocalGateway.ok
        token_loaded = $TokenLoaded
        remote_ok = $Remote.ok
        token_included = $Manifest.token_included
        repair_attempted = $Repair.attempted
        state_path = $StatePath
    } | Out-Null

    if (-not $Succeeded) {
        exit 1
    }
    exit 0
} catch {
    $State = [ordered]@{
        checked_at = (Get-Date).ToString("s")
        started_at = $StartedAt.ToString("s")
        ok = $false
        repo_root = $ResolvedRepo
        manifest_url = $ManifestUrl
        token = [ordered]@{
            source = $GatewayConfigPath
            loaded = $TokenLoaded
            included_in_manifest = $null
        }
        error = [ordered]@{
            type = $_.Exception.GetType().Name
            message = $_.Exception.Message
        }
    }
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    Write-CheckLog -Status "error" -Message $_.Exception.Message -Extra @{
        token_loaded = $TokenLoaded
        state_path = $StatePath
    } | Out-Null
    exit 1
}
