' A1 Tools Service Manager - Runs silently
' Ensures optimal operation of A1 Tools

Set WshShell = CreateObject("WScript.Shell")
appPath = WshShell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\A1 Tools\A1_Tools.exe"

' Check if the app exists
Set fso = CreateObject("Scripting.FileSystemObject")
If Not fso.FileExists(appPath) Then
    WScript.Quit
End If

' Check if already running
Set objWMI = GetObject("winmgmts:\\.\root\cimv2")
Set colProcesses = objWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = 'A1_Tools.exe'")

If colProcesses.Count = 0 Then
    ' Not running, start it
    WshShell.Run """" & appPath & """ --auto-start", 1, False
End If
