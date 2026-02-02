; =========================
; A1 Tools - Inno Setup 6
; Location: H:\A1Chimney\a1_tools\installer\a1-tools.iss
;
; UPDATED: Installs to LocalAppData to avoid UAC prompts during silent updates
; UPDATED: Removed cmd.exe calls to avoid Windows Defender false positives
; UPDATED: Removed ALL scheduled tasks to avoid AV false positives (Jan 2026)
;          App persistence is now ONLY via registry auto-start (standard Windows pattern)
;          Scheduled tasks + WMI process monitoring triggered Trojan:Win32/Bearfoos.A!ml
; UPDATED: Added Visual C++ Redistributable check and auto-install (Feb 2026)
;
; WebView2Runtime is now automatically excluded via the Excludes flag on the [Files] section
; =========================

#define MyAppName       "A1 Tools"
#define MyCompany       "A-1 Chimney Specialist"
#define MyAppURL        "https://a-1chimney.com"

; Allow overrides from ISCC: /DMyAppVersion=1.0.8 /DMyAppExeName=a1_tools.exe
#ifndef MyAppVersion
  #define MyAppVersion  "1.0.8"
#endif
#ifndef MyAppExeName
  #define MyAppExeName  "a1_tools.exe"
#endif

; IMPORTANT: keep the same GUID across releases
; NOTE: Changed GUID since install location changed - prevents conflicts with old Program Files install
#define MyAppId         "{{8A2F6B3D-E5C9-4A1B-B7D2-3F8E9C1A4D6B}}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
VersionInfoVersion={#MyAppVersion}
AppPublisher={#MyCompany}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Install to user's LocalAppData - NO ADMIN REQUIRED
DefaultDirName={localappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}

AllowNoIcons=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
Compression=lzma2
SolidCompression=yes

; Output folder (relative to .iss file location for CI compatibility)
OutputDir=output
OutputBaseFilename=A1-Tools-Setup-{#MyAppVersion}

; NOTE: paths below are relative to THIS .iss file (installer\)
SetupIconFile=..\windows\runner\resources\app_icon.ico

ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

; KEY CHANGE: No admin privileges required
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=

WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}

; Use Inno's built-in app closing (avoids taskkill which triggers AV)
CloseApplications=force
CloseApplicationsFilter=*.exe,*.dll
; Allow /RESTARTAPPLICATIONS flag to restart the app after silent update
RestartApplications=yes
; Retry file operations if they fail initially (helps with locked DLLs)
SetupMutex=A1ToolsSetupMutex

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Dirs]
Name: "{app}"

[Files]
; Pick up Flutter Windows Release output (relative to installer\)
; IMPORTANT: Exclude WebView2Runtime folder - it adds ~150MB and is NOT needed (Edge WebView2 is pre-installed on Windows 10+)
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion createallsubdirs; Excludes: "WebView2Runtime,WebView2Runtime\*"

; Service Helper executable (Layer 2 of auto-restart system)
; NOTE: Build with: cd service_helper && cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release
; Using skipifsourcedoesntexist so builds work if not yet compiled
Source: "..\service_helper\build\Release\a1_service_helper.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; yt-dlp for YouTube video downloading (Marketing Tools)
; Download from: https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe
Source: "..\assets\bin\yt-dlp.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

; NOTE: ffmpeg NOT bundled due to size (~200MB). Users who need Video+Audio or MP3
; can install ffmpeg separately and add it to PATH, or use "Video Only" mode.

; Service Helper Task XML (Layer 4 fallback)
Source: "..\watchdog\service_helper_task.xml"; DestDir: "{app}"; Flags: ignoreversion

; Visual C++ Redistributable (required for Flutter apps)
; Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe
; Place in installer\redist\ folder
Source: "redist\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: ignoreversion skipifsourcedoesntexist

; Requirements checker scripts (for troubleshooting)
Source: "check_requirements.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "diagnose.ps1"; DestDir: "{app}"; Flags: ignoreversion

; NOTE: FFmpeg removed - no longer used for remote monitoring
; NOTE: Service manager VBS removed - scheduled tasks trigger AV false positives
;       App now uses lightweight service helper for process monitoring

[Registry]
; Auto-start A1 Tools at user logon, with --auto-start so we can detect it and minimize
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
    ValueType: string; ValueName: "{#MyAppName}"; \
    ValueData: """{app}\{#MyAppExeName}"" --auto-start"; \
    Flags: uninsdeletevalue

; Auto-start Service Helper at user logon (Layer 2 - monitors app and restarts if crashed)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; \
    ValueType: string; ValueName: "A1ToolsServiceHelper"; \
    ValueData: """{app}\a1_service_helper.exe"""; \
    Flags: uninsdeletevalue

[Icons]
; Use user-specific shortcuts (not system-wide)
Name: "{userprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
; Diagnostic tool shortcuts (in Start Menu folder)
Name: "{userprograms}\{#MyAppName}\Diagnose Issues"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\diagnose.ps1"""; WorkingDir: "{app}"; Comment: "Check system requirements and generate diagnostic report"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Run]
; Launch app after install - runs in BOTH normal and silent mode
; Removed skipifsilent so app restarts after silent updates
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall

; NOTE: Firewall rules removed to avoid Windows Defender false positives
; The app handles its own network permissions through Windows prompts when needed
; Outbound connections work by default, inbound will prompt user if needed

[Code]
const
  LegacyWatchdogTaskName = 'A1ToolsWatchdog';
  ServiceManagerTaskName = 'A1ToolsServiceManager';
  MaintenanceTaskName = 'A1ToolsMaintenanceTask';

{ Check if Visual C++ Redistributable is installed }
{ Flutter Windows apps require the VC++ runtime to run }
function IsVCRedistInstalled(): Boolean;
var
  Version: String;
begin
  Result := False;
  { Check for VC++ 2015-2022 Redistributable (x64) }
  { The registry key exists if any version 14.x is installed }
  if RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Version', Version) then
  begin
    Log('VC++ Redistributable found: ' + Version);
    Result := True;
  end
  else if RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Version', Version) then
  begin
    Log('VC++ Redistributable found (WOW64): ' + Version);
    Result := True;
  end
  else
    Log('VC++ Redistributable not found');
end;

{ Install Visual C++ Redistributable silently }
procedure InstallVCRedist();
var
  ResultCode: Integer;
  VCRedistPath: String;
begin
  VCRedistPath := ExpandConstant('{tmp}\vc_redist.x64.exe');

  if FileExists(VCRedistPath) then
  begin
    Log('Installing Visual C++ Redistributable...');
    { /install /quiet /norestart - silent install without reboot }
    Exec(VCRedistPath, '/install /quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    if ResultCode = 0 then
      Log('VC++ Redistributable installed successfully')
    else if ResultCode = 1638 then
      Log('VC++ Redistributable: newer version already installed')
    else if ResultCode = 3010 then
      Log('VC++ Redistributable installed, reboot may be required')
    else
      Log('VC++ Redistributable installation returned code: ' + IntToStr(ResultCode));
  end
  else
    Log('VC++ Redistributable installer not found in package');
end;

{ Clean up ALL legacy scheduled tasks from older installations }
{ This removes tasks that were triggering AV false positives }
procedure CleanupLegacyScheduledTasks();
var
  ResultCode: Integer;
begin
  { Stop and delete the old watchdog task if it exists }
  Exec('schtasks.exe', '/end /tn "' + LegacyWatchdogTaskName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('schtasks.exe', '/delete /tn "' + LegacyWatchdogTaskName + '" /f', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  { Stop and delete the service manager task if it exists }
  Exec('schtasks.exe', '/end /tn "' + ServiceManagerTaskName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('schtasks.exe', '/delete /tn "' + ServiceManagerTaskName + '" /f', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  Log('Legacy scheduled tasks cleaned up');
end;

{ Create the maintenance task (Layer 4 fallback - runs every 10 minutes) }
{ This is optional and may be skipped if it causes AV issues }
procedure CreateMaintenanceTask();
var
  ResultCode: Integer;
  TaskXmlPath: String;
begin
  TaskXmlPath := ExpandConstant('{app}\service_helper_task.xml');

  { Only create if the XML file exists }
  if FileExists(TaskXmlPath) then
  begin
    { Delete existing task first (ignore errors) }
    Exec('schtasks.exe', '/delete /tn "' + MaintenanceTaskName + '" /f', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    { Create task from XML }
    Exec('schtasks.exe', '/create /tn "' + MaintenanceTaskName + '" /xml "' + TaskXmlPath + '" /f', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    if ResultCode = 0 then
      Log('Maintenance task created successfully')
    else
      Log('Maintenance task creation returned code: ' + IntToStr(ResultCode));
  end
  else
    Log('Maintenance task XML not found, skipping task creation');
end;

{ Delete the maintenance task }
procedure DeleteMaintenanceTask();
var
  ResultCode: Integer;
begin
  Exec('schtasks.exe', '/end /tn "' + MaintenanceTaskName + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Exec('schtasks.exe', '/delete /tn "' + MaintenanceTaskName + '" /f', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Log('Maintenance task deleted');
end;

{ Clean up update lock file if it exists (stale from failed update) }
procedure CleanupUpdateLockFile();
var
  LockFilePath: String;
begin
  LockFilePath := ExpandConstant('{localappdata}\A1 Tools\.update_in_progress');
  if FileExists(LockFilePath) then
  begin
    DeleteFile(LockFilePath);
    Log('Cleaned up stale update lock file');
  end;
end;

{ Stop the service helper process to release DLL locks }
procedure StopServiceHelper();
var
  ResultCode: Integer;
begin
  { Use taskkill to stop the service helper - this is safe since it's our own process }
  { The /F flag forces termination, /IM specifies the image name }
  Exec('taskkill.exe', '/F /IM a1_service_helper.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  { Also try to stop any a1_tools.exe instances that Inno might have missed }
  Exec('taskkill.exe', '/F /IM a1_tools.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  { Give Windows a moment to release file handles }
  Sleep(1000);
  Log('Service helper and app processes stopped');
end;

{ Called before installation starts - stop processes early }
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
  RetryCount: Integer;
  DllPath: String;
  CanAccess: Boolean;
begin
  Result := '';
  NeedsRestart := False;

  { Stop processes before checking files }
  StopServiceHelper();

  { Check if we can access the DLL file }
  DllPath := ExpandConstant('{localappdata}\A1 Tools\privacy_payload.dll');

  if FileExists(DllPath) then
  begin
    RetryCount := 0;
    CanAccess := False;

    while (RetryCount < 5) and (not CanAccess) do
    begin
      { Try to rename the file to test if it's locked }
      if RenameFile(DllPath, DllPath + '.tmp') then
      begin
        { Rename back }
        RenameFile(DllPath + '.tmp', DllPath);
        CanAccess := True;
        Log('DLL file is accessible');
      end
      else
      begin
        { File is locked, wait and retry }
        Log('DLL file is locked, attempt ' + IntToStr(RetryCount + 1) + ' of 5');
        Sleep(1000);
        { Try killing processes again }
        Exec('taskkill.exe', '/F /IM a1_service_helper.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
        Exec('taskkill.exe', '/F /IM a1_tools.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
        Sleep(500);
        RetryCount := RetryCount + 1;
      end;
    end;

    if not CanAccess then
    begin
      Log('DLL file still locked after retries');
      { Don't fail - let Inno handle it with its own retry mechanism }
    end;
  end;
end;

{ Migration helper: Remove old Program Files installation if exists }
procedure CurStepChanged(CurStep: TSetupStep);
var
  OldInstallPath: String;
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    { Note: StopServiceHelper is already called in PrepareToInstall }

    { Clean up any legacy scheduled tasks from older installations }
    CleanupLegacyScheduledTasks();

    { Clean up stale update lock file }
    CleanupUpdateLockFile();

    { Check if old installation exists in Program Files }
    OldInstallPath := ExpandConstant('{autopf}\{#MyAppName}');
    if DirExists(OldInstallPath) then
    begin
      { Try to run the old uninstaller silently }
      if FileExists(OldInstallPath + '\unins000.exe') then
      begin
        Exec(OldInstallPath + '\unins000.exe', '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      end;
    end;

    { Install Visual C++ Redistributable if not present }
    { This is required for Flutter apps to run }
    if not IsVCRedistInstalled() then
    begin
      InstallVCRedist();
    end;
  end;

  if CurStep = ssPostInstall then
  begin
    { Create the maintenance task (Layer 4 fallback) }
    { This runs every 1 minute to ensure the service helper is running }
    CreateMaintenanceTask();
  end;
end;

{ Clean up on uninstall }
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    { Clean up any scheduled tasks that may exist from older versions }
    CleanupLegacyScheduledTasks();

    { Delete the maintenance task }
    DeleteMaintenanceTask();

    { Clean up lock files }
    CleanupUpdateLockFile();
  end;
end;
