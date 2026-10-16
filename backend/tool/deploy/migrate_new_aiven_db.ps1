# Runs the Laravel migrations ONCE against the new, empty Aiven MySQL database (never Railway).
#   powershell -ExecutionPolicy Bypass -File backend\tool\deploy\migrate_new_aiven_db.ps1 [-Migrate]
# Without -Migrate it only checks the target and shows `migrate:status`.
# Safety: the host must be *.aivencloud.com, and migrating stops if the database already has tables
# that are not Laravel's own migration bookkeeping. Credentials come from the Aiven API and stay in
# this process; nothing secret is printed.
param(
    [switch]$Migrate,
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
# The application's own database user (not the admin account).
$dbUser = @($service.users | Where-Object { $_.username -eq $AppUser })[0]
if (-not $dbUser) { throw "Database user $AppUser does not exist on $ServiceName." }

$ca = (Invoke-RestMethod -Uri "$api/project/$project/kms/ca" -Headers $headers).certificate
$caFile = Join-Path $env:TEMP 'hisbah-aiven-ca.pem'
Set-Content -Path $caFile -Value $ca -Encoding ascii

# Process-only environment: overrides nothing on disk (the worktree has no .env and no config cache).
$env:APP_ENV = 'production'
# Throwaway key for this process only: migrations encrypt nothing, and the deployed app uses its own APP_KEY.
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
Write-Host "Target: Aiven service $ServiceName (plan $($service.plan)), database '$($p.dbname)', host *.aivencloud.com, TLS with the project CA"

Push-Location $backend
try {
    # Connection probe from a temporary file (inline `php -r` quoting breaks in Windows PowerShell).
    $probe = Join-Path $env:TEMP 'hisbah-db-probe.php'
    Set-Content -Path $probe -Encoding ascii -Value @'
<?php
$pdo = new PDO(
    'mysql:host=' . getenv('DB_HOST') . ';port=' . getenv('DB_PORT') . ';dbname=' . getenv('DB_DATABASE'),
    getenv('DB_USERNAME'), getenv('DB_PASSWORD'),
    [PDO::MYSQL_ATTR_SSL_CA => getenv('MYSQL_ATTR_SSL_CA'), PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);
echo json_encode([
    'version' => $pdo->query('select version()')->fetchColumn(),
    'tls' => $pdo->query("show session status like 'Ssl_cipher'")->fetch(PDO::FETCH_NUM)[1],
    'require_pk' => $pdo->query('select @@sql_require_primary_key')->fetchColumn(),
    'tables' => $pdo->query('show tables')->fetchAll(PDO::FETCH_COLUMN),
]);
'@
    $tables = php $probe
    $probeExit = $LASTEXITCODE
    Remove-Item $probe -ErrorAction SilentlyContinue
    if ($probeExit -ne 0) { throw 'Could not connect to the database.' }
    $info = $tables | ConvertFrom-Json
    Write-Host "MySQL server: $($info.version); TLS cipher: $($info.tls); sql_require_primary_key=$($info.require_pk); existing tables: $(@($info.tables).Count)"
    $foreign = @($info.tables | Where-Object { $_ -ne 'migrations' })
    php artisan migrate:status --no-interaction
    if (-not $Migrate) { Write-Host 'Check only: run with -Migrate to apply the migrations.'; return }
    if ($foreign.Count -gt 0 -and -not (@($info.tables) -contains 'migrations')) {
        throw "The database already holds tables that Laravel did not create ($($foreign.Count)). Stopping."
    }
    php artisan migrate --force --no-interaction
    if ($LASTEXITCODE -ne 0) { throw 'Migrations failed.' }
    php artisan migrate:status --no-interaction
} finally {
    Pop-Location
    Remove-Item $caFile -ErrorAction SilentlyContinue
    foreach ($n in 'APP_KEY', 'DB_HOST', 'DB_PORT', 'DB_DATABASE', 'DB_USERNAME', 'DB_PASSWORD', 'MYSQL_ATTR_SSL_CA') { Remove-Item "Env:$n" -ErrorAction SilentlyContinue }
}
