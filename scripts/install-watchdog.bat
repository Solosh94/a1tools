@echo off
:: A1 Tools Watchdog Installer
:: Run this as Administrator to set up auto-restart for A1 Tools

echo ==========================================
echo    A1 Tools Watchdog Installer
echo ==========================================
echo.

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script must be run as Administrator!
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

:: Set variables
set TASK_NAME=A1ToolsWatchdog
set SCRIPT_PATH=%~dp0watchdog.ps1

:: Check if watchdog script exists
if not exist "%SCRIPT_PATH%" (
    echo ERROR: watchdog.ps1 not found at %SCRIPT_PATH%
    pause
    exit /b 1
)

:: Copy script to a permanent location
set INSTALL_DIR=%LOCALAPPDATA%\A1_Tools
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
copy /Y "%SCRIPT_PATH%" "%INSTALL_DIR%\watchdog.ps1" >nul

echo Installing watchdog scheduled task...

:: Delete existing task if it exists
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

:: Create scheduled task that runs every 1 minute
:: ONLOGON ensures it starts when user logs in
:: The task runs under the current user's context
schtasks /create /tn "%TASK_NAME%" /tr "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%INSTALL_DIR%\watchdog.ps1\"" /sc minute /mo 1 /ru "%USERNAME%" /rl LIMITED /f

if %errorLevel% equ 0 (
    echo.
    echo SUCCESS! Watchdog installed.
    echo.
    echo The watchdog will:
    echo  - Check every minute if A1_Tools is running
    echo  - Automatically restart it if closed
    echo  - Log restarts to %INSTALL_DIR%\watchdog.log
    echo.
    echo To uninstall, run: schtasks /delete /tn "%TASK_NAME%" /f
) else (
    echo.
    echo ERROR: Failed to create scheduled task
)

echo.
pause
