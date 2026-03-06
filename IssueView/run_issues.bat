@echo off
cd /d "%~dp0"
echo ================================
echo  GitHub IssueView for Rainmeter
echo ================================
echo.
echo Running... (may take ~5 seconds)
echo.
powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -File "%~dp0FetchIssues.ps1"
echo.
if exist "%~dp0IssueView.ini" (
    echo [OK] IssueView.ini created!
    echo Load grassmeter\IssueView\IssueView.ini in Rainmeter.
) else (
    echo [FAIL] Check debug_issues.log for errors.
)
echo.
pause
