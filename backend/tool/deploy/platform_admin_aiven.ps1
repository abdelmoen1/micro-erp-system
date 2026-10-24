# Grants (or revokes) platform admin on the LIVE database for an account that already exists, from the
# release PC (the free Render service has no shell). It only runs `php artisan hisbah:platform-admin`,
# which promotes an existing user: no account or password is ever created.
#   powershell -ExecutionPolicy Bypass -File backend\tool\deploy\platform_admin_aiven.ps1 -Email you@example.com
#   powershell -ExecutionPolicy Bypass -File backend\tool\deploy\platform_admin_aiven.ps1 -Email you@example.com -Revoke
# Safety: same checks as migrate_new_aiven_db.ps1 (Aiven host, free plan, the app's own DB user, TLS), and it
# stops if the platform-admin migration has not run yet. Credentials stay in this process; nothing secret is printed.
param(
    [Parameter(Mandatory = $true)][string]$Email,
    [switch]$Revoke,
    [string]$ServiceName = 'mysql-1f5745b1',
    [string]$AppUser = 'hisbah_app'
)
$ErrorActionPreference = 'Stop'
$backend = Resolve-Path "$PSScriptRoot\..\.."
$token = & "$PSScriptRoot\read_local_secret.ps1" -Name aiven-api-token
$headers = @{ Authorization = "aivenv1 $token" }
$api = 'https://api.aiven.io/v1'

$project = @((Invoke-RestMethod -Uri "$api/project" -Headers $headers).projects)[0].project_name
$service = (Invoke-RestMethod -Uri "$api/project/$project/service/${ServiceName}?include_secrets=true" -Headers $headers).service
if ($service.state -ne 'RUNNING') { throw "Service $ServiceName is $($service.state), not RUNNING. Wait and retry." }
if ($service.plan -notlike 'free-*') { throw "Service plan is $($service.plan), not a free plan. Stopping." }
$p = $service.service_uri_params
if ($p.host -notlike '*.aivencloud.com') { throw "Unexpected database host (not *.aivencloud.com). Stopping." }
$dbUser = @($service.users | Where-Object { $_.username -eq $AppUser })[0]
if (-not $dbUser) { throw "Database user $AppUser does not exist on $ServiceName." }

$ca = (Invoke-RestMethod -Uri "$api/project/$project/kms/ca" -Headers $headers).certificate
$caFile = Join-Path $env:TEMP 'hisbah-aiven-ca.pem'
Set-Content -Path $caFile -Value $ca -Encoding ascii

$env:APP_ENV = 'production'
# Throwaway key for this process only: the command encrypts nothing.
$keyBytes = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($keyBytes)
$env:APP_KEY = 'base64:' + [Convert]::ToBase64String($keyBytes)
$env:DB_CONNECTION = 'mysql'
$env:DB_HOST = $p.host
$env:DB_PORT = $p.port
$env:DB_DATABASE = $p.dbname
$env:DB_USERNAME = $dbUser.username
$env:DB_PASSWORD = $dbUser.password
$env:MYSQL_ATTR_SSL_CA = $caFile
Write-Host "Target: Aiven service $ServiceName, database '$($p.dbname)' (live data)"

Push-Location $backend
try {
    $pending = php artisan migrate:status --pending --no-interaction 2>&1 | Out-String
    if ($pending -match '2026_10_24_000002_add_platform_admin_and_store_access') {
        throw 'The platform-admin migration has not run on this database yet. Run the migration first.'
    }
    if ($Revoke) {
        php artisan hisbah:platform-admin $Email --revoke --no-interaction
    } else {
        php artisan hisbah:platform-admin $Email --no-interaction
    }
    if ($LASTEXITCODE -ne 0) { throw 'The command did not complete (see the message above).' }
} finally {
    Pop-Location
    Remove-Item $caFile -ErrorAction SilentlyContinue
    foreach ($n in 'APP_KEY', 'DB_HOST', 'DB_PORT', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD', 'MYSQL_ATTR_SSL_CA') { Remove-Item "Env:$n" -ErrorAction SilentlyContinue }
}
