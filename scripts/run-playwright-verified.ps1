param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$PlaywrightArgs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-StampOrNull {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (Test-Path -LiteralPath $Path) {
    return (Get-Item -LiteralPath $Path).LastWriteTimeUtc
  }

  return $null
}

function Get-LatestFileStampOrNull {
  param(
    [Parameter(Mandatory = $true)]
    [string]$DirectoryPath
  )

  if (-not (Test-Path -LiteralPath $DirectoryPath)) {
    return $null
  }

  $latest = Get-ChildItem -LiteralPath $DirectoryPath -File -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

  if ($null -eq $latest) {
    return $null
  }

  return $latest.LastWriteTimeUtc
}

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$reportIndexPath = Join-Path $workspaceRoot 'playwright-report/index.html'
$resultsDirPath = Join-Path $workspaceRoot 'test-results'
$summaryPath = Join-Path $workspaceRoot 'tmp/playwright-last-run-summary.json'
$runToken = (Get-Date -Format 'yyyyMMdd-HHmmss')
$stdoutLogPath = Join-Path $workspaceRoot ("tmp/playwright-run-{0}.stdout.log" -f $runToken)
$stderrLogPath = Join-Path $workspaceRoot ("tmp/playwright-run-{0}.stderr.log" -f $runToken)
$maxDurationSeconds = 900
if ($env:PLAYWRIGHT_MAX_SECONDS) {
  $parsed = 0
  if ([int]::TryParse($env:PLAYWRIGHT_MAX_SECONDS, [ref]$parsed) -and $parsed -gt 0) {
    $maxDurationSeconds = $parsed
  }
}

$preReportStamp = Get-StampOrNull -Path $reportIndexPath
$preResultsStamp = Get-LatestFileStampOrNull -DirectoryPath $resultsDirPath
$runStartedAtUtc = (Get-Date).ToUniversalTime()

Write-Host 'PLAYWRIGHT_RUN_START: Running with npx.cmd playwright test'
if ($PlaywrightArgs.Count -gt 0) {
  Write-Host ("PLAYWRIGHT_RUN_ARGS: {0}" -f ($PlaywrightArgs -join ' '))
}
Write-Host ("PLAYWRIGHT_RUN_STARTED_UTC: {0}" -f $runStartedAtUtc.ToString('o'))
Write-Host ("PLAYWRIGHT_MAX_SECONDS: {0}" -f $maxDurationSeconds)
Write-Host ("PLAYWRIGHT_STDOUT_LOG: {0}" -f $stdoutLogPath)
Write-Host ("PLAYWRIGHT_STDERR_LOG: {0}" -f $stderrLogPath)

$tmpDirPath = Join-Path $workspaceRoot 'tmp'
if (-not (Test-Path -LiteralPath $tmpDirPath)) {
  New-Item -ItemType Directory -Path $tmpDirPath | Out-Null
}

$allArgs = @('playwright', 'test') + $PlaywrightArgs
$escapedArgs = $allArgs | ForEach-Object {
  if ($_ -match '[\s\"]') {
    '"{0}"' -f ($_ -replace '"', '\"')
  }
  else {
    $_
  }
}
$cmdLine = "npx.cmd {0}" -f ($escapedArgs -join ' ')

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = 'cmd.exe'
$psi.Arguments = "/c $cmdLine"
$psi.WorkingDirectory = $workspaceRoot
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
$null = $proc.Start()

$stdoutTask = $proc.StandardOutput.ReadToEndAsync()
$stderrTask = $proc.StandardError.ReadToEndAsync()

$timedOut = $false
if ($proc.WaitForExit($maxDurationSeconds * 1000)) {
  $playwrightExitCode = $proc.ExitCode
}
else {
  $timedOut = $true
  try {
    $proc.Kill()
  }
  catch {
  }
  $playwrightExitCode = 124
}

$proc.WaitForExit()
$stdoutTask.Result | Set-Content -LiteralPath $stdoutLogPath -Encoding UTF8
$stderrTask.Result | Set-Content -LiteralPath $stderrLogPath -Encoding UTF8

$runFinishedAtUtc = (Get-Date).ToUniversalTime()
$postReportStamp = Get-StampOrNull -Path $reportIndexPath
$postResultsStamp = Get-LatestFileStampOrNull -DirectoryPath $resultsDirPath

$reportMoved = $false
if ($null -ne $postReportStamp) {
  if ($null -eq $preReportStamp -or $postReportStamp -gt $preReportStamp) {
    $reportMoved = $true
  }
}

$resultsMoved = $false
if ($null -ne $postResultsStamp) {
  if ($null -eq $preResultsStamp -or $postResultsStamp -gt $preResultsStamp) {
    $resultsMoved = $true
  }
}

$executionConfirmed = $reportMoved -or $resultsMoved

$summary = [ordered]@{
  runStartedUtc = $runStartedAtUtc.ToString('o')
  runFinishedUtc = $runFinishedAtUtc.ToString('o')
  playwrightExitCode = $playwrightExitCode
  executionConfirmed = $executionConfirmed
  reportIndexPath = $reportIndexPath
  reportIndexPreUtc = if ($null -ne $preReportStamp) { $preReportStamp.ToString('o') } else { $null }
  reportIndexPostUtc = if ($null -ne $postReportStamp) { $postReportStamp.ToString('o') } else { $null }
  testResultsDir = $resultsDirPath
  testResultsPreUtc = if ($null -ne $preResultsStamp) { $preResultsStamp.ToString('o') } else { $null }
  testResultsPostUtc = if ($null -ne $postResultsStamp) { $postResultsStamp.ToString('o') } else { $null }
  stdoutLogPath = $stdoutLogPath
  stderrLogPath = $stderrLogPath
  watchdogTimeoutSeconds = $maxDurationSeconds
  timedOut = $timedOut
  playwrightProcessId = $proc.Id
}

$summaryDir = Split-Path -Parent $summaryPath
if (-not (Test-Path -LiteralPath $summaryDir)) {
  New-Item -ItemType Directory -Path $summaryDir | Out-Null
}

$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host ("PLAYWRIGHT_EXIT_CODE: {0}" -f $playwrightExitCode)
Write-Host ("PLAYWRIGHT_EXECUTION_CONFIRMED: {0}" -f ($(if ($executionConfirmed) { 'YES' } else { 'NO' })))
Write-Host ("PLAYWRIGHT_TIMED_OUT: {0}" -f ($(if ($timedOut) { 'YES' } else { 'NO' })))
Write-Host ("PLAYWRIGHT_REPORT_INDEX: {0}" -f $reportIndexPath)
Write-Host ("PLAYWRIGHT_RESULTS_DIR: {0}" -f $resultsDirPath)
Write-Host ("PLAYWRIGHT_SUMMARY_JSON: {0}" -f $summaryPath)

if (-not $executionConfirmed) {
  Write-Error 'Playwright command finished but no artifact timestamps changed. Execution cannot be confirmed.'
  exit 3
}

exit $playwrightExitCode
