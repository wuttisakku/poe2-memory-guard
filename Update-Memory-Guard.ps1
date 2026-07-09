[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$Repo = 'wuttisakku/poe2-memory-guard',
    [string]$VersionPath
)

$ErrorActionPreference = 'Stop'

function Write-Status {
    param([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Gray)
    Write-Host ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $Message) -ForegroundColor $Color
}

function ConvertTo-Version {
    param([string]$Value)

    $clean = ($Value -replace '^[vV]', '').Trim()
    try {
        return [version]$clean
    }
    catch {
        return $null
    }
}

function Copy-UpdatedItem {
    param(
        [string]$SourceRoot,
        [string]$DestinationRoot,
        [string]$RelativePath
    )

    $source = Join-Path $SourceRoot $RelativePath
    if (-not (Test-Path -LiteralPath $source)) { return }

    $destination = Join-Path $DestinationRoot $RelativePath
    $parent = Split-Path -Parent $destination
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (Test-Path -LiteralPath $source -PathType Container) {
        if (Test-Path -LiteralPath $destination) {
            Remove-Item -LiteralPath $destination -Recurse -Force
        }
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    }
    else {
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
}

function Merge-ConfigDefaults {
    param(
        [string]$DownloadedConfigPath,
        [string]$LocalConfigPath
    )

    if (-not (Test-Path -LiteralPath $DownloadedConfigPath -PathType Leaf)) { return }

    if (-not (Test-Path -LiteralPath $LocalConfigPath -PathType Leaf)) {
        Copy-Item -LiteralPath $DownloadedConfigPath -Destination $LocalConfigPath -Force
        return
    }

    $defaults = Get-Content -LiteralPath $DownloadedConfigPath -Raw | ConvertFrom-Json
    $local = Get-Content -LiteralPath $LocalConfigPath -Raw | ConvertFrom-Json
    $changed = $false

    foreach ($property in $defaults.PSObject.Properties) {
        if (-not ($local.PSObject.Properties.Name -contains $property.Name)) {
            $local | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
            $changed = $true
        }
    }

    if ($changed) {
        $local | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $LocalConfigPath -Encoding utf8
    }
}

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot 'config.json'
}
if ([string]::IsNullOrWhiteSpace($VersionPath)) {
    $VersionPath = Join-Path $PSScriptRoot 'VERSION'
}

$enableAutoUpdate = $true
if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    if ($null -ne $config.EnableAutoUpdate) {
        $enableAutoUpdate = $config.EnableAutoUpdate -eq $true
    }
}

if (-not $enableAutoUpdate) {
    Write-Status 'Auto-update disabled in config.json.' DarkGray
    return
}

$localTag = 'v0.0.0'
if (Test-Path -LiteralPath $VersionPath -PathType Leaf) {
    $localTag = (Get-Content -LiteralPath $VersionPath -Raw).Trim()
}

try {
    Write-Status 'Checking for updates...' DarkGray
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{
        'User-Agent' = 'PoE2-Memory-Guard'
        'Accept' = 'application/vnd.github+json'
    }

    $latestTag = [string]$release.tag_name
    $localVersion = ConvertTo-Version $localTag
    $latestVersion = ConvertTo-Version $latestTag
    $isNewer = if ($localVersion -and $latestVersion) {
        $latestVersion -gt $localVersion
    }
    else {
        $latestTag -ne $localTag
    }

    if (-not $isNewer) {
        Write-Status "Already up to date ($localTag)." DarkGray
        return
    }

    $asset = @($release.assets | Where-Object {
        $_.name -like '*.zip' -and $_.browser_download_url
    } | Select-Object -First 1)

    if (-not $asset) {
        Write-Status "Latest release $latestTag has no ZIP asset; skipping update." Yellow
        return
    }

    Write-Status "Updating $localTag -> $latestTag..." Cyan
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("PoE2-Memory-Guard-Update-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $zipPath = Join-Path $tempRoot $asset.name
    $extractPath = Join-Path $tempRoot 'extract'

    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force

    $sourceRoot = $extractPath
    $nestedRoot = Get-ChildItem -LiteralPath $extractPath -Directory | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName 'PoE2MemoryGuard.cmd')
    } | Select-Object -First 1
    if ($nestedRoot) {
        $sourceRoot = $nestedRoot.FullName
    }

    $itemsToUpdate = @(
        'VERSION',
        'README.md',
        'LICENSE',
        '.gitignore',
        'Install-RAMMap.ps1',
        'PoE2-Memory-Guard.ps1',
        'PoE2MemoryGuard.cmd',
        'Update-Memory-Guard.ps1',
        'docs'
    )

    foreach ($item in $itemsToUpdate) {
        Copy-UpdatedItem -SourceRoot $sourceRoot -DestinationRoot $PSScriptRoot -RelativePath $item
    }

    Merge-ConfigDefaults -DownloadedConfigPath (Join-Path $sourceRoot 'config.json') -LocalConfigPath $ConfigPath
    Write-Status "Updated to $latestTag. Existing config.json values were preserved." Green
}
catch {
    Write-Status "Update check failed: $($_.Exception.Message)" Yellow
}
finally {
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
