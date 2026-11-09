@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo.
echo GradeFlow Classroom V2 - Firebase Hosting PREVIEW ONLY
echo Project: gradeflow-20260113
echo Channel: classroom-v2 (temporary, 7 days)
echo This does NOT publish the live GradeFlow website.
echo.

if not exist "firebase.preview.json" (
  echo ERROR: Missing firebase.preview.json. Extract the entire artifact ZIP first.
  goto :error
)
if not exist "build\web\index.html" (
  echo ERROR: Missing build\web\index.html. Extract the entire artifact ZIP first.
  goto :error
)

where firebase.cmd >nul 2>&1
if errorlevel 1 (
  echo ERROR: Firebase CLI not found. The CLI used for your older
  echo GradeFlow deployments must be installed and available in PATH.
  goto :error
)

echo Checking Firebase login...
call firebase.cmd projects:list
if errorlevel 1 (
  echo Firebase is not authenticated. Run firebase login in a command
  echo prompt on this computer, then restart this deployment script.
  goto :error
)

echo.
echo This will upload the extracted build to the classroom-v2 PREVIEW
echo channel of your EXISTING GradeFlow Firebase project only.
echo It will NOT run firebase deploy and will NOT touch the live channel.
echo.
set /p confirmation=Type PREVIEW to continue (anything else cancels): 
if /I not "%confirmation%"=="PREVIEW" (
  echo Cancelled; no deployment attempted.
  exit /b 0
)

call firebase.cmd hosting:channel:deploy classroom-v2 --project gradeflow-20260113 --config firebase.preview.json --expires 7d
if errorlevel 1 (
  echo ERROR: Preview deployment failed. The live site was not targeted.
  goto :error
)

echo.
echo Preview published. Copy the Firebase preview URL shown above.
echo The live GradeFlow website was not targeted.
pause
exit /b 0

:error
echo.
echo No deployment was completed by this script.
pause
exit /b 1
