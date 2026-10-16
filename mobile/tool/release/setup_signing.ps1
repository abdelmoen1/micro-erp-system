# One-time: creates the permanent Hisbah Android release key outside the repository and stores the
# signing secrets in GitHub Actions. Run it in a PowerShell window (hidden password prompt):
#   powershell -ExecutionPolicy Bypass -File mobile\tool\release\setup_signing.ps1
# Resumable: an existing keystore is never overwritten (its password is checked instead) and secrets
# that already exist are left untouched. Prints no secret values. If gh is not signed in, it uses the
# GitHub credential Git Credential Manager already stores for github.com.
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

function Invoke-Gh {
    # Retries: the connection drops requests intermittently.
    param([string[]]$GhArgs, [string]$InputText)
    for ($i = 1; $i -le 5; $i++) {
        if ($null -ne $InputText) { $out = $InputText | & $Gh @GhArgs } else { $out = & $Gh @GhArgs }
        if ($LASTEXITCODE -eq 0) { return $out }
        Start-Sleep -Seconds (3 * $i)
    }
    throw "gh $($GhArgs[0..1] -join ' ') failed after 5 attempts (network?). Re-run this script: it resumes."
}

if (-not (Test-Path $patchKey)) { throw "$patchKey is missing (patch-signing key)." }
& $Gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    # Request from a file: Windows PowerShell pipes add line endings git's credential parser rejects.
    $request = [IO.Path]::GetTempFileName()
    [IO.File]::WriteAllText($request, "protocol=https`nhost=github.com`n`n", (New-Object System.Text.ASCIIEncoding))
    $env:GCM_INTERACTIVE = 'never'
    $credential = cmd /c "git credential fill < `"$request`"" 2>$null
    Remove-Item $request
    $env:GH_TOKEN = ($credential | Where-Object { $_ -like 'password=*' }) -replace '^password=', ''
    $credential = $null
    if (-not $env:GH_TOKEN) { throw 'No GitHub access: gh is not signed in and Git has no stored github.com credential.' }
}
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
$existing = @((Invoke-Gh @('secret', 'list', '--repo', $Repo, '--json', 'name') | ConvertFrom-Json).name)

$keystoreExists = Test-Path $keystore
if ($keystoreExists) {
    Write-Host "Keystore $keystore already exists: it is kept. Enter its password to finish the GitHub setup."
    $first = Read-Host 'Keystore password' -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($first))
} else {
    $first = Read-Host 'New keystore password (at least 12 characters)' -AsSecureString
    $second = Read-Host 'Repeat the password' -AsSecureString
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($first))
    $repeat = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($second))
    if ($plain -cne $repeat) { throw 'The passwords do not match. Nothing was created.' }
    if ($plain.Length -lt 12) { throw 'Use at least 12 characters. Nothing was created.' }
    $repeat = $null
}

New-Item -ItemType Directory -Force $Dir | Out-Null
$env:HISBAH_KS_PASS = $plain
try {
    if (-not $keystoreExists) {
        # PKCS12: the key password equals the store password.
        & $Keytool -genkeypair -keystore $keystore -storetype PKCS12 -alias $alias -keyalg RSA -keysize 2048 `
            -validity 10000 -dname 'CN=Hisbah Smart Shop, O=Hisbah' -storepass:env HISBAH_KS_PASS -keypass:env HISBAH_KS_PASS
        if ($LASTEXITCODE -ne 0) { throw 'keytool failed.' }
        Write-Host "Keystore created: $keystore"
    }
    $listing = & $Keytool -list -v -keystore $keystore -alias $alias -storepass:env HISBAH_KS_PASS 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'The password does not open the keystore. Nothing was uploaded.' }
    Write-Host "Certificate $((($listing | Select-String 'SHA256:') | Select-Object -First 1).Line.Trim())"

    # Values go to gh on stdin, never in arguments or history. Existing secrets are not overwritten.
    $values = [ordered]@{
        ANDROID_KEYSTORE_BASE64     = [Convert]::ToBase64String([IO.File]::ReadAllBytes($keystore))
        ANDROID_KEYSTORE_PASSWORD   = $plain
        ANDROID_KEY_PASSWORD        = $plain
        ANDROID_KEY_ALIAS           = $alias
        SHOREBIRD_PATCH_PRIVATE_KEY = (Get-Content -Raw $patchKey)
    }
    foreach ($name in $values.Keys) {
        if ($existing -contains $name) { Write-Host "  $name exists: left untouched"; continue }
        Invoke-Gh @('secret', 'set', $name, '--repo', $Repo) $values[$name] | Out-Null
        Write-Host "  $name set"
    }
    $values = $null
} finally {
    Remove-Item Env:HISBAH_KS_PASS -ErrorAction SilentlyContinue
    $plain = $null
}

Write-Host ''
Write-Host 'Secrets configured (names only):'
Invoke-Gh @('secret', 'list', '--repo', $Repo)
Write-Host ''
Write-Host "Now back up the whole folder $Dir and the password (docs/mobile/ota-updates.md section 2.1)."
