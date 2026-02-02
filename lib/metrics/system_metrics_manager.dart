// File: lib/metrics/system_metrics_manager.dart
//
// OPTIMIZED VERSION - Uses a single PowerShell call to collect all metrics
// instead of spawning 27+ separate processes every collection cycle.

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class BrowserInfo {
  final String name;
  final bool isRunning;
  final int processCount;
  final double memoryMb;
  final String? currentWindow;
  final List<String> windowTitles;

  BrowserInfo({
    required this.name,
    required this.isRunning,
    required this.processCount,
    required this.memoryMb,
    this.currentWindow,
    required this.windowTitles,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'isRunning': isRunning,
    'processCount': processCount,
    'memoryMb': memoryMb,
    'currentWindow': currentWindow,
    'windowTitles': windowTitles,
  };

  factory BrowserInfo.fromJson(Map<String, dynamic> json) {
    return BrowserInfo(
      name: json['name'] ?? '',
      isRunning: json['isRunning'] ?? false,
      processCount: json['processCount'] ?? 0,
      memoryMb: (json['memoryMb'] ?? 0).toDouble(),
      currentWindow: json['currentWindow'],
      windowTitles: List<String>.from(json['windowTitles'] ?? []),
    );
  }
}

class SystemMetrics {
  final String computerName;
  final String username;
  final double cpuUsage;
  final double memoryUsage;
  final double diskUsage;
  final String osVersion;
  final String computerUptime;
  final String windowsUser;
  final String localIp;
  final String publicIp;
  final double networkUpload;
  final double networkDownload;
  final double gpuUsage;
  final int processCount;
  final int? batteryLevel;
  final bool? batteryCharging;
  final String appVersion;
  final String appUptime;
  final String currentScreen;
  final double diskFreeGb;
  final double diskTotalGb;
  final bool isAppFocused;
  final int idleTimeSeconds;
  final String activeWindowTitle;
  final String foregroundApp;
  final String topApps;
  final int browserTabsCount;
  final int activeTimeTodaySeconds;
  final String internetStatus;
  final String connectionType;
  final String wifiName;
  final bool vpnConnected;
  final int? pingMs;
  final String browserDetails;
  final DateTime timestamp;

  SystemMetrics({
    required this.computerName,
    required this.username,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.diskUsage,
    required this.osVersion,
    required this.computerUptime,
    required this.windowsUser,
    required this.localIp,
    required this.publicIp,
    required this.networkUpload,
    required this.networkDownload,
    required this.gpuUsage,
    required this.processCount,
    this.batteryLevel,
    this.batteryCharging,
    required this.appVersion,
    required this.appUptime,
    required this.currentScreen,
    required this.diskFreeGb,
    required this.diskTotalGb,
    required this.isAppFocused,
    required this.idleTimeSeconds,
    required this.activeWindowTitle,
    required this.foregroundApp,
    required this.topApps,
    required this.browserTabsCount,
    required this.activeTimeTodaySeconds,
    required this.internetStatus,
    required this.connectionType,
    required this.wifiName,
    required this.vpnConnected,
    this.pingMs,
    required this.browserDetails,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'computer_name': computerName,
    'username': username,
    'cpu_usage': cpuUsage,
    'memory_usage': memoryUsage,
    'disk_usage': diskUsage,
    'os_version': osVersion,
    'computer_uptime': computerUptime,
    'windows_user': windowsUser,
    'local_ip': localIp,
    'public_ip': publicIp,
    'network_upload': networkUpload,
    'network_download': networkDownload,
    'gpu_usage': gpuUsage,
    'process_count': processCount,
    'battery_level': batteryLevel,
    'battery_charging': batteryCharging == true ? 1 : (batteryCharging == false ? 0 : null),
    'app_version': appVersion,
    'app_uptime': appUptime,
    'current_screen': currentScreen,
    'disk_free_gb': diskFreeGb,
    'disk_total_gb': diskTotalGb,
    'is_app_focused': isAppFocused ? 1 : 0,
    'idle_time_seconds': idleTimeSeconds,
    'active_window_title': activeWindowTitle,
    'foreground_app': foregroundApp,
    'top_apps': topApps,
    'browser_tabs_count': browserTabsCount,
    'active_time_today_seconds': activeTimeTodaySeconds,
    'internet_status': internetStatus,
    'connection_type': connectionType,
    'wifi_name': wifiName,
    'vpn_connected': vpnConnected ? 1 : 0,
    'ping_ms': pingMs,
    'browser_details': browserDetails,
    'timestamp': timestamp.toIso8601String(),
  };
}

class SystemMetricsManager {
  static DateTime? _appStartTime;
  static String _currentScreen = 'Home';
  static bool _isAppFocused = true;
  
  // Cached static values (don't change during app lifetime)
  static String? _cachedComputerName;
  static String? _cachedOsVersion;
  static String? _cachedWindowsUser;
  
  // Network tracking
  static int _lastBytesReceived = 0;
  static int _lastBytesSent = 0;
  static DateTime? _lastNetworkCheck;
  
  // Active time tracking
  static int _activeTimeTodaySeconds = 0;
  static DateTime? _lastActiveCheck;
  static DateTime? _todayDate;
  
  // Process management - prevent concurrent PowerShell execution
  static bool _isCollecting = false;
  static Process? _currentProcess;
  static const Duration _processTimeout = Duration(seconds: 15);

  static void initialize() {
    _appStartTime ??= DateTime.now();
  }

  static void setCurrentScreen(String screen) {
    _currentScreen = screen;
  }

  static void setAppFocused(bool focused) {
    _isAppFocused = focused;
  }

  /// Collect all metrics using a SINGLE PowerShell process
  /// This replaces the old implementation that spawned 27+ separate processes
  static Future<SystemMetrics> collectMetrics(String username) async {
    initialize();
    _updateActiveTime();
    
    // Prevent concurrent collection
    if (_isCollecting) {
      debugPrint('[SystemMetrics] Collection already in progress, returning cached/default values');
      return _getDefaultMetrics(username);
    }
    
    _isCollecting = true;
    
    try {
      // Collect static values (cached after first call)
      await _ensureStaticValuesCached();
      
      // Get local IP (using Dart, not PowerShell)
      final localIp = await _getLocalIp();
      
      // Get public IP (using HTTP, not PowerShell)
      final publicIp = await _getPublicIp();
      
      // Collect all dynamic metrics in ONE PowerShell call
      final dynamicMetrics = await _collectAllDynamicMetrics();
      
      // Calculate network speeds
      final networkSpeeds = _calculateNetworkSpeeds(
        dynamicMetrics['bytesReceived'] ?? 0,
        dynamicMetrics['bytesSent'] ?? 0,
      );
      
      return SystemMetrics(
        computerName: _cachedComputerName ?? 'Unknown',
        username: username,
        cpuUsage: dynamicMetrics['cpuUsage'] ?? 0.0,
        memoryUsage: dynamicMetrics['memoryUsage'] ?? 0.0,
        diskUsage: dynamicMetrics['diskUsage'] ?? 0.0,
        osVersion: _cachedOsVersion ?? Platform.operatingSystem,
        computerUptime: dynamicMetrics['computerUptime'] ?? 'Unknown',
        windowsUser: _cachedWindowsUser ?? 'Unknown',
        localIp: localIp,
        publicIp: publicIp,
        networkUpload: networkSpeeds['upload'] ?? 0.0,
        networkDownload: networkSpeeds['download'] ?? 0.0,
        gpuUsage: dynamicMetrics['gpuUsage'] ?? 0.0,
        processCount: dynamicMetrics['processCount'] ?? 0,
        batteryLevel: dynamicMetrics['batteryLevel'],
        batteryCharging: dynamicMetrics['batteryCharging'],
        appVersion: await _getAppVersion(),
        appUptime: _getAppUptime(),
        currentScreen: _currentScreen,
        diskFreeGb: dynamicMetrics['diskFreeGb'] ?? 0.0,
        diskTotalGb: dynamicMetrics['diskTotalGb'] ?? 0.0,
        isAppFocused: _isAppFocused,
        idleTimeSeconds: dynamicMetrics['idleTimeSeconds'] ?? 0,
        activeWindowTitle: dynamicMetrics['activeWindowTitle'] ?? '',
        foregroundApp: dynamicMetrics['foregroundApp'] ?? '',
        topApps: dynamicMetrics['topApps'] ?? '',
        browserTabsCount: dynamicMetrics['browserTabsCount'] ?? 0,
        activeTimeTodaySeconds: _activeTimeTodaySeconds,
        internetStatus: dynamicMetrics['internetStatus'] ?? 'unknown',
        connectionType: dynamicMetrics['connectionType'] ?? 'unknown',
        wifiName: dynamicMetrics['wifiName'] ?? '',
        vpnConnected: dynamicMetrics['vpnConnected'] ?? false,
        pingMs: dynamicMetrics['pingMs'],
        browserDetails: dynamicMetrics['browserDetails'] ?? '[]',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[SystemMetrics] Error collecting metrics: $e');
      return _getDefaultMetrics(username);
    } finally {
      _isCollecting = false;
    }
  }
  
  /// Cache static values that don't change during app lifetime
  static Future<void> _ensureStaticValuesCached() async {
    if (_cachedComputerName != null) return;
    
    try {
      if (Platform.isWindows) {
        // Get all static values in one PowerShell call
        final result = await _runPowerShell('''
\$computerName = \$env:COMPUTERNAME
\$osVersion = (Get-WmiObject Win32_OperatingSystem).Caption
\$windowsUser = \$env:USERNAME
Write-Output "\$computerName|\$osVersion|\$windowsUser"
''', timeout: const Duration(seconds: 5));
        
        final parts = result.split('|');
        if (parts.length >= 3) {
          _cachedComputerName = parts[0].trim();
          _cachedOsVersion = parts[1].trim();
          _cachedWindowsUser = parts[2].trim();
        }
      } else {
        _cachedComputerName = Platform.localHostname;
        _cachedOsVersion = Platform.operatingSystem;
        _cachedWindowsUser = Platform.environment['USER'] ?? 'Unknown';
      }
    } catch (e) {
      debugPrint('[SystemMetrics] Error caching static values: $e');
      _cachedComputerName = 'Unknown';
      _cachedOsVersion = Platform.operatingSystem;
      _cachedWindowsUser = 'Unknown';
    }
  }
  
  /// Collect ALL dynamic metrics in a SINGLE PowerShell call
  /// This is the key optimization - one process instead of 27+
  static Future<Map<String, dynamic>> _collectAllDynamicMetrics() async {
    if (!Platform.isWindows) {
      return {};
    }
    
    try {
      // Single comprehensive PowerShell script
      const script = r'''
# Collect all metrics in one script to avoid spawning multiple processes
$results = @{}

# CPU Usage
try {
    $results.cpuUsage = (Get-WmiObject Win32_Processor).LoadPercentage
} catch { $results.cpuUsage = 0 }

# Memory Usage
try {
    $os = Get-WmiObject Win32_OperatingSystem
    $results.memoryUsage = [math]::Round((1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 2)
} catch { $results.memoryUsage = 0 }

# Disk Info
try {
    $d = Get-PSDrive C
    $results.diskUsage = [math]::Round($d.Used / ($d.Used + $d.Free) * 100, 2)
    $results.diskFreeGb = [math]::Round($d.Free/1GB, 2)
    $results.diskTotalGb = [math]::Round(($d.Used + $d.Free)/1GB, 2)
} catch { 
    $results.diskUsage = 0
    $results.diskFreeGb = 0
    $results.diskTotalGb = 0
}

# Computer Uptime
try {
    $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $results.computerUptime = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
} catch { $results.computerUptime = "Unknown" }

# Network Stats
try {
    $n = Get-NetAdapterStatistics | Select-Object -First 1
    $results.bytesReceived = $n.ReceivedBytes
    $results.bytesSent = $n.SentBytes
} catch {
    $results.bytesReceived = 0
    $results.bytesSent = 0
}

# GPU Usage (may not be available on all systems)
try {
    $gpu = (Get-Counter "\GPU Engine(*engtype_3D)\Utilization Percentage" -ErrorAction SilentlyContinue).CounterSamples | 
           Measure-Object -Property CookedValue -Sum
    $results.gpuUsage = if($gpu.Sum -le 100) { [math]::Round($gpu.Sum, 2) } else { 0 }
} catch { $results.gpuUsage = 0 }

# Process Count
try {
    $results.processCount = (Get-Process).Count
} catch { $results.processCount = 0 }

# Battery Info
try {
    $b = Get-WmiObject Win32_Battery
    if ($b) {
        $results.batteryLevel = $b.EstimatedChargeRemaining
        $results.batteryCharging = ($b.BatteryStatus -eq 2)
    } else {
        $results.batteryLevel = $null
        $results.batteryCharging = $null
    }
} catch {
    $results.batteryLevel = $null
    $results.batteryCharging = $null
}

# Idle Time
try {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class IdleTimeHelper {
    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }
    public static int GetIdleSeconds() {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)Marshal.SizeOf(lii);
        GetLastInputInfo(ref lii);
        return (int)((Environment.TickCount - lii.dwTime) / 1000);
    }
}
"@
    $results.idleTimeSeconds = [IdleTimeHelper]::GetIdleSeconds()
} catch { $results.idleTimeSeconds = 0 }

# Active Window Info
try {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class ActiveWindowHelper {
    [DllImport("user32.dll")]
    static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")]
    static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    public static string GetTitle() {
        IntPtr hwnd = GetForegroundWindow();
        StringBuilder sb = new StringBuilder(256);
        GetWindowText(hwnd, sb, 256);
        return sb.ToString();
    }
    public static uint GetPid() {
        IntPtr hwnd = GetForegroundWindow();
        uint pid;
        GetWindowThreadProcessId(hwnd, out pid);
        return pid;
    }
}
"@
    $results.activeWindowTitle = [ActiveWindowHelper]::GetTitle()
    $pid = [ActiveWindowHelper]::GetPid()
    $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
    $results.foregroundApp = if($proc) { $proc.ProcessName } else { "Unknown" }
} catch {
    $results.activeWindowTitle = ""
    $results.foregroundApp = ""
}

# Top Apps (simplified - just names and CPU)
try {
    $topApps = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | 
               ForEach-Object { "$($_.ProcessName):$([math]::Round($_.CPU,1)):$([math]::Round($_.WorkingSet64/1MB,0))" }
    $results.topApps = $topApps -join ","
} catch { $results.topApps = "" }

# Browser Info (simplified - count processes for main browsers)
try {
    $browsers = @()
    $totalBrowserProcs = 0
    
    @('chrome','msedge','firefox','opera') | ForEach-Object {
        $procs = Get-Process $_ -ErrorAction SilentlyContinue
        if ($procs) {
            $count = ($procs | Measure-Object).Count
            $mem = [math]::Round(($procs | Measure-Object WorkingSet64 -Sum).Sum / 1MB, 1)
            $titles = ($procs | Where-Object {$_.MainWindowTitle -ne ""} | 
                      Select-Object -ExpandProperty MainWindowTitle -First 3) -join ";"
            $totalBrowserProcs += $count
            $browsers += @{
                name = $_
                processCount = $count
                memoryMb = $mem
                windowTitles = $titles
            }
        }
    }
    
    $results.browserTabsCount = $totalBrowserProcs
    $results.browserDetails = ($browsers | ConvertTo-Json -Compress)
} catch {
    $results.browserTabsCount = 0
    $results.browserDetails = "[]"
}

# Connectivity Info
try {
    # Ping test
    $ping = Test-Connection -ComputerName 8.8.8.8 -Count 1 -ErrorAction SilentlyContinue
    if ($ping) {
        $results.internetStatus = "online"
        $results.pingMs = $ping.ResponseTime
    } else {
        $results.internetStatus = "offline"
        $results.pingMs = $null
    }
} catch {
    $results.internetStatus = "offline"
    $results.pingMs = $null
}

try {
    # Connection type
    $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    $wifi = $adapters | Where-Object {$_.InterfaceDescription -match "Wi-Fi|Wireless"}
    if ($wifi) {
        $results.connectionType = "wifi"
        $profile = (netsh wlan show interfaces | Select-String "SSID" | Select-Object -First 1) -replace ".*: ",""
        $results.wifiName = $profile.Trim()
    } elseif ($adapters | Where-Object {$_.InterfaceDescription -match "Ethernet|LAN"}) {
        $results.connectionType = "ethernet"
        $results.wifiName = ""
    } else {
        $results.connectionType = "unknown"
        $results.wifiName = ""
    }
} catch {
    $results.connectionType = "unknown"
    $results.wifiName = ""
}

try {
    # VPN check
    $vpnAdapters = Get-NetAdapter | Where-Object {
        $_.InterfaceDescription -match "VPN|TAP|TUN|Cisco|OpenVPN|WireGuard|NordVPN|ExpressVPN|Fortinet" -and 
        $_.Status -eq "Up"
    }
    $results.vpnConnected = ($vpnAdapters -ne $null)
} catch { $results.vpnConnected = $false }

# Output as JSON
$results | ConvertTo-Json -Compress
''';

      final output = await _runPowerShell(script, timeout: _processTimeout);
      
      if (output.isEmpty) {
        debugPrint('[SystemMetrics] Empty output from PowerShell');
        return {};
      }
      
      // Parse JSON output
      try {
        final Map<String, dynamic> data = jsonDecode(output);
        return {
          'cpuUsage': (data['cpuUsage'] ?? 0).toDouble(),
          'memoryUsage': (data['memoryUsage'] ?? 0).toDouble(),
          'diskUsage': (data['diskUsage'] ?? 0).toDouble(),
          'diskFreeGb': (data['diskFreeGb'] ?? 0).toDouble(),
          'diskTotalGb': (data['diskTotalGb'] ?? 0).toDouble(),
          'computerUptime': data['computerUptime'] ?? 'Unknown',
          'bytesReceived': data['bytesReceived'] ?? 0,
          'bytesSent': data['bytesSent'] ?? 0,
          'gpuUsage': (data['gpuUsage'] ?? 0).toDouble(),
          'processCount': data['processCount'] ?? 0,
          'batteryLevel': data['batteryLevel'],
          'batteryCharging': data['batteryCharging'],
          'idleTimeSeconds': data['idleTimeSeconds'] ?? 0,
          'activeWindowTitle': data['activeWindowTitle'] ?? '',
          'foregroundApp': data['foregroundApp'] ?? '',
          'topApps': data['topApps'] ?? '',
          'browserTabsCount': data['browserTabsCount'] ?? 0,
          'browserDetails': data['browserDetails'] ?? '[]',
          'internetStatus': data['internetStatus'] ?? 'unknown',
          'pingMs': data['pingMs'],
          'connectionType': data['connectionType'] ?? 'unknown',
          'wifiName': data['wifiName'] ?? '',
          'vpnConnected': data['vpnConnected'] ?? false,
        };
      } catch (e) {
        debugPrint('[SystemMetrics] Error parsing JSON: $e');
        debugPrint('[SystemMetrics] Raw output: $output');
        return {};
      }
    } catch (e) {
      debugPrint('[SystemMetrics] Error in _collectAllDynamicMetrics: $e');
      return {};
    }
  }
  
  /// Run a PowerShell command with proper timeout and process cleanup
  static Future<String> _runPowerShell(String script, {Duration timeout = const Duration(seconds: 10)}) async {
    Process? process;
    
    try {
      process = await Process.start(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-Command', script],
        mode: ProcessStartMode.normal,
      );
      
      _currentProcess = process;
      
      // Collect output with timeout
      final stdout = StringBuffer();
      final stderr = StringBuffer();
      
      final stdoutFuture = process.stdout.transform(const SystemEncoding().decoder).forEach((data) {
        stdout.write(data);
      });
      
      final stderrFuture = process.stderr.transform(const SystemEncoding().decoder).forEach((data) {
        stderr.write(data);
      });
      
      // Wait for process with timeout
      final exitCode = await process.exitCode.timeout(timeout, onTimeout: () {
        debugPrint('[SystemMetrics] PowerShell process timed out, killing...');
        process?.kill(ProcessSignal.sigkill);
        return -1;
      });
      
      // Wait for output streams to complete
      await Future.wait([stdoutFuture, stderrFuture]).timeout(
        const Duration(seconds: 2),
        onTimeout: () => [],
      );
      
      if (exitCode != 0 && stderr.isNotEmpty) {
        debugPrint('[SystemMetrics] PowerShell stderr: ${stderr.toString().trim()}');
      }
      
      return stdout.toString().trim();
    } catch (e) {
      debugPrint('[SystemMetrics] PowerShell execution error: $e');
      // Make sure to kill the process on error
      try {
        process?.kill(ProcessSignal.sigkill);
      } catch (e) {
  debugPrint('[SystemMetricsManager] Error: $e');
}
      return '';
    } finally {
      _currentProcess = null;
    }
  }

  static void _updateActiveTime() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (_todayDate == null || _todayDate != today) {
      _todayDate = today;
      _activeTimeTodaySeconds = 0;
    }
    
    if (_lastActiveCheck != null && _isAppFocused) {
      final diff = now.difference(_lastActiveCheck!).inSeconds;
      if (diff > 0 && diff < 120) { // Increased tolerance
        _activeTimeTodaySeconds += diff;
      }
    }
    _lastActiveCheck = now;
  }

  static Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
  debugPrint('[SystemMetricsManager] Error: $e');
}
    return 'Unknown';
  }

  static Future<String> _getPublicIp() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.ipLookup),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return response.body.trim();
      }
    } catch (e) {
  debugPrint('[SystemMetricsManager] Error: $e');
}
    return 'Unknown';
  }

  static Map<String, double> _calculateNetworkSpeeds(int bytesReceived, int bytesSent) {
    final now = DateTime.now();
    double downloadSpeed = 0.0;
    double uploadSpeed = 0.0;
    
    if (_lastNetworkCheck != null && _lastBytesReceived > 0) {
      final elapsed = now.difference(_lastNetworkCheck!).inSeconds;
      if (elapsed > 0) {
        downloadSpeed = ((bytesReceived - _lastBytesReceived) / elapsed / 1024 / 1024).abs();
        uploadSpeed = ((bytesSent - _lastBytesSent) / elapsed / 1024 / 1024).abs();
      }
    }
    
    _lastBytesReceived = bytesReceived;
    _lastBytesSent = bytesSent;
    _lastNetworkCheck = now;
    
    return {
      'download': double.parse(downloadSpeed.toStringAsFixed(2)),
      'upload': double.parse(uploadSpeed.toStringAsFixed(2)),
    };
  }

  static Future<String> _getAppVersion() async {
    try {
      const defined = String.fromEnvironment('APP_VERSION');
      if (defined.isNotEmpty) {
        return defined;
      }
    } catch (e) {
  debugPrint('[SystemMetricsManager] Error: $e');
}
    return 'Unknown';
  }

  static String _getAppUptime() {
    if (_appStartTime == null) return 'Unknown';
    final uptime = DateTime.now().difference(_appStartTime!);
    if (uptime.inDays > 0) {
      return '${uptime.inDays}d ${uptime.inHours % 24}h ${uptime.inMinutes % 60}m';
    } else if (uptime.inHours > 0) {
      return '${uptime.inHours}h ${uptime.inMinutes % 60}m';
    } else {
      return '${uptime.inMinutes}m';
    }
  }
  
  /// Get default/fallback metrics when collection fails
  static SystemMetrics _getDefaultMetrics(String username) {
    return SystemMetrics(
      computerName: _cachedComputerName ?? 'Unknown',
      username: username,
      cpuUsage: 0,
      memoryUsage: 0,
      diskUsage: 0,
      osVersion: _cachedOsVersion ?? Platform.operatingSystem,
      computerUptime: 'Unknown',
      windowsUser: _cachedWindowsUser ?? 'Unknown',
      localIp: 'Unknown',
      publicIp: 'Unknown',
      networkUpload: 0,
      networkDownload: 0,
      gpuUsage: 0,
      processCount: 0,
      batteryLevel: null,
      batteryCharging: null,
      appVersion: 'Unknown',
      appUptime: _getAppUptime(),
      currentScreen: _currentScreen,
      diskFreeGb: 0,
      diskTotalGb: 0,
      isAppFocused: _isAppFocused,
      idleTimeSeconds: 0,
      activeWindowTitle: '',
      foregroundApp: '',
      topApps: '',
      browserTabsCount: 0,
      activeTimeTodaySeconds: _activeTimeTodaySeconds,
      internetStatus: 'unknown',
      connectionType: 'unknown',
      wifiName: '',
      vpnConnected: false,
      pingMs: null,
      browserDetails: '[]',
      timestamp: DateTime.now(),
    );
  }
  
  /// Force cleanup of any hanging processes (call on app shutdown)
  static void cleanup() {
    try {
      _currentProcess?.kill(ProcessSignal.sigkill);
    } catch (e) {
  debugPrint('[SystemMetricsManager] Error: $e');
}
    _currentProcess = null;
  }
}
