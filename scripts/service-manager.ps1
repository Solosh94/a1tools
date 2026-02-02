# A1 Tools Service Manager - SILENT
# Ensures A1 Tools is running for optimal user experience
[CmdletBinding()]
param()

# Hide console window immediately
Add-Type -Name Win32 -Namespace Native -MemberDefinition @'
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
$null = [Native.Win32]::ShowWindow([Native.Win32]::GetConsoleWindow(), 0)

$appName = "A1_Tools"
$appPath = "$env:LOCALAPPDATA\A1 Tools\A1_Tools.exe"

if (-not (Test-Path $appPath)) { exit 0 }

$process = Get-Process -Name $appName -ErrorAction SilentlyContinue

if ($null -eq $process) {
    Start-Process -FilePath $appPath -ArgumentList "--auto-start" -WindowStyle Normal
}
