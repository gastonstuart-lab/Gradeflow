param(
    [string]$Remote = "origin",
    [string]$Branch,
    [switch]$PushIfAhead
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

$statusLines = Get-GitOutput -Args @("status", "--porcelain")
$hasChanges = $statusLines.Count -gt 0
$stashed = $false
$stashMessage = "auto-sync-safe-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$currentBranch = Get-GitOutput -Args @("rev-parse", "--abbrev-ref", "HEAD")
if ([string]::IsNullOrWhiteSpace($Branch)) {
    $Branch = $currentBranch
}

Write-Host "Syncing with $Remote/$Branch" -ForegroundColor Cyan

if ($currentBranch -ne $Branch) {
    if ($hasChanges) {
        throw "You have local changes on '$currentBranch'. Commit or stash them before switching to '$Branch', or rerun with -Branch $currentBranch."
    }

    Write-Host "Current branch is '$currentBranch'. Switching to '$Branch'." -ForegroundColor Yellow
    & git switch $Branch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Local branch '$Branch' was not found. Trying remote branch '$Remote/$Branch'." -ForegroundColor Yellow
        Invoke-Git -Args @("switch", "--track", "$Remote/$Branch")
    }
}

if ($hasChanges) {
    Write-Host "Working tree has local changes. Creating temporary stash..." -ForegroundColor Yellow
    Invoke-Git -Args @("stash", "push", "-u", "-m", $stashMessage)
    $stashed = $true
}

try {
    Write-Host "Fetching latest changes..." -ForegroundColor Cyan
    Invoke-Git -Args @("fetch", "--prune", $Remote)

    Write-Host "Rebasing local branch onto $Remote/$Branch..." -ForegroundColor Cyan
    Invoke-Git -Args @("pull", "--rebase", $Remote, $Branch)
}
catch {
    Write-Host "Sync failed during pull/rebase." -ForegroundColor Red
    if ($stashed) {
        Write-Host "Your in-progress changes are safely stashed as '$stashMessage'." -ForegroundColor Yellow
        Write-Host "After resolving rebase issues, restore with: git stash pop" -ForegroundColor Yellow
    }
    throw
}

if ($stashed) {
    Write-Host "Restoring stashed local changes..." -ForegroundColor Cyan
    & git stash pop
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Stash pop reported conflicts. Resolve conflicts, then continue work." -ForegroundColor Yellow
        exit 1
    }
}

$aheadBehind = Get-GitOutput -Args @("rev-list", "--left-right", "--count", "$Remote/$Branch...$Branch")
$parts = ($aheadBehind -split "\s+") | Where-Object { $_ -ne "" }
$behind = [int]$parts[0]
$ahead = [int]$parts[1]

if ($PushIfAhead -and $ahead -gt 0) {
    Write-Host "Pushing $ahead local commit(s) to $Remote/$Branch..." -ForegroundColor Cyan
    Invoke-Git -Args @("push", $Remote, $Branch)
    $ahead = 0
}

Write-Host "Sync complete." -ForegroundColor Green
Write-Host "Behind: $behind  Ahead: $ahead" -ForegroundColor Green

if ($hasChanges) {
    Write-Host "Uncommitted changes are back in your working tree on this machine." -ForegroundColor Yellow
    Write-Host "They are not on GitHub yet. Commit them before moving to the other machine if you need them there." -ForegroundColor Yellow
}
elseif ($ahead -gt 0) {
    Write-Host "You still have local commit(s) that are only on this machine." -ForegroundColor Yellow
    Write-Host "Before switching devices, rerun with -PushIfAhead or push manually." -ForegroundColor Yellow
}
else {
    Write-Host "This machine is aligned with $Remote/$Branch." -ForegroundColor Green
}

Invoke-Git -Args @("status", "-sb")
