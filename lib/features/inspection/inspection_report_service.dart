// Inspection Report Service
//
// Handles all API communication for the comprehensive inspection report system.

import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';
import 'inspection_data.dart';

class InspectionReportService {
  static String get _baseUrl => ApiConfig.inspectionReports;
  static String get _workflowUrl => ApiConfig.inspectionWorkflow;

  /// Singleton instance
  static final InspectionReportService _instance = InspectionReportService._();
  static InspectionReportService get instance => _instance;
  InspectionReportService._();

  final ApiClient _api = ApiClient.instance;

  /// Submit a new comprehensive inspection report
  ///
  /// Options:
  /// - [triggerWorkflow] - Whether to trigger post-submission workflow (default: true)
  /// - [skipEmail] - Skip sending email notification (default: false)
  /// - [skipSms] - Skip sending SMS notification (default: false)
  /// - [skipWorkizSync] - Skip syncing to Workiz (default: false)
  /// - [invoiceItems] - List of invoice items to include in the estimate
  Future<InspectionReportResult> submitReport({
    required String username,
    required InspectionFormData formData,
    List<Map<String, dynamic>>? invoiceItems,
    bool triggerWorkflow = true,
    bool skipEmail = false,
    bool skipSms = false,
    bool skipWorkizSync = false,
  }) async {
    try {
      // Build request body
      final body = {
        'action': 'create',
        'inspector_username': username,
        'trigger_workflow': triggerWorkflow,
        'skip_email': skipEmail,
        'skip_sms': skipSms,
        'skip_workiz_sync': skipWorkizSync,
        ...formData.toJson(),
      };

      // Add invoice items if provided
      if (invoiceItems != null && invoiceItems.isNotEmpty) {
        body['invoice_items'] = invoiceItems;
        debugPrint('[InspectionReportService] Including ${invoiceItems.length} invoice items');
      }

      debugPrint('[InspectionReportService] Submitting report for ${formData.firstName} ${formData.lastName}');
      debugPrint('[InspectionReportService] Workiz fields - UUID: ${formData.workizJobUuid}, Serial: ${formData.workizJobSerial}, ClientID: ${formData.workizClientId}');

      final response = await _api.post(
        _baseUrl,
        body: body,
        timeout: const Duration(seconds: 180), // Longer timeout for workflow processing
      );

      if (response.success) {
        final data = response.rawJson!;
        debugPrint('[InspectionReportService] Report submitted successfully, ID: ${data['report_id']}');

        // Parse workflow result if available
        WorkflowResult? workflowResult;
        debugPrint('[InspectionReportService] workflow_triggered: ${data['workflow_triggered']}, workflow_result: ${data['workflow_result']}');
        if (data['workflow_triggered'] == true && data['workflow_result'] != null) {
          workflowResult = WorkflowResult.fromJson(data['workflow_result']);
          debugPrint('[InspectionReportService] Workflow completed: ${workflowResult.success}');
          for (final step in workflowResult.steps) {
            debugPrint('[InspectionReportService] Step ${step.name}: success=${step.success}, error=${step.error}');
          }
        } else if (data['workflow_error'] != null) {
          debugPrint('[InspectionReportService] Workflow error: ${data['workflow_error']}');
        }

        return InspectionReportResult(
          success: true,
          reportId: data['report_id'] is int
              ? data['report_id']
              : int.tryParse(data['report_id']?.toString() ?? ''),
          workflowTriggered: data['workflow_triggered'] == true,
          workflowResult: workflowResult,
        );
      } else {
        debugPrint('[InspectionReportService] Submit failed: ${response.message}');
        return InspectionReportResult(
          success: false,
          error: response.message ?? 'Failed to submit report',
        );
      }
    } catch (e) {
      debugPrint('[InspectionReportService] Submit error: $e');
      return InspectionReportResult(success: false, error: e.toString());
    }
  }

  /// Get workflow status for a report
  Future<WorkflowStatus?> getWorkflowStatus(int reportId) async {
    try {
      final response = await _api.get(
        '$_workflowUrl?action=get_status&report_id=$reportId',
        timeout: const Duration(seconds: 15),
      );

      if (response.success) {
        return WorkflowStatus.fromJson(response.rawJson!);
      }
      return null;
    } catch (e) {
      debugPrint('[InspectionReportService] Get workflow status error: $e');
      return null;
    }
  }

  /// Manually trigger workflow for a report
  Future<WorkflowResult?> triggerWorkflow(
    int reportId, {
    bool skipEmail = false,
    bool skipSms = false,
    bool skipWorkizSync = false,
  }) async {
    try {
      final response = await _api.post(
        _workflowUrl,
        body: {
          'action': 'process_inspection',
          'report_id': reportId,
          'skip_email': skipEmail,
          'skip_sms': skipSms,
          'skip_workiz_sync': skipWorkizSync,
        },
        timeout: const Duration(seconds: 120),
      );

      if (response.success) {
        return WorkflowResult.fromJson(response.rawJson!);
      }
      return null;
    } catch (e) {
      debugPrint('[InspectionReportService] Trigger workflow error: $e');
      return null;
    }
  }

  /// Send email notification manually
  Future<bool> sendEmail(int reportId) async {
    try {
      final response = await _api.post(
        _workflowUrl,
        body: {
          'action': 'send_email',
          'report_id': reportId,
        },
        timeout: const Duration(seconds: 30),
      );

      return response.success;
    } catch (e) {
      debugPrint('[InspectionReportService] Send email error: $e');
      return false;
    }
  }

  /// Send SMS notification manually
  Future<bool> sendSms(int reportId) async {
    try {
      final response = await _api.post(
        _workflowUrl,
        body: {
          'action': 'send_sms',
          'report_id': reportId,
        },
        timeout: const Duration(seconds: 30),
      );

      return response.success;
    } catch (e) {
      debugPrint('[InspectionReportService] Send SMS error: $e');
      return false;
    }
  }

  /// Get list of reports for a user
  Future<List<InspectionReportSummary>> getReports({
    required String username,
    int? limit,
    int? offset,
  }) async {
    try {
      var url = '$_baseUrl?action=list&username=${Uri.encodeComponent(username)}';
      if (limit != null) url += '&limit=$limit';
      if (offset != null) url += '&offset=$offset';

      final response = await _api.get(url, timeout: const Duration(seconds: 15));

      if (response.success && response.rawJson?['reports'] != null) {
        return (response.rawJson!['reports'] as List)
            .map((r) => InspectionReportSummary.fromJson(r))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[InspectionReportService] Get reports error: $e');
      return [];
    }
  }

  /// Get all reports (admin view)
  Future<List<InspectionReportSummary>> getAllReports({
    int? limit,
    int? offset,
    String? filterLevel,
    String? filterSystemType,
    bool? filterHasFailed,
    String? filterInspector,
  }) async {
    try {
      var url = '$_baseUrl?action=list_all';
      if (limit != null) url += '&limit=$limit';
      if (offset != null) url += '&offset=$offset';
      if (filterLevel != null) url += '&level=${Uri.encodeComponent(filterLevel)}';
      if (filterSystemType != null) url += '&system_type=${Uri.encodeComponent(filterSystemType)}';
      if (filterHasFailed != null) url += '&has_failed=${filterHasFailed ? 1 : 0}';
      if (filterInspector != null) url += '&inspector=${Uri.encodeComponent(filterInspector)}';

      final response = await _api.get(url, timeout: const Duration(seconds: 15));

      if (response.success && response.rawJson?['reports'] != null) {
        return (response.rawJson!['reports'] as List)
            .map((r) => InspectionReportSummary.fromJson(r))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[InspectionReportService] Get all reports error: $e');
      return [];
    }
  }

  /// Get a single report with all details
  Future<InspectionReportDetail?> getReport(int id) async {
    try {
      final response = await _api.get(
        '$_baseUrl?action=get&id=$id',
        timeout: const Duration(seconds: 15),
      );

      if (response.success && response.rawJson?['report'] != null) {
        return InspectionReportDetail.fromJson(response.rawJson!['report']);
      }
      return null;
    } catch (e) {
      debugPrint('[InspectionReportService] Get report error: $e');
      return null;
    }
  }

  /// Delete a report (admin only)
  Future<bool> deleteReport(int id) async {
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
      debugPrint('[InspectionReportService] Delete error: $e');
      return false;
    }
  }
}

/// Result of a report submission
class InspectionReportResult {
  final bool success;
  final String? error;
  final int? reportId;
  final bool workflowTriggered;
  final WorkflowResult? workflowResult;

  InspectionReportResult({
    required this.success,
    this.error,
    this.reportId,
    this.workflowTriggered = false,
    this.workflowResult,
  });
}

/// Result of post-submission workflow execution
class WorkflowResult {
  final bool success;
  final String? error;
  final int? workflowId;
  final String? estimateId;
  final bool emailSent;
  final bool smsSent;
  final bool workizSynced;
  final List<WorkflowStep> steps;

  WorkflowResult({
    required this.success,
    this.error,
    this.workflowId,
    this.estimateId,
    this.emailSent = false,
    this.smsSent = false,
    this.workizSynced = false,
    this.steps = const [],
  });

  factory WorkflowResult.fromJson(Map<String, dynamic> json) {
    // Parse steps - can be either a Map (keyed by step name) or a List
    List<WorkflowStep> stepsList = [];
    final stepsData = json['steps'];
    if (stepsData is Map) {
      // Convert Map to List, adding step name to each entry
      stepsData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          stepsList.add(WorkflowStep.fromJson({...value, 'name': key}));
        }
      });
    } else if (stepsData is List) {
      stepsList = stepsData
          .map((s) => WorkflowStep.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    return WorkflowResult(
      success: json['success'] == true,
      error: json['error'],
      workflowId: json['workflow_id'] is int
          ? json['workflow_id']
          : int.tryParse(json['workflow_id']?.toString() ?? ''),
      estimateId: json['estimate_id']?.toString(),
      emailSent: json['email_sent'] == true,
      smsSent: json['sms_sent'] == true,
      workizSynced: json['workiz_synced'] == true,
      steps: stepsList,
    );
  }
}

/// Individual step in the workflow
class WorkflowStep {
  final String name;
  final bool success;
  final String? message;
  final String? error;

  WorkflowStep({
    required this.name,
    required this.success,
    this.message,
    this.error,
  });

  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    return WorkflowStep(
      name: json['step'] ?? json['name'] ?? '',
      success: json['success'] == true,
      message: json['message'],
      error: json['error'],
    );
  }
}

/// Status of workflow for a report
class WorkflowStatus {
  final int reportId;
  final String status;
  final bool estimateCreated;
  final String? estimateId;
  final bool emailSent;
  final bool smsSent;
  final bool workizSynced;
  final DateTime? processedAt;
  final List<WorkflowStep> steps;

  WorkflowStatus({
    required this.reportId,
    required this.status,
    this.estimateCreated = false,
    this.estimateId,
    this.emailSent = false,
    this.smsSent = false,
    this.workizSynced = false,
    this.processedAt,
    this.steps = const [],
  });

  factory WorkflowStatus.fromJson(Map<String, dynamic> json) {
    final workflow = json['workflow'] ?? json;

    // Parse steps - can be either a Map (keyed by step name) or a List
    List<WorkflowStep> stepsList = [];
    final stepsData = workflow['steps'];
    if (stepsData is Map) {
      stepsData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          stepsList.add(WorkflowStep.fromJson({...value, 'name': key}));
        }
      });
    } else if (stepsData is List) {
      stepsList = stepsData
          .map((s) => WorkflowStep.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    return WorkflowStatus(
      reportId: workflow['report_id'] is int
          ? workflow['report_id']
          : int.tryParse(workflow['report_id']?.toString() ?? '0') ?? 0,
      status: workflow['status'] ?? 'unknown',
      estimateCreated: workflow['estimate_created'] == true || workflow['estimate_id'] != null,
      estimateId: workflow['estimate_id']?.toString(),
      emailSent: workflow['email_sent'] == true,
      smsSent: workflow['sms_sent'] == true,
      workizSynced: workflow['workiz_synced'] == true,
      processedAt: workflow['processed_at'] != null
          ? DateTime.tryParse(workflow['processed_at'])
          : null,
      steps: stepsList,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get hasFailed => status == 'failed';
}

/// Summary of an inspection report (for list views)
class InspectionReportSummary {
  final int id;
  final String? jobId;
  final DateTime inspectionDate;
  final String inspectionTime;
  final String inspectorName;
  final String? inspectorUsername;
  final String inspectionLevel;
  final String firstName;
  final String lastName;
  final String address1;
  final String city;
  final String state;
  final String zipCode;
  final String systemType;
  final bool hasFailedItems;
  final DateTime createdAt;

  InspectionReportSummary({
    required this.id,
    this.jobId,
    required this.inspectionDate,
    required this.inspectionTime,
    required this.inspectorName,
    this.inspectorUsername,
    required this.inspectionLevel,
    required this.firstName,
    required this.lastName,
    required this.address1,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.systemType,
    required this.hasFailedItems,
    required this.createdAt,
  });

  factory InspectionReportSummary.fromJson(Map<String, dynamic> json) {
    return InspectionReportSummary(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      jobId: json['job_id'],
      inspectionDate: DateTime.tryParse(json['inspection_date'] ?? '') ?? DateTime.now(),
      inspectionTime: json['inspection_time'] ?? '',
      inspectorName: json['inspector_name'] ?? '',
      inspectorUsername: json['inspector_username'],
      inspectionLevel: json['inspection_level'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      address1: json['address1'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zipCode: json['zip_code'] ?? '',
      systemType: json['system_type'] ?? '',
      hasFailedItems: json['has_failed_items'] == 1 || json['has_failed_items'] == true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get clientName => '$firstName $lastName';
  String get fullAddress => '$address1, $city, $state $zipCode';
}

/// Helper function to parse invoice items from JSON (handles both string and list)
List<Map<String, dynamic>> _parseInvoiceItems(dynamic value) {
  if (value == null) return [];

  // If it's already a list, parse it
  if (value is List) {
    return value
        .map((i) => i is Map ? Map<String, dynamic>.from(i) : <String, dynamic>{})
        .toList();
  }

  // If it's a string, try to decode it
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .map((i) => i is Map ? Map<String, dynamic>.from(i) : <String, dynamic>{})
            .toList();
      }
    } catch (e) {
      // Ignore parse errors
      debugPrint('[InspectionReportService] Error: $e');
    }
  }

  return [];
}

/// Full details of an inspection report
class InspectionReportDetail {
  final int id;
  final String? jobId;
  final DateTime inspectionDate;
  final String inspectionTime;
  final String inspectorName;
  final String inspectorUsername;
  final String inspectionLevel;
  final String? reasonForInspection;
  final String? otherReason;

  final String firstName;
  final String lastName;
  final String address1;
  final String? address2;
  final String city;
  final String state;
  final String zipCode;
  final String? phone;
  final String? email1;
  final String? email2;
  final bool onSiteClient;

  final String systemType;
  final Map<String, dynamic> systemData;
  final Map<String, dynamic> chimneyData;
  final Map<String, dynamic> exteriorData;

  final String? inspectorNote;
  final List<FailedItem> failedItems;
  final bool hasFailedItems;
  final List<ReportImage> images;

  // Invoice/Estimate fields
  final List<Map<String, dynamic>> invoiceItems;
  final int totalEstimateCents;

  final DateTime createdAt;
  final DateTime? updatedAt;

  InspectionReportDetail({
    required this.id,
    this.jobId,
    required this.inspectionDate,
    required this.inspectionTime,
    required this.inspectorName,
    required this.inspectorUsername,
    required this.inspectionLevel,
    this.reasonForInspection,
    this.otherReason,
    required this.firstName,
    required this.lastName,
    required this.address1,
    this.address2,
    required this.city,
    required this.state,
    required this.zipCode,
    this.phone,
    this.email1,
    this.email2,
    required this.onSiteClient,
    required this.systemType,
    required this.systemData,
    required this.chimneyData,
    required this.exteriorData,
    this.inspectorNote,
    required this.failedItems,
    required this.hasFailedItems,
    required this.images,
    this.invoiceItems = const [],
    this.totalEstimateCents = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory InspectionReportDetail.fromJson(Map<String, dynamic> json) {
    return InspectionReportDetail(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      jobId: json['job_id'],
      inspectionDate: DateTime.tryParse(json['inspection_date'] ?? '') ?? DateTime.now(),
      inspectionTime: json['inspection_time'] ?? '',
      inspectorName: json['inspector_name'] ?? '',
      inspectorUsername: json['inspector_username'] ?? '',
      inspectionLevel: json['inspection_level'] ?? '',
      reasonForInspection: json['reason_for_inspection'],
      otherReason: json['other_reason'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      address1: json['address1'] ?? '',
      address2: json['address2'],
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zipCode: json['zip_code'] ?? '',
      phone: json['phone'],
      email1: json['email1'],
      email2: json['email2'],
      onSiteClient: json['on_site_client'] == 1 || json['on_site_client'] == true,
      systemType: json['system_type'] ?? '',
      systemData: (json['system_data'] is Map) ? Map<String, dynamic>.from(json['system_data']) : {},
      chimneyData: (json['chimney_data'] is Map) ? Map<String, dynamic>.from(json['chimney_data']) : {},
      exteriorData: (json['exterior_data'] is Map) ? Map<String, dynamic>.from(json['exterior_data']) : {},
      inspectorNote: json['inspector_note'],
      failedItems: (json['failed_items'] as List?)
          ?.map((i) => FailedItem.fromJson(i))
          .toList() ?? [],
      hasFailedItems: json['has_failed_items'] == 1 || json['has_failed_items'] == true,
      images: (json['images'] as List?)
          ?.map((i) => ReportImage.fromJson(i))
          .toList() ?? [],
      invoiceItems: _parseInvoiceItems(json['invoice_items']),
      totalEstimateCents: json['total_estimate_cents'] is int
          ? json['total_estimate_cents']
          : int.tryParse(json['total_estimate_cents']?.toString() ?? '0') ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  String get clientName => '$firstName $lastName';
  String get fullAddress {
    final parts = <String>[address1];
    if (address2?.isNotEmpty == true) parts.add(address2!);
    parts.add('$city, $state $zipCode');
    return parts.join('\n');
  }

  bool get hasInvoiceItems => invoiceItems.isNotEmpty;
  String get totalEstimateDisplay => '\$${(totalEstimateCents / 100).toStringAsFixed(2)}';
}

/// Failed inspection item from API
class FailedItem {
  final String item;
  final String status;
  final String code;

  FailedItem({
    required this.item,
    required this.status,
    required this.code,
  });

  factory FailedItem.fromJson(Map<String, dynamic> json) {
    return FailedItem(
      item: json['item'] ?? '',
      status: json['status'] ?? 'Failed',
      code: json['code'] ?? '',
    );
  }
}

/// Image attached to a report
class ReportImage {
  final int id;
  final int reportId;
  final String fieldName;
  final String filename;
  final String url;
  final DateTime createdAt;

  ReportImage({
    required this.id,
    required this.reportId,
    required this.fieldName,
    required this.filename,
    required this.url,
    required this.createdAt,
  });

  factory ReportImage.fromJson(Map<String, dynamic> json) {
    return ReportImage(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      reportId: json['report_id'] is int ? json['report_id'] : int.tryParse(json['report_id']?.toString() ?? '0') ?? 0,
      fieldName: json['field_name'] ?? '',
      filename: json['filename'] ?? '',
      url: json['url'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
