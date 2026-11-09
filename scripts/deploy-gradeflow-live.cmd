@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
echo.
echo ================================================================
echo  GradeFlow V2 - replace OLD live website with approved Classroom
echo ================================================================
echo  LIVE WEBSITE: https://gradeflow-20260113.web.app
echo  FIREBASE PROJECT: gradeflow-20260113
echo  CHANGES: Hosting website files ONLY
echo  Firebase Authentication, Firestore, and Functions are not deployed.
echo  A copy of the existing LIVE Hosting release is saved first.
echo.

if not exist "firebase.live.json" (
  echo ERROR: firebase.live.json was not included. Extract the ZIP fully.
  goto :error
)
if not exist "build\web\index.html" (
  echo ERROR: build\web\index.html is missing. Extract the ZIP fully.
  goto :error
)
if not exist "release-gradeflow-live-v2.txt" (
  echo ERROR: The reviewed live-release marker file is missing.
  goto :error
)
where firebase.cmd >nul 2>&1
if errorlevel 1 (
  echo ERROR: Firebase CLI not found on this Surface/Windows computer.
  echo Open PowerShell and run: npm install -g firebase-tools
  echo Then run: firebase login
  goto :error
)
echo Checking existing Firebase CLI access...
call firebase.cmd projects:list
if errorlevel 1 (
  echo ERROR: The Firebase CLI cannot access your projects.
  echo Run firebase login on this computer and reopen this script.
  goto :error
)

echo.
echo This is the REAL live website. All current visitors will receive
echo the new GradeFlow V2 interface if you proceed.
echo No new Firebase project is created. No school records are deleted.
echo The V2 build requires a valid Firebase sign-in.
echo.
set "confirmation="
set /p confirmation=Type REPLACE to back up and update the live website: 
if /I not "%confirmation%"=="REPLACE" (
  echo Cancelled. No changes to live Hosting were made.
  exit /b 0
)

for /f %%I in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"') do set "backupChannel=before-v2-%%I"
if not defined backupChannel (
  echo ERROR: Unable to create a timestamped rollback channel.
  goto :error
)

echo.
echo Step 1/2: Saving the CURRENT live Hosting release to channel:
echo %backupChannel%
call firebase.cmd hosting:clone gradeflow-20260113:live gradeflow-20260113:%backupChannel% --project gradeflow-20260113
if errorlevel 1 (
  echo ERROR: Backup failed. Stopping BEFORE touching the live website.
  goto :error
)
>"gradeflow-backup-channel.txt" echo %backupChannel%
if not exist "gradeflow-backup-channel.txt" (
  echo ERROR: Backup channel was created but rollback record could not
  echo be written. STOPPING before live deployment.
  goto :error
)

echo.
echo Step 2/2: Publishing reviewed Classroom V2 to LIVE Hosting ONLY...
call firebase.cmd deploy --only hosting --project gradeflow-20260113 --config firebase.live.json
if errorlevel 1 (
  echo ERROR: Live deployment failed. Old release is still available in
  echo Firebase Hosting release history and the backup channel above.
  goto :error
)

echo.
echo SUCCESS: https://gradeflow-20260113.web.app/os/home
echo Your previous Hosting version is backed up as %backupChannel%.
echo To restore it, run rollback-gradeflow-live.cmd from this folder.
echo This changes Hosting files only and never changes Firestore records.
pause
exit /b 0

:error
echo.
echo Review the error shown above before trying again.
pause
exit /b 1
