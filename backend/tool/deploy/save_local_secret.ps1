# Stores one API key or token for local deployment commands without displaying it:
#   powershell -ExecutionPolicy Bypass -File backend\tool\deploy\save_local_secret.ps1 -Name render-api-key -Label "Render API key"
# Hidden prompt; saved DPAPI-encrypted (this Windows user on this PC only) as
# %USERPROFILE%\hisbah-release\<Name>.dpapi. Read back with read_local_secret.ps1.
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Label,
    [string]$Dir = "$env:USERPROFILE\hisbah-release",
    [int]$MinLength = 20
)
$ErrorActionPreference = 'Stop'
$file = Join-Path $Dir "$Name.dpapi"
New-Item -ItemType Directory -Force $Dir | Out-Null

while ($true) {
    $secure = Read-Host "Paste the $Label (input stays hidden), then press Enter" -AsSecureString
    $plain = ([Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))).Trim()
    if ($plain.Length -ge $MinLength -and $plain -notmatch '\s') { break }
    Write-Host "That does not look like a complete $Label. Try again." -ForegroundColor Yellow
}
ConvertTo-SecureString $plain -AsPlainText -Force | ConvertFrom-SecureString | Set-Content -Encoding ascii $file
$plain = $null
Write-Host "Saved (encrypted for this Windows user): $file" -ForegroundColor Green
Write-Host 'You can close this window.'
