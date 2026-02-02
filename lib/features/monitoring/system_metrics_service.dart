import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';
import '../admin/privacy_exclusions_service.dart';

/// System Metrics Service
/// 
/// Efficiently collects comprehensive system information using a single
/// PowerShell script execution to minimize CPU usage. All metrics are
/// gathered in one call and sent to the server.
class SystemMetricsService {
  static SystemMetricsService? _instance;
  static SystemMetricsService get instance => _instance ??= SystemMetricsService._();

  SystemMetricsService._();

  static String get _submitUrl => ApiConfig.systemMetrics;
  static const Duration _collectInterval = Duration(minutes: 5);
  final ApiClient _api = ApiClient.instance;

  Timer? _timer;
  String? _username;
  bool _isRunning = false;
  
  /// Initialize and start the metrics collection service
  Future<void> start(String username) async {
    _username = username;
    
    if (_isRunning) return;
    _isRunning = true;
    
    debugPrint('[SystemMetrics] Started for $username');
    
    // Collect immediately on start
    await _collectAndSubmit();
    
    // Then collect periodically
    _timer?.cancel();
    _timer = Timer.periodic(_collectInterval, (_) => _collectAndSubmit());
  }
  
  /// Stop the metrics collection service
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    debugPrint('[SystemMetrics] Stopped');
  }
  
  /// Manually trigger a metrics collection
  Future<void> collectNow() async {
    await _collectAndSubmit();
  }
  
  Future<void> _collectAndSubmit() async {
    if (_username == null) {
      debugPrint('[SystemMetrics] No username set, skipping');
      return;
    }
    if (!Platform.isWindows) {
      debugPrint('[SystemMetrics] Not Windows, skipping');
      return;
    }

    try {
      debugPrint('[SystemMetrics] Collecting metrics for $_username...');
      final metrics = await _collectAllMetrics();

      if (metrics == null) {
        debugPrint('[SystemMetrics] Failed to collect metrics (null result)');
        return;
      }

      // Filter out privacy-excluded programs before sending to server
      await _filterExcludedPrograms(metrics);

      debugPrint('[SystemMetrics] Collected: CPU=${metrics['cpu_usage']}%, MEM=${metrics['memory_usage']}%');

      metrics['username'] = _username;
      metrics['action'] = 'submit';
      
      debugPrint('[SystemMetrics] Submitting to $_submitUrl...');

      final response = await _api.post(
        _submitUrl,
        body: metrics,
        timeout: const Duration(seconds: 30),
      );

      debugPrint('[SystemMetrics] Response: ${response.success}');
      debugPrint('[SystemMetrics] Body: ${response.rawJson}');

      if (response.success) {
        debugPrint('[SystemMetrics] âœ" Submitted successfully');
      } else {
        debugPrint('[SystemMetrics] âœ— Submit failed: ${response.message}');
      }
    } catch (e, stack) {
      debugPrint('[SystemMetrics] âœ— Error: $e');
      debugPrint('[SystemMetrics] Stack: $stack');
    }
  }
  
  /// Collect all system metrics in a single PowerShell execution
  /// Uses a temp file to avoid command line length limits
  Future<Map<String, dynamic>?> _collectAllMetrics() async {
    if (!Platform.isWindows) return null;
    
    // Comprehensive PowerShell script that gathers ALL metrics in one execution
    const script = r'''
$ErrorActionPreference = 'SilentlyContinue'
$result = @{}

# ============ SYSTEM INFO ============
$result.computer_name = $env:COMPUTERNAME
$os = Get-CimInstance Win32_OperatingSystem
$result.os_name = $os.Caption
$result.os_version = $os.Version
$result.total_ram = [long]$os.TotalVisibleMemorySize * 1024
$result.available_ram = [long]$os.FreePhysicalMemory * 1024
$result.uptime_seconds = [int]((Get-Date) - $os.LastBootUpTime).TotalSeconds
if ($result.total_ram -gt 0) {
    $result.memory_usage = [math]::Round((($result.total_ram - $result.available_ram) / $result.total_ram) * 100, 2)
} else {
    $result.memory_usage = 0
}

# ============ CPU ============
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$result.processor = $cpu.Name
$result.cpu_cores = $cpu.NumberOfCores
try {
    $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1
    $result.cpu_usage = [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)
} catch {
    $result.cpu_usage = 0
}

# ============ GPU ============
$gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
$result.gpu_name = if ($gpu.Name) { $gpu.Name } else { '' }

# GPU Usage - try nvidia-smi for NVIDIA, fallback to performance counter
$result.gpu_usage = 0
try {
    # Try NVIDIA first
    if (Test-Path "C:\Windows\System32\nvidia-smi.exe") {
        $nvOut = & "C:\Windows\System32\nvidia-smi.exe" --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>$null
        if ($nvOut -and $nvOut.Trim() -match '^\d+') {
            $result.gpu_usage = [math]::Round([double]$nvOut.Trim(), 2)
        }
    }
} catch {}

# If still 0, try Windows performance counter (works for Intel/AMD integrated)
if ($result.gpu_usage -eq 0) {
    try {
        $gpuCounter = Get-Counter '\GPU Engine(*engtype_3D)\Utilization Percentage' -ErrorAction Stop
        if ($gpuCounter.CounterSamples) {
            $total = ($gpuCounter.CounterSamples | Measure-Object -Property CookedValue -Sum).Sum
            $result.gpu_usage = [math]::Round($total, 2)
        }
    } catch {}
}

# ============ NETWORK ============
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.PhysicalMediaType -ne 'Unspecified' } | Select-Object -First 1
$result.network_adapter = if ($adapter.Name) { $adapter.Name } else { '' }

# Connection type detection
if ($adapter.PhysicalMediaType -match 'Wireless|Wi-?Fi' -or $adapter.Name -match 'Wi-?Fi|Wireless') {
    $result.connection_type = 'WiFi'
} elseif ($adapter.PhysicalMediaType -match '802.3' -or $adapter.Name -match 'Ethernet') {
    $result.connection_type = 'Ethernet'
} else {
    $result.connection_type = 'Other'
}

# WiFi specific info (SSID and signal strength)
$result.wifi_ssid = ''
$result.signal_strength = 0
if ($result.connection_type -eq 'WiFi') {
    try {
        $wifiInfo = netsh wlan show interfaces | Out-String
        if ($wifiInfo -match 'SSID\s+:\s+(.+)') {
            $result.wifi_ssid = $matches[1].Trim()
        }
        if ($wifiInfo -match 'Signal\s+:\s+(\d+)%') {
            $result.signal_strength = [int]$matches[1]
        }
    } catch {}
}

# IP addresses
$ipConfig = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -eq $adapter.Name } | Select-Object -First 1
$result.local_ip = if ($ipConfig.IPAddress) { $ipConfig.IPAddress } else { '' }
try {
    $result.public_ip = (Invoke-WebRequest -Uri 'https://api.ipify.org' -TimeoutSec 3 -UseBasicParsing).Content
} catch {
    $result.public_ip = ''
}

# Network statistics (bytes sent/received since boot)
$result.bytes_sent = 0
$result.bytes_received = 0
try {
    $netStats = Get-NetAdapterStatistics -Name $adapter.Name -ErrorAction Stop
    $result.bytes_sent = [long]$netStats.SentBytes
    $result.bytes_received = [long]$netStats.ReceivedBytes
} catch {}

# ============ STORAGE ============
$drives = @()
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $drives += @{
        name = $_.DeviceID
        label = if ($_.VolumeName) { $_.VolumeName } else { '' }
        total_space = [long]$_.Size
        free_space = [long]$_.FreeSpace
    }
}
$result.drives = $drives

# ============ RUNNING APPS (visible windows) ============
$runningApps = @()
Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -ne '' } | 
    Sort-Object -Property WorkingSet64 -Descending | ForEach-Object {
    $runningApps += @{
        name = $_.ProcessName
        title = $_.MainWindowTitle
        memory_bytes = [long]$_.WorkingSet64
    }
}
$result.running_apps = $runningApps

# ============ BROWSER WINDOWS (actual browser tabs only) ============
$browserWindows = @()

try {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    
    # Get all browser process IDs
    $browserProcessIds = @{}
    @('chrome', 'msedge', 'firefox', 'librewolf') | ForEach-Object {
        Get-Process -Name $_ -ErrorAction SilentlyContinue | ForEach-Object {
            $browserProcessIds[$_.Id] = $_.ProcessName
        }
    }
    
    if ($browserProcessIds.Count -gt 0) {
        # Get ALL top-level windows from the desktop
        $root = [System.Windows.Automation.AutomationElement]::RootElement
        $windowCondition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Window
        )
        $allWindows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $windowCondition)
        
        foreach ($window in $allWindows) {
            try {
                $windowPid = $window.Current.ProcessId
                
                # Check if this window belongs to a browser
                if ($browserProcessIds.ContainsKey($windowPid)) {
                    $browserName = $browserProcessIds[$windowPid]
                    $windowRect = $window.Current.BoundingRectangle
                    $tabMaxY = $windowRect.Top + 100
                    
                    # Find all TabItem controls in this window
                    $tabCondition = New-Object System.Windows.Automation.PropertyCondition(
                        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
                        [System.Windows.Automation.ControlType]::TabItem
                    )
                    $tabs = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tabCondition)
                    
                    $foundTabs = $false
                    foreach ($tab in $tabs) {
                        $tabName = $tab.Current.Name
                        $tabRect = $tab.Current.BoundingRectangle
                        
                        # Only include tabs in the top portion (actual tab bar)
                        if ($tabName -and $tabName.Length -gt 0 -and $tabRect.Top -lt $tabMaxY) {
                            $browserWindows += @{
                                browser = $browserName
                                title = $tabName
                            }
                            $foundTabs = $true
                        }
                    }
                    
                    # If no tabs found, use window title
                    if (-not $foundTabs) {
                        $windowTitle = $window.Current.Name
                        if ($windowTitle -and $windowTitle.Length -gt 0) {
                            $browserWindows += @{
                                browser = $browserName
                                title = $windowTitle
                            }
                        }
                    }
                }
            } catch {
                # Skip windows that throw errors
            }
        }
    }
} catch {
    # Fallback if UIAutomation fails
    @('chrome', 'msedge', 'firefox', 'librewolf') | ForEach-Object {
        Get-Process -Name $_ -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowTitle -ne '' } | ForEach-Object {
            $browserWindows += @{
                browser = $_.ProcessName
                title = $_.MainWindowTitle
            }
        }
    }
}

# Remove duplicates
$seen = @{}
$uniqueBrowserWindows = @()
foreach ($bw in $browserWindows) {
    $key = "$($bw.browser)|$($bw.title)"
    if (-not $seen.ContainsKey($key)) {
        $seen[$key] = $true
        $uniqueBrowserWindows += $bw
    }
}
$result.browser_windows = $uniqueBrowserWindows

# ============ TOP PROCESSES (by memory) ============
$processes = @()
Get-Process | Where-Object { $_.ProcessName -ne 'Idle' -and $_.WorkingSet64 -gt 0 } | 
    Sort-Object -Property WorkingSet64 -Descending | 
    Select-Object -First 20 | ForEach-Object {
    $processes += @{
        name = $_.ProcessName
        cpu_percent = 0
        memory_bytes = [long]$_.WorkingSet64
    }
}
$result.processes = $processes

# ============ IDLE TIME ============
$result.idle_seconds = 0
try {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class IdleTime {
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }
    
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    
    public static uint GetIdleTime() {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        if (GetLastInputInfo(ref lii)) {
            return ((uint)Environment.TickCount - lii.dwTime) / 1000;
        }
        return 0;
    }
}
"@ -ErrorAction SilentlyContinue
    $result.idle_seconds = [int][IdleTime]::GetIdleTime()
} catch {
    $result.idle_seconds = 0
}

# Screen locked status
$result.screen_locked = $false
try {
    $logonUI = Get-Process -Name 'LogonUI' -ErrorAction SilentlyContinue
    $result.screen_locked = ($logonUI -ne $null)
} catch {}

# Active window (currently focused)
$result.active_window = ''
try {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class ActiveWindow {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    
    public static string GetActiveWindowTitle() {
        IntPtr hwnd = GetForegroundWindow();
        StringBuilder sb = new StringBuilder(256);
        GetWindowText(hwnd, sb, 256);
        return sb.ToString();
    }
}
"@ -ErrorAction SilentlyContinue
    $result.active_window = [ActiveWindow]::GetActiveWindowTitle()
} catch {}

# ============ SECURITY STATUS ============
# Windows Defender
$result.defender_enabled = $false
$result.defender_realtime = $false
$result.defender_last_scan = ''
$result.defender_definitions_age = 0
try {
    $defender = Get-MpComputerStatus -ErrorAction Stop
    $result.defender_enabled = $defender.AntivirusEnabled
    $result.defender_realtime = $defender.RealTimeProtectionEnabled
    if ($defender.FullScanEndTime) {
        $result.defender_last_scan = $defender.FullScanEndTime.ToString('yyyy-MM-dd HH:mm:ss')
    }
    if ($defender.AntivirusSignatureLastUpdated) {
        $result.defender_definitions_age = [int]((Get-Date) - $defender.AntivirusSignatureLastUpdated).TotalDays
    }
} catch {}

# Firewall status
$result.firewall_enabled = $false
try {
    $fw = Get-NetFirewallProfile -Profile Domain,Public,Private -ErrorAction Stop | Where-Object { $_.Enabled -eq $true }
    $result.firewall_enabled = ($fw.Count -gt 0)
} catch {}

# Pending Windows Updates
$result.pending_updates = @()
$result.pending_updates_count = 0
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    $pendingUpdates = $updateSearcher.Search("IsInstalled=0 and Type='Software'").Updates
    $result.pending_updates_count = $pendingUpdates.Count
    $updates = @()
    foreach ($update in $pendingUpdates | Select-Object -First 10) {
        $updates += @{
            title = $update.Title
            kb = if ($update.KBArticleIDs.Count -gt 0) { "KB$($update.KBArticleIDs[0])" } else { '' }
        }
    }
    $result.pending_updates = $updates
} catch {}

# ============ BATTERY STATUS ============
$result.has_battery = $false
$result.battery_percent = 0
$result.battery_status = ''
$result.battery_time_remaining = 0
$result.is_charging = $false
try {
    $battery = Get-CimInstance Win32_Battery -ErrorAction Stop
    if ($battery) {
        $result.has_battery = $true
        $result.battery_percent = [int]$battery.EstimatedChargeRemaining
        $result.is_charging = ($battery.BatteryStatus -eq 2 -or $battery.BatteryStatus -eq 6)
        $result.battery_time_remaining = if ($battery.EstimatedRunTime -and $battery.EstimatedRunTime -lt 71582788) { 
            [int]$battery.EstimatedRunTime 
        } else { 0 }
        
        switch ($battery.BatteryStatus) {
            1 { $result.battery_status = 'Discharging' }
            2 { $result.battery_status = 'AC Power' }
            3 { $result.battery_status = 'Fully Charged' }
            4 { $result.battery_status = 'Low' }
            5 { $result.battery_status = 'Critical' }
            6 { $result.battery_status = 'Charging' }
            7 { $result.battery_status = 'Charging High' }
            8 { $result.battery_status = 'Charging Low' }
            9 { $result.battery_status = 'Charging Critical' }
            default { $result.battery_status = 'Unknown' }
        }
    }
} catch {}

# ============ INSTALLED PROGRAMS (top 50 by size, most recently installed first) ============
$installedPrograms = @()
try {
    $regPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    
    $apps = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | 
        Where-Object { $_.DisplayName -and $_.DisplayName -notmatch 'Update|Hotfix|KB\d+' } |
        Sort-Object -Property InstallDate -Descending |
        Select-Object -First 50
    
    foreach ($app in $apps) {
        $installedPrograms += @{
            name = $app.DisplayName
            version = if ($app.DisplayVersion) { $app.DisplayVersion } else { '' }
            publisher = if ($app.Publisher) { $app.Publisher } else { '' }
            install_date = if ($app.InstallDate) { $app.InstallDate } else { '' }
            size_mb = if ($app.EstimatedSize) { [math]::Round($app.EstimatedSize / 1024, 1) } else { 0 }
        }
    }
} catch {}
$result.installed_programs = $installedPrograms

# Startup programs
$startupPrograms = @()
try {
    $startup = Get-CimInstance Win32_StartupCommand -ErrorAction Stop
    foreach ($item in $startup) {
        $startupPrograms += @{
            name = $item.Name
            command = $item.Command
            location = $item.Location
        }
    }
} catch {}
$result.startup_programs = $startupPrograms

# ============ ACTIVE NETWORK CONNECTIONS ============
$activeConnections = @()
try {
    $connections = Get-NetTCPConnection -State Established -ErrorAction Stop | 
        Where-Object { $_.RemoteAddress -ne '127.0.0.1' -and $_.RemoteAddress -ne '::1' } |
        Select-Object -First 30
    
    foreach ($conn in $connections) {
        $processName = ''
        try {
            $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
            $processName = $proc.ProcessName
        } catch {}
        
        $activeConnections += @{
            process = $processName
            local_port = $conn.LocalPort
            remote_address = $conn.RemoteAddress
            remote_port = $conn.RemotePort
        }
    }
} catch {}
$result.active_connections = $activeConnections

# Output JSON
$result | ConvertTo-Json -Depth 4 -Compress
''';

    try {
      // Write script to temp file to avoid command line length limits
      final tempDir = Directory.systemTemp;
      final scriptFile = File('${tempDir.path}\\a1tools_metrics.ps1');
      
      debugPrint('[SystemMetrics] Writing script to: ${scriptFile.path}');
      await scriptFile.writeAsString(script);
      
      debugPrint('[SystemMetrics] Executing PowerShell script...');
      
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy', 'Bypass',
          '-File', scriptFile.path,
        ],
        runInShell: false,
      ).timeout(const Duration(seconds: 90));
      
      // Clean up temp file
      try {
        await scriptFile.delete();
      } catch (e) {
        // Ignore cleanup errors
      }
      
      debugPrint('[SystemMetrics] PowerShell exit code: ${result.exitCode}');
      
      if (result.exitCode != 0) {
        debugPrint('[SystemMetrics] PowerShell stderr: ${result.stderr}');
        return null;
      }
      
      final output = result.stdout.toString().trim();
      debugPrint('[SystemMetrics] Output length: ${output.length} chars');
      
      if (output.isEmpty) {
        debugPrint('[SystemMetrics] Empty output, stderr: ${result.stderr}');
        return null;
      }
      
      // Find the JSON object in the output
      final jsonStart = output.indexOf('{');
      final jsonEnd = output.lastIndexOf('}');
      
      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final cleanJson = output.substring(jsonStart, jsonEnd + 1);
        debugPrint('[SystemMetrics] Parsing ${cleanJson.length} chars of JSON...');
        final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;
        debugPrint('[SystemMetrics] âœ“ Parsed: ${parsed['computer_name']}, CPU=${parsed['cpu_usage']}%');
        return parsed;
      } else {
        debugPrint('[SystemMetrics] No JSON found. Output preview: ${output.substring(0, output.length.clamp(0, 300))}');
      }
    } catch (e, stack) {
      debugPrint('[SystemMetrics] âœ— Collection error: $e');
      debugPrint('[SystemMetrics] Stack: $stack');
    }
    
    return null;
  }

  /// Filter out programs that are in the privacy exclusions list
  /// This modifies the metrics map in place
  Future<void> _filterExcludedPrograms(Map<String, dynamic> metrics) async {
    try {
      // Get the list of excluded program names
      final exclusions = await PrivacyExclusionsService.getExcludedProgramNames();

      if (exclusions.isEmpty) {
        debugPrint('[SystemMetrics] No privacy exclusions to filter');
        return;
      }

      debugPrint('[SystemMetrics] Filtering ${exclusions.length} excluded programs: $exclusions');

      // Filter running_apps
      if (metrics['running_apps'] != null && metrics['running_apps'] is List) {
        final originalCount = (metrics['running_apps'] as List).length;
        metrics['running_apps'] = (metrics['running_apps'] as List).where((app) {
          final name = (app['name'] ?? '').toString().toLowerCase();
          return !_matchesExclusion(name, exclusions);
        }).toList();
        final filteredCount = (metrics['running_apps'] as List).length;
        if (originalCount != filteredCount) {
          debugPrint('[SystemMetrics] Filtered running_apps: $originalCount -> $filteredCount');
        }
      }

      // Filter browser_windows
      if (metrics['browser_windows'] != null && metrics['browser_windows'] is List) {
        final originalCount = (metrics['browser_windows'] as List).length;
        metrics['browser_windows'] = (metrics['browser_windows'] as List).where((win) {
          final browser = (win['browser'] ?? '').toString().toLowerCase();
          return !_matchesExclusion(browser, exclusions);
        }).toList();
        final filteredCount = (metrics['browser_windows'] as List).length;
        if (originalCount != filteredCount) {
          debugPrint('[SystemMetrics] Filtered browser_windows: $originalCount -> $filteredCount');
        }
      }

      // Filter processes (top processes by memory)
      if (metrics['processes'] != null && metrics['processes'] is List) {
        final originalCount = (metrics['processes'] as List).length;
        metrics['processes'] = (metrics['processes'] as List).where((proc) {
          final name = (proc['name'] ?? '').toString().toLowerCase();
          return !_matchesExclusion(name, exclusions);
        }).toList();
        final filteredCount = (metrics['processes'] as List).length;
        if (originalCount != filteredCount) {
          debugPrint('[SystemMetrics] Filtered processes: $originalCount -> $filteredCount');
        }
      }

      // Filter active_window if it matches an exclusion
      if (metrics['active_window'] != null) {
        final activeWindow = metrics['active_window'].toString().toLowerCase();
        for (final exclusion in exclusions) {
          if (activeWindow.contains(exclusion)) {
            debugPrint('[SystemMetrics] Hiding active_window (matched: $exclusion)');
            metrics['active_window'] = '[Private]';
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('[SystemMetrics] Error filtering excluded programs: $e');
      // Don't fail the whole submission if filtering fails
    }
  }

  /// Check if a program name matches any exclusion
  bool _matchesExclusion(String programName, List<String> exclusions) {
    final lowerName = programName.toLowerCase();
    for (final exclusion in exclusions) {
      if (lowerName.contains(exclusion) || exclusion.contains(lowerName)) {
        return true;
      }
    }
    return false;
  }
}


/// Lightweight version for quick status checks (no heavy operations)
class SystemMetricsLight {
  /// Get just CPU and memory usage quickly
  static Future<Map<String, double>?> getQuickStats() async {
    if (!Platform.isWindows) return null;
    
    const script = r'''
$os = Get-CimInstance Win32_OperatingSystem
$totalMem = [long]$os.TotalVisibleMemorySize * 1024
$freeMem = [long]$os.FreePhysicalMemory * 1024
$memUsage = [math]::Round((($totalMem - $freeMem) / $totalMem) * 100, 2)
$cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1
$cpuUsage = [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)
Write-Output "$cpuUsage|$memUsage"
''';

    try {
      final tempDir = Directory.systemTemp;
      final scriptFile = File('${tempDir.path}\\a1tools_quick.ps1');
      await scriptFile.writeAsString(script);
      
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', scriptFile.path],
        runInShell: false,
      );
      
      try { await scriptFile.delete(); } catch (e) { debugPrint('[SystemMetricsService] Cleanup error: \$e'); }
      
      if (result.exitCode == 0) {
        final parts = result.stdout.toString().trim().split('|');
        if (parts.length == 2) {
          return {
            'cpu': double.tryParse(parts[0]) ?? 0,
            'memory': double.tryParse(parts[1]) ?? 0,
          };
        }
      }
    } catch (e) {
      debugPrint('[SystemMetricsLight] Error: $e');
    }
    
    return null;
  }
}
