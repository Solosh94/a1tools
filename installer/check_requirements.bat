@echo off
:: A1 Tools - System Requirements Checker
:: This script checks if all required dependencies are installed
:: and provides helpful error messages if something is missing.

setlocal EnableDelayedExpansion

echo ============================================
echo   A1 Tools - System Requirements Check
echo ============================================
echo.

set ERRORS_FOUND=0
set LOG_FILE=%LOCALAPPDATA%\A1 Tools\requirements_check.log

:: Create log directory if it doesn't exist
if not exist "%LOCALAPPDATA%\A1 Tools" mkdir "%LOCALAPPDATA%\A1 Tools"

:: Start log
echo A1 Tools Requirements Check - %date% %time% > "%LOG_FILE%"
echo. >> "%LOG_FILE%"

:: Check 1: Windows Version
echo [1/4] Checking Windows version...
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo       Windows version: %VERSION%
echo Windows version: %VERSION% >> "%LOG_FILE%"

:: Check 2: 64-bit OS
echo [2/4] Checking system architecture...
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo       Architecture: 64-bit [OK]
    echo Architecture: 64-bit [OK] >> "%LOG_FILE%"
) else if "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
    echo       Architecture: 64-bit [OK]
    echo Architecture: 64-bit [OK] >> "%LOG_FILE%"
) else (
    echo       Architecture: 32-bit [FAILED]
    echo       ERROR: A1 Tools requires a 64-bit version of Windows.
    echo Architecture: 32-bit [FAILED] >> "%LOG_FILE%"
    set ERRORS_FOUND=1
)

:: Check 3: Visual C++ Redistributable
echo [3/4] Checking Visual C++ Redistributable...
set VC_FOUND=0

:: Check primary registry location
reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64" /v Version >nul 2>&1
if %errorlevel%==0 (
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64" /v Version 2^>nul ^| findstr Version') do (
        echo       VC++ Redistributable: %%a [OK]
        echo VC++ Redistributable: %%a [OK] >> "%LOG_FILE%"
        set VC_FOUND=1
    )
)

:: Check WOW6432Node location (alternative)
if !VC_FOUND!==0 (
    reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X64" /v Version >nul 2>&1
    if !errorlevel!==0 (
        for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X64" /v Version 2^>nul ^| findstr Version') do (
            echo       VC++ Redistributable: %%a [OK]
            echo VC++ Redistributable: %%a [OK] >> "%LOG_FILE%"
            set VC_FOUND=1
        )
    )
)

if !VC_FOUND!==0 (
    echo       VC++ Redistributable: NOT FOUND [FAILED]
    echo       ERROR: Visual C++ Redistributable is required but not installed.
    echo.
    echo       To fix this:
    echo       1. Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe
    echo       2. Run the downloaded file and follow the prompts
    echo       3. Restart A1 Tools
    echo.
    echo VC++ Redistributable: NOT FOUND [FAILED] >> "%LOG_FILE%"
    set ERRORS_FOUND=1
)

:: Check 4: WebView2 Runtime (optional but recommended)
echo [4/4] Checking WebView2 Runtime...
set WEBVIEW_FOUND=0

reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv >nul 2>&1
if %errorlevel%==0 (
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv 2^>nul ^| findstr pv') do (
        echo       WebView2 Runtime: %%a [OK]
        echo WebView2 Runtime: %%a [OK] >> "%LOG_FILE%"
        set WEBVIEW_FOUND=1
    )
)

if !WEBVIEW_FOUND!==0 (
    reg query "HKCU\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv >nul 2>&1
    if !errorlevel!==0 (
        for /f "tokens=3" %%a in ('reg query "HKCU\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" /v pv 2^>nul ^| findstr pv') do (
            echo       WebView2 Runtime: %%a [OK]
            echo WebView2 Runtime: %%a [OK] >> "%LOG_FILE%"
            set WEBVIEW_FOUND=1
        )
    )
)

if !WEBVIEW_FOUND!==0 (
    echo       WebView2 Runtime: NOT FOUND [WARNING]
    echo       Note: Some features may not work without WebView2.
    echo       Microsoft Edge usually includes this automatically.
    echo WebView2 Runtime: NOT FOUND [WARNING] >> "%LOG_FILE%"
)

echo.
echo ============================================

if %ERRORS_FOUND%==1 (
    echo   STATUS: FAILED - Missing requirements
    echo.
    echo   Please install the missing components and try again.
    echo   Log saved to: %LOG_FILE%
    echo.
    echo STATUS: FAILED >> "%LOG_FILE%"
    pause
    exit /b 1
) else (
    echo   STATUS: PASSED - All requirements met
    echo.
    echo STATUS: PASSED >> "%LOG_FILE%"
    exit /b 0
)
