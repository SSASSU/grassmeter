@echo off
cd /d "%~dp0"
echo ================================
echo  GitHub Grass for Rainmeter
echo ================================
echo.
echo Running... (may take ~10 seconds)
echo.
powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File "%~dp0FetchAndBuild.ps1"
echo.
if exist "%~dp0GrassView.ini" (
    echo [OK] GrassView.ini created!
    echo Load GrassView.ini in Rainmeter.
) else (
    echo [FAIL] Check debug.log for errors.
)
echo.
pause