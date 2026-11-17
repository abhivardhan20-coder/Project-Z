@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Play_Project_Z.ps1"
if errorlevel 1 pause
