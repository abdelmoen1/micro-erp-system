# Finds or creates the Hisbah MySQL service on Aiven's FREE plan only (docs/deploy/render.md).
#   powershell -ExecutionPolicy Bypass -File backend\tool\deploy\aiven_free_mysql.ps1 [-Create]
# Without -Create it only reports (project, existing services, free MySQL plans and clouds).
# With -Create it creates the service only if a plan named free-* with price 0 exists; otherwise it stops.
# Uses the Aiven token saved by save_local_secret.ps1 (-Name aiven-api-token). Prints no secrets.
param(
    [switch]$Create,
    [string]$ServiceName = 'hisbah-mysql',
    [string]$PreferredCloudPattern = 'europe|frankfurt|germany|eu-'
)
$ErrorActionPreference = 'Stop'
$token = & "$PSScriptRoot\read_local_secret.ps1" -Name aiven-api-token
$headers = @{ Authorization = "aivenv1 $token" }
$api = 'https://api.aiven.io/v1'

function Invoke-Aiven([string]$Method, [string]$Path, $Body) {
    for ($i = 1; $i -le 5; $i++) {
        try {
            if ($Body) { return Invoke-RestMethod -Method $Method -Uri "$api$Path" -Headers $headers -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 6) }
            return Invoke-RestMethod -Method $Method -Uri "$api$Path" -Headers $headers
        } catch {
            $status = $_.Exception.Response.StatusCode.value__
            if ($status -and $status -lt 500) { throw "Aiven API $Method $Path failed: HTTP $status $($_.ErrorDetails.Message)" }
            Start-Sleep -Seconds (3 * $i)
        }
    }
    throw "Aiven API $Method $Path failed after retries (network)."
}

$projects = @((Invoke-Aiven GET '/project').projects)
if ($projects.Count -eq 0) { throw 'No Aiven project in this account yet: finish the sign-up in the Aiven Console first.' }
$project = $projects[0].project_name
Write-Host "Project: $project (of $($projects.Count))"

$services = @((Invoke-Aiven GET "/project/$project/service").services)
$existing = $services | Where-Object { $_.service_type -eq 'mysql' }
foreach ($s in $services) { Write-Host "  existing service: $($s.service_name) type=$($s.service_type) plan=$($s.plan) state=$($s.state) cloud=$($s.cloud_name)" }
if ($existing) {
    Write-Host "A MySQL service already exists ($($existing[0].service_name), plan $($existing[0].plan)): reusing it, nothing created."
    return
}

$types = Invoke-Aiven GET "/project/$project/service_types"
$plans = @($types.service_types.mysql.service_plans)
$free = @()
foreach ($p in $plans) {
    foreach ($cloud in $p.regions.PSObject.Properties) {
        $price = [decimal]($cloud.Value.price_usd)
        if ($p.service_plan -like 'free-*' -and $price -eq 0) {
            $free += [pscustomobject]@{ Plan = $p.service_plan; Cloud = $cloud.Name; Price = $price; DiskMB = $cloud.Value.disk_space_mb }
        }
    }
}
if ($free.Count -eq 0) { throw 'No free MySQL plan is offered to this project. Nothing created (no paid plan will be used).' }
$free | Sort-Object Cloud | ForEach-Object { Write-Host "  free plan: $($_.Plan) cloud=$($_.Cloud) price=$($_.Price) USD/h disk=$($_.DiskMB) MB" }

$choice = ($free | Where-Object { $_.Cloud -match $PreferredCloudPattern } | Select-Object -First 1)
if (-not $choice) { $choice = $free[0] }
Write-Host "Selected: plan $($choice.Plan) in $($choice.Cloud) (price $($choice.Price))"
if (-not $Create) { Write-Host 'Report only: run with -Create to create it.'; return }

$created = Invoke-Aiven POST "/project/$project/service" @{
    service_name = $ServiceName
    service_type = 'mysql'
    plan         = $choice.Plan
    cloud        = $choice.Cloud
}
Write-Host "Created: $($created.service.service_name) plan=$($created.service.plan) state=$($created.service.state) cloud=$($created.service.cloud_name)"
