@echo off
chcp 65001 >nul 2>&1
title Spicetify Manager

:: ──────────────────────────────────────────────────────────────
::  Spicetify Manager Launcher
::  This batch file runs the PowerShell script with the correct
::  execution policy. No admin rights needed.
:: ──────────────────────────────────────────────────────────────

:: Check if PowerShell is available
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo.
    echo   [x] PowerShell is not available on this system.
    echo       Windows PowerShell 5.1+ is required.
    echo.
    pause
    exit /b 1
)

:: Resolve the directory where this .bat lives
set "SCRIPT_DIR=%~dp0"

:: Run the PowerShell script with Bypass execution policy
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Spicetify_Manager.ps1"

:: If the script exits with an error, keep the window open
if %ERRORLEVEL% neq 0 (
    echo.
    echo   [x] Script exited with error code %ERRORLEVEL%.
    pause
    exit /b %ERRORLEVEL%
)
