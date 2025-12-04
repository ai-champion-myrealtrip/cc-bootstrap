#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Code Bootstrap Agent - Windows Test Suite

.DESCRIPTION
    Tests the installation process on Windows.
    Run with: .\test-win.ps1

.EXAMPLE
    .\test-win.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# =============================================================================
# Test Configuration
# =============================================================================
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:TestsRun = 0
$script:TestsPassed = 0
$script:TestsFailed = 0

# =============================================================================
# Output Functions
# =============================================================================
function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Blue
    Write-Host $Title -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor Blue
}

function Write-TestResult {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Message = ""
    )

    $script:TestsRun++

    if ($Passed) {
        $script:TestsPassed++
        Write-Host "  [PASS] " -ForegroundColor Green -NoNewline
        Write-Host $Name
    } else {
        $script:TestsFailed++
        Write-Host "  [FAIL] " -ForegroundColor Red -NoNewline
        Write-Host $Name
        if ($Message) {
            Write-Host "         $Message" -ForegroundColor Yellow
        }
    }
}

# =============================================================================
# Test Utilities
# =============================================================================
function Test-CommandExists {
    param([string]$Command)
    try {
        $null = Get-Command $Command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-FileExists {
    param([string]$Path)
    return Test-Path $Path -PathType Leaf
}

function Test-ScriptSyntax {
    param([string]$Path)
    try {
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $Path,
            [ref]$null,
            [ref]$null
        )
        return $true
    } catch {
        return $false
    }
}

# =============================================================================
# Test Suites
# =============================================================================

function Test-ScriptFiles {
    Write-TestHeader "Testing Script Files"

    # Test setup-win.ps1 exists
    $setupPath = Join-Path $script:ProjectRoot "scripts\setup-win.ps1"
    Write-TestResult "setup-win.ps1 exists" (Test-FileExists $setupPath)

    # Test setup-win.ps1 syntax
    if (Test-FileExists $setupPath) {
        Write-TestResult "setup-win.ps1 syntax is valid" (Test-ScriptSyntax $setupPath)
    }

    # Test test script exists
    $testPath = Join-Path $script:ProjectRoot "tests\test-win.ps1"
    Write-TestResult "test-win.ps1 exists" (Test-FileExists $testPath)
}

function Test-SystemRequirements {
    Write-TestHeader "Testing System Requirements"

    # Test Windows version
    $osVersion = [Environment]::OSVersion.Version
    Write-TestResult "Windows 10 or later" ($osVersion.Major -ge 10)

    # Test PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-TestResult "PowerShell 5.1 or later" ($psVersion.Major -ge 5)

    # Test 64-bit OS
    $is64Bit = [Environment]::Is64BitOperatingSystem
    Write-TestResult "64-bit operating system" $is64Bit
}

function Test-PackageManagers {
    Write-TestHeader "Testing Package Managers"

    # Test winget
    $wingetInstalled = Test-CommandExists "winget"
    Write-TestResult "winget available" $wingetInstalled

    if ($wingetInstalled) {
        try {
            $wingetVersion = (winget --version 2>$null)
            Write-TestResult "winget version accessible" ($null -ne $wingetVersion)
        } catch {
            Write-TestResult "winget version accessible" $false
        }
    }

    # Test chocolatey (optional)
    $chocoInstalled = Test-CommandExists "choco"
    if ($chocoInstalled) {
        Write-TestResult "chocolatey available (optional)" $true
    } else {
        Write-Host "  [INFO] chocolatey not installed (optional)" -ForegroundColor Cyan
    }
}

function Test-Dependencies {
    Write-TestHeader "Testing Dependencies"

    # Test Node.js
    $nodeInstalled = Test-CommandExists "node"
    Write-TestResult "Node.js installed" $nodeInstalled

    if ($nodeInstalled) {
        try {
            $nodeVersion = (node -v 2>$null) -replace 'v', '' -split '\.' | Select-Object -First 1
            $nodeOk = [int]$nodeVersion -ge 18
            Write-TestResult "Node.js version >= 18" $nodeOk
        } catch {
            Write-TestResult "Node.js version >= 18" $false "Could not determine version"
        }
    }

    # Test npm
    $npmInstalled = Test-CommandExists "npm"
    Write-TestResult "npm installed" $npmInstalled

    if ($npmInstalled) {
        try {
            $npmVersion = npm -v 2>$null
            Write-TestResult "npm version accessible" ($null -ne $npmVersion)
        } catch {
            Write-TestResult "npm version accessible" $false
        }
    }

    # Test Claude Code
    $claudeInstalled = Test-CommandExists "claude"
    Write-TestResult "Claude Code installed" $claudeInstalled

    if ($claudeInstalled) {
        try {
            $claudeVersion = claude --version 2>$null
            Write-TestResult "Claude Code version accessible" ($null -ne $claudeVersion)
        } catch {
            Write-TestResult "Claude Code version accessible" $false
        }
    }
}

function Test-SetupScript {
    Write-TestHeader "Testing Setup Script Functions"

    $setupPath = Join-Path $script:ProjectRoot "scripts\setup-win.ps1"

    if (-not (Test-FileExists $setupPath)) {
        Write-Host "  [SKIP] setup-win.ps1 not found" -ForegroundColor Yellow
        return
    }

    # Parse the script content
    $scriptContent = Get-Content $setupPath -Raw

    # Check for required functions
    $requiredFunctions = @(
        "Show-Banner",
        "Test-Administrator",
        "Install-Winget",
        "Install-NodeJS",
        "Install-ClaudeCode",
        "Show-InstallationSummary"
    )

    foreach ($func in $requiredFunctions) {
        $hasFunction = $scriptContent -match "function\s+$func"
        Write-TestResult "Function $func defined" $hasFunction
    }
}

function Test-NetworkConnectivity {
    Write-TestHeader "Testing Network Connectivity"

    # Test internet connectivity
    try {
        $response = Invoke-WebRequest -Uri "https://www.google.com" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-TestResult "Internet connectivity" ($response.StatusCode -eq 200)
    } catch {
        Write-TestResult "Internet connectivity" $false "Could not reach google.com"
    }

    # Test npm registry
    try {
        $response = Invoke-WebRequest -Uri "https://registry.npmjs.org" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-TestResult "npm registry reachable" ($response.StatusCode -eq 200)
    } catch {
        Write-TestResult "npm registry reachable" $false "Could not reach registry.npmjs.org"
    }
}

# =============================================================================
# Test Summary
# =============================================================================
function Show-TestSummary {
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Blue
    Write-Host "Test Summary" -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor Blue
    Write-Host ""
    Write-Host "  Tests Run:    $script:TestsRun"
    Write-Host "  Tests Passed: " -NoNewline
    Write-Host $script:TestsPassed -ForegroundColor Green
    Write-Host "  Tests Failed: " -NoNewline
    Write-Host $script:TestsFailed -ForegroundColor Red
    Write-Host ""

    if ($script:TestsFailed -eq 0) {
        Write-Host "All tests passed!" -ForegroundColor Green
        return 0
    } else {
        Write-Host "Some tests failed." -ForegroundColor Red
        return 1
    }
}

# =============================================================================
# Main
# =============================================================================
function Main {
    Write-Host ""
    Write-Host ("+=" + ("=" * 56) + "=+") -ForegroundColor Blue
    Write-Host "|     Claude Code Bootstrap - Windows Test Suite        |" -ForegroundColor Blue
    Write-Host ("+=" + ("=" * 56) + "=+") -ForegroundColor Blue

    # Run test suites
    Test-ScriptFiles
    Test-SystemRequirements
    Test-PackageManagers
    Test-Dependencies
    Test-SetupScript
    Test-NetworkConnectivity

    # Show summary
    $exitCode = Show-TestSummary
    exit $exitCode
}

# Run main
Main
