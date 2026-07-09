[CmdletBinding()]
param(
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot 'config.json'
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Config file not found: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if ($config.EnableRAMMap -ne $true) {
    Write-Host 'RAMMap mode is disabled; skipping installation.' -ForegroundColor DarkGray
    exit 0
}

$downloadUrl = 'https://download.sysinternals.com/files/RAMMap.zip'
$destination = Join-Path $PSScriptRoot 'Tools\RAMMap'
$executable = Join-Path $destination 'RAMMap64.exe'
$archive = Join-Path ([IO.Path]::GetTempPath()) 'PoE2-Memory-Guard-RAMMap.zip'

if (Test-Path -LiteralPath $executable -PathType Leaf) {
    exit 0
}

Write-Host 'RAMMap is not installed. Downloading from Microsoft Sysinternals...' -ForegroundColor Cyan
New-Item -ItemType Directory -Path $destination -Force | Out-Null

try {
    & curl.exe --fail --location --silent --show-error $downloadUrl --output $archive
    if ($LASTEXITCODE -ne 0) {
        throw "curl failed with exit code $LASTEXITCODE"
    }

    Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        throw 'RAMMap64.exe was not found in the downloaded archive.'
    }

    $signature = Get-AuthenticodeSignature -LiteralPath $executable
    if ($signature.Status -ne 'Valid' -or
        $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
        Remove-Item -LiteralPath $executable -Force -ErrorAction SilentlyContinue
        throw 'RAMMap did not have a valid Microsoft digital signature.'
    }

    Write-Host 'RAMMap downloaded and verified successfully.' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
}
