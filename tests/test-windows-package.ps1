<#
.SYNOPSIS
    Windows offline package end-to-end test.

.DESCRIPTION
    Verifies the built claude-offline-packages-windows directory:
      1. Structure: real native PE binary (>100MB), setup scripts present
      2. bin\claude.exe --version prints the expected version
      3. setup-claude-code.ps1 -OfflinePath <pkg> -NonInteractive succeeds
      4. %USERPROFILE%\.claude\settings.json exists afterwards
      5. The package bin directory was added to the user PATH (registry)

.PARAMETER PackageDir
    Path to the extracted claude-offline-packages-windows directory.

.PARAMETER ExpectedVersion
    Version string expected in `claude.exe --version` output.

.EXAMPLE
    powershell -NoProfile -File tests\test-windows-package.ps1 -PackageDir .\claude-offline-packages-windows -ExpectedVersion 2.1.215
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageDir,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedVersion
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Msg) { Write-Host "[FAIL] $Msg" -ForegroundColor Red; exit 1 }
function Ok([string]$Msg)   { Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Info([string]$Msg) { Write-Host "[INFO] $Msg" -ForegroundColor Cyan }

$PackageDir = (Resolve-Path $PackageDir).Path

Write-Host '======================================================================'
Write-Host '  Windows package test'
Write-Host "  Package: $PackageDir"
Write-Host "  Expect:  v$ExpectedVersion"
Write-Host '======================================================================'

# ---------------------------------------------------------------------------
# 1. Structure assertions
# ---------------------------------------------------------------------------
Info 'Checking package structure...'

$exe = Join-Path $PackageDir 'node_modules\@anthropic-ai\claude-code\bin\claude.exe'
if (-not (Test-Path $exe)) { Fail 'bin\claude.exe is missing' }
$size = (Get-Item $exe).Length
if ($size -le 100MB) { Fail "bin\claude.exe is only $size bytes (<= 100MB) - looks like a stub" }
Ok "bin\claude.exe is a real binary ($size bytes)"

$ps1 = Join-Path $PackageDir 'setup-claude-code.ps1'
$bat = Join-Path $PackageDir 'setup-claude-code.bat'
if (-not (Test-Path $ps1)) { Fail 'setup-claude-code.ps1 is missing' }
if (-not (Test-Path $bat)) { Fail 'setup-claude-code.bat is missing' }
Ok 'setup-claude-code.ps1 / setup-claude-code.bat present'

$pkgInfo = Join-Path $PackageDir 'package-info.json'
if (-not (Test-Path $pkgInfo)) { Fail 'package-info.json is missing' }
Ok 'package-info.json present'

# ---------------------------------------------------------------------------
# 2. Direct version check
# ---------------------------------------------------------------------------
Info 'Running bin\claude.exe --version ...'
$out = & $exe --version 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { Fail "claude.exe --version exited $LASTEXITCODE`: $out" }
Write-Host "    output: $($out.Trim())"
if ($out -notmatch [regex]::Escape($ExpectedVersion)) {
    Fail "version output does not contain expected version $ExpectedVersion"
}
Ok 'version check passed'

# ---------------------------------------------------------------------------
# 3. Non-interactive install
# ---------------------------------------------------------------------------
Info 'Running setup-claude-code.ps1 -OfflinePath <pkg> -NonInteractive ...'
& $ps1 -OfflinePath $PackageDir -NonInteractive
if ($LASTEXITCODE -ne 0) { Fail "setup-claude-code.ps1 exited $LASTEXITCODE" }
Ok 'installer completed (exit 0)'

# ---------------------------------------------------------------------------
# 4. settings.json exists
# ---------------------------------------------------------------------------
$settings = Join-Path $env:USERPROFILE '.claude\settings.json'
if (-not (Test-Path $settings)) { Fail "settings.json not found at $settings" }
Ok "settings.json exists: $settings"

# ---------------------------------------------------------------------------
# 5. User PATH written to registry
# ---------------------------------------------------------------------------
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
$rawPath = ''
if ($null -ne $key) {
    $rawPath = [string]$key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    $key.Close()
}
$binDir = Join-Path $PackageDir 'node_modules\@anthropic-ai\claude-code\bin'
$normalizedTarget = $binDir.TrimEnd('\').ToLowerInvariant()
$hit = @($rawPath -split ';' | Where-Object { $_.TrimEnd('\').ToLowerInvariant() -eq $normalizedTarget })
if ($hit.Count -eq 0) { Fail "user PATH (registry) does not contain: $binDir" }
Ok 'user PATH (registry) contains the package bin directory'

Write-Host ''
Write-Host 'ALL WINDOWS PACKAGE TESTS PASSED'
exit 0
