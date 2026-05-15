# Deprecated frontend OpenAI configuration check.
#
# This script is intentionally no longer used for Flutter web setup.
# Do not put OpenAI API keys in Flutter/web code, --dart-define, VS Code launch
# config, .vscode/settings.json, or client-side environment variables.
#
# Safe direction:
# Flutter UI -> service wrapper -> Firebase callable Function -> OpenAI API
# Store OpenAI credentials only in Firebase Functions / Google Cloud
# server-side secret storage.

Write-Host ""
Write-Host "Deprecated OpenAI frontend setup check" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Do not configure OpenAI keys for Flutter/web or VS Code launch configs." -ForegroundColor Red
Write-Host "Use Firebase Functions/server-side secrets only when real OpenAI integration is added." -ForegroundColor Cyan
Write-Host ""
exit 1
