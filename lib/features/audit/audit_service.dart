// Audit Service
//
// Tracks and logs all sensitive actions in the application for security and compliance.
// Categories include: auth, user, data, admin, system, security

import 'dart:io';
import '../../config/api_config.dart';
import '../../core/services/base_service.dart';

/// Audit log action categories
enum AuditCategory {
  auth('auth'),        // Login, logout, password changes
  user('user'),        // Profile updates, settings changes
  data('data'),        // Data creation, modification, deletion
  admin('admin'),      // Admin operations, user management
  system('system'),    // System operations, exports, backups
  security('security'); // Security events, failed attempts

  final String value;
  const AuditCategory(this.value);
}

/// Audit log entry model
class AuditLogEntry {
  final int id;
  final String username;
  final String action;
  final String category;
  final String? targetType;
  final String? targetId;
  final String? targetName;
  final Map<String, dynamic>? details;
  final String? ipAddress;
  final String? userAgent;
  final String? deviceInfo;
  final bool success;
  final String? errorMessage;
  final DateTime createdAt;

  AuditLogEntry({
    required this.id,
    required this.username,
    required this.action,
    required this.category,
    this.targetType,
    this.targetId,
    this.targetName,
    this.details,
    this.ipAddress,
    this.userAgent,
    this.deviceInfo,
    required this.success,
    this.errorMessage,
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      username: json['username'] ?? '',
      action: json['action'] ?? '',
      category: json['category'] ?? 'general',
      targetType: json['target_type'],
      targetId: json['target_id'],
      targetName: json['target_name'],
      details: json['details'] is Map ? Map<String, dynamic>.from(json['details']) : null,
      ipAddress: json['ip_address'],
      userAgent: json['user_agent'],
      deviceInfo: json['device_info'],
      success: json['success'] == 1 || json['success'] == true,
      errorMessage: json['error_message'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// Get a human-readable description of the action
  String get description {
    final buffer = StringBuffer(action.replaceAll('_', ' ').toUpperCase());
    if (targetName != null && targetName!.isNotEmpty) {
      buffer.write(': $targetName');
    } else if (targetId != null && targetId!.isNotEmpty) {
      buffer.write(': $targetId');
    }
    return buffer.toString();
  }
}

/// Audit statistics
class AuditStats {
  final int periodDays;
  final int totalLogs;
  final int failedActions;
  final double successRate;
  final List<Map<String, dynamic>> byCategory;
  final List<Map<String, dynamic>> topActions;
  final List<Map<String, dynamic>> activeUsers;
  final List<Map<String, dynamic>> dailyActivity;
  final List<Map<String, dynamic>> recentFailures;

  AuditStats({
    required this.periodDays,
    required this.totalLogs,
    required this.failedActions,
    required this.successRate,
    required this.byCategory,
    required this.topActions,
    required this.activeUsers,
    required this.dailyActivity,
    required this.recentFailures,
  });

  factory AuditStats.fromJson(Map<String, dynamic> json) {
    return AuditStats(
      periodDays: json['period_days'] ?? 30,
      totalLogs: json['total_logs'] ?? 0,
      failedActions: json['failed_actions'] ?? 0,
      successRate: (json['success_rate'] ?? 100).toDouble(),
      byCategory: List<Map<String, dynamic>>.from(json['by_category'] ?? []),
      topActions: List<Map<String, dynamic>>.from(json['top_actions'] ?? []),
      activeUsers: List<Map<String, dynamic>>.from(json['active_users'] ?? []),
      dailyActivity: List<Map<String, dynamic>>.from(json['daily_activity'] ?? []),
      recentFailures: List<Map<String, dynamic>>.from(json['recent_failures'] ?? []),
    );
  }
}

/// Paginated audit logs response
class AuditLogsResponse {
  final List<AuditLogEntry> logs;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  AuditLogsResponse({
    required this.logs,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  factory AuditLogsResponse.fromJson(Map<String, dynamic> json) {
    final logsData = json['logs'] as List? ?? [];
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};

    return AuditLogsResponse(
      logs: logsData.map((e) => AuditLogEntry.fromJson(e)).toList(),
      page: pagination['page'] ?? 1,
      limit: pagination['limit'] ?? 50,
      total: pagination['total'] ?? 0,
      totalPages: pagination['total_pages'] ?? 1,
    );
  }
}

/// Service for audit logging
class AuditService extends BaseService {
  static final AuditService _instance = AuditService._();
  static AuditService get instance => _instance;
  AuditService._();

  @override
  String get serviceName => 'AuditService';

  /// Log an action (fire and forget - doesn't block)
  Future<void> logAction({
    required String username,
    required String action,
    AuditCategory category = AuditCategory.system,
    String? targetType,
    String? targetId,
    String? targetName,
    Map<String, dynamic>? details,
    bool success = true,
    String? errorMessage,
  }) async {
    try {
      // Get device info
      String? deviceInfo;
      try {
        deviceInfo = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
      } catch (_) {
        deviceInfo = 'Unknown';
      }

      await api.post(
        ApiConfig.auditLog,
        body: {
          'action': 'log',
          'username': username,
          'action_name': action,
          'category': category.value,
          'target_type': targetType,
          'target_id': targetId,
          'target_name': targetName,
          'details': details,
          'success': success ? 1 : 0,
          'error_message': errorMessage,
          'device_info': deviceInfo,
        },
      );
      log('Logged action: $action for $username');
    } catch (e) {
      // Don't let audit logging failures affect the app
      logError('Failed to log action', e);
    }
  }

  /// Get audit logs with filtering
  Future<AuditLogsResponse> getLogs({
    String? username,
    String? action,
    String? category,
    String? targetType,
    DateTime? startDate,
    DateTime? endDate,
    bool? success,
    String? search,
    int page = 1,
    int limit = 50,
    String sortBy = 'created_at',
    String sortDir = 'DESC',
  }) async {
    final params = <String, String>{
      'action': 'list',
      'page': page.toString(),
      'limit': limit.toString(),
      'sort_by': sortBy,
      'sort_dir': sortDir,
    };

    if (username != null) params['username'] = username;
    if (action != null) params['filter_action'] = action;
    if (category != null) params['category'] = category;
    if (targetType != null) params['target_type'] = targetType;
    if (startDate != null) params['start_date'] = _formatDate(startDate);
    if (endDate != null) params['end_date'] = _formatDate(endDate);
    if (success != null) params['success'] = success ? '1' : '0';
    if (search != null) params['search'] = search;

    final url = '${ApiConfig.auditLog}?${_buildQueryString(params)}';
    final response = await api.get(url);

    if (response.success && response.rawJson != null) {
      final data = response.rawJson!['data'] ?? response.rawJson;
      return AuditLogsResponse.fromJson(data);
    }

    return AuditLogsResponse(
      logs: [],
      page: page,
      limit: limit,
      total: 0,
      totalPages: 0,
    );
  }

  /// Get audit statistics
  Future<AuditStats?> getStats({int days = 30, String? username}) async {
    final params = <String, String>{
      'action': 'stats',
      'days': days.toString(),
    };
    if (username != null) params['username'] = username;

    final url = '${ApiConfig.auditLog}?${_buildQueryString(params)}';
    final response = await api.get(url);

    if (response.success && response.rawJson != null) {
      final data = response.rawJson!['data'] ?? response.rawJson;
      return AuditStats.fromJson(data);
    }

    return null;
  }

  /// Get distinct categories
  Future<List<String>> getCategories() async {
    final response = await api.get('${ApiConfig.auditLog}?action=categories');
    if (response.success && response.rawJson != null) {
      final data = response.rawJson!['data'] ?? response.rawJson;
      return List<String>.from(data['categories'] ?? []);
    }
    return [];
  }

  /// Get distinct actions for a category
  Future<List<String>> getActions({String? category}) async {
    var url = '${ApiConfig.auditLog}?action=actions';
    if (category != null) url += '&category=$category';

    final response = await api.get(url);
    if (response.success && response.rawJson != null) {
      final data = response.rawJson!['data'] ?? response.rawJson;
      return List<String>.from(data['actions'] ?? []);
    }
    return [];
  }

  /// Export logs to CSV
  Future<String?> exportLogs({
    required String requestingUser,
    String? username,
    String? action,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await api.post(
      ApiConfig.auditLog,
      body: {
        'action': 'export',
        'requesting_user': requestingUser,
        'username': username,
        'filter_action': action,
        'category': category,
        'start_date': startDate != null ? _formatDate(startDate) : null,
        'end_date': endDate != null ? _formatDate(endDate) : null,
      },
    );

    if (response.success && response.rawJson != null) {
      final data = response.rawJson!['data'] ?? response.rawJson;
      return data['csv'] as String?;
    }

    return null;
  }

  // ============================================
  // Convenience methods for common actions
  // ============================================

  /// Log a login event
  Future<void> logLogin(String username, {bool success = true, String? errorMessage}) =>
      logAction(
        username: username,
        action: 'login',
        category: AuditCategory.auth,
        success: success,
        errorMessage: errorMessage,
      );

  /// Log a logout event
  Future<void> logLogout(String username) =>
      logAction(
        username: username,
        action: 'logout',
        category: AuditCategory.auth,
      );

  /// Log a password change
  Future<void> logPasswordChange(String username, {bool success = true}) =>
      logAction(
        username: username,
        action: 'password_change',
        category: AuditCategory.auth,
        success: success,
      );

  /// Log a data creation
  Future<void> logCreate(
    String username, {
    required String targetType,
    required String targetId,
    String? targetName,
    Map<String, dynamic>? details,
  }) =>
      logAction(
        username: username,
        action: 'create',
        category: AuditCategory.data,
        targetType: targetType,
        targetId: targetId,
        targetName: targetName,
        details: details,
      );

  /// Log a data update
  Future<void> logUpdate(
    String username, {
    required String targetType,
    required String targetId,
    String? targetName,
    Map<String, dynamic>? changes,
  }) =>
      logAction(
        username: username,
        action: 'update',
        category: AuditCategory.data,
        targetType: targetType,
        targetId: targetId,
        targetName: targetName,
        details: changes,
      );

  /// Log a data deletion
  Future<void> logDelete(
    String username, {
    required String targetType,
    required String targetId,
    String? targetName,
  }) =>
      logAction(
        username: username,
        action: 'delete',
        category: AuditCategory.data,
        targetType: targetType,
        targetId: targetId,
        targetName: targetName,
      );

  /// Log an admin action
  Future<void> logAdminAction(
    String username, {
    required String action,
    String? targetType,
    String? targetId,
    String? targetName,
    Map<String, dynamic>? details,
  }) =>
      logAction(
        username: username,
        action: action,
        category: AuditCategory.admin,
        targetType: targetType,
        targetId: targetId,
        targetName: targetName,
        details: details,
      );

  /// Log a security event
  Future<void> logSecurityEvent(
    String username, {
    required String action,
    bool success = true,
    String? errorMessage,
    Map<String, dynamic>? details,
  }) =>
      logAction(
        username: username,
        action: action,
        category: AuditCategory.security,
        success: success,
        errorMessage: errorMessage,
        details: details,
      );

  // Helper methods
  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _buildQueryString(Map<String, String> params) =>
      params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
}
