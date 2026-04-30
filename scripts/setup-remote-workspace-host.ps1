param(
    [switch]$SkipFirewallRule
)

$ErrorActionPreference = "Stop"

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Step {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host $Message -ForegroundColor Cyan
}

Write-Step "Preparing this Windows machine to host the shared VS Code workspace."

if (-not (Test-IsAdministrator)) {
    throw "Run this script from an elevated PowerShell window on the desktop host."
}

$capability = Get-WindowsCapability -Online |
    Where-Object { $_.Name -like "OpenSSH.Server*" } |
    Select-Object -First 1

if (-not $capability) {
    throw "OpenSSH Server capability was not found on this Windows installation."
}

if ($capability.State -ne "Installed") {
    Write-Step "Installing OpenSSH Server..."
    Add-WindowsCapability -Online -Name $capability.Name | Out-Null
}
else {
    Write-Host "OpenSSH Server is already installed." -ForegroundColor Green
}

Write-Step "Configuring the sshd service..."
Set-Service -Name sshd -StartupType Automatic
Start-Service -Name sshd

if (-not $SkipFirewallRule) {
    $firewallRule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
    if ($firewallRule) {
        Enable-NetFirewallRule -Name "OpenSSH-Server-In-TCP" | Out-Null
        Write-Host "Firewall rule OpenSSH-Server-In-TCP is enabled." -ForegroundColor Green
    }
    else {
        New-NetFirewallRule `
            -Name "OpenSSH-Server-In-TCP" `
            -DisplayName "OpenSSH Server (sshd)" `
            -Enabled True `
            -Direction Inbound `
            -Protocol TCP `
            -Action Allow `
            -LocalPort 22 | Out-Null
        Write-Host "Firewall rule OpenSSH-Server-In-TCP was created." -ForegroundColor Green
    }
}

$service = Get-Service -Name sshd
if ($service.Status -ne "Running") {
    throw "The sshd service did not start successfully."
}

Write-Host ""
Write-Host "Remote workspace host setup is complete." -ForegroundColor Green
Write-Host "Next step:" -ForegroundColor Green
Write-Host "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/show-remote-workspace-host-info.ps1" -ForegroundColor Yellow
