# Run GradeFlow with Development Configuration

param(
    [string]$Platform = "chrome"
)

Write-Host "Starting GradeFlow in development mode..." -ForegroundColor Cyan
Write-Host "Platform: $Platform" -ForegroundColor Yellow

flutter run -d $Platform

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nFailed to start! ✗" -ForegroundColor Red
    exit 1
}
