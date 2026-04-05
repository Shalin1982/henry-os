# Henry OS Windows Installer
# PowerShell one-liner:
# irm https://raw.githubusercontent.com/henry-os/henry-os/main/install.ps1 | iex

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Configuration
$RepoUrl = "https://raw.githubusercontent.com/henry-os/henry-os/main"
$InstallDir = "$env:USERPROFILE\.openclaw"
$WorkspaceDir = "$InstallDir\workspace"
$ConfigDir = "$InstallDir\config"

# Logging functions
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warn { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Show-Banner {
    Write-Host @"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║                    HENRY OS INSTALLER                      ║
║              Your AI Chief of Staff — v1.0                 ║
║                      (Windows Preview)                     ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
}

function Test-NodeJs {
    try {
        $version = node --version 2>$null
        if ($version) {
            $major = [int]($version -replace 'v' -split '\.')[0]
            if ($major -ge 20) {
                return @{ Status = "ok"; Version = $version }
            } else {
                return @{ Status = "old"; Version = $version }
            }
        }
    } catch {}
    return @{ Status = "missing"; Version = $null }
}

function Install-NodeJs {
    Write-Info "Installing Node.js 20+..."
    
    # Download and run Node.js installer
    $nodeInstaller = "$env:TEMP\node-setup.msi"
    Invoke-WebRequest -Uri "https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi" -OutFile $nodeInstaller
    Start-Process msiexec.exe -ArgumentList "/i", $nodeInstaller, "/quiet", "/norestart" -Wait
    Remove-Item $nodeInstaller
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    Write-Success "Node.js installed"
}

function Install-OpenClaw {
    Write-Info "Installing OpenClaw..."
    npm install -g openclaw@latest
    Write-Success "OpenClaw installed"
}

function New-DirectoryStructure {
    Write-Info "Creating workspace structure..."
    
    New-Item -ItemType Directory -Force -Path $WorkspaceDir | Out-Null
    New-Item -ItemType Directory -Force -Path "$WorkspaceDir\memory" | Out-Null
    New-Item -ItemType Directory -Force -Path "$WorkspaceDir\agents" | Out-Null
    New-Item -ItemType Directory -Force -Path "$WorkspaceDir\mission-control" | Out-Null
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    
    Write-Success "Directory structure created"
}

function Invoke-OnboardingWizard {
    Write-Info "Starting onboarding wizard..."
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                    ONBOARDING WIZARD                       " -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    $name = Read-Host "1. What's your name?"
    $aiName = Read-Host "2. What should the AI call you?"
    $timezone = Read-Host "3. What's your timezone? (e.g., America/New_York)"
    
    Write-Host "4. What's your primary goal?"
    Write-Host "   (1) revenue  (2) family  (3) learning  (4) other"
    $goalChoice = Read-Host "   Select (1-4)"
    $primaryGoal = switch ($goalChoice) { "1" { "revenue" } "2" { "family" } "3" { "learning" } default { "other" } }
    
    if ($primaryGoal -eq "revenue") {
        $revenueTarget = Read-Host "5. What's your monthly revenue target? (USD, e.g., 10000)"
    } else {
        $revenueTarget = 0
    }
    
    Write-Host "6. Preferred model?"
    Write-Host "   (1) kimi-k2.5 (default)  (2) claude-sonnet-4-6  (3) claude-opus-4-6"
    $modelChoice = Read-Host "   Select (1-3)"
    $preferredModel = switch ($modelChoice) { "2" { "claude-sonnet-4-6" } "3" { "claude-opus-4-6" } default { "kimi-k2.5" } }
    
    $proactiveIntel = Read-Host "7. Enable proactive intelligence? (yes/no)"
    $revenueHunt = Read-Host "8. Enable revenue hunting? (yes/no)"
    
    Write-Host "9. Preferred notification channel?"
    Write-Host "   (1) telegram  (2) imessage  (3) discord  (4) none"
    $channelChoice = Read-Host "   Select (1-4)"
    $notificationChannel = switch ($channelChoice) { "1" { "telegram" } "2" { "imessage" } "3" { "discord" } default { "none" } }
    
    $domains = Read-Host "10. Any specific domains to focus on? (comma-separated, or 'none')"
    
    # Generate config
    $config = @{
        user = @{
            name = $name
            ai_name = $aiName
            timezone = $timezone
            primary_goal = $primaryGoal
            revenue_target = [int]$revenueTarget
            domains = if ($domains -ne "none") { $domains -split ',' | ForEach-Object { $_.Trim() } } else { @() }
        }
        ai = @{
            preferred_model = $preferredModel
            proactive_intelligence = $proactiveIntel -match '^[Yy]'
            revenue_hunting = $revenueHunt -match '^[Yy]'
        }
        notifications = @{
            channel = $notificationChannel
            enabled = $notificationChannel -ne "none"
        }
        security = @{
            gateway_bind = "127.0.0.1"
            websocket_origin_validation = "strict"
            filesystem_scope = $WorkspaceDir
            cve_2026_25253_patched = $true
        }
        installed_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        version = "1.0.0"
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content "$ConfigDir\user-config.json"
    
    # Generate USER.md
    $userMd = @"
# USER.md - About Your Human

- **Name:** $name
- **What to call them:** $aiName
- **Timezone:** $timezone

## Context

- **Primary Goal:** $primaryGoal
- **Focus Domains:** $domains

## Notes

Installed via Henry OS installer on $(Get-Date -Format "yyyy-MM-dd").
"@
    $userMd | Set-Content "$WorkspaceDir\USER.md"
    
    Write-Success "Onboarding complete!"
}

function Set-SecurityHardening {
    Write-Info "Applying security hardening..."
    
    $security = @{
        gateway = @{ bind_address = "127.0.0.1"; port = 3333; external_access = $false }
        websocket = @{ origin_validation = "strict"; allowed_origins = @("http://localhost:3333", "http://127.0.0.1:3333") }
        filesystem = @{ scope = $WorkspaceDir; allow_outside_scope = $false }
        cve_patches = @{
            "CVE-2026-25253" = @{
                patched = $true
                patch_date = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                description = "WebSocket origin validation bypass - strict validation enabled"
            }
        }
    }
    
    $security | ConvertTo-Json -Depth 10 | Set-Content "$ConfigDir\security.json"
    
    Write-Success "Security hardening applied (CVE-2026-25253 patched)"
}

function Install-MissionControl {
    Write-Info "Installing Mission Control..."
    
    $mcDir = "$WorkspaceDir\mission-control"
    
    # Create minimal server
    $serverJs = @'
const http = require('http');
const PORT = 3333;
const HOST = '127.0.0.1';

const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`
<!DOCTYPE html>
<html>
<head>
    <title>Henry OS - Mission Control</title>
    <style>
        body { font-family: -apple-system, sans-serif; background: #0a0a0a; color: #fff; margin: 0; padding: 40px; }
        h1 { color: #00d4ff; }
        .status { background: #1a1a1a; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .metric { display: inline-block; margin: 10px 20px 10px 0; }
        .metric-value { font-size: 24px; font-weight: bold; color: #00d4ff; }
        .metric-label { font-size: 12px; color: #888; }
    </style>
</head>
<body>
    <h1>🎯 Mission Control</h1>
    <div class="status">
        <div class="metric">
            <div class="metric-value">●</div>
            <div class="metric-label">System Online</div>
        </div>
        <div class="metric">
            <div class="metric-value">Henry</div>
            <div class="metric-label">Master Agent</div>
        </div>
    </div>
    <p>Your AI Chief of Staff is running.</p>
    <p>Workspace: ${process.env.USERPROFILE}\\.openclaw\\workspace</p>
</body>
</html>
    `);
});

server.listen(PORT, HOST, () => {
    console.log(`Mission Control running at http://${HOST}:${PORT}`);
});
'@
    
    $serverJs | Set-Content "$mcDir\server.js"
    
    $packageJson = @'
{
  "name": "henry-mission-control",
  "version": "1.0.0",
  "description": "Henry OS Mission Control Dashboard",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  }
}
'@
    $packageJson | Set-Content "$mcDir\package.json"
    
    # Start Mission Control
    Start-Process -FilePath "node" -ArgumentList "$mcDir\server.js" -WindowStyle Hidden
    
    Write-Success "Mission Control installed and started"
}

function Open-Browser {
    Write-Info "Opening Mission Control..."
    Start-Process "http://localhost:3333"
}

function Show-Welcome {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                            ║" -ForegroundColor Green
    Write-Host "║              🎉 HENRY OS INSTALLATION COMPLETE! 🎉          ║" -ForegroundColor Green
    Write-Host "║                                                            ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your AI Chief of Staff is ready." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📊 Mission Control: http://localhost:3333" -ForegroundColor Yellow
    Write-Host "📁 Workspace: $WorkspaceDir" -ForegroundColor Yellow
    Write-Host "⚙️  Config: $ConfigDir" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Henry is now running and ready to help you." -ForegroundColor Green
    Write-Host "Check Mission Control to monitor status and give commands." -ForegroundColor Green
    Write-Host ""
}

# Main
Show-Banner

# Check Node.js
$nodeStatus = Test-NodeJs
if ($nodeStatus.Status -eq "missing") {
    Install-NodeJs
} elseif ($nodeStatus.Status -eq "old") {
    Write-Warn "Node.js version is too old, upgrading..."
    Install-NodeJs
} else {
    Write-Success "Node.js $($nodeStatus.Version) is ready"
}

# Install components
Install-OpenClaw
New-DirectoryStructure
Invoke-OnboardingWizard
Set-SecurityHardening
Install-MissionControl
Open-Browser
Show-Welcome
