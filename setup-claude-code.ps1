<#
.SYNOPSIS
    Claude Code offline installer for Windows.

.DESCRIPTION
    Sets up Claude Code from the claude-offline-packages-windows package
    (standalone native binary - Node.js is NOT required).

    Mirrors the behavior of setup-claude-code.sh on Linux/macOS:
    detects existing installations, validates the native binary, creates the
    ~/.claude directory structure, writes settings.json / config.json /
    .claude.json (backing up existing files), and manages the user PATH.

.PARAMETER OfflinePath
    Path to the extracted claude-offline-packages-windows directory.

.PARAMETER AutoDownload
    Download the latest Windows package from GitHub Releases first.

.PARAMETER NonInteractive
    Never prompt; automatically take default answers (printed to the console).

.PARAMETER Uninstall
    Remove Claude Code configuration and the PATH entry created by this script.

.PARAMETER ConfigOnly
    Only (re)generate configuration files; skip binary/PATH setup.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File setup-claude-code.ps1 -OfflinePath .\claude-offline-packages-windows -NonInteractive
#>
[CmdletBinding()]
param(
    [string]$OfflinePath,
    [switch]$AutoDownload,
    [switch]$NonInteractive,
    [switch]$Uninstall,
    [switch]$ConfigOnly
)

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
$ErrorActionPreference = 'Stop'
$script:ExitCode = 0

# GitHub Release configuration
$script:GitHubRepo   = 'DeepTrial/claude-code-offline'
$script:GitHubApiUrl = "https://api.github.com/repos/$($script:GitHubRepo)/releases/latest"
$script:AssetName    = 'claude-offline-packages-windows.zip'

# Paths
$script:UserClaudeDir = Join-Path $env:USERPROFILE '.claude'
$script:ClaudeJson    = Join-Path $env:USERPROFILE '.claude.json'

# Force TLS 1.2 for Windows PowerShell 5.1 (GitHub requires it)
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch { }

# ---------------------------------------------------------------------------
# Logging helpers (colored)
# ---------------------------------------------------------------------------
function Write-Info  { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Warn  { param([string]$Msg) Write-Host "  [WARN] $Msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$Msg) Write-Host "  [ERROR] $Msg" -ForegroundColor Red }

# Write UTF-8 WITHOUT BOM (byte-level parity with the bash installer)
function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

# ---------------------------------------------------------------------------
# Confirmation helper: -NonInteractive takes the default and prints it
# ---------------------------------------------------------------------------
function Confirm-Action {
    param(
        [string]$Prompt,
        [string]$Default = 'n'   # 'y' or 'n'
    )
    $hint = if ($Default -eq 'y') { '[Y/n]' } else { '[y/N]' }
    if ($NonInteractive) {
        Write-Host "$Prompt ${hint}: $Default (auto)"
        return ($Default -eq 'y')
    }
    $answer = Read-Host "$Prompt $hint"
    if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $Default }
    return ($answer -match '^(?i)y(es)?$')
}

# ---------------------------------------------------------------------------
# Network helpers
# ---------------------------------------------------------------------------
function Test-Url {
    param(
        [string]$Url,
        [int]$TimeoutSec = 5
    )
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
        return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500)
    } catch {
        return $false
    }
}

function Assert-Network {
    param([string]$What)
    Write-Info "Checking network connectivity (5s timeout)..."
    $npmOk = Test-Url -Url 'https://registry.npmjs.org/' -TimeoutSec 5
    $ghOk  = Test-Url -Url 'https://api.github.com'      -TimeoutSec 5
    if ($npmOk) { Write-Ok 'npm registry reachable' } else { Write-Warn 'npm registry UNREACHABLE' }
    if ($ghOk)  { Write-Ok 'GitHub reachable' }       else { Write-Warn 'GitHub UNREACHABLE' }
    if (-not ($npmOk -or $ghOk)) {
        Write-Err "Cannot ${What}: network is unreachable."
        Write-Host ''
        Write-Host 'Troubleshooting suggestions:'
        Write-Host '  - Check your internet connection / proxy / firewall settings'
        Write-Host '  - Behind a proxy? set HTTPS_PROXY env var or configure system proxy'
        Write-Host '  - Fully offline? use a pre-downloaded package:'
        Write-Host '      .\setup-claude-code.ps1 -OfflinePath <path\to\claude-offline-packages-windows>'
        return $false
    }
    Write-Ok 'Network available'
    return $true
}

# ---------------------------------------------------------------------------
# Existing installation detection
# ---------------------------------------------------------------------------
function Get-ExistingInstallation {
    $found = @()
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) { $found += "  - claude command: $($claudeCmd.Source)" }
    if (Test-Path $script:UserClaudeDir) { $found += "  - Config directory: $($script:UserClaudeDir)" }
    if (Test-Path $script:ClaudeJson)    { $found += "  - Config file: $($script:ClaudeJson)" }
    $npmGlobal = Join-Path $env:APPDATA 'npm\node_modules\@anthropic-ai\claude-code'
    if (Test-Path $npmGlobal) { $found += "  - npm global: $npmGlobal" }
    return $found
}

# ---------------------------------------------------------------------------
# Package location & validation
# ---------------------------------------------------------------------------
function Find-Package {
    $candidates = @()
    if ($OfflinePath) { $candidates += $OfflinePath }
    $candidates += @(
        $PSScriptRoot,
        (Join-Path $PSScriptRoot 'claude-offline-packages-windows'),
        (Join-Path (Split-Path $PSScriptRoot -Parent) 'claude-offline-packages-windows'),
        (Join-Path $env:USERPROFILE 'claude-offline-packages-windows'),
        (Join-Path $script:UserClaudeDir 'offline-packages-windows')
    )
    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
        $exe = Join-Path $candidate 'node_modules\@anthropic-ai\claude-code\bin\claude.exe'
        if (Test-Path $exe) {
            return (Resolve-Path $candidate).Path
        }
    }
    return $null
}

function Test-NativeBinary {
    param([string]$PackageDir)
    $exe = Join-Path $PackageDir 'node_modules\@anthropic-ai\claude-code\bin\claude.exe'
    if (-not (Test-Path $exe)) {
        Write-Err "Native binary not found: $exe"
        return $false
    }
    $size = (Get-Item $exe).Length
    if ($size -lt 100MB) {
        Write-Err "claude.exe is a placeholder stub ($size bytes), not a real Windows binary."
        Write-Host 'This package appears to be built for a different platform.'
        Write-Host 'Please use the Windows package (claude-offline-packages-windows.zip).'
        return $false
    }
    try {
        $versionOutput = & $exe --version 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE" }
        Write-Ok "Native binary verified: $($versionOutput.Trim()) ($([math]::Round($size/1MB)) MB)"
        return $true
    } catch {
        Write-Err "claude.exe exists ($size bytes) but failed to run: $_"
        return $false
    }
}

# ---------------------------------------------------------------------------
# Auto-download from GitHub Releases
# ---------------------------------------------------------------------------
function Get-PackageFromGitHub {
    param([string]$DestinationDir)

    if (-not (Assert-Network 'download the offline package')) { return $null }

    Write-Info "Fetching latest release info from $($script:GitHubApiUrl)..."
    try {
        $release = Invoke-RestMethod -Uri $script:GitHubApiUrl -TimeoutSec 30 -Headers @{ 'User-Agent' = 'claude-offline-setup' }
    } catch {
        Write-Err "Failed to fetch release info: $_"
        return $null
    }

    $asset = $release.assets | Where-Object { $_.name -eq $script:AssetName } | Select-Object -First 1
    if (-not $asset) {
        Write-Err "Asset '$($script:AssetName)' not found in the latest release ($($release.tag_name))."
        return $null
    }

    $zipPath = Join-Path $env:TEMP $script:AssetName
    Write-Info "Downloading $($asset.browser_download_url) ..."
    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -TimeoutSec 600 -UseBasicParsing
    } catch {
        Write-Err "Download failed: $_"
        return $null
    }
    Write-Ok "Downloaded: $zipPath"

    Write-Info "Extracting to $DestinationDir ..."
    if (Test-Path $DestinationDir) { Remove-Item $DestinationDir -Recurse -Force }
    New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    try {
        Expand-Archive -Path $zipPath -DestinationPath $DestinationDir -Force
    } catch {
        Write-Err "Extraction failed: $_"
        return $null
    }
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    # The zip contains a top-level claude-offline-packages-windows directory
    $nested = Join-Path $DestinationDir 'claude-offline-packages-windows'
    if (Test-Path (Join-Path $nested 'node_modules\@anthropic-ai\claude-code\bin\claude.exe')) {
        return $nested
    }
    return $DestinationDir
}

# ---------------------------------------------------------------------------
# Directory structure
# ---------------------------------------------------------------------------
function New-ClaudeDirectories {
    foreach ($sub in @('', 'tmp', 'backups', 'plugins')) {
        $dir = if ($sub) { Join-Path $script:UserClaudeDir $sub } else { $script:UserClaudeDir }
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }
    Write-Ok "Directories created: $($script:UserClaudeDir)\{tmp,backups,plugins}"
}

# ---------------------------------------------------------------------------
# Configuration file generators (identical content to the bash installer)
# ---------------------------------------------------------------------------
function Backup-IfExists {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backupName = "$(Split-Path $FilePath -Leaf).backup.$stamp"
        $backupPath = Join-Path (Join-Path $script:UserClaudeDir 'backups') $backupName
        Copy-Item $FilePath $backupPath -Force
        Write-Warn "$(Split-Path $FilePath -Leaf) already exists. Backed up to backups\$backupName"
        return $true
    }
    return $false
}

function Write-SettingsJson {
    $file = Join-Path $script:UserClaudeDir 'settings.json'
    if (Backup-IfExists $file) { return }
    $content = @'
{
  "env": {
    "ANTHROPIC_BASE_URL": "YOUR_BASE_URL_HERE",
    "ANTHROPIC_API_KEY": "YOUR_API_KEY_HERE",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "YOUR_MODEL_HERE",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "YOUR_MODEL_HERE",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "YOUR_MODEL_HERE",
    "DISABLE_AUTOUPDATER": "1",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_SKIP_FIRST_RUN": "1",
    "CLAUDE_CODE_TELEMETRY": "0",
    "DISABLE_TELEMETRY": "1",
    "CLAUDE_CODE_WEB_FETCH_SKIP_SAFETY_CHECK": "1"
  },
  "autoUpdate": { "enabled": false },
  "hasCompletedOnboarding": true,
  "skipOnboarding": true,
  "telemetry": { "enabled": false }
}
'@
    Write-Utf8File -Path $file -Content $content
    Write-Ok 'Created settings.json with placeholder values'
}

function Write-ConfigJson {
    $file = Join-Path $script:UserClaudeDir 'config.json'
    if (Test-Path $file) {
        Write-Ok 'config.json already exists'
        return
    }
    Write-Utf8File -Path $file -Content '{ "primaryApiKey": "mimo" }'
    Write-Ok 'Created config.json'
}

function Write-ClaudeJson {
    $file = $script:ClaudeJson
    $firstStart = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z")
    if (Test-Path $file) {
        Backup-IfExists $file
        try {
            $data = Get-Content $file -Raw | ConvertFrom-Json
            $data | Add-Member -NotePropertyName 'hasCompletedOnboarding' -NotePropertyValue $true -Force
            $jsonOut = $data | ConvertTo-Json -Depth 32
            Write-Utf8File -Path $file -Content $jsonOut
            Write-Ok 'Updated .claude.json (hasCompletedOnboarding=true)'
        } catch {
            Write-Warn "Could not update existing .claude.json: $_"
        }
        return
    }
    $content = @"
{
  "hasCompletedOnboarding": true,
  "firstStartTime": "$firstStart",
  "skipOnboarding": true,
  "onboardingCompleted": true,
  "hasSeenInitialMessage": true,
  "hasAcceptedTerms": true,
  "telemetry": {
    "enabled": false,
    "consentGiven": false
  },
  "regionCheck": {
    "bypassed": true,
    "checkedAt": "$firstStart"
  }
}
"@
    Write-Utf8File -Path $file -Content $content
    Write-Ok 'Created .claude.json'
}

# ---------------------------------------------------------------------------
# User PATH management (registry, idempotent)
# NOTE: reads/writes the RAW (unexpanded) registry value so existing
# %VARIABLE%-style entries are preserved verbatim.
# ---------------------------------------------------------------------------
function Get-RawUserPath {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
    if ($null -eq $key) { return '' }
    $value = $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    $key.Close()
    if ($null -eq $value) { return '' }
    return [string]$value
}

function Set-RawUserPath {
    param([string]$NewPath)
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    if ($null -eq $key) {
        $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    }
    $key.SetValue('Path', $NewPath, 'ExpandString')
    $key.Close()
}

function Add-UserPath {
    param([string]$BinDir)
    $userPath = Get-RawUserPath
    $entries = @($userPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $normalizedTarget = $BinDir.TrimEnd('\').ToLowerInvariant()
    $exists = $entries | Where-Object { $_.TrimEnd('\').ToLowerInvariant() -eq $normalizedTarget }
    if ($exists) {
        Write-Ok "PATH already contains: $BinDir"
    } else {
        $newPath = (@($entries) + $BinDir) -join ';'
        Set-RawUserPath -NewPath $newPath
        Write-Ok "Added to user PATH: $BinDir"
    }
    # Make it available in the current session too
    if (($env:Path -split ';') -notcontains $BinDir) {
        $env:Path = "$BinDir;$env:Path"
    }
}

function Remove-UserPath {
    param([string]$BinDir)
    $userPath = Get-RawUserPath
    if ([string]::IsNullOrWhiteSpace($userPath)) { return }
    $normalizedTarget = $BinDir.TrimEnd('\').ToLowerInvariant()
    $entries = @($userPath -split ';' | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and $_.TrimEnd('\').ToLowerInvariant() -ne $normalizedTarget
    })
    $newPath = $entries -join ';'
    if ($newPath -ne $userPath) {
        Set-RawUserPath -NewPath $newPath
        Write-Ok "Removed from user PATH: $BinDir"
    }
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
function Invoke-Uninstall {
    Write-Host '============================================================================='
    Write-Host '  Claude Code Uninstaller (Windows)'
    Write-Host '============================================================================='
    Write-Host ''

    $existing = Get-ExistingInstallation
    if ($existing.Count -eq 0) {
        Write-Warn 'No existing Claude Code installation detected.'
        return
    }
    Write-Host 'Detected existing installation at:'
    $existing | ForEach-Object { Write-Host $_ }
    Write-Host ''

    # The explicit -Uninstall switch is the confirmation; in interactive mode
    # ask once more (default: No).
    if (-not $NonInteractive) {
        if (-not (Confirm-Action 'Are you sure you want to uninstall Claude Code?' 'n')) {
            Write-Info 'Uninstall cancelled.'
            return
        }
    } else {
        Write-Host 'Are you sure you want to uninstall Claude Code? [y/N]: y (auto, -NonInteractive)'
    }

    # Backup configuration first
    if ((Test-Path $script:UserClaudeDir) -or (Test-Path $script:ClaudeJson)) {
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $backupDir = Join-Path $env:USERPROFILE ".claude-backup-$stamp"
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        if (Test-Path $script:UserClaudeDir) { Copy-Item $script:UserClaudeDir (Join-Path $backupDir '.claude') -Recurse -Force }
        if (Test-Path $script:ClaudeJson)    { Copy-Item $script:ClaudeJson (Join-Path $backupDir '.claude.json') -Force }
        Write-Ok "Configuration backed up to: $backupDir"
    }

    # Remove PATH entries pointing into any offline package
    $userPath = Get-RawUserPath
    if (-not [string]::IsNullOrWhiteSpace($userPath)) {
        $kept = @($userPath -split ';' | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '@anthropic-ai[\\/]claude-code[\\/]bin'
        })
        if (($kept -join ';') -ne $userPath) {
            Set-RawUserPath -NewPath ($kept -join ';')
            Write-Ok 'Removed Claude Code entries from user PATH'
        }
    }

    # Remove configuration
    if (Test-Path $script:ClaudeJson)    { Remove-Item $script:ClaudeJson -Force; Write-Ok 'Removed .claude.json' }
    if (Test-Path $script:UserClaudeDir) { Remove-Item $script:UserClaudeDir -Recurse -Force; Write-Ok 'Removed .claude directory' }

    Write-Host ''
    Write-Host '============================================================================='
    Write-Host '  Uninstallation Complete'
    Write-Host '============================================================================='
    Write-Host ''
    Write-Host 'Open a NEW terminal for the PATH change to take effect.'
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
function Invoke-Install {
    Write-Host '============================================================================='
    Write-Host '  Claude Code Deployment Script v2.3 (Windows) - Native Binary / No Node.js'
    Write-Host '============================================================================='
    Write-Host ''

    # ---- Existing installation ------------------------------------------
    $existing = Get-ExistingInstallation
    if ($existing.Count -gt 0) {
        Write-Warn 'Detected existing Claude Code installation:'
        $existing | ForEach-Object { Write-Host $_ }
        Write-Host ''
        if (-not (Confirm-Action 'Continue and update the existing installation?' 'y')) {
            Write-Info 'Exiting. No changes made.'
            return
        }
        Write-Host ''
    }

    # ---- Step 1: locate / download the package ---------------------------
    Write-Host 'Step 1/5: Locating Claude Code package...'
    $packageDir = $null
    if ($AutoDownload) {
        $dest = Join-Path $script:UserClaudeDir 'offline-packages-windows'
        $packageDir = Get-PackageFromGitHub -DestinationDir $dest
        if (-not $packageDir) {
            throw 'Failed to download the offline package.'
        }
    } else {
        $packageDir = Find-Package
        if (-not $packageDir) {
            Write-Err 'Could not find a valid claude-offline-packages-windows package.'
            Write-Host ''
            Write-Host 'Searched: -OfflinePath argument, script directory, and user profile.'
            Write-Host 'Run one of:'
            Write-Host '  .\setup-claude-code.ps1 -OfflinePath <path\to\claude-offline-packages-windows>'
            Write-Host '  .\setup-claude-code.ps1 -AutoDownload'
            throw 'Package not found.'
        }
    }
    Write-Ok "Using package: $packageDir"

    # ---- Step 2: validate the native binary ------------------------------
    Write-Host 'Step 2/5: Verifying native binary (Node.js not required)...'
    if (-not (Test-NativeBinary -PackageDir $packageDir)) {
        throw 'Native binary validation failed.'
    }

    # ---- Step 3: directory structure -------------------------------------
    Write-Host 'Step 3/5: Creating .claude directory structure...'
    New-ClaudeDirectories

    # ---- Step 4: configuration files --------------------------------------
    Write-Host 'Step 4/5: Generating configuration files...'
    Write-SettingsJson
    Write-ConfigJson
    Write-ClaudeJson

    # ---- Step 5: PATH ------------------------------------------------------
    Write-Host 'Step 5/5: Updating user PATH...'
    $binDir = Join-Path $packageDir 'node_modules\@anthropic-ai\claude-code\bin'
    Add-UserPath -BinDir $binDir

    # ---- Summary -----------------------------------------------------------
    Write-Host ''
    Write-Host '============================================================================='
    Write-Host '  SETUP SUMMARY'
    Write-Host '============================================================================='
    Write-Host ''
    Write-Host '  Configured:'
    Write-Host '    - Native Claude Code binary (standalone, Node.js NOT required)'
    Write-Host "    - Offline package at: $packageDir"
    Write-Host '    - .claude directory structure (tmp, backups, plugins)'
    Write-Host '    - .claude\settings.json (with placeholder values)'
    Write-Host '    - .claude\config.json'
    Write-Host '    - .claude.json (onboarding complete)'
    Write-Host '    - User PATH (registry)'
    Write-Host ''
    Write-Host '============================================================================='
    Write-Host '  !!! ACTION REQUIRED !!!'
    Write-Host '============================================================================='
    Write-Host ''
    Write-Host '  You MUST edit settings.json to add your own credentials:'
    Write-Host ''
    Write-Host "    notepad $($script:UserClaudeDir)\settings.json"
    Write-Host ''
    Write-Host '  Replace these placeholder values with your actual API key and base URL:'
    Write-Host ''
    Write-Host '    "ANTHROPIC_BASE_URL": "YOUR_BASE_URL_HERE"   -> your actual base URL'
    Write-Host '    "ANTHROPIC_API_KEY": "YOUR_API_KEY_HERE"     -> your actual API key'
    Write-Host ''
    Write-Host '============================================================================='
    Write-Host '  NEXT STEPS'
    Write-Host '============================================================================='
    Write-Host ''
    Write-Host '  1. Edit .claude\settings.json with your API key and base URL'
    Write-Host '  2. Open a NEW terminal (so the updated PATH is loaded)'
    Write-Host '  3. Verify: claude --version'
    Write-Host ''
    Write-Host '============================================================================='
}

# ---------------------------------------------------------------------------
# Config-only mode
# ---------------------------------------------------------------------------
function Invoke-ConfigOnly {
    Write-Host '============================================================================='
    Write-Host '  Configuration Only Mode'
    Write-Host '============================================================================='
    Write-Host ''
    New-ClaudeDirectories
    Write-SettingsJson
    Write-ConfigJson
    Write-ClaudeJson
    Write-Host ''
    Write-Host '  Generated files:'
    Write-Host '    - .claude\settings.json'
    Write-Host '    - .claude\config.json'
    Write-Host '    - .claude.json'
    Write-Host ''
    Write-Host "  IMPORTANT: Edit $($script:UserClaudeDir)\settings.json with your API credentials."
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
try {
    if ($Uninstall) {
        Invoke-Uninstall
    } elseif ($ConfigOnly) {
        Invoke-ConfigOnly
    } else {
        Invoke-Install
    }
    exit 0
} catch {
    Write-Host ''
    Write-Err "Setup failed: $($_.Exception.Message)"
    exit 1
}
