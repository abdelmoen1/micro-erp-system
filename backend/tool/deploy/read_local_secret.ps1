# Returns a secret saved by save_local_secret.ps1, for use inside another script (never print it):
#   $key = & backend\tool\deploy\read_local_secret.ps1 -Name render-api-key
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Dir = "$env:USERPROFILE\hisbah-release"
)
$ErrorActionPreference = 'Stop'
$file = Join-Path $Dir "$Name.dpapi"
if (-not (Test-Path $file)) { throw "$file is missing: save it first with save_local_secret.ps1." }
$secure = ConvertTo-SecureString (Get-Content -Raw $file).Trim()
[Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
