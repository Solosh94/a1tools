' A1 Tools Watchdog Launcher - Runs PowerShell completely hidden
' This VBS wrapper ensures no window flash occurs

Set WshShell = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
psScript = scriptDir & "\watchdog.ps1"

' Run PowerShell completely hidden (0 = hidden, False = don't wait)
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psScript & """", 0, False
