<#
.SYNOPSIS
    shlama - Your terminal llama. Natural language -> safe Windows commands.

.DESCRIPTION
    shlama is a CLI tool that converts natural language into shell commands 
    using a local LLM (Ollama). You ask for something, it suggests a command, 
    and you approve before execution.

.PARAMETER Request
    The natural language request to convert to a command.

.PARAMETER Help
    Show help information.

.PARAMETER Version
    Show version information.

.PARAMETER Model
    Change the AI model.

.EXAMPLE
    shlama "list all files"
    shlama "show disk space"
    shlama "find large files"
    shlama --model

.LINK
    https://github.com/xt67/shlama-windows
#>

param(
    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$Request,
    
    [Alias("h")]
    [switch]$Help,
    
    [Alias("v")]
    [switch]$ShowVersion,
    
    [Alias("m")]
    [switch]$SelectModel
)

# Configuration
$script:CONFIG_FILE = "$env:LOCALAPPDATA\shlama\config"
$script:OLLAMA_HOST = if ($env:OLLAMA_HOST) { $env:OLLAMA_HOST } else { "http://localhost:11434" }
$script:SHLAMA_VERSION = "1.1.0"

# Load saved model from config
function Get-SavedModel {
    if (Test-Path $script:CONFIG_FILE) {
        return (Get-Content $script:CONFIG_FILE -Raw).Trim()
    }
    return $null
}

# Set model with priority: env > config > default
$savedModel = Get-SavedModel
$script:MODEL = if ($env:SHLAMA_MODEL) { $env:SHLAMA_MODEL } elseif ($savedModel) { $savedModel } else { "llama3.2" }

# Colors
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Show help
function Show-Help {
    Write-Host ""
    Write-ColorOutput "[llama] shlama - Your terminal llama" "Cyan"
    Write-Host ""
    Write-Host "Usage: shlama `"<natural language request>`""
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  shlama `"list all files`""
    Write-Host "  shlama `"show disk space`""
    Write-Host "  shlama `"find files modified today`""
    Write-Host "  shlama `"show running processes`""
    Write-Host "  shlama `"get my ip address`""
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  shlama --model, -m   Change the AI model"
    Write-Host "  shlama --version, -v Show version"
    Write-Host "  shlama --help, -h    Show this help"
    Write-Host ""
    Write-Host "Current model: $script:MODEL"
    Write-Host ""
    Write-Host "Environment variables:"
    Write-Host "  SHLAMA_MODEL    - Ollama model to use (overrides saved config)"
    Write-Host "  OLLAMA_HOST     - Ollama API host (default: http://localhost:11434)"
    Write-Host ""
}

# Show version
function Show-Version {
    Write-Host "shlama v$script:SHLAMA_VERSION (Windows)"
}

# Change model
function Change-Model {
    Write-Host ""
    Write-ColorOutput "[robot] Select AI Model" "Cyan"
    Write-Host ""
    Write-Host "Current model: $script:MODEL"
    Write-Host ""
    Write-Host "  1) llama3.2     - Fast & light (~2GB)"
    Write-Host "  2) llama3.2:1b  - Fastest, minimal (~1.3GB)"
    Write-Host "  3) llama3       - Balanced (~4.7GB)"
    Write-Host "  4) mistral      - Good quality (~4.1GB)"
    Write-Host "  5) Custom       - Enter custom model name"
    Write-Host "  0) Cancel"
    Write-Host ""
    
    $choice = Read-Host "Select model [0-5]"
    
    $newModel = switch ($choice) {
        "1" { "llama3.2" }
        "2" { "llama3.2:1b" }
        "3" { "llama3" }
        "4" { "mistral" }
        "5" { 
            $custom = Read-Host "Enter model name"
            if ([string]::IsNullOrWhiteSpace($custom)) { return }
            $custom.Trim()
        }
        "0" { return }
        default { return }
    }
    
    if ([string]::IsNullOrWhiteSpace($newModel)) {
        Write-ColorOutput "Cancelled." "Yellow"
        return
    }
    
    # Save to config
    $configDir = Split-Path $script:CONFIG_FILE -Parent
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    Set-Content -Path $script:CONFIG_FILE -Value $newModel
    
    Write-ColorOutput "[OK] Model changed to: $newModel" "Green"
    
    # Check if model is downloaded
    $existingModels = ollama list 2>$null
    if ($existingModels -notmatch [regex]::Escape($newModel)) {
        Write-Host ""
        $download = Read-Host "Model not downloaded. Download now? (y/N)"
        if ($download -eq "y" -or $download -eq "Y") {
            Write-ColorOutput "[download] Downloading $newModel..." "Blue"
            ollama pull $newModel
            Write-ColorOutput "[OK] Download complete" "Green"
        }
    }
}

# Check if Ollama is running, start if not
function Test-Ollama {
    try {
        $response = Invoke-RestMethod -Uri "$script:OLLAMA_HOST/api/tags" -Method Get -TimeoutSec 2 -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Start-OllamaIfNeeded {
    if (Test-Ollama) {
        return $true
    }
    
    # Check if OLLAMA_HOST points to remote (like WSL using Windows Ollama)
    if ($script:OLLAMA_HOST -ne "http://localhost:11434" -and $script:OLLAMA_HOST -notmatch "127\.0\.0\.1") {
        # Remote Ollama - can't auto-start, just fail
        return $false
    }
    
    # Try to start Ollama silently
    Write-Host "Starting Ollama..." -ForegroundColor Yellow
    
    $ollamaApp = "$env:LOCALAPPDATA\Programs\Ollama\ollama app.exe"
    
    if (Test-Path $ollamaApp) {
        # Start Ollama app minimized - it will go to system tray
        $proc = Start-Process $ollamaApp -PassThru -WindowStyle Minimized -ErrorAction SilentlyContinue
    } else {
        # Try from PATH
        Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden -ErrorAction SilentlyContinue
    }
    
    # Wait for it to start (max 15 seconds)
    $attempts = 0
    while ($attempts -lt 30) {
        Start-Sleep -Milliseconds 500
        if (Test-Ollama) {
            Write-Host "[OK] Ollama started" -ForegroundColor Green
            return $true
        }
        $attempts++
    }
    
    return $false
}

# Generate command from natural language
function Get-SuggestedCommand {
    param([string]$Prompt)
    
    $systemPrompt = "You are a Windows PowerShell and CMD expert. Convert the user's natural language request into a single, safe Windows command (PowerShell preferred). Rules: Output ONLY the command, nothing else. No explanations, no markdown, no code blocks. Use common, safe commands. Prefer non-destructive operations. If the request is unclear or potentially dangerous, output: Write-Host 'Unable to generate safe command'. Never output commands that could cause data loss without explicit user intent. Prefer PowerShell cmdlets over CMD commands when possible."
    
    $body = @{
        model = $script:MODEL
        prompt = $Prompt
        system = $systemPrompt
        stream = $false
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$script:OLLAMA_HOST/api/generate" `
            -Method Post `
            -Body $body `
            -ContentType "application/json" `
            -TimeoutSec 120 `
            -ErrorAction Stop
        
        $command = $response.response.Trim()
        # Clean up response - remove backticks, code blocks
        $command = $command -replace '^\s*```[\w]*\s*', '' -replace '\s*```\s*$', ''
        $command = $command -replace '^`', '' -replace '`$', ''
        $command = $command.Trim()
        
        return $command
    }
    catch {
        return $null
    }
}

# Main function
function Main {
    # Handle flags
    if ($Help) {
        Show-Help
        return
    }
    
    if ($ShowVersion) {
        Show-Version
        return
    }
    
    if ($SelectModel) {
        Change-Model
        return
    }
    
    # Check if request was provided
    $requestText = $Request -join " "
    if ([string]::IsNullOrWhiteSpace($requestText)) {
        Write-ColorOutput "Error: Please provide a natural language request." "Red"
        Write-Host "Usage: shlama `"<request>`""
        Write-Host "Example: shlama `"list all files`""
        Write-Host ""
        Write-Host "Run 'shlama --help' for more options."
        return
    }
    
    # Start Ollama if not running
    if (-not (Start-OllamaIfNeeded)) {
        Write-ColorOutput "Error: Ollama is not running and could not be started." "Red"
        Write-ColorOutput "Install Ollama from https://ollama.com" "Yellow"
        return
    }
    
    # Generate command
    Write-ColorOutput "[llama] Thinking..." "Cyan"
    $suggestedCommand = Get-SuggestedCommand -Prompt $requestText
    
    if ([string]::IsNullOrWhiteSpace($suggestedCommand)) {
        Write-ColorOutput "Error: Failed to generate command." "Red"
        return
    }
    
    # Display suggested command
    Write-Host ""
    Write-ColorOutput "Suggested command:" "Yellow"
    Write-ColorOutput $suggestedCommand "Green"
    Write-Host ""
    
    # Ask for confirmation
    $confirmation = Read-Host "Run command? (y/N)"
    
    if ($confirmation -eq "y" -or $confirmation -eq "Y") {
        Write-Host ""
        Write-ColorOutput "Executing..." "Blue"
        Write-Host "-------------------------------------"
        try {
            Invoke-Expression $suggestedCommand
        }
        catch {
            Write-ColorOutput "Error: $($_.Exception.Message)" "Red"
        }
        Write-Host "-------------------------------------"
        Write-ColorOutput "[OK] Done" "Green"
    }
    else {
        Write-ColorOutput "Command not executed." "Yellow"
    }
}

# Run main
Main
