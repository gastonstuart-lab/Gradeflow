@echo off
setlocal
title InstructOS - Update and Preview

cd /d "%~dp0"

echo.
echo ==========================================
echo   InstructOS - Update and Preview
echo ==========================================
echo.

echo [1/4] Updating the preview branch...
git pull --ff-only
if errorlevel 1 (
  echo.
  echo ERROR: Git could not update this branch safely.
  echo Nothing was overwritten. Send Stuart/ChatGPT this window.
  echo.
  pause
  exit /b 1
)

set "FLUTTER=%USERPROFILE%\flutter\bin\flutter.bat"
if not exist "%FLUTTER%" (
  echo.
  echo ERROR: Flutter was not found at:
  echo %FLUTTER%
  echo.
  pause
  exit /b 1
)

echo.
echo [2/4] Building the InstructOS teaching preview...
call "%FLUTTER%" build web --release --no-wasm-dry-run --no-pub --target lib/teaching_preview.dart --output build/teaching-preview
if errorlevel 1 (
  echo.
  echo ERROR: The preview build failed.
  echo Nothing was deployed or merged.
  echo.
  pause
  exit /b 1
)

echo.
echo [3/4] Checking local preview server...
netstat -ano | findstr /R /C:":8769 .*LISTENING" >nul
if errorlevel 1 (
  echo Starting local preview server on port 8769...
  start "InstructOS Preview Server" /min py -m http.server 8769 --directory "%CD%\build\teaching-preview"
  timeout /t 2 /nobreak >nul
) else (
  echo Preview server is already running.
)

echo.
echo [4/4] Opening InstructOS...
start "" "http://127.0.0.1:8769/?review=github"

echo.
echo Done. Refresh the browser after future updates if it was already open.
echo This launcher never merges, deploys, or touches production.
echo.
timeout /t 3 /nobreak >nul
endlocal
