#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Code Bootstrap Agent - Windows Setup Script

.DESCRIPTION
    One-shot installation script for Claude Code on Windows.
    Automatically installs all required dependencies:
    - winget (if not present)
    - Node.js (v18+)
    - npm
    - Claude Code CLI

.NOTES
    Usage: irm https://raw.githubusercontent.com/{user}/cc-bootstrap/main/scripts/setup-win.ps1 | iex

.EXAMPLE
    # Run directly in PowerShell
    .\setup-win.ps1

    # Or via web
    irm https://raw.githubusercontent.com/{user}/cc-bootstrap/main/scripts/setup-win.ps1 | iex
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# =============================================================================
# Global Variables
# =============================================================================
$script:MIN_NODE_VERSION = 18
$script:INSTALL_LOG = @()

# =============================================================================
# Color Output Functions
# =============================================================================
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$ForegroundColor = "White",
        [switch]$NoNewline
    )

    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $ForegroundColor -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $ForegroundColor
    }
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "[INFO] " -ForegroundColor Cyan -NoNewline
    Write-ColorOutput $Message
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "[OK] " -ForegroundColor Green -NoNewline
    Write-ColorOutput $Message
}

function Write-Warn {
    param([string]$Message)
    Write-ColorOutput "[!] " -ForegroundColor Yellow -NoNewline
    Write-ColorOutput $Message
}

function Write-Err {
    param([string]$Message)
    Write-ColorOutput "[X] " -ForegroundColor Red -NoNewline
    Write-ColorOutput $Message
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "[STEP] " -ForegroundColor Magenta -NoNewline
    Write-ColorOutput $Message
}

# =============================================================================
# Banner
# =============================================================================
function Show-Banner {
    Write-Host ""
    Write-ColorOutput "+==========================================================+" -ForegroundColor Blue
    Write-ColorOutput "|         Claude Code Bootstrap Agent                      |" -ForegroundColor Blue
    Write-ColorOutput "|         One-shot Setup for Windows                       |" -ForegroundColor Blue
    Write-ColorOutput "+==========================================================+" -ForegroundColor Blue
    Write-Host ""
}

# =============================================================================
# System Information
# =============================================================================
function Get-SystemInfo {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
    $psVersion = $PSVersionTable.PSVersion.ToString()

    return @{
        OSName = $osInfo.Caption
        OSVersion = $osInfo.Version
        Architecture = $arch
        PowerShellVersion = $psVersion
    }
}

function Show-SystemInfo {
    $info = Get-SystemInfo

    Write-ColorOutput "System Information:" -ForegroundColor Magenta
    Write-Host "  - OS:         $($info.OSName)"
    Write-Host "  - Version:    $($info.OSVersion)"
    Write-Host "  - Arch:       $($info.Architecture)"
    Write-Host "  - PowerShell: $($info.PowerShellVersion)"
    Write-Host ""
}

# =============================================================================
# Administrator Check
# =============================================================================
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# =============================================================================
# Dependency Check Functions
# =============================================================================
function Test-WingetInstalled {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-NodeInstalled {
    try {
        $null = Get-Command node -ErrorAction Stop
        $version = (node -v) -replace 'v', '' -split '\.' | Select-Object -First 1
        return [int]$version -ge $script:MIN_NODE_VERSION
    } catch {
        return $false
    }
}

function Test-NpmInstalled {
    try {
        $null = Get-Command npm -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-ClaudeInstalled {
    try {
        $null = Get-Command claude -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Get-NodeVersion {
    try {
        $result = & node -v 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
        return $null
    } catch {
        return $null
    }
}

# =============================================================================
# PATH Refresh
# =============================================================================
function Update-PathEnvironment {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

# =============================================================================
# Installation Functions
# =============================================================================

# Install winget if not present
function Install-Winget {
    Write-Step "Checking winget..."

    if (Test-WingetInstalled) {
        Write-Success "winget already installed"
        return
    }

    Write-Info "winget not found. Installing..."

    # Check if running on Windows 10/11
    $osVersion = [Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-Err "winget requires Windows 10 or later"
        throw "Unsupported Windows version"
    }

    try {
        # Try to install via Microsoft Store App Installer
        $installerUrl = "https://aka.ms/getwinget"
        $installerPath = "$env:TEMP\Microsoft.DesktopAppInstaller.msixbundle"

        Write-Info "Downloading winget installer..."
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

        Write-Info "Installing winget..."
        Add-AppxPackage -Path $installerPath

        # Clean up
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        # Refresh PATH
        Update-PathEnvironment

        if (Test-WingetInstalled) {
            Write-Success "winget installed successfully"
        } else {
            throw "winget installation completed but command not found"
        }
    } catch {
        Write-Warn "Automatic winget installation failed"
        Write-Info "Please install 'App Installer' from Microsoft Store manually"
        Write-Info "URL: https://www.microsoft.com/store/productId/9NBLGGH4NNS1"
        throw "winget installation failed: $_"
    }
}

# Install Node.js
function Install-NodeJS {
    Write-Step "Checking Node.js..."

    if (Test-NodeInstalled) {
        $version = Get-NodeVersion
        Write-Success "Node.js $version already installed (>= v$script:MIN_NODE_VERSION)"
        return
    }

    $existingVersion = Get-NodeVersion
    if ($existingVersion) {
        Write-Warn "Node.js $existingVersion is installed but below v$script:MIN_NODE_VERSION"
        Write-Info "Upgrading Node.js..."
    } else {
        Write-Info "Node.js not found. Installing..."
    }

    # Try winget first
    if (Test-WingetInstalled) {
        try {
            Write-Info "Installing Node.js via winget..."
            winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements --silent

            # Refresh PATH
            Update-PathEnvironment

            if (Test-NodeInstalled) {
                $version = Get-NodeVersion
                Write-Success "Node.js $version installed successfully"
                return
            }
        } catch {
            Write-Warn "winget installation failed, trying alternative method..."
        }
    }

    # Fallback: Direct download
    try {
        Write-Info "Downloading Node.js installer..."

        $arch = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
        $nodeVersion = "20.10.0"  # LTS version
        $installerUrl = "https://nodejs.org/dist/v$nodeVersion/node-v$nodeVersion-$arch.msi"
        $installerPath = "$env:TEMP\node-installer.msi"

        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing

        Write-Info "Running Node.js installer..."
        Start-Process msiexec.exe -ArgumentList "/i", $installerPath, "/quiet", "/norestart" -Wait

        # Clean up
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        # Refresh PATH
        Update-PathEnvironment

        if (Test-NodeInstalled) {
            $version = Get-NodeVersion
            Write-Success "Node.js $version installed successfully"
        } else {
            throw "Node.js installation completed but command not found"
        }
    } catch {
        Write-Err "Node.js installation failed: $_"
        Write-Info "Please install Node.js manually from: https://nodejs.org"
        throw
    }
}

# Verify npm
function Test-Npm {
    Write-Step "Checking npm..."

    if (Test-NpmInstalled) {
        try {
            $version = & npm -v 2>&1
            Write-Success "npm $version available"
        } catch {
            Write-Success "npm available"
        }
    } else {
        Write-Err "npm not found. This should be included with Node.js."
        Write-Info "Try reinstalling Node.js or install npm manually."
        throw "npm not available"
    }
}

# Install Claude Code
function Install-ClaudeCode {
    Write-Step "Checking Claude Code..."

    if (Test-ClaudeInstalled) {
        try {
            $version = & claude --version 2>&1
        } catch {
            $version = "unknown"
        }
        Write-Success "Claude Code already installed ($version)"

        Write-Info "Checking for updates..."
        try {
            & npm update -g @anthropic-ai/claude-code 2>&1 | Out-Null
            Write-Info "Update check complete"
        } catch {
            # Ignore update errors
        }
        return
    }

    Write-Info "Installing Claude Code..."

    try {
        & npm install -g @anthropic-ai/claude-code

        # Refresh PATH
        Update-PathEnvironment

        if (Test-ClaudeInstalled) {
            try {
                $version = & claude --version 2>&1
            } catch {
                $version = "installed"
            }
            Write-Success "Claude Code installed successfully ($version)"
        } else {
            Write-Warn "Claude Code installed but not in PATH"
            Write-Info "You may need to restart your terminal"

            # Show npm global path
            try {
                $npmPrefix = & npm config get prefix 2>&1
                if ($npmPrefix) {
                    Write-Info "npm global bin: $npmPrefix"
                }
            } catch {
                # Ignore
            }
        }
    } catch {
        Write-Err "Claude Code installation failed: $_"
        throw
    }
}

# =============================================================================
# Installation Verification
# =============================================================================
function Show-InstallationSummary {
    Write-Host ""
    Write-ColorOutput "===========================================================" -ForegroundColor Blue
    Write-ColorOutput "              Installation Complete!                       " -ForegroundColor Green
    Write-ColorOutput "===========================================================" -ForegroundColor Blue
    Write-Host ""

    Write-ColorOutput "Installed Components:" -ForegroundColor White

    # Node.js
    if (Test-NodeInstalled) {
        $nodeVer = Get-NodeVersion
        Write-Host "  - Node.js:     " -NoNewline
        Write-ColorOutput $nodeVer -ForegroundColor Green
    } else {
        Write-Host "  - Node.js:     " -NoNewline
        Write-ColorOutput "not installed" -ForegroundColor Red
    }

    # npm
    if (Test-NpmInstalled) {
        try {
            $npmVer = & npm -v 2>&1
        } catch {
            $npmVer = "installed"
        }
        Write-Host "  - npm:         " -NoNewline
        Write-ColorOutput $npmVer -ForegroundColor Green
    } else {
        Write-Host "  - npm:         " -NoNewline
        Write-ColorOutput "not installed" -ForegroundColor Red
    }

    # Claude Code
    if (Test-ClaudeInstalled) {
        try {
            $claudeVer = & claude --version 2>&1
        } catch {
            $claudeVer = "installed"
        }
        if (-not $claudeVer) { $claudeVer = "installed" }
        Write-Host "  - Claude Code: " -NoNewline
        Write-ColorOutput $claudeVer -ForegroundColor Green
    } else {
        Write-Host "  - Claude Code: " -NoNewline
        Write-ColorOutput "installed (restart terminal)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-ColorOutput "-----------------------------------------------------------" -ForegroundColor Yellow
    Write-ColorOutput "Next Steps:" -ForegroundColor Yellow
    Write-ColorOutput "-----------------------------------------------------------" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Open a new PowerShell or Command Prompt window"
    Write-Host ""
    Write-Host "  2. Run Claude Code:"
    Write-ColorOutput "     claude" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. Follow the authentication prompts to log in"
    Write-Host ""
    Write-Host "  4. Start coding with AI assistance!"
    Write-Host ""
    Write-ColorOutput "Useful commands:" -ForegroundColor Cyan
    Write-Host "  claude --help     Show all options"
    Write-Host "  claude --version  Show version info"
    Write-Host ""
}

# =============================================================================
# Error Handler
# =============================================================================
function Handle-Error {
    param([string]$ErrorMessage)

    Write-Host ""
    Write-Err "Installation failed!"
    Write-Err $ErrorMessage
    Write-Host ""
    Write-Info "Troubleshooting steps:"
    Write-Host "  1. Ensure you have internet connectivity"
    Write-Host "  2. Try running PowerShell as Administrator"
    Write-Host "  3. Check if antivirus is blocking the installation"
    Write-Host "  4. Visit https://docs.anthropic.com/claude-code for manual installation"
    Write-Host ""
}

# =============================================================================
# Main Execution
# =============================================================================
function Main {
    try {
        Show-Banner
        Show-SystemInfo

        # Administrator check (warning only)
        if (-not (Test-Administrator)) {
            Write-Warn "Running without administrator privileges"
            Write-Warn "Some installations may require elevation"
            Write-Host ""
        }

        Write-Info "Starting Claude Code setup for Windows..."
        Write-Host ""

        # Run installation steps
        Install-Winget
        Install-NodeJS
        Test-Npm
        Install-ClaudeCode
        Show-InstallationSummary

    } catch {
        Handle-Error $_.Exception.Message
        exit 1
    }
}

# Run main function
Main
