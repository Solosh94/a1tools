import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

/// Employee payroll rate data
class PayrollRate {
  final String username;
  final String displayName;
  final String? role;
  final double? hourlyRate;
  final double? overtimeRate;
  final String? effectiveDate;
  final String? notes;
  final String? updatedBy;
  final String? updatedAt;
  final bool isActive;

  PayrollRate({
    required this.username,
    required this.displayName,
    this.role,
    this.hourlyRate,
    this.overtimeRate,
    this.effectiveDate,
    this.notes,
    this.updatedBy,
    this.updatedAt,
    this.isActive = true,
  });

  factory PayrollRate.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name'] ?? '';
    final lastName = json['last_name'] ?? '';
    final displayName = '$firstName $lastName'.trim();

    return PayrollRate(
      username: json['username'] ?? '',
      displayName: displayName.isNotEmpty ? displayName : json['username'] ?? '',
      role: json['role'],
      hourlyRate: json['hourly_rate'] != null
          ? double.tryParse(json['hourly_rate'].toString())
          : null,
      overtimeRate: json['overtime_rate'] != null
          ? double.tryParse(json['overtime_rate'].toString())
          : null,
      effectiveDate: json['effective_date'],
      notes: json['notes'],
      updatedBy: json['updated_by'],
      updatedAt: json['updated_at'],
      isActive: json['is_active'] == 1 || json['is_active'] == true || json['is_active'] == '1',
    );
  }

  bool get hasRate => hourlyRate != null && hourlyRate! > 0;
}

/// Employee earnings data
class EmployeeEarnings {
  final String username;
  final String displayName;
  final String? role;
  final double hourlyRate;
  final double overtimeRate;
  final double totalHours;
  final double regularHours;
  final double overtimeHours;
  final int daysWorked;
  final double regularPay;
  final double overtimePay;
  final double grossPay;
  final bool rateSet;

  EmployeeEarnings({
    required this.username,
    required this.displayName,
    this.role,
    required this.hourlyRate,
    required this.overtimeRate,
    required this.totalHours,
    required this.regularHours,
    required this.overtimeHours,
    required this.daysWorked,
    required this.regularPay,
    required this.overtimePay,
    required this.grossPay,
    required this.rateSet,
  });

  factory EmployeeEarnings.fromJson(Map<String, dynamic> json) {
    return EmployeeEarnings(
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      role: json['role'],
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 0,
      overtimeRate: (json['overtime_rate'] as num?)?.toDouble() ?? 0,
      totalHours: (json['total_hours'] as num?)?.toDouble() ?? 0,
      regularHours: (json['regular_hours'] as num?)?.toDouble() ?? 0,
      overtimeHours: (json['overtime_hours'] as num?)?.toDouble() ?? 0,
      daysWorked: json['days_worked'] ?? 0,
      regularPay: (json['regular_pay'] as num?)?.toDouble() ?? 0,
      overtimePay: (json['overtime_pay'] as num?)?.toDouble() ?? 0,
      grossPay: (json['gross_pay'] as num?)?.toDouble() ?? 0,
      rateSet: json['rate_set'] == true,
    );
  }
}

/// Earnings report result
class EarningsReport {
  final DateTime from;
  final DateTime to;
  final List<EmployeeEarnings> employees;
  final double totalHours;
  final double totalPayroll;
  final int employeeCount;
  final double avgHourlyRate;

  EarningsReport({
    required this.from,
    required this.to,
    required this.employees,
    required this.totalHours,
    required this.totalPayroll,
    required this.employeeCount,
    required this.avgHourlyRate,
  });

  factory EarningsReport.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] ?? {};
    return EarningsReport(
      from: DateTime.parse(json['from']),
      to: DateTime.parse(json['to']),
      employees: (json['employees'] as List?)
              ?.map((e) => EmployeeEarnings.fromJson(e))
              .toList() ??
          [],
      totalHours: (summary['total_hours'] as num?)?.toDouble() ?? 0,
      totalPayroll: (summary['total_payroll'] as num?)?.toDouble() ?? 0,
      employeeCount: summary['total_employees'] ?? 0,
      avgHourlyRate: (summary['avg_hourly_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Payroll summary with comparison
class PayrollSummary {
  final DateTime from;
  final DateTime to;
  final int periodDays;
  final int employeeCount;
  final int totalRecords;
  final double totalHours;
  final double totalPayroll;
  final double previousHours;
  final double previousPayroll;
  final double hoursChangePercent;
  final double payrollChangePercent;
  final List<TopEarner> topEarners;

  PayrollSummary({
    required this.from,
    required this.to,
    required this.periodDays,
    required this.employeeCount,
    required this.totalRecords,
    required this.totalHours,
    required this.totalPayroll,
    required this.previousHours,
    required this.previousPayroll,
    required this.hoursChangePercent,
    required this.payrollChangePercent,
    required this.topEarners,
  });

  factory PayrollSummary.fromJson(Map<String, dynamic> json) {
    final period = json['period'] ?? {};
    final current = json['current'] ?? {};
    final previous = json['previous'] ?? {};
    final changes = json['changes'] ?? {};

    return PayrollSummary(
      from: DateTime.parse(period['from'] ?? json['from']),
      to: DateTime.parse(period['to'] ?? json['to']),
      periodDays: period['days'] ?? 0,
      employeeCount: current['employee_count'] ?? 0,
      totalRecords: current['total_records'] ?? 0,
      totalHours: (current['total_hours'] as num?)?.toDouble() ?? 0,
      totalPayroll: (current['total_payroll'] as num?)?.toDouble() ?? 0,
      previousHours: (previous['total_hours'] as num?)?.toDouble() ?? 0,
      previousPayroll: (previous['total_payroll'] as num?)?.toDouble() ?? 0,
      hoursChangePercent: (changes['hours_percent'] as num?)?.toDouble() ?? 0,
      payrollChangePercent: (changes['payroll_percent'] as num?)?.toDouble() ?? 0,
      topEarners: (json['top_earners'] as List?)
              ?.map((e) => TopEarner.fromJson(e))
              .toList() ??
          [],
    );
  }
}

/// Top earner data
class TopEarner {
  final String username;
  final String displayName;
  final double hours;
  final double earnings;

  TopEarner({
    required this.username,
    required this.displayName,
    required this.hours,
    required this.earnings,
  });

  factory TopEarner.fromJson(Map<String, dynamic> json) {
    return TopEarner(
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      hours: (json['hours'] as num?)?.toDouble() ?? 0,
      earnings: (json['earnings'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Service for managing payroll data
class PayrollService {
  PayrollService._();
  static final PayrollService instance = PayrollService._();

  static const String _endpoint = ApiConfig.payroll;

  /// Get all employee hourly rates
  Future<List<PayrollRate>> getRates() async {
    try {
      final response = await http.get(
        Uri.parse('$_endpoint?action=rates'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['rates'] != null) {
          return (data['rates'] as List)
              .map((r) => PayrollRate.fromJson(r))
              .toList();
        }
      }
    } catch (e) {
      // Silently fail
    }
    return [];
  }

  /// Set hourly rate for an employee
  Future<bool> setRate({
    required String username,
    required double hourlyRate,
    double? overtimeRate,
    String? effectiveDate,
    String? notes,
    required String updatedBy,
    String? changeReason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_endpoint?action=set_rate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'hourly_rate': hourlyRate,
          'overtime_rate': overtimeRate,
          'effective_date': effectiveDate ?? DateTime.now().toIso8601String().split('T').first,
          'notes': notes,
          'updated_by': updatedBy,
          'change_reason': changeReason,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      // Silently fail
    }
    return false;
  }

  /// Get earnings report for date range
  Future<EarningsReport?> getEarnings({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final fromStr = from.toIso8601String().split('T').first;
      final toStr = to.toIso8601String().split('T').first;

      final response = await http.get(
        Uri.parse('$_endpoint?action=earnings&from=$fromStr&to=$toStr'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return EarningsReport.fromJson(data);
        }
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  /// Get payroll summary with comparison
  Future<PayrollSummary?> getSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final fromStr = from.toIso8601String().split('T').first;
      final toStr = to.toIso8601String().split('T').first;

      final response = await http.get(
        Uri.parse('$_endpoint?action=summary&from=$fromStr&to=$toStr'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return PayrollSummary.fromJson(data);
        }
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }
}
