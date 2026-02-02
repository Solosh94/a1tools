// File: lib/metrics/metrics_service.dart
//
// Note: This service uses http directly instead of ApiClient because
// the API returns raw JSON arrays, not wrapped objects.
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

  factory BrowserInfo.fromJson(Map<String, dynamic> json) {
    return BrowserInfo(
      name: json['name'] ?? 'Unknown',
      isRunning: json['isRunning'] == true,
      processCount: int.tryParse(json['processCount']?.toString() ?? '0') ?? 0,
      memoryMb: double.tryParse(json['memoryMb']?.toString() ?? '0') ?? 0.0,
      currentWindow: json['currentWindow'],
      windowTitles: (json['windowTitles'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isRunning': isRunning,
      'processCount': processCount,
      'memoryMb': memoryMb,
      'currentWindow': currentWindow,
      'windowTitles': windowTitles,
    };
  }
}

class ComputerMetrics {
  final String computerName;
  final String username;
  final double cpuUsage;
  final double memoryUsage;
  final double diskUsage;
  final String? osVersion;
  final String? computerUptime;
  final String? windowsUser;
  final String? localIp;
  final String? publicIp;
  final double networkUpload;
  final double networkDownload;
  final double gpuUsage;
  final int processCount;
  final int? batteryLevel;
  final bool? batteryCharging;
  final String? appVersion;
  final String? appUptime;
  final String? currentScreen;
  final double diskFreeGb;
  final double diskTotalGb;
  final bool isAppFocused;
  final int idleTimeSeconds;
  final String? activeWindowTitle;
  final String? foregroundApp;
  final String? topApps;
  final int browserTabsCount;
  final int activeTimeTodaySeconds;
  final String internetStatus;
  final String? connectionType;
  final String? wifiName;
  final bool vpnConnected;
  final int? pingMs;
  final List<BrowserInfo> browserDetails;
  final DateTime lastUpdate;

  ComputerMetrics({
    required this.computerName,
    required this.username,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.diskUsage,
    this.osVersion,
    this.computerUptime,
    this.windowsUser,
    this.localIp,
    this.publicIp,
    required this.networkUpload,
    required this.networkDownload,
    required this.gpuUsage,
    required this.processCount,
    this.batteryLevel,
    this.batteryCharging,
    this.appVersion,
    this.appUptime,
    this.currentScreen,
    required this.diskFreeGb,
    required this.diskTotalGb,
    required this.isAppFocused,
    required this.idleTimeSeconds,
    this.activeWindowTitle,
    this.foregroundApp,
    this.topApps,
    required this.browserTabsCount,
    required this.activeTimeTodaySeconds,
    required this.internetStatus,
    this.connectionType,
    this.wifiName,
    required this.vpnConnected,
    this.pingMs,
    required this.browserDetails,
    required this.lastUpdate,
  });

  factory ComputerMetrics.fromJson(Map<String, dynamic> json) {
    // Parse browser details from JSON string
    List<BrowserInfo> browsers = [];
    if (json['browser_details'] != null) {
      try {
        final browserData = json['browser_details'] is String
            ? jsonDecode(json['browser_details'])
            : json['browser_details'];
        if (browserData is List) {
          browsers = browserData
              .map((b) => BrowserInfo.fromJson(b as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        // Failed to parse browser details, leave empty
        debugPrint('[MetricsService] Error: $e');
      }
    }

    return ComputerMetrics(
      computerName: json['computer_name'] ?? 'Unknown',
      username: json['username'] ?? 'Unknown',
      cpuUsage: double.tryParse(json['cpu_usage']?.toString() ?? '0') ?? 0.0,
      memoryUsage: double.tryParse(json['memory_usage']?.toString() ?? '0') ?? 0.0,
      diskUsage: double.tryParse(json['disk_usage']?.toString() ?? '0') ?? 0.0,
      osVersion: json['os_version'],
      computerUptime: json['computer_uptime'],
      windowsUser: json['windows_user'],
      localIp: json['local_ip'],
      publicIp: json['public_ip'],
      networkUpload: double.tryParse(json['network_upload']?.toString() ?? '0') ?? 0.0,
      networkDownload: double.tryParse(json['network_download']?.toString() ?? '0') ?? 0.0,
      gpuUsage: double.tryParse(json['gpu_usage']?.toString() ?? '0') ?? 0.0,
      processCount: int.tryParse(json['process_count']?.toString() ?? '0') ?? 0,
      batteryLevel: json['battery_level'] != null ? int.tryParse(json['battery_level'].toString()) : null,
      batteryCharging: json['battery_charging'] == 1 || json['battery_charging'] == '1',
      appVersion: json['app_version'],
      appUptime: json['app_uptime'],
      currentScreen: json['current_screen'],
      diskFreeGb: double.tryParse(json['disk_free_gb']?.toString() ?? '0') ?? 0.0,
      diskTotalGb: double.tryParse(json['disk_total_gb']?.toString() ?? '0') ?? 0.0,
      isAppFocused: json['is_app_focused'] == 1 || json['is_app_focused'] == '1',
      idleTimeSeconds: int.tryParse(json['idle_time_seconds']?.toString() ?? '0') ?? 0,
      activeWindowTitle: json['active_window_title'],
      foregroundApp: json['foreground_app'],
      topApps: json['top_apps'],
      browserTabsCount: int.tryParse(json['browser_tabs_count']?.toString() ?? '0') ?? 0,
      activeTimeTodaySeconds: int.tryParse(json['active_time_today_seconds']?.toString() ?? '0') ?? 0,
      internetStatus: json['internet_status'] ?? 'unknown',
      connectionType: json['connection_type'],
      wifiName: json['wifi_name'],
      vpnConnected: json['vpn_connected'] == 1 || json['vpn_connected'] == '1',
      pingMs: json['ping_ms'] != null ? int.tryParse(json['ping_ms'].toString()) : null,
      browserDetails: browsers,
      lastUpdate: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
      'battery_charging': batteryCharging == true ? 1 : 0,
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
      'browser_details': browserDetails.map((b) => b.toJson()).toList(),
      'timestamp': lastUpdate.toIso8601String(),
    };
  }
}

class MetricsService {
  static Future<List<ComputerMetrics>> getAllMetrics() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.metricsAll),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((json) => ComputerMetrics.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch metrics: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching metrics: $e');
    }
  }

  static Future<ComputerMetrics?> getComputerMetrics(String computerName) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.metricsComputer}?name=$computerName'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ComputerMetrics.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to fetch metrics: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching metrics: $e');
    }
  }

  static Future<List<ComputerMetrics>> getComputerHistory(
    String computerName, {
    int minutes = 60,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.metricsComputer}?name=$computerName&history=$minutes'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((json) => ComputerMetrics.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching history: $e');
    }
  }
}
