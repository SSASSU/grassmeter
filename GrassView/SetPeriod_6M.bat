@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -NonInteractive -File "%~dp0FetchAndBuild.ps1" -WeeksOverride 26
