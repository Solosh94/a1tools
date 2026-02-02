import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';

/// Service for Workiz integration
/// Handles job sync, customer data retrieval, and estimate creation
/// Now supports multi-location with API tokens
class WorkizService {
  static String get _baseUrl => ApiConfig.apiBase;

  // Singleton pattern
  static final WorkizService _instance = WorkizService._internal();
  factory WorkizService() => _instance;
  WorkizService._internal();

  final ApiClient _api = ApiClient.instance;

  // Cache for jobs per location
  final Map<String, List<WorkizJob>> _cachedJobsByLocation = {};
  final Map<String, DateTime> _lastSyncByLocation = {};

  // Current context
  String? _currentUsername;
  String? _currentLocationCode;

  /// Set the current user context for location-based operations
  void setUserContext(String username, String? locationCode) {
    _currentUsername = username;
    _currentLocationCode = locationCode;
  }

  /// Clear user context
  void clearUserContext() {
    _currentUsername = null;
    _currentLocationCode = null;
  }

  /// Check if Workiz is configured for the current location
  /// Uses the new multi-location system with API tokens
  Future<WorkizConfigStatus> getConfigStatus({String? locationCode}) async {
    final locCode = locationCode ?? _currentLocationCode;
    final username = _currentUsername;

    // If no location context, check if user has any locations assigned
    if (locCode == null || username == null) {
      return WorkizConfigStatus(
        isConfigured: false,
        status: 'no_context',
        message: 'No location selected',
      );
    }

    try {
      // Check if this location is configured for Workiz
      final response = await _api.get(
        '$_baseUrl/workiz_locations.php?action=get_location_status&location_code=$locCode&username=$username',
      );

      if (response.success) {
        final location = response.rawJson?['location'];
        return WorkizConfigStatus(
          isConfigured: location?['has_api_token'] == true,
          status: location?['status'] ?? 'not_configured',
          lastSync: location?['last_sync'] != null
              ? DateTime.tryParse(location['last_sync'])
              : null,
          accountName: location?['location_name'],
          locationCode: locCode,
          hasApiToken: location?['has_api_token'] == true,
        );
      }
      return WorkizConfigStatus(isConfigured: false, status: 'error');
    } catch (e) {
      debugPrint('Error checking Workiz config: $e');
      return WorkizConfigStatus(isConfigured: false, status: 'error');
    }
  }

  /// Save Workiz configuration
  Future<bool> saveConfig({
    required String accountName,
    required String accountId,
    required String userId,
    required String sessionId,
    String? email,
    String? password,
    String? franchiseId,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl/workiz_integration.php',
        body: {
          'action': 'save_config',
          'account_name': accountName,
          'workiz_account_id': accountId,
          'workiz_user_id': userId,
          'workiz_session_id': sessionId,
          'email': email,
          'password': password,
          'franchise_id': franchiseId,
        },
      );

      return response.success;
    } catch (e) {
      debugPrint('Error saving Workiz config: $e');
      return false;
    }
  }

  /// Test Workiz connection
  Future<bool> testConnection() async {
    try {
      final response = await _api.post(
        '$_baseUrl/workiz_integration.php',
        body: {'action': 'test_connection'},
      );

      return response.success;
    } catch (e) {
      debugPrint('Error testing Workiz connection: $e');
      return false;
    }
  }

  /// Sync/fetch jobs from Workiz for the current location
  /// Uses the API token to fetch directly from Workiz API
  Future<SyncResult> syncJobs({String? locationCode}) async {
    final locCode = locationCode ?? _currentLocationCode;

    if (locCode == null) {
      return SyncResult(success: false, message: 'No location selected');
    }

    try {
      // Use GET request with get_jobs action - same as getJobs but forces refresh
      final url = '$_baseUrl/workiz_locations.php?action=get_jobs&location_code=$locCode&limit=100';

      final response = await _api.get(url);

      if (response.success) {
        final jobs = (response.rawJson?['jobs'] as List? ?? [])
            .map((j) => WorkizJob.fromJson(j))
            .toList();

        _lastSyncByLocation[locCode] = DateTime.now();
        // Update cache with fresh data
        _cachedJobsByLocation[locCode] = jobs;

        return SyncResult(
          success: true,
          syncedCount: jobs.length,
          message: 'Fetched ${jobs.length} jobs from Workiz',
        );
      }
      return SyncResult(
        success: false,
        message: response.message ?? 'Sync failed',
      );
    } catch (e) {
      debugPrint('Error syncing Workiz jobs: $e');
      return SyncResult(success: false, message: e.toString());
    }
  }

  /// Get list of jobs for the current location
  /// Fetches directly from Workiz API using location's API token
  Future<List<WorkizJob>> getJobs({
    int limit = 50,
    int offset = 0,
    String? status,
    String? dateFrom,
    String? dateTo,
    bool forceRefresh = false,
    String? locationCode,
  }) async {
    final locCode = locationCode ?? _currentLocationCode;

    if (locCode == null) {
      debugPrint('No location code provided for getJobs');
      return [];
    }

    // Return cached if available and not forcing refresh
    final cached = _cachedJobsByLocation[locCode];
    if (!forceRefresh && cached != null && cached.isNotEmpty && offset == 0) {
      return cached;
    }

    try {
      var url = '$_baseUrl/workiz_locations.php?action=get_jobs&location_code=$locCode&limit=$limit&offset=$offset';
      if (status != null) url += '&status=${Uri.encodeComponent(status)}';
      if (dateFrom != null) url += '&date_from=${Uri.encodeComponent(dateFrom)}';
      if (dateTo != null) url += '&date_to=${Uri.encodeComponent(dateTo)}';

      final response = await _api.get(url);

      if (response.success) {
        final jobs = (response.rawJson?['jobs'] as List? ?? [])
            .map((j) => WorkizJob.fromJson(j))
            .toList();

        if (offset == 0) {
          _cachedJobsByLocation[locCode] = jobs;
        }
        return jobs;
      } else {
        // API returned an error message
        final errorMsg = response.message ?? 'Failed to load jobs';
        debugPrint('Workiz API error: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Error getting Workiz jobs: $e');
      rethrow;
    }
  }

  /// Search jobs by query (serial ID, customer name, address, phone)
  Future<List<WorkizJob>> searchJobs(String query, {String? locationCode}) async {
    if (query.length < 2) return [];

    final locCode = locationCode ?? _currentLocationCode;
    if (locCode == null) return [];

    try {
      final response = await _api.get(
        '$_baseUrl/workiz_locations.php?action=search_jobs&location_code=$locCode&q=${Uri.encodeComponent(query)}',
      );

      if (response.success) {
        final jobs = (response.rawJson?['jobs'] as List? ?? [])
            .map((j) {
              final jobMap = Map<String, dynamic>.from(j as Map);
              return WorkizJob.fromJson(jobMap);
            })
            .toList();
        return jobs;
      }
      return [];
    } catch (e) {
      debugPrint('Error searching Workiz jobs: $e');
      return [];
    }
  }

  /// Get job details with fresh data from Workiz
  Future<WorkizJob?> getJobDetails(String jobId, {bool fetchFresh = false}) async {
    try {
      final response = await _api.get(
        '$_baseUrl/workiz_integration.php?action=get_job&id=$jobId&fresh=${fetchFresh ? 'true' : 'false'}',
      );

      if (response.success && response.rawJson?['job'] != null) {
        return WorkizJob.fromJson(response.rawJson!['job']);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting Workiz job details: $e');
      return null;
    }
  }

  /// Create estimate in Workiz for a completed inspection
  Future<EstimateResult> createEstimate({
    required String workizJobId,
    required String clientId,
    required List<InvoiceItem> items,
  }) async {
    try {
      final response = await _api.post(
        '$_baseUrl/workiz_integration.php',
        body: {
          'action': 'create_estimate',
          'workiz_job_id': workizJobId,
          'client_id': clientId,
          'items': items.map((i) => i.toJson()).toList(),
        },
      );

      if (response.success) {
        return EstimateResult(
          success: true,
          estimateId: response.rawJson?['estimate_id']?.toString(),
          itemsAdded: response.rawJson?['items_added'] ?? [],
        );
      }
      return EstimateResult(success: false, error: response.message);
    } catch (e) {
      debugPrint('Error creating Workiz estimate: $e');
      return EstimateResult(success: false, error: e.toString());
    }
  }

  /// Clear cached data
  void clearCache({String? locationCode}) {
    if (locationCode != null) {
      _cachedJobsByLocation.remove(locationCode);
      _lastSyncByLocation.remove(locationCode);
    } else {
      _cachedJobsByLocation.clear();
      _lastSyncByLocation.clear();
    }
  }

  DateTime? getLastSync({String? locationCode}) {
    final locCode = locationCode ?? _currentLocationCode;
    return locCode != null ? _lastSyncByLocation[locCode] : null;
  }

  bool hasCachedJobs({String? locationCode}) {
    final locCode = locationCode ?? _currentLocationCode;
    return locCode != null && (_cachedJobsByLocation[locCode]?.isNotEmpty ?? false);
  }

  // Legacy getters for backward compatibility
  DateTime? get lastSync => getLastSync();
}

/// Workiz configuration status
class WorkizConfigStatus {
  final bool isConfigured;
  final String status;
  final DateTime? lastSync;
  final String? accountName;
  final String? locationCode;
  final bool hasApiToken;
  final String? message;

  WorkizConfigStatus({
    required this.isConfigured,
    required this.status,
    this.lastSync,
    this.accountName,
    this.locationCode,
    this.hasApiToken = false,
    this.message,
  });

  bool get isWorking => status == 'working';
  bool get hasAuthError => status == 'auth_error';
  bool get noContext => status == 'no_context';
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int syncedCount;
  final String message;

  SyncResult({
    required this.success,
    this.syncedCount = 0,
    this.message = '',
  });
}

/// Result of creating an estimate
class EstimateResult {
  final bool success;
  final String? estimateId;
  final List<dynamic> itemsAdded;
  final String? error;

  EstimateResult({
    required this.success,
    this.estimateId,
    this.itemsAdded = const [],
    this.error,
  });
}

/// Workiz Job model
class WorkizJob {
  final int id;
  final String? workizUuid;
  final int? workizNumericId;
  final String? workizSerialId;
  final String? clientId;
  final String? clientFirstName;
  final String? clientLastName;
  final String? clientPhone;
  final String? clientPhone2;
  final String? clientEmail;
  final String? clientEmail2;
  final String? address;
  final String? address2;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? jobType;
  final String? jobStatus;
  final DateTime? scheduledDate;
  final String? scheduledTime;
  final Map<String, dynamic>? jobData;
  final DateTime? syncedAt;

  WorkizJob({
    required this.id,
    this.workizUuid,
    this.workizNumericId,
    this.workizSerialId,
    this.clientId,
    this.clientFirstName,
    this.clientLastName,
    this.clientPhone,
    this.clientPhone2,
    this.clientEmail,
    this.clientEmail2,
    this.address,
    this.address2,
    this.city,
    this.state,
    this.zipCode,
    this.jobType,
    this.jobStatus,
    this.scheduledDate,
    this.scheduledTime,
    this.jobData,
    this.syncedAt,
  });

  factory WorkizJob.fromJson(Map<String, dynamic> json) {
    // Helper to safely convert any value to String?
    String? toStr(dynamic val) => val?.toString();

    // Helper to safely parse int
    int? toInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    return WorkizJob(
      id: toInt(json['id']) ?? 0,
      workizUuid: toStr(json['workiz_uuid']),
      workizNumericId: toInt(json['workiz_numeric_id']),
      workizSerialId: toStr(json['workiz_serial_id']),
      clientId: toStr(json['client_id']),
      clientFirstName: toStr(json['client_first_name']),
      clientLastName: toStr(json['client_last_name']),
      clientPhone: toStr(json['client_phone']),
      clientPhone2: toStr(json['client_phone2']),
      clientEmail: toStr(json['client_email']),
      clientEmail2: toStr(json['client_email2']),
      address: toStr(json['address']),
      address2: toStr(json['address2']),
      city: toStr(json['city']),
      state: toStr(json['state']),
      zipCode: toStr(json['zip_code']),
      jobType: toStr(json['job_type']),
      jobStatus: toStr(json['job_status']),
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.tryParse(json['scheduled_date'].toString())
          : null,
      scheduledTime: toStr(json['scheduled_time']),
      jobData: json['job_data'] is Map ? json['job_data'] : null,
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'].toString())
          : null,
    );
  }

  String get clientFullName {
    final first = clientFirstName ?? '';
    final last = clientLastName ?? '';
    return '$first $last'.trim();
  }

  String get fullAddress {
    final parts = <String>[];
    if (address?.isNotEmpty == true) parts.add(address!);
    if (address2?.isNotEmpty == true) parts.add(address2!);
    if (city?.isNotEmpty == true) parts.add(city!);
    if (state?.isNotEmpty == true) parts.add(state!);
    if (zipCode?.isNotEmpty == true) parts.add(zipCode!);
    return parts.join(', ');
  }

  String get displayLabel {
    final serial = workizSerialId ?? '';
    final name = clientFullName;
    if (serial.isNotEmpty && name.isNotEmpty) {
      return '#$serial - $name';
    } else if (serial.isNotEmpty) {
      return '#$serial';
    } else if (name.isNotEmpty) {
      return name;
    }
    return 'Job #$id';
  }
}

/// Invoice item for estimates
class InvoiceItem {
  final int? id;
  final int? workizId;
  final String name;
  final String? description;
  final int priceCents;
  final int quantity;
  final String? imageUrl;

  InvoiceItem({
    this.id,
    this.workizId,
    required this.name,
    this.description,
    required this.priceCents,
    this.quantity = 1,
    this.imageUrl,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      workizId: json['workiz_id'] is int
          ? json['workiz_id']
          : int.tryParse(json['workiz_id']?.toString() ?? ''),
      name: json['item_name'] ?? json['name'] ?? '',
      description: json['long_description'] ?? json['description'],
      priceCents: json['price_cents'] is int
          ? json['price_cents']
          : int.tryParse(json['price_cents']?.toString() ?? '0') ?? 0,
      quantity: json['quantity'] ?? 1,
      imageUrl: json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workiz_id': workizId,
      'name': name,
      'item_name': name,
      'description': description,
      'price_cents': priceCents,
      'price': priceCents / 100,
      'quantity': quantity,
      'image_url': imageUrl,
    };
  }

  String get priceDisplay => '\$${(priceCents / 100).toStringAsFixed(2)}';
  int get totalCents => priceCents * quantity;
  String get totalDisplay => '\$${(totalCents / 100).toStringAsFixed(2)}';
}
