# Load environment variables from .env file
# This script is automatically used by the VS Code launch configurations

$envFile = Join-Path $PSScriptRoot ".env"

if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
            Write-Host "Loaded: $name" -ForegroundColor Green
        }
    }
    Write-Host "Environment variables loaded from .env" -ForegroundColor Cyan
} else {
    Write-Host "No .env file found - AI features will be disabled" -ForegroundColor Yellow
}
