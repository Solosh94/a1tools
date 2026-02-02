// Digital Signature Service
//
// Handles capturing, storing, and managing digital signatures
// for inspection reports and customer sign-offs.

import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';
import 'api_client.dart';

class SignatureService {
  static String get _baseUrl => ApiConfig.apiBase;

  // Singleton pattern
  static final SignatureService _instance = SignatureService._internal();
  factory SignatureService() => _instance;
  SignatureService._internal();

  final ApiClient _api = ApiClient.instance;

  /// Save a signature for an inspection
  Future<SignatureSaveResult> saveInspectionSignature({
    required int inspectionId,
    required String signatureBase64,
    required String signerName,
    required SignatureType signatureType,
    String? signerEmail,
    String? signerPhone,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl/signatures.php',
        body: {
          'action': 'save_signature',
          'inspection_id': inspectionId,
          'signature_base64': signatureBase64,
          'signer_name': signerName,
          'signer_email': signerEmail,
          'signer_phone': signerPhone,
          'signature_type': signatureType.value,
        },
      );

      if (response.success) {
        return SignatureSaveResult(
          success: true,
          signatureId: response.rawJson?['signature_id'],
          signatureUrl: response.rawJson?['signature_url'],
        );
      }
      return SignatureSaveResult(
        success: false,
        error: response.message ?? 'Failed to save signature',
      );
    } catch (e) {
      debugPrint('Error saving signature: $e');
      return SignatureSaveResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Save a signature for a work order / job
  Future<SignatureSaveResult> saveWorkOrderSignature({
    required String workOrderId,
    required String signatureBase64,
    required String signerName,
    required SignatureType signatureType,
    String? signerEmail,
    String? notes,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl/signatures.php',
        body: {
          'action': 'save_work_order_signature',
          'work_order_id': workOrderId,
          'signature_base64': signatureBase64,
          'signer_name': signerName,
          'signer_email': signerEmail,
          'signature_type': signatureType.value,
          'notes': notes,
        },
      );

      if (response.success) {
        return SignatureSaveResult(
          success: true,
          signatureId: response.rawJson?['signature_id'],
          signatureUrl: response.rawJson?['signature_url'],
        );
      }
      return SignatureSaveResult(
        success: false,
        error: response.message ?? 'Failed to save signature',
      );
    } catch (e) {
      debugPrint('Error saving work order signature: $e');
      return SignatureSaveResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get signatures for an inspection
  Future<List<SignatureRecord>> getInspectionSignatures(int inspectionId) async {
    try {
      final response = await _api.get(
        '$_baseUrl/signatures.php?action=get_signatures&inspection_id=$inspectionId',
      );

      if (response.success && response.rawJson?['signatures'] != null) {
        return (response.rawJson!['signatures'] as List)
            .map((s) => SignatureRecord.fromJson(s))
            .toList();
      }
    } catch (e) {
      debugPrint('Error getting signatures: $e');
    }
    return [];
  }

  /// Get signature by ID
  Future<SignatureRecord?> getSignature(int signatureId) async {
    try {
      final response = await _api.get(
        '$_baseUrl/signatures.php?action=get_signature&id=$signatureId',
      );

      if (response.success && response.rawJson?['signature'] != null) {
        return SignatureRecord.fromJson(response.rawJson!['signature']);
      }
    } catch (e) {
      debugPrint('Error getting signature: $e');
    }
    return null;
  }

  /// Delete a signature
  Future<bool> deleteSignature(int signatureId) async {
    try {
      final response = await _api.post(
        '$_baseUrl/signatures.php',
        body: {
          'action': 'delete_signature',
          'signature_id': signatureId,
        },
      );

      return response.success;
    } catch (e) {
      debugPrint('Error deleting signature: $e');
    }
    return false;
  }

  /// Send signature confirmation email to customer
  Future<bool> sendSignatureConfirmation({
    required int signatureId,
    required String email,
    String? customMessage,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl/signatures.php',
        body: {
          'action': 'send_confirmation',
          'signature_id': signatureId,
          'email': email,
          'custom_message': customMessage,
        },
      );

      return response.success;
    } catch (e) {
      debugPrint('Error sending confirmation: $e');
    }
    return false;
  }

  /// Convert signature points to base64 PNG
  static Future<String?> pointsToBase64(List<List<Map<String, double>>> points, {
    int width = 600,
    int height = 200,
    int strokeWidth = 2,
  }) async {
    // This would typically use a canvas to render the points
    // For Flutter, the signature package handles this
    return null;
  }
}

/// Result of saving a signature
class SignatureSaveResult {
  final bool success;
  final int? signatureId;
  final String? signatureUrl;
  final String? error;

  SignatureSaveResult({
    required this.success,
    this.signatureId,
    this.signatureUrl,
    this.error,
  });
}

/// Types of signatures
enum SignatureType {
  customer('customer'),
  technician('technician'),
  supervisor('supervisor'),
  witness('witness');

  final String value;
  const SignatureType(this.value);

  static SignatureType fromString(String? value) {
    return SignatureType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SignatureType.customer,
    );
  }

  String get displayName {
    switch (this) {
      case SignatureType.customer:
        return 'Customer';
      case SignatureType.technician:
        return 'Technician';
      case SignatureType.supervisor:
        return 'Supervisor';
      case SignatureType.witness:
        return 'Witness';
    }
  }
}

/// Signature record from database
class SignatureRecord {
  final int id;
  final int? inspectionId;
  final String? workOrderId;
  final String signerName;
  final String? signerEmail;
  final String? signerPhone;
  final SignatureType signatureType;
  final String signatureUrl;
  final DateTime createdAt;
  final String? ipAddress;
  final String? deviceInfo;

  SignatureRecord({
    required this.id,
    this.inspectionId,
    this.workOrderId,
    required this.signerName,
    this.signerEmail,
    this.signerPhone,
    required this.signatureType,
    required this.signatureUrl,
    required this.createdAt,
    this.ipAddress,
    this.deviceInfo,
  });

  factory SignatureRecord.fromJson(Map<String, dynamic> json) {
    return SignatureRecord(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      inspectionId: int.tryParse(json['inspection_id']?.toString() ?? ''),
      workOrderId: json['work_order_id'],
      signerName: json['signer_name'] ?? '',
      signerEmail: json['signer_email'],
      signerPhone: json['signer_phone'],
      signatureType: SignatureType.fromString(json['signature_type']),
      signatureUrl: json['signature_url'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      ipAddress: json['ip_address'],
      deviceInfo: json['device_info'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inspection_id': inspectionId,
    'work_order_id': workOrderId,
    'signer_name': signerName,
    'signer_email': signerEmail,
    'signer_phone': signerPhone,
    'signature_type': signatureType.value,
    'signature_url': signatureUrl,
    'created_at': createdAt.toIso8601String(),
    'ip_address': ipAddress,
    'device_info': deviceInfo,
  };
}

/// Represents signature data being captured
class SignatureData {
  final Uint8List? imageBytes;
  final String? base64Data;
  final List<List<Map<String, double>>>? points;
  final int width;
  final int height;

  SignatureData({
    this.imageBytes,
    this.base64Data,
    this.points,
    this.width = 600,
    this.height = 200,
  });

  bool get isEmpty => (imageBytes?.isEmpty ?? true) && (points?.isEmpty ?? true);
  bool get isNotEmpty => !isEmpty;
}
