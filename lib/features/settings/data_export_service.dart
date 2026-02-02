// Data Export Service (GDPR Compliance)
//
// Allows users to export all their personal data and request account deletion.

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../config/api_config.dart';
import '../../core/services/base_service.dart';

/// Status of a data export request
enum ExportStatus {
  pending,
  processing,
  ready,
  downloaded,
  expired,
  failed,
}

/// Type of data request
enum DataRequestType {
  export,
  deletion,
}

/// Model for a data export request
class DataExportRequest {
  final int id;
  final DataRequestType type;
  final ExportStatus status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final DateTime? expiresAt;
  final int? fileSize;
  final String? errorMessage;

  DataExportRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.expiresAt,
    this.fileSize,
    this.errorMessage,
  });

  factory DataExportRequest.fromJson(Map<String, dynamic> json) {
    return DataExportRequest(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      type: json['request_type'] == 'deletion' ? DataRequestType.deletion : DataRequestType.export,
      status: _parseStatus(json['status']),
      requestedAt: DateTime.tryParse(json['requested_at'] ?? '') ?? DateTime.now(),
      processedAt: json['processed_at'] != null ? DateTime.tryParse(json['processed_at']) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at']) : null,
      fileSize: json['file_size'] != null ? int.tryParse(json['file_size'].toString()) : null,
      errorMessage: json['error_message'],
    );
  }

  static ExportStatus _parseStatus(String? status) {
    return switch (status?.toLowerCase()) {
      'pending' => ExportStatus.pending,
      'processing' => ExportStatus.processing,
      'ready' => ExportStatus.ready,
      'downloaded' => ExportStatus.downloaded,
      'expired' => ExportStatus.expired,
      'failed' => ExportStatus.failed,
      _ => ExportStatus.pending,
    };
  }

  bool get isReady => status == ExportStatus.ready;
  bool get isPending => status == ExportStatus.pending || status == ExportStatus.processing;
  bool get canDownload => status == ExportStatus.ready;

  String get statusText {
    return switch (status) {
      ExportStatus.pending => 'Pending',
      ExportStatus.processing => 'Processing...',
      ExportStatus.ready => 'Ready to download',
      ExportStatus.downloaded => 'Downloaded',
      ExportStatus.expired => 'Expired',
      ExportStatus.failed => 'Failed',
    };
  }

  String get formattedFileSize {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Service for managing data exports (GDPR compliance)
class DataExportService extends BaseService {
  static final DataExportService _instance = DataExportService._();
  static DataExportService get instance => _instance;
  DataExportService._();

  @override
  String get serviceName => 'DataExportService';

  /// Request a data export
  Future<DataExportRequest?> requestExport(String username) async {
    try {
      final response = await api.post(
        ApiConfig.dataExport,
        body: {
          'action': 'request_export',
          'username': username,
        },
      );

      if (response.success && response.rawJson != null) {
        final data = response.rawJson!['data'] ?? response.rawJson;
        final requestId = data['request_id'];
        if (requestId != null) {
          return await checkStatus(requestId, username);
        }
      }

      logError('Failed to request export', response.message);
      return null;
    } catch (e, st) {
      logError('Error requesting export', e, st);
      return null;
    }
  }

  /// Check the status of an export request
  Future<DataExportRequest?> checkStatus(int requestId, String username) async {
    try {
      final response = await api.get(
        '${ApiConfig.dataExport}?action=status&request_id=$requestId&username=$username',
      );

      if (response.success && response.rawJson != null) {
        final data = response.rawJson!['data'] ?? response.rawJson;
        return DataExportRequest.fromJson(data);
      }

      return null;
    } catch (e, st) {
      logError('Error checking status', e, st);
      return null;
    }
  }

  /// Get list of user's export requests
  Future<List<DataExportRequest>> getMyRequests(String username) async {
    try {
      final response = await api.get(
        '${ApiConfig.dataExport}?action=my_requests&username=$username',
      );

      if (response.success && response.rawJson != null) {
        final data = response.rawJson!['data'] ?? response.rawJson;
        final requests = data['requests'] as List? ?? [];
        return requests.map((e) => DataExportRequest.fromJson(e)).toList();
      }

      return [];
    } catch (e, st) {
      logError('Error getting requests', e, st);
      return [];
    }
  }

  /// Download an export and save to file
  Future<String?> downloadExport(int requestId, String username) async {
    try {
      final response = await api.get(
        '${ApiConfig.dataExport}?action=download&request_id=$requestId&username=$username',
      );

      if (response.success && response.rawJson != null) {
        final data = response.rawJson!['data'] ?? response.rawJson;
        final content = data['content'] as String?;
        final filename = data['filename'] as String? ?? 'data_export.json';

        if (content != null) {
          // Save to documents directory
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$filename');
          await file.writeAsString(content);

          log('Export saved to: ${file.path}');
          return file.path;
        }
      }

      logError('Failed to download export', response.message);
      return null;
    } catch (e, st) {
      logError('Error downloading export', e, st);
      return null;
    }
  }

  /// Request account deletion (Right to be Forgotten)
  Future<bool> requestAccountDeletion({
    required String username,
    required String password,
  }) async {
    try {
      final response = await api.post(
        ApiConfig.dataExport,
        body: {
          'action': 'delete_my_data',
          'username': username,
          'password': password,
          'confirmation': 'DELETE_MY_ACCOUNT',
        },
      );

      if (response.success) {
        log('Account deletion requested for $username');
        return true;
      }

      logError('Failed to request deletion', response.message);
      return false;
    } catch (e, st) {
      logError('Error requesting deletion', e, st);
      return false;
    }
  }

  /// Poll for export completion
  Future<DataExportRequest?> waitForExport(
    int requestId,
    String username, {
    Duration timeout = const Duration(minutes: 5),
    Duration pollInterval = const Duration(seconds: 2),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      final request = await checkStatus(requestId, username);
      if (request == null) return null;

      if (request.status == ExportStatus.ready ||
          request.status == ExportStatus.failed ||
          request.status == ExportStatus.expired) {
        return request;
      }

      await Future.delayed(pollInterval);
    }

    log('Export polling timed out');
    return null;
  }
}
