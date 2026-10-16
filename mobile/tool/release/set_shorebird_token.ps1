# Stores a Shorebird Console API key (Account → API Keys) without displaying it:
#   powershell -ExecutionPolicy Bypass -File mobile\tool\release\set_shorebird_token.ps1
# - Hidden prompt; the key must start with sb_api_.
# - Sets the GitHub Actions secret SHOREBIRD_TOKEN over stdin (left untouched if it already exists).
# - Keeps a DPAPI-encrypted copy (this Windows user on this PC only) in hisbah-release\shorebird-api-key.dpapi
#   for local Shorebird commands: $env:SHOREBIRD_TOKEN is filled from it by tool\release\shorebird_env.ps1.
param(
    [string]$Repo = 'abdelmoen1/micro-erp-system',
    [string]$Dir = "$env:USERPROFILE\hisbah-release",
    [string]$Gh = 'C:\Program Files\GitHub CLI\gh.exe'
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\send_stdin.ps1"
$keyFile = Join-Path $Dir 'shorebird-api-key.dpapi'

function Use-GitCredentialForGh {
    $ErrorActionPreference = 'Continue' # native stderr ('not logged in') must not abort
    & $Gh auth status *> $null
    if ($LASTEXITCODE -eq 0) { return }
    $request = [IO.Path]::GetTempFileName()
    [IO.File]::WriteAllText($request, "protocol=https`nhost=github.com`n`n", (New-Object System.Text.ASCIIEncoding))
    $env:GCM_INTERACTIVE = 'never'
    $credential = cmd /c "git credential fill < `"$request`"" 2>$null
    Remove-Item $request
    $env:GH_TOKEN = ($credential | Where-Object { $_ -like 'password=*' }) -replace '^password=', ''
    if (-not $env:GH_TOKEN) { throw 'No GitHub access: gh is not signed in and Git has no stored github.com credential.' }
}

Use-GitCredentialForGh
New-Item -ItemType Directory -Force $Dir | Out-Null

while ($true) {
    $secure = Read-Host 'Paste the Shorebird API key (input stays hidden), then press Enter' -AsSecureString
    $plain = ([Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))).Trim()
    if ($plain.StartsWith('sb_api_') -and $plain.Length -gt 20) { break }
    Write-Host 'That does not look like a Shorebird API key (they start with sb_api_). Try again.' -ForegroundColor Yellow
}

try {
    ConvertTo-SecureString $plain -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -Encoding ascii $keyFile
    Write-Host "Saved (encrypted for this Windows user): $keyFile"

    $existing = $null
    for ($i = 1; $i -le 5 -and $null -eq $existing; $i++) {
        $json = & $Gh secret list --repo $Repo --json name
        if ($LASTEXITCODE -eq 0) { $existing = @(($json | ConvertFrom-Json).name) } else { Start-Sleep -Seconds (3 * $i) }
    }
    if ($null -eq $existing) { throw 'Could not reach GitHub. Run this script again.' }
    if ($existing -contains 'SHOREBIRD_TOKEN') {
        Write-Host 'GitHub secret SHOREBIRD_TOKEN already exists: left untouched.'
    } else {
        for ($i = 1; $i -le 5; $i++) {
            # Exact bytes: a PowerShell pipe would prefix the key with a UTF-8 BOM.
            if ((Send-Stdin -FilePath $Gh -ArgumentList @('secret', 'set', 'SHOREBIRD_TOKEN', '--repo', $Repo) -Text $plain) -eq 0) { break }
            if ($i -eq 5) { throw 'Could not set SHOREBIRD_TOKEN (network). Run this script again.' }
            Start-Sleep -Seconds (3 * $i)
        }
        Write-Host 'GitHub secret SHOREBIRD_TOKEN set.'
    }
} finally {
    $plain = $null
}
Write-Host ''
Write-Host 'Done. You can close this window.' -ForegroundColor Green
