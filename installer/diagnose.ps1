# A1 Tools - System Diagnostics
# Collects detailed system information to help troubleshoot installation issues
# Run with: powershell -ExecutionPolicy Bypass -File diagnose.ps1

$ErrorActionPreference = "Continue"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  A1 Tools - System Diagnostics" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$report = @()
$report += "A1 Tools System Diagnostics Report"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "============================================"
$report += ""

# 1. Windows Version
Write-Host "[1/7] Windows Version..." -ForegroundColor Yellow
$os = Get-CimInstance Win32_OperatingSystem
$winVer = "$($os.Caption) - Build $($os.BuildNumber)"
Write-Host "      $winVer" -ForegroundColor White
$report += "Windows Version: $winVer"

# 2. System Architecture
Write-Host "[2/7] System Architecture..." -ForegroundColor Yellow
$arch = if ([Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
$status = if ($arch -eq "64-bit") { "[OK]" } else { "[FAILED]" }
$color = if ($arch -eq "64-bit") { "Green" } else { "Red" }
Write-Host "      $arch $status" -ForegroundColor $color
$report += "Architecture: $arch $status"

if ($arch -ne "64-bit") {
    Write-Host "      ERROR: A1 Tools requires 64-bit Windows" -ForegroundColor Red
}

# 3. Visual C++ Redistributable
Write-Host "[3/7] Visual C++ Redistributable..." -ForegroundColor Yellow
$vcPaths = @(
    "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X64"
)
$vcFound = $false
$vcVersion = "NOT FOUND"

foreach ($path in $vcPaths) {
    if (Test-Path $path) {
        try {
            $vcVersion = (Get-ItemProperty $path -ErrorAction SilentlyContinue).Version
            if ($vcVersion) {
                $vcFound = $true
                break
            }
        } catch {}
    }
}

if ($vcFound) {
    Write-Host "      Version: $vcVersion [OK]" -ForegroundColor Green
    $report += "VC++ Redistributable: $vcVersion [OK]"
} else {
    Write-Host "      NOT INSTALLED [FAILED]" -ForegroundColor Red
    Write-Host ""
    Write-Host "      To fix this:" -ForegroundColor Yellow
    Write-Host "      1. Download: https://aka.ms/vs/17/release/vc_redist.x64.exe" -ForegroundColor White
    Write-Host "      2. Run the installer" -ForegroundColor White
    Write-Host "      3. Restart A1 Tools" -ForegroundColor White
    Write-Host ""
    $report += "VC++ Redistributable: NOT INSTALLED [FAILED]"
}

# 4. WebView2 Runtime
Write-Host "[4/7] WebView2 Runtime..." -ForegroundColor Yellow
$wv2Paths = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}",
    "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}",
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
)
$wv2Found = $false
$wv2Version = "NOT FOUND"

foreach ($path in $wv2Paths) {
    if (Test-Path $path) {
        try {
            $wv2Version = (Get-ItemProperty $path -ErrorAction SilentlyContinue).pv
            if ($wv2Version) {
                $wv2Found = $true
                break
            }
        } catch {}
    }
}

if ($wv2Found) {
    Write-Host "      Version: $wv2Version [OK]" -ForegroundColor Green
    $report += "WebView2 Runtime: $wv2Version [OK]"
} else {
    Write-Host "      NOT INSTALLED [WARNING]" -ForegroundColor Yellow
    Write-Host "      Some features may not work. Usually included with Microsoft Edge." -ForegroundColor Gray
    $report += "WebView2 Runtime: NOT INSTALLED [WARNING]"
}

# 5. .NET Framework
Write-Host "[5/7] .NET Framework..." -ForegroundColor Yellow
$netPath = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"
if (Test-Path $netPath) {
    $netRelease = (Get-ItemProperty $netPath).Release
    $netVersion = switch ($netRelease) {
        { $_ -ge 533320 } { "4.8.1+" }
        { $_ -ge 528040 } { "4.8" }
        { $_ -ge 461808 } { "4.7.2" }
        { $_ -ge 461308 } { "4.7.1" }
        { $_ -ge 460798 } { "4.7" }
        { $_ -ge 394802 } { "4.6.2" }
        default { "4.6 or earlier" }
    }
    Write-Host "      Version: $netVersion [OK]" -ForegroundColor Green
    $report += ".NET Framework: $netVersion [OK]"
} else {
    Write-Host "      Version 4.x not found [WARNING]" -ForegroundColor Yellow
    $report += ".NET Framework: Not found [WARNING]"
}

# 6. Available Memory
Write-Host "[6/7] System Resources..." -ForegroundColor Yellow
$mem = Get-CimInstance Win32_ComputerSystem
$totalRAM = [math]::Round($mem.TotalPhysicalMemory / 1GB, 2)
$freeRAM = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
Write-Host "      Total RAM: $totalRAM GB" -ForegroundColor White
Write-Host "      Free RAM: $freeRAM GB" -ForegroundColor White
$report += "Total RAM: $totalRAM GB"
$report += "Free RAM: $freeRAM GB"

# 7. A1 Tools Installation
Write-Host "[7/7] A1 Tools Installation..." -ForegroundColor Yellow
$a1Path = "$env:LOCALAPPDATA\A1 Tools"
if (Test-Path $a1Path) {
    $exePath = Join-Path $a1Path "a1_tools.exe"
    if (Test-Path $exePath) {
        $exeInfo = Get-Item $exePath
        Write-Host "      Installed: Yes" -ForegroundColor Green
        Write-Host "      Location: $a1Path" -ForegroundColor White
        Write-Host "      Exe Size: $([math]::Round($exeInfo.Length / 1MB, 2)) MB" -ForegroundColor White
        Write-Host "      Modified: $($exeInfo.LastWriteTime)" -ForegroundColor White
        $report += "A1 Tools: Installed at $a1Path"
        $report += "Exe Size: $([math]::Round($exeInfo.Length / 1MB, 2)) MB"
        $report += "Modified: $($exeInfo.LastWriteTime)"
    } else {
        Write-Host "      Folder exists but exe not found [WARNING]" -ForegroundColor Yellow
        $report += "A1 Tools: Folder exists but exe missing"
    }
} else {
    Write-Host "      Not installed" -ForegroundColor Yellow
    $report += "A1 Tools: Not installed"
}

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan

$hasCriticalError = (-not $vcFound) -or ($arch -ne "64-bit")

if ($hasCriticalError) {
    Write-Host "  STATUS: ISSUES FOUND" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Please fix the issues marked [FAILED] above." -ForegroundColor Yellow
    $report += ""
    $report += "STATUS: ISSUES FOUND"
} else {
    Write-Host "  STATUS: ALL REQUIREMENTS MET" -ForegroundColor Green
    $report += ""
    $report += "STATUS: ALL REQUIREMENTS MET"
}

# Save report
$reportPath = "$env:LOCALAPPDATA\A1 Tools\diagnostics_report.txt"
$reportDir = Split-Path $reportPath -Parent
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host ""
Write-Host "  Report saved to:" -ForegroundColor Gray
Write-Host "  $reportPath" -ForegroundColor White
Write-Host ""
Write-Host "  Send this file to support if you need help." -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Option to open report
$openReport = Read-Host "Open report file? (Y/N)"
if ($openReport -eq "Y" -or $openReport -eq "y") {
    Start-Process notepad.exe -ArgumentList $reportPath
}

# Keep window open
Read-Host "Press Enter to close"
