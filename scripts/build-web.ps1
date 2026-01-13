# Build and Deployment Scripts for GradeFlow

# Web Build (Production)
Write-Host "Building GradeFlow for Web..." -ForegroundColor Cyan
flutter build web --release --web-renderer canvaskit

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nBuild successful! ✓" -ForegroundColor Green
    Write-Host "Output directory: build\web\" -ForegroundColor Yellow
    Write-Host "`nTo test locally, run:" -ForegroundColor Cyan
    Write-Host "  python -m http.server 8000 -d build\web" -ForegroundColor White
    Write-Host "  Then open http://localhost:8000" -ForegroundColor White
} else {
    Write-Host "`nBuild failed! ✗" -ForegroundColor Red
    exit 1
}
