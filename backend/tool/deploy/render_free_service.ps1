# Creates the Hisbah API on Render's FREE web-service plan (Docker, Frankfurt) connected to the Aiven MySQL.
#   powershell -ExecutionPolicy Bypass -File backend\tool\deploy\render_free_service.ps1 [-Create]
# Without -Create it only reports. Never creates a second service with the same name, never uses a paid plan.
# Secrets (APP_KEY from Railway's existing service, Aiven credentials and CA) go straight from the
# provider APIs into Render's protected environment variables; nothing secret is printed.
param(
    [switch]$Create,
    [string]$ServiceName = 'hisbah-api',
    [string]$Branch = 'infra/render-backend',
    [string]$AivenService = 'hisbah-mysql'
)
$ErrorActionPreference = 'Stop'
# Render API token: the official CLI's login (`render login`, browser authorization) or a saved API key.
$cliConfig = Join-Path $env:USERPROFILE '.render\cli.yaml'
$renderKey = $null
if (Test-Path $cliConfig) {
    $line = Get-Content $cliConfig | Where-Object { $_ -match '^\s*key:\s*(\S+)' } | Select-Object -First 1
    if ($line -match '^\s*key:\s*(\S+)') { $renderKey = $Matches[1].Trim('"', "'") }
}
if (-not $renderKey) { $renderKey = & "$PSScriptRoot\read_local_secret.ps1" -Name render-api-key }
$rh = @{ Authorization = "Bearer $renderKey"; Accept = 'application/json' }
$rapi = 'https://api.render.com/v1'

function Invoke-Render([string]$Method, [string]$Path, $Body) {
    for ($i = 1; $i -le 5; $i++) {
        try {
            if ($Body) { return Invoke-RestMethod -Method $Method -Uri "$rapi$Path" -Headers $rh -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 8) }
            return Invoke-RestMethod -Method $Method -Uri "$rapi$Path" -Headers $rh
        } catch {
            $status = $_.Exception.Response.StatusCode.value__
            if ($status -and $status -lt 500) { throw "Render API $Method $Path failed: HTTP $status $($_.ErrorDetails.Message)" }
            Start-Sleep -Seconds (3 * $i)
        }
    }
    throw "Render API $Method $Path failed after retries (network)."
}

$owner = @(Invoke-Render GET '/owners?limit=20')[0].owner
Write-Host "Render workspace: $($owner.name) ($($owner.type))"
$existing = @(Invoke-Render GET "/services?name=$ServiceName&limit=20") | ForEach-Object { $_.service } | Where-Object { $_.name -eq $ServiceName }
if ($existing) {
    $s = $existing[0]
    Write-Host "Service already exists: $($s.name) plan=$($s.serviceDetails.plan) url=$($s.serviceDetails.url) (nothing created)"
    return
}

# Database connection (Aiven API) and the existing application key (Railway CLI), kept in memory.
$aivenToken = & "$PSScriptRoot\read_local_secret.ps1" -Name aiven-api-token
$ah = @{ Authorization = "aivenv1 $aivenToken" }
$project = @((Invoke-RestMethod -Uri 'https://api.aiven.io/v1/project' -Headers $ah).projects)[0].project_name
$db = (Invoke-RestMethod -Uri "https://api.aiven.io/v1/project/$project/service/$AivenService" -Headers $ah).service
if ($db.plan -notlike 'free-*') { throw "Aiven service plan is $($db.plan), not free. Stopping." }
$ca = (Invoke-RestMethod -Uri "https://api.aiven.io/v1/project/$project/kms/ca" -Headers $ah).certificate
$p = $db.service_uri_params

$railway = Join-Path $env:APPDATA 'npm\railway.cmd'
$vars = & $railway variables -s micro-erp-system -p cea4f7e1-c87f-4075-a45d-136f7c51dcf9 -e production --json | ConvertFrom-Json
$appKey = $vars.APP_KEY
if (-not $appKey -or $appKey -notlike 'base64:*') { throw 'Could not read the existing APP_KEY from Railway. Stopping.' }
Write-Host 'Existing APP_KEY read from Railway (not shown).'

$body = @{
    type              = 'web_service'
    name              = $ServiceName
    ownerId           = $owner.id
    repo              = 'https://github.com/abdelmoen1/micro-erp-system'
    branch            = $Branch
    rootDir           = 'backend'
    autoDeployTrigger = 'commit'
    serviceDetails    = @{
        runtime            = 'docker'
        plan               = 'free'
        region             = 'frankfurt'
        healthCheckPath    = '/up'
        numInstances       = 1
        envSpecificDetails = @{ dockerfilePath = './Dockerfile'; dockerContext = '.' }
    }
    envVars           = @(
        @{ key = 'APP_ENV'; value = 'production' }
        @{ key = 'APP_DEBUG'; value = 'false' }
        @{ key = 'APP_KEY'; value = $appKey }
        @{ key = 'LOG_CHANNEL'; value = 'stderr' }
        @{ key = 'LOG_LEVEL'; value = 'info' }
        @{ key = 'DB_CONNECTION'; value = 'mysql' }
        @{ key = 'DB_HOST'; value = $p.host }
        @{ key = 'DB_PORT'; value = "$($p.port)" }
        @{ key = 'DB_DATABASE'; value = $p.dbname }
        @{ key = 'DB_USERNAME'; value = $p.user }
        @{ key = 'DB_PASSWORD'; value = $p.password }
        @{ key = 'DB_SSL_CA_PEM'; value = $ca }
        @{ key = 'SESSION_DRIVER'; value = 'database' }
        @{ key = 'CACHE_STORE'; value = 'database' }
        @{ key = 'QUEUE_CONNECTION'; value = 'database' }
    )
}
if (-not $Create) { Write-Host "Report only: would create $ServiceName on plan 'free' in frankfurt from $Branch. Run with -Create."; return }

$created = Invoke-Render POST '/services' $body
$appKey = $null; $body = $null
$svc = $created.service
Write-Host "Created: $($svc.name) id=$($svc.id) plan=$($svc.serviceDetails.plan) region=$($svc.serviceDetails.region)"
Write-Host "URL: $($svc.serviceDetails.url)"
if ($svc.serviceDetails.plan -ne 'free') { Write-Host "WARNING: plan is $($svc.serviceDetails.plan), not free: suspend it in the dashboard." -ForegroundColor Red }
