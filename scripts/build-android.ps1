# Build Android APK (Production)

Write-Host "Building GradeFlow for Android..." -ForegroundColor Cyan
flutter build apk --release --split-per-abi

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nBuild successful! ✓" -ForegroundColor Green
    Write-Host "Output files:" -ForegroundColor Yellow
    Get-ChildItem -Path "build\app\outputs\flutter-apk\*.apk" | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor White
    }
    Write-Host "`nInstall on device:" -ForegroundColor Cyan
    Write-Host "  flutter install" -ForegroundColor White
} else {
    Write-Host "`nBuild failed! ✗" -ForegroundColor Red
    exit 1
}
