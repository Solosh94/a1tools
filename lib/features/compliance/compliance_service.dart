/// Compliance monitoring service for employee activity tracking.
///
/// Sends periodic heartbeats to the server to verify employee activity.
/// The server uses these heartbeats to automatically clock out inactive users,
/// ensuring accurate time records and compliance with work hour policies.
///
/// ## Usage
///
/// ```dart
/// // Start monitoring for a user
/// await ComplianceService.instance.start('username');
///
/// // Stop monitoring
/// ComplianceService.instance.stop();
///
/// // Check if running
/// if (ComplianceService.instance.isRunning) {
///   print('Monitoring ${ComplianceService.instance.username}');
/// }
/// ```
///
/// ## Server Integration
///
/// The server can:
/// - Track user activity via heartbeats
/// - Auto clock-out users after configurable inactivity periods
/// - Extend timeouts for specific users
/// - Log all compliance events
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';

/// Compliance Service for employee activity monitoring.
///
/// Singleton service accessed via [ComplianceService.instance].
/// Sends heartbeats every 2 minutes while active.
class ComplianceService {
  static String get _baseUrl => ApiConfig.compliance;
  static const Duration _heartbeatInterval = Duration(minutes: 2);
  static final ApiClient _api = ApiClient.instance;

  static ComplianceService? _instance;
  static ComplianceService get instance => _instance ??= ComplianceService._();

  ComplianceService._();

  Timer? _heartbeatTimer;
  String? _username;
  bool _isRunning = false;
  String? _appVersion;

  bool get isRunning => _isRunning;
  String? get username => _username;

  /// Start sending heartbeats for the given user
  Future<void> start(String username) async {
    if (_isRunning && _username == username) {
      debugPrint('[ComplianceService] Already running for $username');
      return;
    }

    stop(); // Stop any existing timer

    _username = username;
    _isRunning = true;

    // Get app version once at start
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
    } catch (e) {
      debugPrint('[ComplianceService] Could not get app version: $e');
      _appVersion = 'unknown';
    }

    debugPrint('[ComplianceService] Starting heartbeat for $username');

    // Send immediate heartbeat
    _sendHeartbeat();

    // Schedule periodic heartbeats
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeat();
    });
  }

  /// Stop sending heartbeats
  void stop() {
    debugPrint('[ComplianceService] Stopping heartbeat');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isRunning = false;
    _username = null;
    _appVersion = null;
  }

  /// Send a single heartbeat to the server
  Future<void> _sendHeartbeat() async {
    if (_username == null) return;

    try {
      final response = await _api.post(
        '$_baseUrl?action=heartbeat',
        body: {
          'username': _username,
          'computer_name': Platform.localHostname,
          'app_version': _appVersion ?? 'unknown',
          'platform': Platform.operatingSystem,
        },
        timeout: const Duration(seconds: 10),
      );

      if (response.success) {
        debugPrint('[ComplianceService] Heartbeat sent successfully');
      } else {
        debugPrint('[ComplianceService] Heartbeat failed: ${response.message}');
      }
    } catch (e) {
      debugPrint('[ComplianceService] Heartbeat error: $e');
    }
  }

  /// Get compliance status for all users (for management screen)
  static Future<ComplianceStatusResult?> getStatus() async {
    try {
      final response = await _api.get(
        '$_baseUrl?action=status',
        timeout: const Duration(seconds: 15),
      );

      if (response.success && response.rawJson != null) {
        return ComplianceStatusResult.fromJson(response.rawJson!);
      }
      return null;
    } catch (e) {
      debugPrint('[ComplianceService] Get status error: $e');
      return null;
    }
  }

  /// Get compliance settings
  static Future<ComplianceSettings?> getSettings() async {
    try {
      final response = await _api.get(
        '$_baseUrl?action=settings',
        timeout: const Duration(seconds: 10),
      );

      if (response.success && response.rawJson?['settings'] != null) {
        return ComplianceSettings.fromJson(response.rawJson!['settings']);
      }
      return null;
    } catch (e) {
      debugPrint('[ComplianceService] Get settings error: $e');
      return null;
    }
  }

  /// Update compliance settings
  static Future<bool> updateSettings({
    required int heartbeatTimeoutMinutes,
    required int gracePeriodMinutes,
    required bool enabled,
    required bool notifyOnAutoClockout,
    required String updatedBy,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=update_settings',
        body: {
          'heartbeat_timeout_minutes': heartbeatTimeoutMinutes,
          'grace_period_after_shift_minutes': gracePeriodMinutes,
          'enabled': enabled ? '1' : '0',
          'notify_on_auto_clockout': notifyOnAutoClockout ? '1' : '0',
          'updated_by': updatedBy,
        },
        timeout: const Duration(seconds: 10),
      );

      return response.success;
    } catch (e) {
      debugPrint('[ComplianceService] Update settings error: $e');
      return false;
    }
  }

  /// Extend timeout for a user
  static Future<bool> extendTimeout({
    required String username,
    required int minutes,
    required String extendedBy,
    String? reason,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=extend_timeout',
        body: {
          'username': username,
          'minutes': minutes,
          'extended_by': extendedBy,
          'reason': reason ?? '',
        },
        timeout: const Duration(seconds: 10),
      );

      return response.success;
    } catch (e) {
      debugPrint('[ComplianceService] Extend timeout error: $e');
      return false;
    }
  }

  /// Get compliance logs
  static Future<List<ComplianceLog>> getLogs({
    String? username,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    try {
      var url = '$_baseUrl?action=logs&limit=$limit';
      if (username != null) url += '&username=$username';
      if (from != null) url += '&from=${_formatDate(from)}';
      if (to != null) url += '&to=${_formatDate(to)}';

      final response = await _api.get(
        url,
        timeout: const Duration(seconds: 15),
      );

      if (response.success && response.rawJson?['logs'] != null) {
        return (response.rawJson!['logs'] as List)
            .map((l) => ComplianceLog.fromJson(l))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ComplianceService] Get logs error: $e');
      return [];
    }
  }

  /// Manually trigger compliance check (for testing/admin)
  static Future<Map<String, dynamic>?> checkCompliance() async {
    try {
      final response = await _api.get(
        '$_baseUrl?action=check_compliance',
        timeout: const Duration(seconds: 30),
      );

      if (response.success) {
        return response.rawJson;
      }
      return null;
    } catch (e) {
      debugPrint('[ComplianceService] Check compliance error: $e');
      return null;
    }
  }

  /// Delete a single compliance log entry
  static Future<bool> deleteLog({
    required int logId,
    required String deletedBy,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=delete_log',
        body: {
          'id': logId,
          'deleted_by': deletedBy,
        },
        timeout: const Duration(seconds: 10),
      );

      return response.success;
    } catch (e) {
      debugPrint('[ComplianceService] Delete log error: $e');
      return false;
    }
  }

  /// Clear compliance logs
  static Future<ClearLogsResult> clearLogs({
    required String clearedBy,
    int? olderThanDays,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=clear_logs',
        body: {
          'cleared_by': clearedBy,
          if (olderThanDays != null) 'older_than_days': olderThanDays,
        },
        timeout: const Duration(seconds: 15),
      );

      return ClearLogsResult(
        success: response.success,
        deletedCount: response.rawJson?['deleted_count'] ?? 0,
        message: response.message ?? response.rawJson?['error'] ?? 'Unknown error',
      );
    } catch (e) {
      debugPrint('[ComplianceService] Clear logs error: $e');
      return ClearLogsResult(success: false, deletedCount: 0, message: e.toString());
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Compliance status result
class ComplianceStatusResult {
  final ComplianceSettings settings;
  final String serverTime;
  final List<UserComplianceStatus> users;

  ComplianceStatusResult({
    required this.settings,
    required this.serverTime,
    required this.users,
  });

  factory ComplianceStatusResult.fromJson(Map<String, dynamic> json) {
    return ComplianceStatusResult(
      settings: ComplianceSettings.fromJson(json['settings']),
      serverTime: json['server_time'] ?? '',
      users: (json['users'] as List?)
          ?.map((u) => UserComplianceStatus.fromJson(u))
          .toList() ?? [],
    );
  }
}

/// Compliance settings
class ComplianceSettings {
  final int heartbeatTimeoutMinutes;
  final int gracePeriodMinutes;
  final bool enabled;
  final bool notifyOnAutoClockout;

  ComplianceSettings({
    required this.heartbeatTimeoutMinutes,
    required this.gracePeriodMinutes,
    required this.enabled,
    required this.notifyOnAutoClockout,
  });

  factory ComplianceSettings.fromJson(Map<String, dynamic> json) {
    return ComplianceSettings(
      heartbeatTimeoutMinutes: json['heartbeat_timeout_minutes'] ?? 20,
      gracePeriodMinutes: json['grace_period_after_shift_minutes'] ?? 30,
      enabled: json['enabled'] == true || json['enabled'] == 1 || json['enabled'] == '1',
      notifyOnAutoClockout: json['notify_on_auto_clockout'] == true || json['notify_on_auto_clockout'] == 1 || json['notify_on_auto_clockout'] == '1',
    );
  }
}

/// User compliance status
class UserComplianceStatus {
  final String username;
  final String displayName;
  final String role;
  final DateTime clockIn;
  final DateTime? lastHeartbeat;
  final int? minutesSinceHeartbeat;
  final String status; // online, active, warning, critical, no_heartbeat
  final String? computerName;
  final String? platform;
  final String? scheduledEnd;
  final bool isExtended;
  final DateTime? extendedUntil;
  final String? extendedBy;
  final String? extensionReason;
  final int timeoutMinutes;

  UserComplianceStatus({
    required this.username,
    required this.displayName,
    required this.role,
    required this.clockIn,
    this.lastHeartbeat,
    this.minutesSinceHeartbeat,
    required this.status,
    this.computerName,
    this.platform,
    this.scheduledEnd,
    required this.isExtended,
    this.extendedUntil,
    this.extendedBy,
    this.extensionReason,
    required this.timeoutMinutes,
  });

  factory UserComplianceStatus.fromJson(Map<String, dynamic> json) {
    return UserComplianceStatus(
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      role: json['role'] ?? '',
      clockIn: DateTime.parse(json['clock_in']),
      lastHeartbeat: json['last_heartbeat'] != null ? DateTime.parse(json['last_heartbeat']) : null,
      minutesSinceHeartbeat: json['minutes_since_heartbeat'],
      status: json['status'] ?? 'unknown',
      computerName: json['computer_name'],
      platform: json['platform'],
      scheduledEnd: json['scheduled_end'],
      isExtended: json['is_extended'] == true,
      extendedUntil: json['extended_until'] != null ? DateTime.parse(json['extended_until']) : null,
      extendedBy: json['extended_by'],
      extensionReason: json['extension_reason'],
      timeoutMinutes: json['timeout_minutes'] ?? 20,
    );
  }

  /// Get status color
  int get statusColor {
    switch (status) {
      case 'online':
        return 0xFF4CAF50; // Green
      case 'active':
        return 0xFF8BC34A; // Light green
      case 'warning':
        return 0xFFFF9800; // Orange
      case 'critical':
        return 0xFFF44336; // Red
      case 'no_heartbeat':
        return 0xFF9E9E9E; // Grey
      default:
        return 0xFF9E9E9E;
    }
  }

  /// Get status text
  String get statusText {
    if (isExtended) return 'Extended';
    switch (status) {
      case 'online':
        return 'Online';
      case 'active':
        return 'Active';
      case 'warning':
        return 'Warning';
      case 'critical':
        return 'Critical';
      case 'no_heartbeat':
        return 'No Signal';
      default:
        return 'Unknown';
    }
  }

  /// Time until auto clock-out
  int? get minutesUntilTimeout {
    if (minutesSinceHeartbeat == null) return null;
    if (isExtended && extendedUntil != null) {
      final diff = extendedUntil!.difference(DateTime.now());
      return diff.inMinutes;
    }
    return timeoutMinutes - minutesSinceHeartbeat!;
  }
}

/// Compliance log entry
class ComplianceLog {
  final int id;
  final String username;
  final String displayName;
  final String actionType;
  final String? reason;
  final int? minutesInactive;
  final String? performedBy;
  final DateTime createdAt;

  ComplianceLog({
    required this.id,
    required this.username,
    required this.displayName,
    required this.actionType,
    this.reason,
    this.minutesInactive,
    this.performedBy,
    required this.createdAt,
  });

  factory ComplianceLog.fromJson(Map<String, dynamic> json) {
    return ComplianceLog(
      id: json['id'],
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      actionType: json['action_type'] ?? '',
      reason: json['reason'],
      minutesInactive: json['minutes_inactive'],
      performedBy: json['performed_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  String get actionTypeDisplay {
    switch (actionType) {
      case 'auto_clock_out':
        return 'Auto Clock-Out';
      case 'timeout_extended':
        return 'Timeout Extended';
      case 'manual_clock_out':
        return 'Manual Clock-Out';
      case 'warning_sent':
        return 'Warning Sent';
      default:
        return actionType;
    }
  }
}

/// Result of clearing logs
class ClearLogsResult {
  final bool success;
  final int deletedCount;
  final String message;

  ClearLogsResult({
    required this.success,
    required this.deletedCount,
    required this.message,
  });
}
