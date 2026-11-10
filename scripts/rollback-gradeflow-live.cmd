@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
echo.
echo GradeFlow - Restore the previous LIVE Hosting version
echo Project: gradeflow-20260113
echo This restores website files only (not Firebase student records).
echo.

if not exist "gradeflow-backup-channel.txt" (
  echo ERROR: The backup record file was not found.
  echo You can still roll back in Firebase Console - Hosting - Release history.
  goto :error
)
set "backupChannel="
for /f "usebackq delims=" %%I in ("gradeflow-backup-channel.txt") do set "backupChannel=%%I"
if /I not "%backupChannel:~0,10%"=="before-v2-" (
  echo ERROR: The saved backup channel has an invalid name.
  goto :error
)
where firebase.cmd >nul 2>&1
if errorlevel 1 (
  echo ERROR: Firebase CLI missing; cannot restore the backup.
  goto :error
)
echo Existing version to restore: %backupChannel%
echo Target: gradeflow-20260113:live
echo.
set "confirmation="
set /p confirmation=Type ROLLBACK to restore the earlier live website: 
if /I not "%confirmation%"=="ROLLBACK" (
  echo Cancelled. Live Hosting remains unchanged.
  exit /b 0
)
call firebase.cmd hosting:clone gradeflow-20260113:%backupChannel% gradeflow-20260113:live --project gradeflow-20260113
if errorlevel 1 goto :error
echo.
echo Rollback successful. Open https://gradeflow-20260113.web.app/os/home
pause
exit /b 0

:error
echo.
echo The requested rollback was NOT confirmed successful.
echo You may use Firebase Console - Hosting - Release history - Roll back.
pause
exit /b 1
