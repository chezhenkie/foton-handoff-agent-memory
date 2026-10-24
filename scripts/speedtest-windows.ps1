<#
Windows speedtest for foton-handoff. Mirrors scripts/speedtest-linux.sh.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\speedtest-windows.ps1 [-Bin path\to\foton-handoff.exe]
#>
param(
    [string]$Bin = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrEmpty($Bin)) {
    $candidates = @(
        (Join-Path $PSScriptRoot "..\release\foton-handoff.exe"),
        (Join-Path $PSScriptRoot "..\foton-handoff-src\target\x86_64-pc-windows-gnu\release\foton-handoff.exe"),
        (Join-Path $PSScriptRoot "..\target\x86_64-pc-windows-gnu\release\foton-handoff.exe")
    )
    $found = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $found) {
        Write-Error ("no -Bin given and none found. Tried:`n" + ($candidates -join "`n"))
        exit 1
    }
    $Bin = $found
}
$Bin = (Resolve-Path -LiteralPath $Bin).Path

Write-Host "=== Windows speedtest: $Bin ==="
Write-Host ""

$sandbox = Join-Path $env:TEMP "opencode"
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
$stamp = "{0}-{1}" -f $PID, (Get-Date -Format "HHmmss")
$root = Join-Path $sandbox ("foton-speedtest-" + $stamp)
New-Item -ItemType Directory -Force -Path $root | Out-Null

$runExe = Join-Path $root "foton-handoff.exe"
Copy-Item -LiteralPath $Bin -Destination $runExe -Force

function Setup-Files([int]$count, [string]$prefix) {
    Get-ChildItem -LiteralPath $root -Filter "*.md" -ErrorAction SilentlyContinue | Remove-Item -Force
    $archiveDir = Join-Path $root "handoffarchive"
    if (Test-Path -LiteralPath $archiveDir) { Remove-Item -LiteralPath $archiveDir -Recurse -Force }
    for ($i = 1; $i -le $count; $i++) {
        $fname = "2026-01-01_0000_{0}_{1:D4}.md" -f $prefix, $i
        "# File $i" | Out-File -LiteralPath (Join-Path $root $fname) -Encoding utf8 -Force
    }
}

function Run-Scenario([string]$name, [int]$iters, [scriptblock]$cmd) {
    for ($w = 0; $w -lt 3; $w++) {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        & $cmd 2>&1 | Out-Null
        $ErrorActionPreference = $prevEap
    }
    
    $times = @()
    for ($i = 0; $i -lt $iters; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        & $cmd 2>&1 | Out-Null
        $ErrorActionPreference = $prevEap
        $sw.Stop()
        $times += $sw.Elapsed.TotalMilliseconds
    }
    
    $sorted = $times | Sort-Object
    $min = [math]::Round($sorted[0], 2)
    $max = [math]::Round($sorted[$iters - 1], 2)
    $sum = ($times | Measure-Object -Sum).Sum
    $mean = [math]::Round($sum / $iters, 2)
    $median = [math]::Round($sorted[[int]($iters / 2)], 2)
    $p95 = [math]::Round($sorted[[int]($iters * 0.95)], 2)
    $ops = [math]::Round(1000 * $iters / $sum, 0)
    
    "| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |" -f $name, $iters, $min, $median, $mean, $p95, $max, $ops
}

Write-Host "| Scenario | Iters | Min | Median | Mean | P95 | Max | Ops/sec |"
Write-Host "|---|---|---|---|---|---|---|---|"

Run-Scenario "startup only (no args)" 200 { & $runExe 2>&1 }

Setup-Files 10 "test"
Run-Scenario "read, 10 md files" 200 { & $runExe read test_0001 }

Setup-Files 1000 "test"
Run-Scenario "read, 1,000 md files" 200 { & $runExe read test_0500 }

Setup-Files 5000 "test"
Run-Scenario "read, 5,000 md files" 100 { & $runExe read test_2500 }

Setup-Files 10 "test"
Run-Scenario "write, 10 md files" 200 { "update" | & $runExe write test_0001 }

Setup-Files 1000 "test"
Run-Scenario "write, 1,000 md files" 200 { "update" | & $runExe write test_0500 }

Setup-Files 1000 "test"
Run-Scenario "write -n, 1,000 md files" 200 { "update" | & $runExe write test_0500 -n }

Write-Host ""
Write-Host "All timings in milliseconds. Binary location: $root (NTFS)"
Write-Host "Speedtest complete."
exit 0
