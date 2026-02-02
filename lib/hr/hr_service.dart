// lib/hr/hr_service.dart
// Service for HR API interactions

import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../core/services/api_client.dart';

class HREmployee {
  final int id;
  final String firstName;
  final String lastName;
  final String? profilePicture;
  final String? role;
  final DateTime? dateOfEmployment;
  final DateTime? dateOfTermination;
  final DateTime? birthday;
  final String? ssn;
  final String? username;
  final int? userId;
  final String? notes;
  final bool isActive;
  final int? daysWorked;
  final String? employmentStatus;
  final int documentCount;
  final List<HRDocument> documents;
  final String? documentTypes; // Comma-separated list from list query
  final String? bankAccountNumber;
  final String? bankRoutingNumber;

  HREmployee({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.profilePicture,
    this.role,
    this.dateOfEmployment,
    this.dateOfTermination,
    this.birthday,
    this.ssn,
    this.username,
    this.userId,
    this.notes,
    this.isActive = true,
    this.daysWorked,
    this.employmentStatus,
    this.documentCount = 0,
    this.documents = const [],
    this.documentTypes,
    this.bankAccountNumber,
    this.bankRoutingNumber,
  });

  String get fullName => '$firstName $lastName'.trim();
  
  String get roleDisplay {
    if (role == null || role!.isEmpty) return 'Not Set';
    return role!.replaceAll('_', ' ').split(' ').map((w) => 
      w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : ''
    ).join(' ');
  }

  // Document status helpers - check both documents list AND documentTypes string
  List<String> get _docTypesList {
    if (documents.isNotEmpty) {
      return documents.map((d) => d.documentType).toList();
    }
    if (documentTypes != null && documentTypes!.isNotEmpty) {
      return documentTypes!.split(',').map((t) => t.trim()).toList();
    }
    return [];
  }
  
  // ID document - now just needs one file (simplified from front/back)
  bool get hasId => _docTypesList.any((t) => t == 'id_front' || t == 'id_back' || t == 'id');
  bool get hasIdComplete => hasId;  // Single file is complete
  bool get hasIdPartial => false;   // No partial state with single file
  bool get hasContract => _docTypesList.any((t) => t == 'contract');
  bool get hasSsnDoc => _docTypesList.any((t) => t == 'ssn_doc' || t == 'ssn');
  bool get hasOtherDocs => _docTypesList.any((t) => t == 'other');
  
  int get idDocsCount {
    if (documents.isNotEmpty) {
      return documents.where((d) =>
          d.documentType == 'id_front' || d.documentType == 'id_back' || d.documentType == 'id').length;
    }
    return _docTypesList.where((t) => t == 'id_front' || t == 'id_back' || t == 'id').length;
  }
  
  int get otherDocsCount {
    if (documents.isNotEmpty) {
      return documents.where((d) => d.documentType == 'other').length;
    }
    return _docTypesList.where((t) => t == 'other').length;
  }
  
  List<HRDocument> get idDocuments => documents.where((d) => 
      d.documentType == 'id_front' || d.documentType == 'id_back' || d.documentType == 'id').toList();
  List<HRDocument> get contractDocuments => documents.where((d) => 
      d.documentType == 'contract').toList();
  List<HRDocument> get ssnDocuments => documents.where((d) => 
      d.documentType == 'ssn_doc' || d.documentType == 'ssn').toList();
  List<HRDocument> get otherDocuments => documents.where((d) => 
      d.documentType == 'other').toList();

  factory HREmployee.fromJson(Map<String, dynamic> json) {
    return HREmployee(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      profilePicture: json['profile_picture'],
      role: json['role'],
      dateOfEmployment: json['date_of_employment'] != null 
          ? DateTime.tryParse(json['date_of_employment']) 
          : null,
      dateOfTermination: json['date_of_termination'] != null 
          ? DateTime.tryParse(json['date_of_termination']) 
          : null,
      birthday: json['birthday'] != null 
          ? DateTime.tryParse(json['birthday']) 
          : null,
      ssn: json['ssn'],
      username: json['username'],
      userId: json['user_id'] != null 
          ? (json['user_id'] is String ? int.tryParse(json['user_id']) : json['user_id'])
          : null,
      notes: json['notes'],
      isActive: json['is_active'] == 1 || json['is_active'] == '1' || json['is_active'] == true,
      daysWorked: json['days_worked'] != null 
          ? (json['days_worked'] is String ? int.tryParse(json['days_worked']) : json['days_worked'])
          : null,
      employmentStatus: json['employment_status'],
      documentCount: json['document_count'] != null 
          ? (json['document_count'] is String ? int.tryParse(json['document_count']) ?? 0 : json['document_count'])
          : 0,
      documents: json['documents'] != null
          ? (json['documents'] as List).map((d) => HRDocument.fromJson(d)).toList()
          : [],
      documentTypes: json['document_types'],
      bankAccountNumber: json['bank_account_number'],
      bankRoutingNumber: json['bank_routing_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'profile_picture': profilePicture,
      'role': role,
      'date_of_employment': dateOfEmployment?.toIso8601String().split('T').first,
      'date_of_termination': dateOfTermination?.toIso8601String().split('T').first,
      'birthday': birthday?.toIso8601String().split('T').first,
      'ssn': ssn,
      'username': username,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'bank_account_number': bankAccountNumber,
      'bank_routing_number': bankRoutingNumber,
    };
  }
}

class HRDocument {
  final int id;
  final String documentType;
  final String? documentLabel;
  final String fileName;
  final DateTime? uploadedAt;

  HRDocument({
    required this.id,
    required this.documentType,
    this.documentLabel,
    required this.fileName,
    this.uploadedAt,
  });

  String get displayName => documentLabel?.isNotEmpty == true ? documentLabel! : fileName;
  
  String get typeLabel {
    switch (documentType) {
      case 'id_front': return 'ID (Front)';
      case 'id_back': return 'ID (Back)';
      case 'id': return 'ID'; // Legacy type
      case 'contract': return 'Contract';
      case 'ssn_doc': return 'SSN Card';
      case 'ssn': return 'SSN Card'; // Legacy type
      case 'other': return 'Other';
      default: return 'Document';
    }
  }

  factory HRDocument.fromJson(Map<String, dynamic> json) {
    return HRDocument(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      documentType: json['document_type'] ?? 'other',
      documentLabel: json['document_label'],
      fileName: json['file_name'] ?? '',
      uploadedAt: json['uploaded_at'] != null 
          ? DateTime.tryParse(json['uploaded_at']) 
          : null,
    );
  }
}

class AvailableUser {
  final int id;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? profilePicture;

  AvailableUser({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.profilePicture,
  });

  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) {
      return '$firstName ${lastName ?? ''}'.trim();
    }
    return username;
  }

  factory AvailableUser.fromJson(Map<String, dynamic> json) {
    return AvailableUser(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      username: json['username'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      profilePicture: json['profile_picture'],
    );
  }
}

class HRService {
  final String username;
  final String role;
  final ApiClient _api = ApiClient.instance;

  HRService({required this.username, required this.role});

  Map<String, String> get _authParams => {
    'requesting_user': username,
    'requesting_role': role,
    '_': DateTime.now().millisecondsSinceEpoch.toString(),
  };

  String _buildUrl([Map<String, String>? params]) {
    final allParams = {..._authParams, ...?params};
    final queryString = allParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '${ApiConfig.hrEmployees}?$queryString';
  }

  // List all employees
  Future<List<HREmployee>> getEmployees({String? search, bool includeInactive = false}) async {
    final params = <String, String>{
      'action': 'list',
      if (search != null && search.isNotEmpty) 'search': search,
      'include_inactive': includeInactive.toString(),
    };

    final response = await _api.get(_buildUrl(params));

    if (response.success) {
      return (response.rawJson?['employees'] as List? ?? [])
          .map((e) => HREmployee.fromJson(e))
          .toList();
    }
    throw Exception(response.message ?? 'Failed to load employees');
  }

  // Get single employee with documents
  Future<HREmployee> getEmployee(int id) async {
    final params = <String, String>{
      'action': 'get',
      'id': id.toString(),
    };

    final response = await _api.get(_buildUrl(params));

    if (response.success) {
      final employee = response.rawJson?['employee'];
      if (employee != null) {
        // Debug: print documents info
        if (employee['documents'] != null) {
          debugPrint('HR Service: Employee $id has ${(employee['documents'] as List).length} documents');
          for (var doc in employee['documents']) {
            debugPrint('HR Service: Doc type: ${doc['document_type']}, file: ${doc['file_name']}');
          }
        } else {
          debugPrint('HR Service: Employee $id has NULL documents');
        }
        return HREmployee.fromJson(employee);
      }
    }
    throw Exception(response.message ?? 'Failed to load employee');
  }

  // Create employee
  Future<int> createEmployee({
    required String firstName,
    required String lastName,
    String? profilePicture,
    String? role,
    DateTime? dateOfEmployment,
    DateTime? dateOfTermination,
    DateTime? birthday,
    String? ssn,
    String? username,
    String? notes,
    String? bankAccountNumber,
    String? bankRoutingNumber,
  }) async {
    final response = await _api.postForm(
      _buildUrl(),
      body: {
        'action': 'create',
        'first_name': firstName,
        'last_name': lastName,
        if (profilePicture != null) 'profile_picture': profilePicture,
        if (role != null) 'role': role,
        if (dateOfEmployment != null) 'date_of_employment': dateOfEmployment.toIso8601String().split('T').first,
        if (dateOfTermination != null) 'date_of_termination': dateOfTermination.toIso8601String().split('T').first,
        if (birthday != null) 'birthday': birthday.toIso8601String().split('T').first,
        if (ssn != null) 'ssn': ssn,
        if (username != null) 'username': username,
        if (notes != null) 'notes': notes,
        if (bankAccountNumber != null) 'bank_account_number': bankAccountNumber,
        if (bankRoutingNumber != null) 'bank_routing_number': bankRoutingNumber,
        'requesting_user': this.username,
        'requesting_role': this.role,
      },
    );

    if (response.success) {
      final id = response.rawJson?['id'];
      return id is String ? int.parse(id) : id;
    }
    throw Exception(response.message ?? 'Failed to create employee');
  }

  // Update employee
  Future<void> updateEmployee({
    required int id,
    required String firstName,
    required String lastName,
    String? profilePicture,
    String? role,
    DateTime? dateOfEmployment,
    DateTime? dateOfTermination,
    DateTime? birthday,
    String? ssn,
    String? notes,
    bool isActive = true,
    String? bankAccountNumber,
    String? bankRoutingNumber,
  }) async {
    final response = await _api.postForm(
      _buildUrl(),
      body: {
        'action': 'update',
        'id': id.toString(),
        'first_name': firstName,
        'last_name': lastName,
        'profile_picture': profilePicture ?? '',
        'role': role ?? '',
        'date_of_employment': dateOfEmployment?.toIso8601String().split('T').first ?? '',
        'date_of_termination': dateOfTermination?.toIso8601String().split('T').first ?? '',
        'birthday': birthday?.toIso8601String().split('T').first ?? '',
        'ssn': ssn ?? '',
        'notes': notes ?? '',
        'is_active': isActive ? '1' : '0',
        'bank_account_number': bankAccountNumber ?? '',
        'bank_routing_number': bankRoutingNumber ?? '',
        'requesting_user': username,
        'requesting_role': this.role,
      },
    );

    if (!response.success) {
      throw Exception(response.message ?? 'Failed to update employee');
    }
  }

  // Delete employee
  Future<void> deleteEmployee(int id, {bool permanent = false}) async {
    final response = await _api.postForm(
      _buildUrl(),
      body: {
        'action': 'delete',
        'id': id.toString(),
        'permanent': permanent.toString(),
        'requesting_user': username,
        'requesting_role': role,
      },
    );

    if (!response.success) {
      throw Exception(response.message ?? 'Failed to delete employee');
    }
  }

  // Link user to employee
  Future<void> linkUser(int employeeId, String username) async {
    final response = await _api.postForm(
      _buildUrl(),
      body: {
        'action': 'link_user',
        'employee_id': employeeId.toString(),
        'username': username,
        'requesting_user': this.username,
        'requesting_role': role,
      },
    );

    if (!response.success) {
      throw Exception(response.message ?? 'Failed to link user');
    }
  }

  // Unlink user from employee
  Future<void> unlinkUser(int employeeId) async {
    final response = await _api.postForm(
      _buildUrl(),
      body: {
        'action': 'unlink_user',
        'employee_id': employeeId.toString(),
        'requesting_user': username,
        'requesting_role': role,
      },
    );

    if (!response.success) {
      throw Exception(response.message ?? 'Failed to unlink user');
    }
  }

  // Upload profile picture
  Future<String> uploadPicture(int employeeId, String base64Image) async {
    final response = await _api.postForm(
      _buildUrl(),
      body: {
        'action': 'upload_picture',
        'employee_id': employeeId.toString(),
        'picture': base64Image,
        'requesting_user': username,
        'requesting_role': role,
      },
    );

    if (response.success) {
      return response.rawJson?['picture_url'] ?? '';
    }
    throw Exception(response.message ?? 'Failed to upload picture');
  }

  // Sync profile picture from user's profile
  Future<String?> syncPictureFromProfile(int employeeId) async {
    final response = await _api.postForm(
      _buildUrl(),
      body: {
        'action': 'sync_picture',
        'employee_id': employeeId.toString(),
        'requesting_user': username,
        'requesting_role': role,
      },
    );

    if (response.success) {
      return response.rawJson?['picture_url'];
    }
    return null; // No picture found
  }

  // Auto-sync all profile pictures for employees with linked users but no picture
  Future<int> autoSyncProfilePictures() async {
    final response = await _api.postForm(
      _buildUrl(),
      body: {
        'action': 'auto_sync_pictures',
        'requesting_user': username,
        'requesting_role': role,
      },
    );

    if (response.success) {
      return response.rawJson?['synced_count'] ?? 0;
    }
    return 0;
  }

  // Get available users (not linked)
  Future<List<AvailableUser>> getAvailableUsers() async {
    final params = <String, String>{
      'action': 'available_users',
    };

    final response = await _api.get(_buildUrl(params));

    if (response.success) {
      return (response.rawJson?['users'] as List? ?? [])
          .map((u) => AvailableUser.fromJson(u))
          .toList();
    }
    throw Exception(response.message ?? 'Failed to load users');
  }

  // Upload document using base64
  Future<HRDocument> uploadDocument({
    required int employeeId,
    required String documentType,
    required String fileName,
    required String fileData, // base64 encoded
    String? label,
  }) async {
    debugPrint('HR uploadDocument: type=$documentType, label=$label');

    // Build body explicitly - use doc_type instead of document_type
    // (some servers/firewalls may filter certain parameter names)
    final Map<String, String> body = {
      'action': 'upload_document',
      'employee_id': employeeId.toString(),
      'doc_type': documentType,  // Changed from document_type
      'file_name': fileName,
      'file_data': fileData,
      'requesting_user': username,
      'requesting_role': role,
    };

    // Add label if provided
    if (label != null && label.isNotEmpty) {
      body['document_label'] = label;
    }

    debugPrint('HR uploadDocument body keys: ${body.keys.toList()}');
    debugPrint('HR uploadDocument doc_type value: "${body['doc_type']}"');

    final response = await _api.postForm(
      _buildUrl(),
      body: body,
    );

    debugPrint('HR uploadDocument response success: ${response.success}');

    if (response.success && response.rawJson?['document'] != null) {
      return HRDocument.fromJson(response.rawJson!['document']);
    }
    throw Exception(response.message ?? 'Failed to upload document');
  }

  // Delete document
  Future<void> deleteDocument(int employeeId, int documentId) async {
    final response = await _api.postForm(
      _buildUrl(),
      body: {
        'action': 'delete_document',
        'employee_id': employeeId.toString(),
        'document_id': documentId.toString(),
        'requesting_user': username,
        'requesting_role': role,
      },
    );

    if (!response.success) {
      throw Exception(response.message ?? 'Failed to delete document');
    }
  }

  // Get document download URL
  Future<String> getDocumentUrl(int employeeId, int documentId) async {
    return _buildUrl({
      'action': 'get_document',
      'employee_id': employeeId.toString(),
      'id': documentId.toString(),
    });
  }
}
