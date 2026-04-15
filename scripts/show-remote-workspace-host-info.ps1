param(
    [string]$WorkspacePath = "C:\Users\Stuart\Nosapp\Gradeflow"
)

$ErrorActionPreference = "Stop"

$computerName = $env:COMPUTERNAME
$userName = $env:USERNAME
$hostAlias = "gradeflow-" + $computerName.ToLower()
$service = Get-Service -Name sshd -ErrorAction SilentlyContinue
$addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254*"
    } |
    Sort-Object InterfaceAlias, IPAddress -Unique |
    Select-Object InterfaceAlias, IPAddress

Write-Host "Remote workspace host information" -ForegroundColor Cyan
Write-Host "Computer name: $computerName" -ForegroundColor Green
Write-Host "Windows user:  $userName" -ForegroundColor Green
Write-Host "Workspace:     $WorkspacePath" -ForegroundColor Green

if ($service) {
    Write-Host "sshd status:   $($service.Status)" -ForegroundColor Green
}
else {
    Write-Host "sshd status:   not installed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Use one of these SSH targets from the Surface:" -ForegroundColor Cyan
Write-Host "$userName@$computerName" -ForegroundColor Yellow

if ($addresses) {
    $addresses | ForEach-Object {
        Write-Host "$userName@$($_.IPAddress)  ($($_.InterfaceAlias))" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Recommended VS Code SSH config snippet:" -ForegroundColor Cyan
Write-Host "Host $hostAlias" -ForegroundColor Yellow
Write-Host "    HostName $computerName" -ForegroundColor Yellow
Write-Host "    User $userName" -ForegroundColor Yellow

Write-Host ""
Write-Host "From the Surface in VS Code:" -ForegroundColor Cyan
Write-Host "1. Install the Remote - SSH extension." -ForegroundColor Yellow
Write-Host "2. Run 'Remote-SSH: Connect to Host...'." -ForegroundColor Yellow
Write-Host "3. Connect to one of the targets above." -ForegroundColor Yellow
Write-Host "4. Open $WorkspacePath on the host machine." -ForegroundColor Yellow
