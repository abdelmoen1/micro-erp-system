# Dot-source: . "$PSScriptRoot\send_stdin.ps1"
# Windows PowerShell 5.1 prefixes text piped to a native program with a UTF-8 BOM and appends CRLF,
# which corrupts secrets (`$value | gh secret set NAME`). Send-Stdin writes the exact UTF-8 bytes
# instead and returns the program's exit code. Nothing is printed.
function Send-Stdin {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo $FilePath
    $psi.Arguments = ($ArgumentList | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # .NET Framework creates the child's stdin writer with Console.InputEncoding and writes its
    # preamble immediately, so a BOM-free encoding must be in place while the process starts.
    $previousEncoding = [Console]::InputEncoding
    try {
        [Console]::InputEncoding = New-Object System.Text.UTF8Encoding $false
        $process = [System.Diagnostics.Process]::Start($psi)
    } finally {
        [Console]::InputEncoding = $previousEncoding
    }
    $bytes = (New-Object System.Text.UTF8Encoding $false).GetBytes($Text)
    # Write and close the raw stream: closing the StreamWriter itself would emit its encoding preamble (BOM).
    $process.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $process.StandardInput.BaseStream.Flush()
    $process.StandardInput.BaseStream.Close()
    $null = $process.StandardOutput.ReadToEnd()
    $null = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return $process.ExitCode
}
