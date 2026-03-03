@echo off
cd /d "%~dp0"
echo ================================
echo  GitHub CommitView for Rainmeter
echo ================================
echo.
echo Running... (may take ~5 seconds)
echo.
powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File "%~dp0FetchCommits.ps1"
echo.
if exist "%~dp0CommitView.ini" (
    echo [OK] CommitView.ini created!
    echo Load grassmeter\CommitView\CommitView.ini in Rainmeter.
) else (
    echo [FAIL] Check debug_commits.log for errors.
)
echo.
pause
