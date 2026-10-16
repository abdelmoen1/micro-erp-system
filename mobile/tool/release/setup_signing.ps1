# One-time: creates the permanent Hisbah Android release key and stores the signing secrets in
# GitHub Actions. Non-interactive:
#   powershell -ExecutionPolicy Bypass -File mobile\tool\release\setup_signing.ps1
# - The keystore password is random (32 bytes) and never shown. It is kept only in GitHub secrets
#   and in keystore-password.dpapi, encrypted with Windows DPAPI: readable only by this Windows
#   user on this PC (not portable to another account or machine).
# - The folder is restricted to the current user. Nothing is written to the repository.
# - Resumable: an existing keystore is reused (with its stored password), never overwritten;
#   existing GitHub secrets are left untouched. Prints no secret values.
# - If gh is not signed in, it uses the github.com credential Git Credential Manager already stores.
param(
    [string]$Repo = 'abdelmoen1/micro-erp-system',
    [string]$Dir = "$env:USERPROFILE\hisbah-release",
    [string]$Keytool = "$env:USERPROFILE\dev\jdk17\bin\keytool.exe",
    [string]$Gh = 'C:\Program Files\GitHub CLI\gh.exe'
)
$ErrorActionPreference = 'Stop'

$keystore = Join-Path $Dir 'hisbah-upload.jks'
$passwordFile = Join-Path $Dir 'keystore-password.dpapi'
$patchKey = Join-Path $Dir 'shorebird-patch-private.pem'
$alias = 'upload'
. "$PSScriptRoot\send_stdin.ps1"

function Invoke-Gh {
    # Retries: the connection drops requests intermittently. Values go through Send-Stdin:
    # piping text would prefix it with a UTF-8 BOM in Windows PowerShell and corrupt the secret.
    param([string[]]$GhArgs, [string]$InputText)
    for ($i = 1; $i -le 5; $i++) {
        if ($InputText) {
            if ((Send-Stdin -FilePath $Gh -ArgumentList $GhArgs -Text $InputText) -eq 0) { return }
        } else {
            $out = & $Gh @GhArgs
            if ($LASTEXITCODE -eq 0) { return $out }
        }
        Start-Sleep -Seconds (3 * $i)
    }
    throw "gh $($GhArgs[0..1] -join ' ') failed after 5 attempts (network?). Re-run this script: it resumes."
}

function Use-GitCredentialForGh {
    $ErrorActionPreference = 'Continue' # native stderr ('not logged in') must not abort
    & $Gh auth status *> $null
    if ($LASTEXITCODE -eq 0) { return }
    # Request from a file: Windows PowerShell pipes add line endings git's credential parser rejects.
    $request = [IO.Path]::GetTempFileName()
    [IO.File]::WriteAllText($request, "protocol=https`nhost=github.com`n`n", (New-Object System.Text.ASCIIEncoding))
    $env:GCM_INTERACTIVE = 'never'
    $credential = cmd /c "git credential fill < `"$request`"" 2>$null
    Remove-Item $request
    $env:GH_TOKEN = ($credential | Where-Object { $_ -like 'password=*' }) -replace '^password=', ''
    if (-not $env:GH_TOKEN) { throw 'No GitHub access: gh is not signed in and Git has no stored github.com credential.' }
}

function Read-DpapiSecret([string]$Path) {
    $secure = ConvertTo-SecureString (Get-Content -Raw $Path).Trim()
    [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}

if (-not (Test-Path $patchKey)) { throw "$patchKey is missing (patch-signing key)." }
Use-GitCredentialForGh

# Only the current user may read the folder (inherited Users/Administrators entries removed).
New-Item -ItemType Directory -Force $Dir | Out-Null
icacls $Dir /inheritance:r /grant:r "$($env:USERDOMAIN)\$($env:USERNAME):(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Could not restrict access to $Dir." }

if (Test-Path $keystore) {
    if (-not (Test-Path $passwordFile)) { throw "$keystore exists but its password is not stored in $passwordFile. Not touching it." }
    $plain = Read-DpapiSecret $passwordFile
    Write-Host "Reusing the existing keystore $keystore"
} else {
    if (Test-Path $passwordFile) { throw "$passwordFile exists without a keystore. Inspect $Dir before continuing." }
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $plain = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $bytes = $null
    # Store the password before creating the key, so a created key never lacks its password.
    ConvertTo-SecureString $plain -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -Encoding ascii $passwordFile
}

$env:HISBAH_KS_PASS = $plain
try {
    if (-not (Test-Path $keystore)) {
        # PKCS12: the key password equals the store password.
        & $Keytool -genkeypair -keystore $keystore -storetype PKCS12 -alias $alias -keyalg RSA -keysize 2048 `
            -validity 10000 -dname 'CN=Hisbah Smart Shop, O=Hisbah' -storepass:env HISBAH_KS_PASS -keypass:env HISBAH_KS_PASS
        if ($LASTEXITCODE -ne 0) { throw 'keytool failed to create the keystore.' }
        Write-Host "Keystore created: $keystore"
    }
    $listing = & $Keytool -list -v -keystore $keystore -alias $alias -storepass:env HISBAH_KS_PASS
    if ($LASTEXITCODE -ne 0) { throw 'The stored password does not open the keystore. Nothing was uploaded.' }
    Write-Host "Keystore opens with the stored password. Alias: $alias"
    Write-Host "Certificate $((($listing | Select-String 'SHA256:') | Select-Object -First 1).Line.Trim())"

    # Values go to gh on stdin, never in arguments or history. Existing secrets are not overwritten.
    $existing = @((Invoke-Gh @('secret', 'list', '--repo', $Repo, '--json', 'name') | ConvertFrom-Json).name)
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
