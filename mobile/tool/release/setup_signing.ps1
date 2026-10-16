# One-time: creates the permanent Hisbah Android release key outside the repository and stores the
# signing secrets in GitHub Actions. Run it yourself in a PowerShell window (hidden password prompt):
#   powershell -ExecutionPolicy Bypass -File mobile\tool\release\setup_signing.ps1
# Never overwrites an existing keystore or existing secrets. Prints no secret values.
param(
    [string]$Repo = 'abdelmoen1/micro-erp-system',
    [string]$Dir = "$env:USERPROFILE\hisbah-release",
    [string]$Keytool = "$env:USERPROFILE\dev\jdk17\bin\keytool.exe",
    [string]$Gh = 'C:\Program Files\GitHub CLI\gh.exe'
)
$ErrorActionPreference = 'Stop'

$keystore = Join-Path $Dir 'hisbah-upload.jks'
$patchKey = Join-Path $Dir 'shorebird-patch-private.pem'
$alias = 'upload'
$names = 'ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD', 'SHOREBIRD_PATCH_PRIVATE_KEY'

if (Test-Path $keystore) { throw "$keystore already exists. The permanent key is never overwritten." }
if (-not (Test-Path $patchKey)) { throw "$patchKey is missing (patch-signing key)." }
& $Gh auth status *> $null
if ($LASTEXITCODE -ne 0) { throw "GitHub CLI is not signed in: run 'gh auth login' first." }
$existing = (& $Gh secret list --repo $Repo --json name | ConvertFrom-Json).name
$clash = $names | Where-Object { $existing -contains $_ }
if ($clash) { throw "These secrets already exist and are left untouched: $($clash -join ', '). Delete them deliberately first if they must be replaced." }

$first = Read-Host 'New keystore password (at least 12 characters)' -AsSecureString
$second = Read-Host 'Repeat the password' -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($first))
$repeat = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($second))
if ($plain -cne $repeat) { throw 'The passwords do not match. Nothing was created.' }
if ($plain.Length -lt 12) { throw 'Use at least 12 characters. Nothing was created.' }
$repeat = $null

New-Item -ItemType Directory -Force $Dir | Out-Null
$env:HISBAH_KS_PASS = $plain
try {
    # PKCS12: the key password equals the store password.
    & $Keytool -genkeypair -keystore $keystore -storetype PKCS12 -alias $alias -keyalg RSA -keysize 2048 `
        -validity 10000 -dname 'CN=Hisbah Smart Shop, O=Hisbah' -storepass:env HISBAH_KS_PASS -keypass:env HISBAH_KS_PASS
    if ($LASTEXITCODE -ne 0) { throw 'keytool failed.' }

    $fingerprint = (& $Keytool -list -v -keystore $keystore -alias $alias -storepass:env HISBAH_KS_PASS |
        Select-String 'SHA256:' | Select-Object -First 1).Line.Trim()
    Write-Host "Keystore created: $keystore"
    Write-Host "Certificate $fingerprint"

    # Values go to gh on stdin (not in arguments or history); gh trims the trailing newline.
    $OutputEncoding = New-Object System.Text.UTF8Encoding $false
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystore)) | & $Gh secret set ANDROID_KEYSTORE_BASE64 --repo $Repo
    $plain | & $Gh secret set ANDROID_KEYSTORE_PASSWORD --repo $Repo
    $plain | & $Gh secret set ANDROID_KEY_PASSWORD --repo $Repo
    $alias | & $Gh secret set ANDROID_KEY_ALIAS --repo $Repo
    (Get-Content -Raw $patchKey) | & $Gh secret set SHOREBIRD_PATCH_PRIVATE_KEY --repo $Repo
} finally {
    Remove-Item Env:HISBAH_KS_PASS -ErrorAction SilentlyContinue
    $plain = $null
}

Write-Host ''
Write-Host 'Secrets now configured (names only):'
& $Gh secret list --repo $Repo
Write-Host ''
Write-Host "Back up the whole folder $Dir (keystore + patch key) and the password now: docs/mobile/ota-updates.md section 2.1."
