<#
.SYNOPSIS
    shlama Windows installer - Installs shlama and all dependencies

.DESCRIPTION
    This script installs shlama, Ollama, and downloads the AI model.
    Run in PowerShell as Administrator.

.EXAMPLE
    irm https://raw.githubusercontent.com/xt67/shlama-windows/main/install.ps1 | iex
#>

$ErrorActionPreference = "Stop"

# Colors
function Write-Step {
    param([string]$Message)
    Write-Host "`n$Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[X] $Message" -ForegroundColor Red
}

# Banner
function Show-Banner {
    Write-Host ""
    Write-Host "  +-------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |        shlama installer           |" -ForegroundColor Cyan
    Write-Host "  |   Natural language -> shell commands |" -ForegroundColor Cyan
    Write-Host "  |            Windows Edition          |" -ForegroundColor Cyan
    Write-Host "  +-------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
}

# Check if running as admin (optional but recommended)
function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Install Ollama
function Install-Ollama {
    Write-Step " Checking Ollama..."
    
    if (Get-Command ollama -ErrorAction SilentlyContinue) {
        Write-Success "Ollama already installed"
        return
    }
    
    Write-Host "-> Installing Ollama..." -ForegroundColor Blue
    
    # Download and run Ollama installer
    $installerUrl = "https://ollama.com/download/OllamaSetup.exe"
    $installerPath = "$env:TEMP\OllamaSetup.exe"
    
    try {
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
        Start-Process -FilePath $installerPath -Wait
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Success "Ollama installed"
    }
    catch {
        Write-Error "Failed to install Ollama. Please install manually from https://ollama.com"
        throw
    }
}

# Start Ollama service
function Start-OllamaService {
    Write-Step " Starting Ollama..."
    
    # Check if already running
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
        Write-Success "Ollama is already running"
        return
    }
    catch {
        # Not running, start it
    }
    
    # Start Ollama
    Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 3
    
    # Verify it started
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 10 -ErrorAction Stop
        Write-Success "Ollama started"
    }
    catch {
        Write-Warning "Could not start Ollama automatically"
        Write-Warning "Run 'ollama serve' in another terminal"
    }
}

# Select and pull model
function Install-Model {
    $configFile = "$env:LOCALAPPDATA\shlama\config"
    
    # Check if already configured (not first install)
    if (Test-Path $configFile) {
        $savedModel = (Get-Content $configFile -Raw).Trim()
        Write-Success "Model already configured: $savedModel"
        Write-Host "  To change model later, run: shlama --model" -ForegroundColor Blue
        
        # Check if model is downloaded
        $existingModels = ollama list 2>$null
        if ($existingModels -match [regex]::Escape($savedModel)) {
            Write-Success "Model $savedModel is available"
        }
        else {
            Write-Warning "Model $savedModel not downloaded"
            $download = Read-Host "Download now? (y/N)"
            if ($download -eq "y" -or $download -eq "Y") {
                ollama pull $savedModel
            }
        }
        return
    }
    
    # First time install - show model selection
    Write-Host ""
    Write-Host " Choose an AI model:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) llama3.2     - Fast & light (~2GB) [Recommended]"
    Write-Host "  2) llama3.2:1b  - Fastest, minimal (~1.3GB)"
    Write-Host "  3) llama3       - Balanced (~4.7GB)"
    Write-Host "  4) mistral      - Good quality (~4.1GB)"
    Write-Host "  5) Skip         - I'll download a model later"
    Write-Host ""
    
    $choice = Read-Host "Select model [1-5] (default: 1)"
    
    $model = switch ($choice) {
        "1" { "llama3.2" }
        "2" { "llama3.2:1b" }
        "3" { "llama3" }
        "4" { "mistral" }
        "5" { $null }
        "" { "llama3.2" }
        default { "llama3.2" }
    }
    
    if ($null -eq $model) {
        Write-Warning "Skipping model download"
        Write-Warning "Run 'shlama --model' later to select a model"
        return
    }
    
    # Save model to config
    $configDir = Split-Path $configFile -Parent
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    Set-Content -Path $configFile -Value $model
    
    Write-Step " Pulling model ($model)..."
    
    # Check if model exists
    $existingModels = ollama list 2>$null
    if ($existingModels -match $model) {
        Write-Success "Model $model already downloaded"
        return
    }
    
    Write-Host "-> Downloading $model (this may take a few minutes)..." -ForegroundColor Blue
    ollama pull $model
    Write-Success "Model $model downloaded"
    Write-Success "Model saved. To change later, run: shlama --model"
}

# Install shlama
function Install-Shlama {
    Write-Step " Installing shlama..."
    
    # Create installation directory
    $installDir = "$env:LOCALAPPDATA\shlama"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }
    
    # Download shlama.ps1
    $shlamaUrl = "https://raw.githubusercontent.com/xt67/shlama-windows/main/shlama.ps1"
    $shlamaPath = "$installDir\shlama.ps1"
    
    Invoke-WebRequest -Uri $shlamaUrl -OutFile $shlamaPath -UseBasicParsing
    
    # Create batch wrapper for easy calling
    $batchContent = @"
@echo off
powershell -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\shlama\shlama.ps1" %*
"@
    Set-Content -Path "$installDir\shlama.bat" -Value $batchContent
    
    # Create PowerShell function wrapper
    $psProfile = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $psProfile -Parent
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    # Add function to PowerShell profile if not exists
    $functionDef = @"

# shlama - Natural language to shell commands
function shlama { & "$env:LOCALAPPDATA\shlama\shlama.ps1" @args }
"@
    
    if (Test-Path $psProfile) {
        $profileContent = Get-Content $psProfile -Raw
        if ($profileContent -notmatch "function shlama") {
            Add-Content -Path $psProfile -Value $functionDef
        }
    }
    else {
        Set-Content -Path $psProfile -Value $functionDef
    }
    
    # Add to PATH for CMD
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -notlike "*$installDir*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installDir", "User")
        $env:Path = "$env:Path;$installDir"
    }
    
    Write-Success "shlama installed to $installDir"
}

# Print success message
function Show-Success {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "  ✅ Installation complete!" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Restart your terminal, then try:" -ForegroundColor Cyan
    Write-Host "    shlama `"list all files`""
    Write-Host "    shlama `"show disk space`""
    Write-Host "    shlama `"find large files`""
    Write-Host ""
    Write-Host "  Make sure Ollama is running:" -ForegroundColor Yellow
    Write-Host "    ollama serve"
    Write-Host ""
    Write-Host "  Documentation: https://github.com/xt67/shlama-windows" -ForegroundColor Cyan
    Write-Host ""
}

# Main
function Main {
    Show-Banner
    
    Write-Host "This will install shlama and its dependencies." -ForegroundColor White
    Write-Host ""
    
    Install-Ollama
    Start-OllamaService
    Install-Model
    Install-Shlama
    Show-Success
}

Main
