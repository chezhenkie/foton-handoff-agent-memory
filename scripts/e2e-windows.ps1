<#
Windows e2e smoke test for foton-handoff. Mirrors scripts/e2e-linux.sh.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\e2e-windows.ps1 [-Bin path\to\foton-handoff.exe]

With no -Bin, these candidates are tried relative to this script's folder:
  ..\foton-handoff.exe
  ..\foton-handoff-win11.exe
  ..\foton-handoff\target\release\foton-handoff.exe
  ..\target\release\foton-handoff.exe
#>
param(
    [string]$Bin = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrEmpty($Bin)) {
    $candidates = @(
        (Join-Path $PSScriptRoot "..\foton-handoff.exe"),
        (Join-Path $PSScriptRoot "..\foton-handoff-win11.exe"),
        (Join-Path $PSScriptRoot "..\foton-handoff\target\release\foton-handoff.exe"),
        (Join-Path $PSScriptRoot "..\target\release\foton-handoff.exe")
    )
    $found = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $found) {
        Write-Error ("no -Bin given and none found. Tried:`n" + ($candidates -join "`n"))
        exit 1
    }
    $Bin = $found
}
$Bin = (Resolve-Path -LiteralPath $Bin).Path

Write-Host "=== binary: $Bin ==="

$sandbox = Join-Path $env:TEMP "opencode"
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
$stamp = "{0}-{1}" -f $PID, (Get-Date -Format "HHmmss")
$root = Join-Path $sandbox ("foton-e2e-" + $stamp)
New-Item -ItemType Directory -Force -Path $root | Out-Null

$runExe = Join-Path $root "foton-handoff.exe"
Copy-Item -LiteralPath $Bin -Destination $runExe -Force

function Fail([string]$msg) {
    Write-Host "FAIL: $msg"
    exit 1
}

Write-Host "=== 1. write writes a handoff ==="
"# Project Alpha" | & $runExe write alpha
if ($LASTEXITCODE -ne 0) { Fail "write alpha exited $LASTEXITCODE" }
$written = @(Get-ChildItem -LiteralPath $root -Filter "*.md")
if ($written.Count -ne 1) { Fail "expected 1 md file in root, got $($written.Count)" }

Write-Host "=== 2. read retrieves it ==="
$out = (& $runExe read alpha)
if ($LASTEXITCODE -ne 0) { Fail "read alpha exited $LASTEXITCODE" }
if (($out -join "`n") -ne "# Project Alpha") { Fail "read returned: $($out -join '|')" }

Write-Host "=== 3. dry-run previews archive ==="
$preview = "# Project Alpha v2" | & $runExe write alpha -n
if ($LASTEXITCODE -ne 0) { Fail "dry-run exited $LASTEXITCODE" }
$joined = @($preview) -join "`n"
if ($joined -notmatch "would archive:") { Fail "dry-run missing 'would archive'" }
if ($joined -notmatch "would write:") { Fail "dry-run missing 'would write'" }
$stillThere = @(Get-ChildItem -LiteralPath (Join-Path $root "handoffarchive") -Filter "*.md" -ErrorAction SilentlyContinue)
if ($stillThere.Count -ne 0) { Fail "dry-run must not move files" }

Write-Host "=== 4. real write archives old and writes new ==="
"# Project Alpha v2" | & $runExe write alpha
if ($LASTEXITCODE -ne 0) { Fail "second write exited $LASTEXITCODE" }
$archive = Join-Path $root "handoffarchive"
$archFiles = @(Get-ChildItem -LiteralPath $archive -Filter "*alpha*.md")
if ($archFiles.Count -lt 1) { Fail "archive holds no alpha file" }
$rootFiles = @(Get-ChildItem -LiteralPath $root -Filter "*alpha*.md")
if ($rootFiles.Count -ne 1) { Fail "expected exactly 1 alpha in root after write" }

Write-Host "=== 5. read returns newest ==="
$out = (& $runExe read alpha)
if (($out -join "`n") -ne "# Project Alpha v2") { Fail "newest read mismatch" }

Write-Host "=== 6. same-minute archive collision gets -2 suffix ==="
"# Another Alpha" | & $runExe write alpha
if ($LASTEXITCODE -ne 0) { Fail "third write exited $LASTEXITCODE" }
$coll = @(Get-ChildItem -LiteralPath $archive -Filter "*alpha-2.md")
if ($coll.Count -ne 1) { Fail "expected exactly one *alpha-2.md in archive" }

Write-Host "=== 7. cross-project isolation ==="
"# Project Beta" | & $runExe write beta
if ($LASTEXITCODE -ne 0) { Fail "beta write exited $LASTEXITCODE" }
$betaOut = (& $runExe read beta)
if (($betaOut -join "`n") -ne "# Project Beta") { Fail "beta read mismatch" }
$alphaArch = @(Get-ChildItem -LiteralPath $archive -Filter "*alpha*.md")
$betaRoot = @(Get-ChildItem -LiteralPath $root -Filter "*beta*.md")
if ($alphaArch.Count -lt 2) { Fail "expected >=2 archived alpha files" }
if ($betaRoot.Count -ne 1) { Fail "expected exactly 1 beta file in root" }

Write-Host "=== 8. unknown subcommand exits 2 ==="
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
& $runExe bogus proj 2>&1 | Out-Null
$code = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($code -ne 2) { Fail "unknown subcommand exited $code, expected 2" }

Write-Host "=== 9. case-insensitive project matching ==="
$out = (& $runExe read ALPHA)
if ($LASTEXITCODE -ne 0) { Fail "read ALPHA exited $LASTEXITCODE" }
if (($out -join "`n") -ne "# Another Alpha") { Fail "ALPHA read mismatch" }

Write-Host "=== 10. read on missing project exits 1 with stderr ==="
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$errFile = Join-Path $sandbox ("foton-stderr-" + $stamp + ".txt")
& $runExe read ghost 1> (Join-Path $root "stdout-ghost.txt") 2> $errFile
$code = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($code -ne 1) { Fail "read ghost exited $code, expected 1" }
if (-not (Test-Path -LiteralPath $errFile) -or (Get-Item -LiteralPath $errFile).Length -eq 0) {
    Fail "expected an error message on stderr"
}

Write-Host "=== 11. missing project argument exits 2 ==="
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
& $runExe 2>&1 | Out-Null
$codeA = $LASTEXITCODE
& $runExe read 2>&1 | Out-Null
$codeB = $LASTEXITCODE
& $runExe write 2>&1 | Out-Null
$codeC = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($codeA -ne 2 -or $codeB -ne 2 -or $codeC -ne 2) { Fail "usage exits were $codeA/$codeB/$codeC, expected 2/2/2" }

Write-Host "=== 12. empty stdin write exits 1 and writes nothing ==="
$emptyFile = Join-Path $root "empty.txt"
[System.IO.File]::WriteAllBytes($emptyFile, @())
$out12 = "$root\err12.txt"
$p12 = Start-Process -FilePath $runExe -ArgumentList @("write", "voidproj") -NoNewWindow -PassThru -Wait -RedirectStandardInput $emptyFile -RedirectStandardError $out12
$code = $p12.ExitCode
if ($code -ne 1) { Fail "empty-stdin write exited $code, expected 1 (stderr: $(Get-Content -LiteralPath $out12 -Raw))" }
$void = @(Get-ChildItem -LiteralPath $root -Filter "*voidproj*")
if ($void.Count -ne 0) { Fail "empty-stdin write must not create files" }

Write-Host "=== 13. empty project name exits 2 and writes nothing ==="
$before = @(Get-ChildItem -LiteralPath $root -Filter "*.md").Count
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
& $runExe write "" 2>&1 | Out-Null
$codeA = $LASTEXITCODE
& $runExe read "" 2>&1 | Out-Null
$codeB = $LASTEXITCODE
& $runExe write "   " 2>&1 | Out-Null
$codeC = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($codeA -ne 2 -or $codeB -ne 2 -or $codeC -ne 2) { Fail "empty-project exits were $codeA/$codeB/$codeC, expected 2/2/2" }
$after = @(Get-ChildItem -LiteralPath $root -Filter "*.md").Count
if ($before -ne $after) { Fail "empty-project writes must not create files" }

Write-Host "=== 14. strict argument parsing ==="
$before14 = @(Get-ChildItem -LiteralPath $root -Filter "*.md").Count
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
& $runExe write -x alpha 2>&1 | Out-Null
$codeA = $LASTEXITCODE
& $runExe write alpha junk 2>&1 | Out-Null
$codeB = $LASTEXITCODE
& $runExe read --verbose alpha 2>&1 | Out-Null
$codeC = $LASTEXITCODE
$ErrorActionPreference = $prevEap
if ($codeA -ne 2 -or $codeB -ne 2 -or $codeC -ne 2) { Fail "strict-arg exits were $codeA/$codeB/$codeC, expected 2/2/2" }
$after14 = @(Get-ChildItem -LiteralPath $root -Filter "*.md").Count
if ($before14 -ne $after14) { Fail "strict-arg negative cases must not create files" }

"# Multi Word Handoff" | & $runExe write "multi word"
if ($LASTEXITCODE -ne 0) { Fail "write multi-word exited $LASTEXITCODE" }
$mwOut = (& $runExe read "multi word")
if ($LASTEXITCODE -ne 0) { Fail "read multi-word exited $LASTEXITCODE" }
if (($mwOut -join "`n") -ne "# Multi Word Handoff") { Fail "multi-word round-trip mismatch" }

Write-Host "=== ALL WINDOWS E2E TESTS PASSED ==="
exit 0