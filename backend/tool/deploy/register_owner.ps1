# Creates the first shop owner on the live API through the app's own registration endpoint, then
# proves login + an authenticated read work, and logs out. The password is typed at a hidden prompt
# and never printed or stored.
#   powershell -ExecutionPolicy Bypass -File backend\tool\deploy\register_owner.ps1
param([string]$Api = 'https://hisbah-api-alur.onrender.com/api/v1')
$ErrorActionPreference = 'Stop'
$json = @{ Accept = 'application/json' }

function Read-Plain([string]$Prompt) {
    $s = Read-Host $Prompt -AsSecureString
    [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
}
function Invoke-Api([string]$Method, [string]$Path, $Body, [string]$Token) {
    $headers = $json.Clone()
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    $params = @{ Method = $Method; Uri = "$Api$Path"; Headers = $headers; TimeoutSec = 120 }
    if ($Body) { $params.ContentType = 'application/json; charset=utf-8'; $params.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json)) }
    try { return Invoke-RestMethod @params }
    catch {
        $detail = $_.ErrorDetails.Message
        try { $e = $detail | ConvertFrom-Json; $detail = "$($e.code): $($e.message) $(($e.errors | ConvertTo-Json -Compress))" } catch { }
        throw "API $Method $Path failed: HTTP $($_.Exception.Response.StatusCode.value__) $detail"
    }
}

Write-Host "Waking the API (free plan: the first request can take about a minute)..."
try { Invoke-WebRequest -Uri ($Api -replace '/api/v1$', '/up') -UseBasicParsing -TimeoutSec 120 | Out-Null } catch { }

$store = Read-Host 'Store name'
$owner = Read-Host 'Owner name'
$email = Read-Host 'Owner email (used to log in)'
do {
    $password = Read-Plain 'Password (hidden; at least 8 characters)'
    $confirm = Read-Plain 'Repeat the password'
    if ($password -cne $confirm) { Write-Host 'The passwords do not match. Try again.' -ForegroundColor Yellow }
} while ($password -cne $confirm)
$confirm = $null

try {
    $registered = Invoke-Api POST '/register' @{
        store_name = $store; owner_name = $owner; email = $email
        password = $password; password_confirmation = $password; timezone = 'Asia/Gaza'
    }
    Write-Host "Registered: $($registered.message)" -ForegroundColor Green
    if ($registered.token) { try { Invoke-Api POST '/logout' $null $registered.token | Out-Null } catch { } }

    $login = Invoke-Api POST '/login' @{ email = $email; password = $password }
    $me = Invoke-Api GET '/me' $null $login.token
    $user = $me.user
    Write-Host "Login works. /me: role=$($user.role), store=$($user.store.name), status=$($user.status)" -ForegroundColor Green
    Invoke-Api POST '/logout' $null $login.token | Out-Null
    Write-Host 'Logged out again (no token left behind). Sign in on the phone with this email and password.'
} finally {
    $password = $null
}
