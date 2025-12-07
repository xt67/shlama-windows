<#
.SYNOPSIS
    shlama - Your terminal llama. Natural language → safe Windows commands.

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

.EXAMPLE
    shlama "list all files"
    shlama "show disk space"
    shlama "find large files"

.LINK
    https://github.com/xt67/shlama-windows
#>

param(
    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$Request,
    
    [Alias("h")]
    [switch]$Help,
    
    [Alias("v")]
    [switch]$ShowVersion
)

# Configuration
$script:MODEL = if ($env:SHLAMA_MODEL) { $env:SHLAMA_MODEL } else { "llama3.2" }
$script:OLLAMA_HOST = if ($env:OLLAMA_HOST) { $env:OLLAMA_HOST } else { "http://localhost:11434" }
$script:SHLAMA_VERSION = "1.0.0"

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
    Write-ColorOutput "🦙 shlama - Your terminal llama" "Cyan"
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
    Write-Host "Environment variables:"
    Write-Host "  SHLAMA_MODEL    - Ollama model to use (default: llama3.2)"
    Write-Host "  OLLAMA_HOST     - Ollama API host (default: http://localhost:11434)"
    Write-Host ""
}

# Show version
function Show-Version {
    Write-Host "shlama v$script:SHLAMA_VERSION (Windows)"
}

# Check if Ollama is running
function Test-Ollama {
    try {
        $response = Invoke-RestMethod -Uri "$script:OLLAMA_HOST/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
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
    
    # Check if request was provided
    $requestText = $Request -join " "
    if ([string]::IsNullOrWhiteSpace($requestText)) {
        Write-ColorOutput "Error: Please provide a natural language request." "Red"
        Write-Host "Usage: shlama `"<request>`""
        Write-Host "Example: shlama `"list all files`""
        return
    }
    
    # Check if Ollama is running
    if (-not (Test-Ollama)) {
        Write-ColorOutput "Error: Ollama is not running." "Red"
        Write-ColorOutput "Start it with: ollama serve" "Yellow"
        return
    }
    
    # Generate command
    Write-ColorOutput "🦙 Thinking..." "Cyan"
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
        Write-Host "─────────────────────────────────────"
        try {
            Invoke-Expression $suggestedCommand
        }
        catch {
            Write-ColorOutput "Error: $($_.Exception.Message)" "Red"
        }
        Write-Host "─────────────────────────────────────"
        Write-ColorOutput "✓ Done" "Green"
    }
    else {
        Write-ColorOutput "Command not executed." "Yellow"
    }
}

# Run main
Main
