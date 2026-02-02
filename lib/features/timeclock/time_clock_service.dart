/// Time Clock Service for employee attendance tracking.
///
/// Provides clock in/out functionality, schedule management, and time record
/// operations. Supports role-based requirements where certain roles must
/// clock in before accessing the application.
///
/// ## Usage
///
/// ```dart
/// // Clock in
/// final result = await TimeClockService.clockIn('username');
/// if (result.success) {
///   print('Clocked in at ${result.clockInTime}');
/// }
///
/// // Check status
/// final status = await TimeClockService.getStatus('username');
/// if (status?.isClockedIn == true) {
///   // User is currently clocked in
/// }
///
/// // Clock out
/// await TimeClockService.clockOut('username');
/// ```
///
/// ## Role Requirements
///
/// Use [requiresClockIn] to check if a role needs to clock in:
/// - dispatcher, remote_dispatcher, marketing, manager, admin, developer: Required
/// - technician: Not required (field workers)
library;

import 'dart:async';
import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_client.dart';
import '../../core/repository/repository.dart';
import '../../core/models/app_error.dart';

/// Time Clock Service for employee attendance tracking.
///
/// All methods are static - no instantiation required.
class TimeClockService {
  static const String _baseUrl = ApiConfig.timeClock;
  static final ApiClient _api = ApiClient.instance;
  
  /// Roles that require clock in/out (everyone except technician)
  static const List<String> clockRequiredRoles = [
    'dispatcher',
    'remote_dispatcher',
    'marketing',
    'management',
    'administrator',
    'developer',
  ];
  
  /// Check if a role requires clock in/out
  static bool requiresClockIn(String? role) {
    if (role == null) return false;
    return clockRequiredRoles.contains(role.toLowerCase());
  }
  
  /// Clock in a user
  static Future<ClockResult> clockIn(String username) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=clock_in',
        body: {'username': username},
        timeout: const Duration(seconds: 10),
      );

      if (response.success) {
        final data = response.rawJson ?? {};
        return ClockResult(
          success: true,
          message: data['message'] ?? 'Clocked in',
          recordId: data['record_id'] != null ? int.tryParse(data['record_id'].toString()) : null,
          clockInTime: _tryParseDateTime(data['clock_in_time']),
        );
      } else {
        final data = response.rawJson ?? {};
        return ClockResult(
          success: false,
          message: response.message ?? 'Failed to clock in',
          clockInTime: _tryParseDateTime(data['clock_in_time']),
        );
      }
    } catch (e) {
      debugPrint('[TimeClockService] Clock in error: $e');
      return ClockResult(success: false, message: 'Network error: $e');
    }
  }
  
  /// Clock out a user
  static Future<ClockResult> clockOut(String username, {bool auto = false, String? notes}) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=clock_out',
        body: {
          'username': username,
          'auto': auto,
          'notes': notes,
        },
        timeout: const Duration(seconds: 10),
      );

      if (response.success) {
        final data = response.rawJson ?? {};
        return ClockResult(
          success: true,
          message: data['message'] ?? 'Clocked out',
          recordId: data['record_id'] != null ? int.tryParse(data['record_id'].toString()) : null,
          clockInTime: _tryParseDateTime(data['clock_in_time']),
          clockOutTime: _tryParseDateTime(data['clock_out_time']),
          hoursWorked: (data['hours_worked'] as num?)?.toDouble(),
        );
      } else {
        return ClockResult(
          success: false,
          message: response.message ?? 'Failed to clock out',
        );
      }
    } catch (e) {
      debugPrint('[TimeClockService] Clock out error: $e');
      return ClockResult(success: false, message: 'Network error: $e');
    }
  }
  
  /// Get current clock status
  /// @deprecated Use [getStatusResult] instead for better error handling
  static Future<ClockStatus?> getStatus(String username) async {
    final result = await getStatusResult(username);
    return result.isSuccess ? result.data : null;
  }

  /// Get clock-in status for a user with Result pattern for better error handling
  /// Returns Result.success(ClockStatus) or Result.failure(AppError)
  static Future<Result<ClockStatus>> getStatusResult(String username) async {
    try {
      // Add timestamp for cache-busting
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = '$_baseUrl?action=status&username=${Uri.encodeComponent(username)}&_t=$timestamp';
      debugPrint('[TimeClockService] Getting status from: $url');

      final response = await _api.get(
        url,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
        timeout: const Duration(seconds: 10),
      );

      final data = response.rawJson ?? {};
      debugPrint('[TimeClockService] Parsed: is_clocked_in=${data['is_clocked_in']}, current_record=${data['current_record']}');

      if (response.success) {
        return Result.success(ClockStatus(
          isClockedIn: data['is_clocked_in'] == true,
          currentRecordId: data['current_record']?['id'] != null
              ? int.tryParse(data['current_record']['id'].toString())
              : null,
          clockInTime: _tryParseDateTime(data['current_record']?['clock_in_time']),
          role: data['role'],
          workSchedule: data['work_schedule'] != null
              ? WorkSchedule.fromJson(data['work_schedule'])
              : null,
          todaySchedule: data['today_schedule'] != null
              ? DaySchedule.fromJson(data['today_schedule'])
              : null,
          today: data['today'],
          isTodayOff: data['is_today_off'] == true,
          hasLockScreenException: data['has_lock_screen_exception'] == true,
        ));
      }
      return Result.failure(
        response.error ?? AppError.server(details: response.message ?? 'Failed to get clock status'),
      );
    } catch (e) {
      debugPrint('[TimeClockService] Get status error: $e');
      return Result.failure(AppError.network(details: 'Network error: $e'));
    }
  }
  
  /// Get time records for a user
  /// @deprecated Use [getRecordsResult] instead for better error handling
  static Future<List<TimeRecord>> getRecords(String username, {DateTime? from, DateTime? to}) async {
    final result = await getRecordsResult(username, from: from, to: to);
    return result.isSuccess ? result.data! : [];
  }

  /// Get time records for a user with Result pattern for better error handling
  /// Returns `Result.success(List<TimeRecord>)` or `Result.failure(AppError)`
  static Future<Result<List<TimeRecord>>> getRecordsResult(String username, {DateTime? from, DateTime? to}) async {
    try {
      final fromStr = (from ?? DateTime.now().subtract(const Duration(days: TimeConstants.defaultRecordLookbackDays)))
          .toIso8601String().split('T').first;
      final toStr = (to ?? DateTime.now()).toIso8601String().split('T').first;

      final response = await _api.get(
        '$_baseUrl?action=records&username=${Uri.encodeComponent(username)}&from=$fromStr&to=$toStr',
        timeout: const Duration(seconds: 10),
      );

      if (response.success && response.rawJson?['records'] != null) {
        final records = (response.rawJson!['records'] as List)
            .map((r) => TimeRecord.fromJson(r))
            .toList();
        return Result.success(records);
      }

      // API returned success but no records - this is valid (empty list)
      if (response.success) {
        return Result.success([]);
      }

      return Result.failure(
        response.error ?? AppError.server(details: response.message ?? 'Failed to get time records'),
      );
    } catch (e) {
      debugPrint('[TimeClockService] Get records error: $e');
      return Result.failure(AppError.network(details: 'Network error: $e'));
    }
  }
  
  /// Get all users' time records (for managers)
  /// @deprecated Use [getAllRecordsResult] instead for better error handling
  static Future<AllRecordsResult?> getAllRecords({DateTime? from, DateTime? to}) async {
    final result = await getAllRecordsResult(from: from, to: to);
    return result.isSuccess ? result.data : null;
  }

  /// Get all users' time records with Result pattern for better error handling
  /// Returns Result.success(AllRecordsResult) or Result.failure(AppError)
  static Future<Result<AllRecordsResult>> getAllRecordsResult({DateTime? from, DateTime? to}) async {
    try {
      final fromStr = (from ?? DateTime.now().subtract(const Duration(days: 30)))
          .toIso8601String().split('T').first;
      final toStr = (to ?? DateTime.now()).toIso8601String().split('T').first;

      final response = await _api.get(
        '$_baseUrl?action=all_records&from=$fromStr&to=$toStr',
        timeout: const Duration(seconds: 15),
      );

      if (response.success) {
        final data = response.rawJson ?? {};
        final fromDate = _tryParseDateTime(data['from']);
        final toDate = _tryParseDateTime(data['to']);
        if (fromDate == null || toDate == null) {
          debugPrint('[TimeClockService] Invalid date range in response');
          return Result.failure(AppError.parse(details: 'Invalid date range in response'));
        }
        return Result.success(AllRecordsResult(
          records: (data['records'] as List).map((r) => TimeRecord.fromJson(r)).toList(),
          byUser: (data['by_user'] as List).map((u) => UserSummary.fromJson(u)).toList(),
          from: fromDate,
          to: toDate,
        ));
      }
      return Result.failure(
        response.error ?? AppError.server(details: response.message ?? 'Failed to get all records'),
      );
    } catch (e) {
      debugPrint('[TimeClockService] Get all records error: $e');
      return Result.failure(AppError.network(details: 'Network error: $e'));
    }
  }
  
  /// Get work schedule for a user
  static Future<WorkSchedule?> getSchedule(String username) async {
    try {
      final response = await _api.get(
        '$_baseUrl?action=get_schedule&username=${Uri.encodeComponent(username)}',
        timeout: const Duration(seconds: 10),
      );

      if (response.success && response.rawJson?['work_schedule'] != null) {
        return WorkSchedule.fromJson(response.rawJson!['work_schedule']);
      }
      return null;
    } catch (e) {
      debugPrint('[TimeClockService] Get schedule error: $e');
      return null;
    }
  }
  
  /// Set work schedule for a user
  static Future<bool> setSchedule(String username, WorkSchedule schedule) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=set_schedule',
        body: {
          'username': username,
          'work_schedule': schedule.toJson(),
        },
        timeout: const Duration(seconds: 10),
      );

      return response.success;
    } catch (e) {
      debugPrint('[TimeClockService] Set schedule error: $e');
      return false;
    }
  }
  
  /// Set day status (vacation, sick, absent, etc.)
  static Future<bool> setDayStatus({
    required String username,
    required DateTime date,
    required String status,
    String? notes,
    String? createdBy,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=set_day_status',
        body: {
          'username': username,
          'date': _formatDate(date),
          'status': status,
          'notes': notes,
          'created_by': createdBy,
        },
        timeout: const Duration(seconds: 10),
      );

      return response.success;
    } catch (e) {
      debugPrint('[TimeClockService] Set day status error: $e');
      return false;
    }
  }
  
  /// Get day statuses for a user or all users
  static Future<DayStatusResult?> getDayStatuses({
    String? username,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final params = <String, String>{};
      if (username != null) params['username'] = username;
      if (from != null) params['from'] = _formatDate(from);
      if (to != null) params['to'] = _formatDate(to);

      final uri = Uri.parse('$_baseUrl?action=get_day_statuses')
          .replace(queryParameters: {...params, 'action': 'get_day_statuses'});

      final response = await _api.get(uri.toString(), timeout: const Duration(seconds: 15));

      if (response.success && response.rawJson != null) {
        return DayStatusResult.fromJson(response.rawJson!);
      }
      return null;
    } catch (e) {
      debugPrint('[TimeClockService] Get day statuses error: $e');
      return null;
    }
  }
  
  /// Fill missing days with absent status
  static Future<int> fillMissingDays({
    DateTime? from,
    DateTime? to,
    String? createdBy,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=fill_missing_days',
        body: {
          'from': from != null ? _formatDate(from) : null,
          'to': to != null ? _formatDate(to) : null,
          'created_by': createdBy ?? 'system',
        },
        timeout: const Duration(seconds: 30),
      );

      return response.rawJson?['count'] ?? 0;
    } catch (e) {
      debugPrint('[TimeClockService] Fill missing days error: $e');
      return 0;
    }
  }

  /// Set schedule override for today (self-service)
  static Future<bool> setTodaySchedule({
    required String username,
    required String startTime,
    required String endTime,
    String? reason,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=set_today_schedule',
        body: {
          'username': username,
          'start_time': startTime,
          'end_time': endTime,
          'reason': reason,
        },
        timeout: const Duration(seconds: 10),
      );

      return response.success;
    } catch (e) {
      debugPrint('[TimeClockService] Set today schedule error: $e');
      return false;
    }
  }

  /// Get today's schedule override for a user
  static Future<TodayScheduleOverride?> getTodaySchedule(String username) async {
    try {
      final response = await _api.get(
        '$_baseUrl?action=get_today_schedule&username=${Uri.encodeComponent(username)}',
        timeout: const Duration(seconds: 10),
      );

      final data = response.rawJson ?? {};
      if (response.success && data['has_override'] == true) {
        return TodayScheduleOverride(
          startTime: data['start_time'],
          endTime: data['end_time'],
          reason: data['reason'],
        );
      }
      return null;
    } catch (e) {
      debugPrint('[TimeClockService] Get today schedule error: $e');
      return null;
    }
  }
  
  /// Update notes on a time record
  static Future<bool> updateRecordNotes(int recordId, String notes) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=update_record_notes',
        body: {
          'record_id': recordId,
          'notes': notes,
        },
        timeout: const Duration(seconds: 10),
      );

      return response.success;
    } catch (e) {
      debugPrint('[TimeClockService] Update record notes error: $e');
      return false;
    }
  }
  
  /// Correct a time record (edit clock in/out times)
  /// Only managers, admins, and developers should have access to this
  static Future<CorrectRecordResult> correctRecord({
    required int recordId,
    String? clockIn,
    String? clockOut,
    String? notes,
    required String correctedBy,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=correct_record',
        body: {
          'record_id': recordId,
          'clock_in': clockIn,
          'clock_out': clockOut,
          'notes': notes,
          'corrected_by': correctedBy,
        },
        timeout: const Duration(seconds: 10),
      );

      if (response.success) {
        final data = response.rawJson ?? {};
        return CorrectRecordResult(
          success: true,
          message: data['message'] ?? 'Record corrected',
          record: data['record'] != null ? TimeRecord.fromJson(data['record']) : null,
        );
      } else {
        return CorrectRecordResult(
          success: false,
          message: response.message ?? 'Failed to correct record',
        );
      }
    } catch (e) {
      debugPrint('[TimeClockService] Correct record error: $e');
      return CorrectRecordResult(success: false, message: 'Network error: $e');
    }
  }
  
  /// Create a new time record manually (for managers to add missing days)
  static Future<CreateRecordResult> createRecord({
    required String username,
    required String clockIn,
    String? clockOut,
    String? notes,
    required String createdBy,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=create_record',
        body: {
          'username': username,
          'clock_in': clockIn,
          'clock_out': clockOut,
          'notes': notes,
          'created_by': createdBy,
        },
        timeout: const Duration(seconds: 10),
      );

      if (response.success) {
        final data = response.rawJson ?? {};
        // Parse record_id as int (PHP lastInsertId returns string)
        int? recordId;
        if (data['record_id'] != null) {
          recordId = data['record_id'] is int
              ? data['record_id']
              : int.tryParse(data['record_id'].toString());
        }
        return CreateRecordResult(
          success: true,
          message: data['message'] ?? 'Record created',
          recordId: recordId,
          record: data['record'] != null ? TimeRecord.fromJson(data['record']) : null,
        );
      } else {
        return CreateRecordResult(
          success: false,
          message: response.message ?? 'Failed to create record',
        );
      }
    } catch (e) {
      debugPrint('[TimeClockService] Create record error: $e');
      return CreateRecordResult(success: false, message: 'Network error: $e');
    }
  }

  /// Delete a time record (admin only)
  static Future<DeleteRecordResult> deleteRecord({
    required int recordId,
    required String deletedBy,
    String? reason,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl?action=delete_record',
        body: {
          'record_id': recordId,
          'deleted_by': deletedBy,
          'reason': reason ?? '',
        },
        timeout: const Duration(seconds: 10),
      );

      final data = response.rawJson ?? {};
      return DeleteRecordResult(
        success: response.success,
        message: data['message'] ?? response.message ?? 'Unknown error',
      );
    } catch (e) {
      debugPrint('[TimeClockService] Delete record error: $e');
      return DeleteRecordResult(success: false, message: 'Network error: $e');
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Safely parse a DateTime from dynamic input, returning null on failure
  static DateTime? _tryParseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

}

/// Result of a create record operation
class CreateRecordResult {
  final bool success;
  final String message;
  final int? recordId;
  final TimeRecord? record;

  CreateRecordResult({
    required this.success,
    required this.message,
    this.recordId,
    this.record,
  });
}

/// Result of a delete record operation
class DeleteRecordResult {
  final bool success;
  final String message;

  DeleteRecordResult({
    required this.success,
    required this.message,
  });
}

/// Result of a clock in/out operation
class ClockResult {
  final bool success;
  final String message;
  final int? recordId;
  final DateTime? clockInTime;
  final DateTime? clockOutTime;
  final double? hoursWorked;
  
  ClockResult({
    required this.success,
    required this.message,
    this.recordId,
    this.clockInTime,
    this.clockOutTime,
    this.hoursWorked,
  });
}

/// Result of a record correction operation
class CorrectRecordResult {
  final bool success;
  final String message;
  final TimeRecord? record;
  
  CorrectRecordResult({
    required this.success,
    required this.message,
    this.record,
  });
}

/// Current clock status
class ClockStatus {
  final bool isClockedIn;
  final int? currentRecordId;
  final DateTime? clockInTime;
  final String? role;
  final WorkSchedule? workSchedule;
  final DaySchedule? todaySchedule;
  final String? today;
  final bool _isTodayOff;
  final bool hasLockScreenException;

  ClockStatus({
    required this.isClockedIn,
    this.currentRecordId,
    this.clockInTime,
    this.role,
    this.workSchedule,
    this.todaySchedule,
    this.today,
    bool isTodayOff = false,
    this.hasLockScreenException = false,
  }) : _isTodayOff = isTodayOff;
  
  /// Check if today is a day off
  bool get isTodayOff => _isTodayOff || (todaySchedule?.isOff ?? false);
  
  /// Get scheduled end time for today
  DateTime? get scheduledEndTime {
    if (todaySchedule == null || todaySchedule!.isOff || todaySchedule!.end == null) {
      return null;
    }
    final now = DateTime.now();
    final parts = todaySchedule!.end!.split(':');
    return DateTime(now.year, now.month, now.day, 
        int.parse(parts[0]), int.parse(parts[1]));
  }
  
  /// Check if past scheduled end time
  bool get isPastEndTime {
    final endTime = scheduledEndTime;
    if (endTime == null) return false;
    return DateTime.now().isAfter(endTime);
  }
}

/// Work schedule for a user
class WorkSchedule {
  final DaySchedule? monday;
  final DaySchedule? tuesday;
  final DaySchedule? wednesday;
  final DaySchedule? thursday;
  final DaySchedule? friday;
  final DaySchedule? saturday;
  final DaySchedule? sunday;
  
  WorkSchedule({
    this.monday,
    this.tuesday,
    this.wednesday,
    this.thursday,
    this.friday,
    this.saturday,
    this.sunday,
  });
  
  factory WorkSchedule.fromJson(Map<String, dynamic> json) {
    return WorkSchedule(
      monday: json['monday'] != null ? DaySchedule.fromJson(json['monday']) : null,
      tuesday: json['tuesday'] != null ? DaySchedule.fromJson(json['tuesday']) : null,
      wednesday: json['wednesday'] != null ? DaySchedule.fromJson(json['wednesday']) : null,
      thursday: json['thursday'] != null ? DaySchedule.fromJson(json['thursday']) : null,
      friday: json['friday'] != null ? DaySchedule.fromJson(json['friday']) : null,
      saturday: json['saturday'] != null ? DaySchedule.fromJson(json['saturday']) : null,
      sunday: json['sunday'] != null ? DaySchedule.fromJson(json['sunday']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'monday': monday?.toJson(),
      'tuesday': tuesday?.toJson(),
      'wednesday': wednesday?.toJson(),
      'thursday': thursday?.toJson(),
      'friday': friday?.toJson(),
      'saturday': saturday?.toJson(),
      'sunday': sunday?.toJson(),
    };
  }
  
  DaySchedule? getDay(String day) {
    switch (day.toLowerCase()) {
      case 'monday': return monday;
      case 'tuesday': return tuesday;
      case 'wednesday': return wednesday;
      case 'thursday': return thursday;
      case 'friday': return friday;
      case 'saturday': return saturday;
      case 'sunday': return sunday;
      default: return null;
    }
  }
  
  WorkSchedule copyWith({
    DaySchedule? monday,
    DaySchedule? tuesday,
    DaySchedule? wednesday,
    DaySchedule? thursday,
    DaySchedule? friday,
    DaySchedule? saturday,
    DaySchedule? sunday,
  }) {
    return WorkSchedule(
      monday: monday ?? this.monday,
      tuesday: tuesday ?? this.tuesday,
      wednesday: wednesday ?? this.wednesday,
      thursday: thursday ?? this.thursday,
      friday: friday ?? this.friday,
      saturday: saturday ?? this.saturday,
      sunday: sunday ?? this.sunday,
    );
  }
  
  /// Create a default schedule (Mon-Fri 9-5)
  factory WorkSchedule.defaultSchedule() {
    final workDay = DaySchedule(start: '09:00', end: '17:00', isOff: false);
    final offDay = DaySchedule(start: null, end: null, isOff: true);
    return WorkSchedule(
      monday: workDay,
      tuesday: workDay,
      wednesday: workDay,
      thursday: workDay,
      friday: workDay,
      saturday: offDay,
      sunday: offDay,
    );
  }
}

/// Today's schedule override (for self-service schedule changes)
class TodayScheduleOverride {
  final String startTime; // "09:00" format
  final String endTime;   // "17:00" format
  final String? reason;

  TodayScheduleOverride({
    required this.startTime,
    required this.endTime,
    this.reason,
  });
}

/// Schedule for a single day
class DaySchedule {
  final String? start; // "09:00" format
  final String? end;   // "17:00" format
  final bool isOff;
  
  DaySchedule({
    this.start,
    this.end,
    this.isOff = false,
  });
  
  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    return DaySchedule(
      start: json['start'],
      end: json['end'],
      isOff: json['off'] == true,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'off': isOff,
    };
  }
  
  String get displayText {
    if (isOff) return 'Day Off';
    if (start == null || end == null) return 'Not Set';
    return '$start - $end';
  }
}

/// A single time record
class TimeRecord {
  final int id;
  final String? username;
  final String? firstName;
  final String? lastName;
  final DateTime clockIn;
  final DateTime? clockOut;
  final bool autoClockOut;
  final String? notes;
  final int minutesWorked;
  
  TimeRecord({
    required this.id,
    this.username,
    this.firstName,
    this.lastName,
    required this.clockIn,
    this.clockOut,
    this.autoClockOut = false,
    this.notes,
    this.minutesWorked = 0,
  });
  
  factory TimeRecord.fromJson(Map<String, dynamic> json) {
    // Parse id safely (MySQL may return string)
    int id = 0;
    if (json['id'] != null) {
      id = json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0;
    }

    // Parse minutes_worked safely
    int minutesWorked = 0;
    if (json['minutes_worked'] != null) {
      minutesWorked = json['minutes_worked'] is int
          ? json['minutes_worked']
          : int.tryParse(json['minutes_worked'].toString()) ?? 0;
    }

    // Parse DateTime with timezone handling
    // Server returns local time strings without timezone info, so we parse as local
    // If server returns UTC (with 'Z' suffix), DateTime.parse handles it correctly
    final clockInStr = json['clock_in'] as String;
    final clockIn = DateTime.parse(clockInStr);
    // Convert to local if parsed as UTC (has 'Z' suffix or '+' timezone offset)
    final clockInLocal = clockIn.isUtc ? clockIn.toLocal() : clockIn;

    DateTime? clockOutLocal;
    if (json['clock_out'] != null) {
      final clockOut = DateTime.parse(json['clock_out']);
      clockOutLocal = clockOut.isUtc ? clockOut.toLocal() : clockOut;
    }

    return TimeRecord(
      id: id,
      username: json['username'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      clockIn: clockInLocal,
      clockOut: clockOutLocal,
      autoClockOut: json['auto_clock_out'] == 1 || json['auto_clock_out'] == true || json['auto_clock_out'] == '1',
      notes: json['notes'],
      minutesWorked: minutesWorked,
    );
  }
  
  String get displayName {
    if (firstName != null || lastName != null) {
      return '${firstName ?? ''} ${lastName ?? ''}'.trim();
    }
    return username ?? 'Unknown';
  }
  
  double get hoursWorked => minutesWorked / 60;
  
  String get hoursWorkedFormatted {
    final hours = minutesWorked ~/ 60;
    final mins = minutesWorked % 60;
    return '${hours}h ${mins}m';
  }
}

/// Summary of records for a user
class UserSummary {
  final String username;
  final String displayName;
  final double totalHours;
  final int totalDays;
  final List<TimeRecord> records;
  
  UserSummary({
    required this.username,
    required this.displayName,
    required this.totalHours,
    required this.totalDays,
    required this.records,
  });
  
  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      username: json['username'],
      displayName: json['display_name'] ?? json['username'],
      totalHours: (json['total_hours'] as num).toDouble(),
      totalDays: json['total_days'],
      records: (json['records'] as List).map((r) => TimeRecord.fromJson(r)).toList(),
    );
  }
}

/// Result of getting all records
class AllRecordsResult {
  final List<TimeRecord> records;
  final List<UserSummary> byUser;
  final DateTime from;
  final DateTime to;
  
  AllRecordsResult({
    required this.records,
    required this.byUser,
    required this.from,
    required this.to,
  });
}

/// Day status (vacation, sick, absent, etc.)
class DayStatus {
  final int id;
  final String username;
  final DateTime date;
  final String status; // worked, vacation, sick, absent, holiday, other
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  DayStatus({
    required this.id,
    required this.username,
    required this.date,
    required this.status,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });
  
  factory DayStatus.fromJson(Map<String, dynamic> json) {
    return DayStatus(
      id: json['id'],
      username: json['username'],
      date: DateTime.parse(json['date']),
      status: json['status'],
      notes: json['notes'],
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }
  
  String get statusDisplay {
    switch (status) {
      case 'worked': return 'Worked';
      case 'vacation': return 'Vacation';
      case 'sick': return 'Sick Day';
      case 'absent': return 'Absent';
      case 'holiday': return 'Holiday';
      case 'other': return 'Other';
      default: return status;
    }
  }
  
  Color get statusColor {
    switch (status) {
      case 'worked': return const Color(0xFF4CAF50);
      case 'vacation': return const Color(0xFF2196F3);
      case 'sick': return const Color(0xFFFF9800);
      case 'absent': return const Color(0xFFF44336);
      case 'holiday': return const Color(0xFF9C27B0);
      case 'other': return const Color(0xFF607D8B);
      default: return const Color(0xFF9E9E9E);
    }
  }
}

/// Result of getting day statuses
class DayStatusResult {
  final List<DayStatus> statuses;
  final Map<String, Map<String, DayStatus>> byUser; // username -> date -> status
  final DateTime from;
  final DateTime to;
  
  DayStatusResult({
    required this.statuses,
    required this.byUser,
    required this.from,
    required this.to,
  });
  
  factory DayStatusResult.fromJson(Map<String, dynamic> json) {
    final statuses = (json['statuses'] as List).map((s) => DayStatus.fromJson(s)).toList();
    
    // Convert by_user from JSON to proper map structure
    final byUserJson = json['by_user'] as Map<String, dynamic>? ?? {};
    final byUser = <String, Map<String, DayStatus>>{};
    
    byUserJson.forEach((username, dateMap) {
      byUser[username] = {};
      (dateMap as Map<String, dynamic>).forEach((date, statusJson) {
        byUser[username]![date] = DayStatus.fromJson(statusJson);
      });
    });
    
    return DayStatusResult(
      statuses: statuses,
      byUser: byUser,
      from: DateTime.parse(json['from']),
      to: DateTime.parse(json['to']),
    );
  }
  
  /// Get status for a specific user and date
  DayStatus? getStatus(String username, DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return byUser[username]?[dateStr];
  }
}
