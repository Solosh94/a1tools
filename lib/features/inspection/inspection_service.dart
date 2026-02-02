// Inspection Service
//
// Handles all API communication for the inspection system.

import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import '../../core/services/api_client.dart';
import 'inspection_models.dart';

class InspectionService {
  static const String _baseUrl = ApiConfig.inspections;

  /// Singleton instance
  static final InspectionService _instance = InspectionService._();
  static InspectionService get instance => _instance;
  InspectionService._();

  final ApiClient _api = ApiClient.instance;

  /// Maximum number of photos allowed per inspection
  static const int maxPhotosPerInspection = 50;

  /// Maximum address length
  static const int maxAddressLength = 500;

  /// Validate inspection data before submission
  /// Returns null if valid, or an error message if invalid
  String? _validateInspection({
    required String username,
    required String address,
    required String chimneyType,
    required String condition,
    required String issues,
    required String jobCategory,
    required String jobType,
    required String completionStatus,
    required DateTime startTime,
    required DateTime endTime,
    List<PendingPhoto>? photos,
  }) {
    // Required field validation
    if (username.trim().isEmpty) {
      return 'Username is required';
    }
    if (address.trim().isEmpty) {
      return 'Address is required';
    }
    if (address.length > maxAddressLength) {
      return 'Address is too long (max $maxAddressLength characters)';
    }
    if (chimneyType.trim().isEmpty) {
      return 'Chimney type is required';
    }
    if (condition.trim().isEmpty) {
      return 'Condition is required';
    }
    if (issues.trim().isEmpty) {
      return 'Issues field is required';
    }
    if (jobCategory.trim().isEmpty) {
      return 'Job category is required';
    }
    if (jobType.trim().isEmpty) {
      return 'Job type is required';
    }
    if (completionStatus.trim().isEmpty) {
      return 'Completion status is required';
    }

    // Time validation
    if (endTime.isBefore(startTime)) {
      return 'End time cannot be before start time';
    }
    final duration = endTime.difference(startTime);
    if (duration.inHours > 24) {
      return 'Inspection duration cannot exceed 24 hours';
    }

    // Photo validation
    if (photos != null && photos.length > maxPhotosPerInspection) {
      return 'Too many photos (max $maxPhotosPerInspection allowed)';
    }

    return null; // Valid
  }

  /// Submit a new inspection
  Future<InspectionResult> submitInspection({
    required String username,
    required String firstName,
    required String lastName,
    required String address,
    String? state,
    String? zipCode,
    required String chimneyType,
    required String condition,
    String? description,
    required String issues,
    String? recommendations,
    String? customerName,
    String? customerPhone,
    required String jobCategory,
    required String jobType,
    required String completionStatus,
    required DateTime startTime,
    required DateTime endTime,
    required DateTime localSubmitTime,
    required bool discountUsed,
    List<PendingPhoto>? photos,
  }) async {
    // Validate inputs before submitting
    final validationError = _validateInspection(
      username: username,
      address: address,
      chimneyType: chimneyType,
      condition: condition,
      issues: issues,
      jobCategory: jobCategory,
      jobType: jobType,
      completionStatus: completionStatus,
      startTime: startTime,
      endTime: endTime,
      photos: photos,
    );

    if (validationError != null) {
      debugPrint('[InspectionService] Validation failed: $validationError');
      return InspectionResult(success: false, error: validationError);
    }

    try {
      final body = {
        'action': 'create',
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'address': address,
        'state': state ?? '',
        'zip_code': zipCode ?? '',
        'chimney_type': chimneyType,
        'condition': condition,
        'description': description ?? '',
        'issues': issues,
        'recommendations': recommendations ?? '',
        'customer_name': customerName ?? '',
        'customer_phone': customerPhone ?? '',
        'job_category': jobCategory,
        'job_type': jobType,
        'completion_status': completionStatus,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'local_submit_time': localSubmitTime.toIso8601String(),
        'discount_used': discountUsed,
        'photos': photos?.map((p) => p.toJson()).toList() ?? [],
      };

      debugPrint('[InspectionService] Submitting inspection for $username at $address');

      final response = await _api.post(
        _baseUrl,
        body: body,
        timeout: const Duration(seconds: 60), // Longer timeout for photo uploads
      );

      if (response.success) {
        debugPrint('[InspectionService] Inspection submitted successfully');
        final inspection = response.rawJson?['inspection'] != null
            ? Inspection.fromJson(response.rawJson!['inspection'])
            : null;
        return InspectionResult(success: true, inspection: inspection);
      } else {
        debugPrint('[InspectionService] Submit failed: ${response.message}');
        return InspectionResult(
          success: false,
          error: response.message ?? 'Failed to submit inspection',
        );
      }
    } catch (e) {
      debugPrint('[InspectionService] Submit error: $e');
      return InspectionResult(success: false, error: e.toString());
    }
  }

  /// Get list of inspections for a user
  Future<List<Inspection>> getInspections({
    required String username,
    int? limit,
    int? offset,
  }) async {
    try {
      var url = '$_baseUrl?action=list&username=${Uri.encodeComponent(username)}';
      if (limit != null) url += '&limit=$limit';
      if (offset != null) url += '&offset=$offset';

      final response = await _api.get(url, timeout: const Duration(seconds: 15));

      if (response.success && response.rawJson?['inspections'] != null) {
        return (response.rawJson!['inspections'] as List)
            .map((i) => Inspection.fromJson(i))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[InspectionService] Get inspections error: $e');
      return [];
    }
  }

  /// Get all inspections (for admin/manager view)
  Future<List<Inspection>> getAllInspections({
    int? limit,
    int? offset,
    String? filterType,
    String? filterCondition,
    String? filterCategory,
    String? filterStatus,
    String? filterTechnician,
    String? filterCustomer,
  }) async {
    try {
      var url = '$_baseUrl?action=list_all';
      if (limit != null) url += '&limit=$limit';
      if (offset != null) url += '&offset=$offset';
      if (filterType != null) url += '&chimney_type=${Uri.encodeComponent(filterType)}';
      if (filterCondition != null) url += '&condition=${Uri.encodeComponent(filterCondition)}';
      if (filterCategory != null) url += '&job_category=${Uri.encodeComponent(filterCategory)}';
      if (filterStatus != null) url += '&completion_status=${Uri.encodeComponent(filterStatus)}';
      if (filterTechnician != null) url += '&technician=${Uri.encodeComponent(filterTechnician)}';
      if (filterCustomer != null) url += '&customer=${Uri.encodeComponent(filterCustomer)}';

      final response = await _api.get(url, timeout: const Duration(seconds: 15));

      if (response.success && response.rawJson?['inspections'] != null) {
        return (response.rawJson!['inspections'] as List)
            .map((i) => Inspection.fromJson(i))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[InspectionService] Get all inspections error: $e');
      return [];
    }
  }

  /// Get list of technicians who have submitted inspections
  Future<List<TechnicianInfo>> getTechniciansWithInspections() async {
    try {
      final response = await _api.get(
        '$_baseUrl?action=technicians',
        timeout: const Duration(seconds: 15),
      );

      if (response.success && response.rawJson?['technicians'] != null) {
        return (response.rawJson!['technicians'] as List)
            .map((t) => TechnicianInfo.fromJson(t))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[InspectionService] Get technicians error: $e');
      return [];
    }
  }

  /// Get list of customers who have inspections
  Future<List<String>> getCustomersWithInspections() async {
    try {
      final response = await _api.get(
        '$_baseUrl?action=customers',
        timeout: const Duration(seconds: 15),
      );

      if (response.success && response.rawJson?['customers'] != null) {
        final customers = response.rawJson!['customers'];
        if (customers is List) {
          return customers
              .map((c) => c?.toString() ?? '')
              .where((c) => c.isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[InspectionService] Get customers error: $e');
      return [];
    }
  }

  /// Get a single inspection by ID
  Future<Inspection?> getInspection(int id) async {
    try {
      final response = await _api.get(
        '$_baseUrl?action=get&id=$id',
        timeout: const Duration(seconds: 15),
      );

      if (response.success && response.rawJson?['inspection'] != null) {
        return Inspection.fromJson(response.rawJson!['inspection']);
      }
      return null;
    } catch (e) {
      debugPrint('[InspectionService] Get inspection error: $e');
      return null;
    }
  }

  /// Search inspections
  Future<List<Inspection>> searchInspections({
    required String query,
    String? username,
  }) async {
    try {
      var url = '$_baseUrl?action=search&q=${Uri.encodeComponent(query)}';
      if (username != null) url += '&username=${Uri.encodeComponent(username)}';

      final response = await _api.get(url, timeout: const Duration(seconds: 15));

      if (response.success && response.rawJson?['inspections'] != null) {
        return (response.rawJson!['inspections'] as List)
            .map((i) => Inspection.fromJson(i))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[InspectionService] Search error: $e');
      return [];
    }
  }

  /// Delete an inspection (admin only)
  Future<bool> deleteInspection(int id) async {
    try {
      final response = await _api.post(
        _baseUrl,
        body: {
          'action': 'delete',
          'id': id,
        },
        timeout: const Duration(seconds: 10),
      );

      return response.success;
    } catch (e) {
      debugPrint('[InspectionService] Delete error: $e');
      return false;
    }
  }

  /// Get inspection statistics
  Future<InspectionStats?> getStats({String? username}) async {
    try {
      var url = '$_baseUrl?action=stats';
      if (username != null) url += '&username=${Uri.encodeComponent(username)}';

      final response = await _api.get(url, timeout: const Duration(seconds: 10));

      if (response.success && response.rawJson?['stats'] != null) {
        return InspectionStats.fromJson(response.rawJson!['stats']);
      }
      return null;
    } catch (e) {
      debugPrint('[InspectionService] Get stats error: $e');
      return null;
    }
  }
}

/// Result of an inspection submission
class InspectionResult {
  final bool success;
  final String? error;
  final Inspection? inspection;

  InspectionResult({
    required this.success,
    this.error,
    this.inspection,
  });
}

/// Statistics for inspections
class InspectionStats {
  final int total;
  final int thisMonth;
  final int thisWeek;
  final Map<String, int> byCondition;
  final Map<String, int> byType;
  final Map<String, int> byCategory;
  final Map<String, int> byStatus;

  InspectionStats({
    required this.total,
    required this.thisMonth,
    required this.thisWeek,
    required this.byCondition,
    required this.byType,
    required this.byCategory,
    required this.byStatus,
  });

  factory InspectionStats.fromJson(Map<String, dynamic> json) {
    return InspectionStats(
      total: json['total'] ?? 0,
      thisMonth: json['this_month'] ?? 0,
      thisWeek: json['this_week'] ?? 0,
      byCondition: Map<String, int>.from(json['by_condition'] ?? {}),
      byType: Map<String, int>.from(json['by_type'] ?? {}),
      byCategory: Map<String, int>.from(json['by_category'] ?? {}),
      byStatus: Map<String, int>.from(json['by_status'] ?? {}),
    );
  }
}

/// Technician info for filter dropdown
class TechnicianInfo {
  final String username;
  final String firstName;
  final String lastName;
  final int inspectionCount;

  TechnicianInfo({
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.inspectionCount,
  });

  factory TechnicianInfo.fromJson(Map<String, dynamic> json) {
    return TechnicianInfo(
      username: json['username'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      inspectionCount: json['inspection_count'] is int
          ? json['inspection_count']
          : int.tryParse(json['inspection_count']?.toString() ?? '0') ?? 0,
    );
  }

  String get displayName {
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }
    return username;
  }
}
