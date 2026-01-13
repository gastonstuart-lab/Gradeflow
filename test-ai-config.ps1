# Quick test to check if AI is configured
# Run this in VS Code terminal: .\test-ai-config.ps1

Write-Host "`n🤖 AI Configuration Test" -ForegroundColor Cyan
Write-Host "========================`n" -ForegroundColor Cyan

# Check if environment variable exists
$apiKey = $env:OPENAI_API_KEY

if ($null -eq $apiKey -or $apiKey -eq "") {
    Write-Host "❌ OPENAI_API_KEY not found in environment" -ForegroundColor Red
    Write-Host "`nTo fix this:" -ForegroundColor Yellow
    Write-Host "1. Edit .vscode/settings.json" -ForegroundColor White
    Write-Host "2. Uncomment the terminal.integrated.env.windows section" -ForegroundColor White
    Write-Host "3. Add your API key" -ForegroundColor White
    Write-Host "4. Restart VS Code completely`n" -ForegroundColor White
    Write-Host "See AI_SETUP_QUICK.md for help`n" -ForegroundColor Cyan
    exit 1
}

# Check format
if ($apiKey -notmatch '^sk-[a-zA-Z0-9_-]+$') {
    Write-Host "⚠️  API key format looks incorrect" -ForegroundColor Yellow
    Write-Host "   Expected: sk-..." -ForegroundColor White
    Write-Host "   Got: $($apiKey.Substring(0, [Math]::Min(10, $apiKey.Length)))..." -ForegroundColor White
    Write-Host "`n   Make sure you copied the full key`n" -ForegroundColor Yellow
    exit 1
}

# All good
Write-Host "✅ API key found in environment" -ForegroundColor Green
Write-Host "✅ Key format looks correct" -ForegroundColor Green
Write-Host "`n🎉 AI is configured!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Press F5 in VS Code" -ForegroundColor White
Write-Host "2. Select 'Flutter (Chrome) + AI 🤖'" -ForegroundColor White
Write-Host "3. Try importing a file to test AI features`n" -ForegroundColor White
