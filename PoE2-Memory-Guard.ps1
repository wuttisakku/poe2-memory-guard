[CmdletBinding()]
param(
    [string]$ConfigPath,

    [ValidateRange(10, 3600)]
    [int]$CheckEverySeconds = 15,

    [ValidateRange(512, 131072)]
    [int]$TrimWhenWorkingSetMB = 8192,

    [ValidateRange(1, 100)]
    [int]$TrimCooldownMinutes = 2,

    [switch]$TrimImmediately,

    [string]$StandbyToolPath,

    [ValidateRange(0, 100)]
    [int]$PurgeStandbyWhenMemoryUsedPercent = 90,

    [switch]$Once
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot 'config.json'
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Config file not found: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if (-not $PSBoundParameters.ContainsKey('CheckEverySeconds') -and $null -ne $config.CheckEverySeconds) {
    $CheckEverySeconds = [int]$config.CheckEverySeconds
}
if (-not $PSBoundParameters.ContainsKey('TrimWhenWorkingSetMB') -and $null -ne $config.TrimWhenWorkingSetMB) {
    $TrimWhenWorkingSetMB = [int]$config.TrimWhenWorkingSetMB
}
if (-not $PSBoundParameters.ContainsKey('TrimCooldownMinutes') -and $null -ne $config.TrimCooldownMinutes) {
    $TrimCooldownMinutes = [int]$config.TrimCooldownMinutes
}
if (-not $PSBoundParameters.ContainsKey('PurgeStandbyWhenMemoryUsedPercent') -and $null -ne $config.PurgeStandbyWhenMemoryUsedPercent) {
    $PurgeStandbyWhenMemoryUsedPercent = [int]$config.PurgeStandbyWhenMemoryUsedPercent
}

$enableRAMMap = $config.EnableRAMMap -eq $true
if (-not $enableRAMMap) {
    $StandbyToolPath = $null
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class WorkingSetTrimmer
{
    [DllImport("psapi.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool EmptyWorkingSet(IntPtr processHandle);
}
'@

function Write-Status {
    param([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Gray)
    Write-Host ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $Message) -ForegroundColor $Color
}

function Get-PoE2Processes {
    # Covers Steam, standalone, and common renamed Path of Exile clients.
    @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'PathOfExile*'
    })
}

function Get-MemoryUsedPercent {
    $os = Get-CimInstance Win32_OperatingSystem
    [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) /
        $os.TotalVisibleMemorySize) * 100, 1)
}

function Invoke-WorkingSetTrim {
    param([System.Diagnostics.Process]$Process)

    $beforeMB = [math]::Round($Process.WorkingSet64 / 1MB)
    try {
        $ok = [WorkingSetTrimmer]::EmptyWorkingSet($Process.Handle)
        if (-not $ok) {
            $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            throw "EmptyWorkingSet failed (Win32 error $code)"
        }
        Start-Sleep -Milliseconds 500
        $Process.Refresh()
        $afterMB = [math]::Round($Process.WorkingSet64 / 1MB)
        Write-Status "Trimmed $($Process.ProcessName) (PID $($Process.Id)): ${beforeMB} MB -> ${afterMB} MB" Green
        return $true
    }
    catch {
        Write-Status "Could not trim PID $($Process.Id): $($_.Exception.Message)" Red
        return $false
    }
}

function Invoke-StandbyPurge {
    param([string]$ToolPath)

    if ([string]::IsNullOrWhiteSpace($ToolPath)) { return }
    if (-not (Test-Path -LiteralPath $ToolPath -PathType Leaf)) {
        Write-Status "Standby-list tool not found: $ToolPath" Yellow
        return
    }

    $file = [IO.Path]::GetFileName($ToolPath)
    try {
        if ($file -ieq 'EmptyStandbyList.exe') {
            & $ToolPath standbylist | Out-Null
        }
        elseif ($file -ieq 'RAMMap.exe' -or $file -ieq 'RAMMap64.exe') {
            & $ToolPath -Es | Out-Null
        }
        else {
            Write-Status "Unsupported standby tool '$file'. Use EmptyStandbyList.exe, RAMMap.exe, or RAMMap64.exe." Yellow
            return
        }
        Write-Status "Standby list purge requested via $file" Cyan
    }
    catch {
        Write-Status "Standby purge failed: $($_.Exception.Message). Try running as Administrator." Red
    }
}

$lastTrim = @{}
$lastPurge = [datetime]::MinValue
$cooldown = [timespan]::FromMinutes($TrimCooldownMinutes)

Write-Status "PoE 2 Memory Guard started. Press Ctrl+C to stop." Cyan
Write-Status "Trim threshold: $TrimWhenWorkingSetMB MB; check every $CheckEverySeconds seconds; cooldown: $TrimCooldownMinutes minutes."
if ($enableRAMMap -and $StandbyToolPath) {
    Write-Status "Standby purge enabled at $PurgeStandbyWhenMemoryUsedPercent% total memory usage."
}
else {
    Write-Status "RAMMap mode disabled; only the PoE process working set will be trimmed." DarkGray
}

do {
    $now = Get-Date
    $processes = Get-PoE2Processes

    if ($processes.Count -eq 0) {
        Write-Status "PoE client not found; waiting..." DarkGray
    }
    else {
        foreach ($process in $processes) {
            $workingSetMB = [math]::Round($process.WorkingSet64 / 1MB)
            $last = if ($lastTrim.ContainsKey($process.Id)) { $lastTrim[$process.Id] } else { [datetime]::MinValue }
            $due = ($now - $last) -ge $cooldown

            Write-Status "$($process.ProcessName) (PID $($process.Id)): ${workingSetMB} MB working set" DarkGray
            if (($TrimImmediately -or $workingSetMB -ge $TrimWhenWorkingSetMB) -and $due) {
                if (Invoke-WorkingSetTrim -Process $process) {
                    $lastTrim[$process.Id] = $now
                }
            }
        }

        if ($StandbyToolPath -and ($now - $lastPurge) -ge $cooldown) {
            $usedPercent = Get-MemoryUsedPercent
            if ($usedPercent -ge $PurgeStandbyWhenMemoryUsedPercent) {
                Write-Status "System memory usage is $usedPercent%; purging standby list..." Yellow
                Invoke-StandbyPurge -ToolPath $StandbyToolPath
                $lastPurge = $now
            }
        }
    }

    $TrimImmediately = $false
    if (-not $Once) { Start-Sleep -Seconds $CheckEverySeconds }
} while (-not $Once)
