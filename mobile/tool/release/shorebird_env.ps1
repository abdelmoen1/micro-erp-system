# Dot-source before local Shorebird commands: . mobile\tool\release\shorebird_env.ps1
# Sets $env:SHOREBIRD_TOKEN for this PowerShell session from the DPAPI-encrypted API key saved by
# set_shorebird_token.ps1. Prints nothing secret.
$keyFile = Join-Path "$env:USERPROFILE\hisbah-release" 'shorebird-api-key.dpapi'
if (-not (Test-Path $keyFile)) { throw "$keyFile is missing: run mobile\tool\release\set_shorebird_token.ps1 first." }
$secure = ConvertTo-SecureString (Get-Content -Raw $keyFile).Trim()
$env:SHOREBIRD_TOKEN = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
$secure = $null
