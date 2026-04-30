param(
    [string]$Remote = "origin",
    [string]$Branch
)

$ErrorActionPreference = "Stop"

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    & git @Args
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Args -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Get-GitOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Args
    )

    $output = & git @Args
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Args -join ' ') failed with exit code $LASTEXITCODE"
    }

    return $output
}

$insideWorkTree = Get-GitOutput -Args @("rev-parse", "--is-inside-work-tree")
if ($insideWorkTree -ne "true") {
    throw "This script must run inside a Git repository."
}

$currentBranch = Get-GitOutput -Args @("rev-parse", "--abbrev-ref", "HEAD")
if ([string]::IsNullOrWhiteSpace($Branch)) {
    $Branch = $currentBranch
}

Write-Host "Checking sync status for $Remote/$Branch" -ForegroundColor Cyan
Invoke-Git -Args @("fetch", "--prune", $Remote)

$statusLines = Get-GitOutput -Args @("status", "--porcelain")
$hasChanges = $statusLines.Count -gt 0
$aheadBehind = Get-GitOutput -Args @("rev-list", "--left-right", "--count", "$Remote/$Branch...$Branch")
$parts = ($aheadBehind -split "\s+") | Where-Object { $_ -ne "" }
$behind = [int]$parts[0]
$ahead = [int]$parts[1]

Write-Host "Current branch: $currentBranch" -ForegroundColor Green
Write-Host "Tracking:      $Remote/$Branch" -ForegroundColor Green
Write-Host "Behind:        $behind" -ForegroundColor Green
Write-Host "Ahead:         $ahead" -ForegroundColor Green

if ($hasChanges) {
    Write-Host "" 
    Write-Host "Local changes:" -ForegroundColor Yellow
    Invoke-Git -Args @("status", "--short")
}
else {
    Write-Host "Working tree:  clean" -ForegroundColor Green
}

Write-Host ""
if ($currentBranch -ne $Branch) {
    Write-Host "You are on '$currentBranch', not '$Branch'." -ForegroundColor Yellow
    Write-Host "If that is intentional, sync this branch instead. If not, switch branches before editing." -ForegroundColor Yellow
}
elseif ($hasChanges) {
    Write-Host "This machine has uncommitted work. The other machine cannot see it yet." -ForegroundColor Yellow
    Write-Host "Commit the work, then run the handoff task before switching devices." -ForegroundColor Yellow
}
elseif ($behind -gt 0 -and $ahead -eq 0) {
    Write-Host "This machine is behind the remote. Run the arrival task before you start editing." -ForegroundColor Yellow
}
elseif ($ahead -gt 0) {
    Write-Host "This machine has commit(s) not yet pushed. Run the handoff task before switching devices." -ForegroundColor Yellow
}
else {
    Write-Host "This machine is in sync and ready." -ForegroundColor Green
}
