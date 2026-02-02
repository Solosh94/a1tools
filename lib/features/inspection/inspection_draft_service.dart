import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';

/// Service for managing inspection report drafts
/// Supports both local storage and server-side drafts
class InspectionDraftService {
  static String get _baseUrl => ApiConfig.apiBase;
  static const String _localDraftsKey = 'inspection_drafts';
  static const String _autoSaveKey = 'inspection_autosave_';

  // Singleton pattern
  static final InspectionDraftService _instance = InspectionDraftService._internal();
  factory InspectionDraftService() => _instance;
  InspectionDraftService._internal();

  final ApiClient _api = ApiClient.instance;

  /// Save draft to local storage (for offline support)
  Future<bool> saveLocalDraft(String username, Map<String, dynamic> formData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = prefs.getString(_localDraftsKey);
      final drafts = draftsJson != null ? json.decode(draftsJson) as Map<String, dynamic> : {};

      // Create draft entry
      final draftId = DateTime.now().millisecondsSinceEpoch.toString();
      final draft = {
        'id': draftId,
        'username': username,
        'form_data': formData,
        'saved_at': DateTime.now().toIso8601String(),
        'synced': false,
      };

      // Add to drafts keyed by username
      if (!drafts.containsKey(username)) {
        drafts[username] = [];
      }
      (drafts[username] as List).add(draft);

      await prefs.setString(_localDraftsKey, json.encode(drafts));
      return true;
    } catch (e) {
      debugPrint('Error saving local draft: $e');
      return false;
    }
  }

  /// Auto-save current form state (single draft per user)
  Future<bool> autoSave(String username, Map<String, dynamic> formData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoSave = {
        'username': username,
        'form_data': formData,
        'saved_at': DateTime.now().toIso8601String(),
      };
      await prefs.setString('$_autoSaveKey$username', json.encode(autoSave));
      return true;
    } catch (e) {
      debugPrint('Error auto-saving: $e');
      return false;
    }
  }

  /// Get auto-saved form data
  Future<Map<String, dynamic>?> getAutoSave(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoSaveJson = prefs.getString('$_autoSaveKey$username');
      if (autoSaveJson != null) {
        final autoSave = json.decode(autoSaveJson) as Map<String, dynamic>;
        return autoSave['form_data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting auto-save: $e');
      return null;
    }
  }

  /// Clear auto-saved data
  Future<void> clearAutoSave(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_autoSaveKey$username');
    } catch (e) {
      debugPrint('Error clearing auto-save: $e');
    }
  }

  /// Get last auto-save time
  Future<DateTime?> getAutoSaveTime(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoSaveJson = prefs.getString('$_autoSaveKey$username');
      if (autoSaveJson != null) {
        final autoSave = json.decode(autoSaveJson) as Map<String, dynamic>;
        final savedAt = autoSave['saved_at'] as String?;
        if (savedAt != null) {
          return DateTime.tryParse(savedAt);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get all local drafts for a user
  Future<List<InspectionDraft>> getLocalDrafts(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = prefs.getString(_localDraftsKey);
      if (draftsJson == null) return [];

      final drafts = json.decode(draftsJson) as Map<String, dynamic>;
      final userDrafts = drafts[username] as List?;
      if (userDrafts == null) return [];

      return userDrafts
          .map((d) => InspectionDraft.fromLocalJson(d as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error getting local drafts: $e');
      return [];
    }
  }

  /// Delete a local draft
  Future<bool> deleteLocalDraft(String username, String draftId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = prefs.getString(_localDraftsKey);
      if (draftsJson == null) return true;

      final drafts = json.decode(draftsJson) as Map<String, dynamic>;
      final userDrafts = drafts[username] as List?;
      if (userDrafts == null) return true;

      userDrafts.removeWhere((d) => d['id'] == draftId);
      drafts[username] = userDrafts;

      await prefs.setString(_localDraftsKey, json.encode(drafts));
      return true;
    } catch (e) {
      debugPrint('Error deleting local draft: $e');
      return false;
    }
  }

  /// Save draft to server
  Future<DraftSaveResult> saveDraftToServer(Map<String, dynamic> formData) async {
    try {
      final body = Map<String, dynamic>.from(formData);
      body['action'] = 'save_draft';

      final response = await _api.post(
        '$_baseUrl/inspection_reports.php',
        body: body,
        timeout: const Duration(seconds: 30),
      );

      if (response.success) {
        return DraftSaveResult(
          success: true,
          reportId: response.rawJson?['report_id'],
          message: response.rawJson?['message'] ?? 'Draft saved',
        );
      }
      return DraftSaveResult(success: false, message: response.message ?? 'Save failed');
    } catch (e) {
      debugPrint('Error saving draft to server: $e');
      return DraftSaveResult(success: false, message: e.toString());
    }
  }

  /// Get server-side drafts for a user
  Future<List<InspectionDraft>> getServerDrafts(String username) async {
    try {
      final response = await _api.get(
        '$_baseUrl/inspection_reports.php?action=list_drafts&username=$username',
      );

      if (response.success && response.rawJson?['drafts'] != null) {
        return (response.rawJson!['drafts'] as List)
            .map((d) => InspectionDraft.fromServerJson(d as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting server drafts: $e');
      return [];
    }
  }

  /// Get all drafts (both local and server) for a user
  Future<List<InspectionDraft>> getAllDrafts(String username) async {
    final results = await Future.wait([
      getLocalDrafts(username),
      getServerDrafts(username),
    ]);

    final localDrafts = results[0];
    final serverDrafts = results[1];

    // Combine and sort by date (newest first)
    final allDrafts = [...localDrafts, ...serverDrafts];
    allDrafts.sort((a, b) => b.savedAt.compareTo(a.savedAt));

    return allDrafts;
  }

  /// Sync local drafts to server (when online)
  Future<SyncResult> syncLocalDrafts(String username) async {
    try {
      final localDrafts = await getLocalDrafts(username);
      final unsyncedDrafts = localDrafts.where((d) => !d.synced).toList();

      if (unsyncedDrafts.isEmpty) {
        return SyncResult(success: true, syncedCount: 0, message: 'Nothing to sync');
      }

      int syncedCount = 0;
      final errors = <String>[];

      for (final draft in unsyncedDrafts) {
        final result = await saveDraftToServer(draft.formData);
        if (result.success) {
          await deleteLocalDraft(username, draft.id);
          syncedCount++;
        } else {
          errors.add('Draft ${draft.id}: ${result.message}');
        }
      }

      return SyncResult(
        success: errors.isEmpty,
        syncedCount: syncedCount,
        message: errors.isEmpty
            ? 'Synced $syncedCount drafts'
            : 'Synced $syncedCount drafts with ${errors.length} errors',
        errors: errors,
      );
    } catch (e) {
      return SyncResult(success: false, message: e.toString());
    }
  }
}

/// Model for an inspection draft
class InspectionDraft {
  final String id;
  final String? username;
  final Map<String, dynamic> formData;
  final DateTime savedAt;
  final bool synced;
  final bool isLocal;

  // Convenience getters from form data
  String get customerName {
    final first = formData['first_name'] ?? '';
    final last = formData['last_name'] ?? '';
    return '$first $last'.trim();
  }

  String get address => formData['address1'] ?? '';
  String get systemType => formData['system_type'] ?? '';
  String get inspectionLevel => formData['inspection_level'] ?? '';
  String? get workizJobSerial => formData['workiz_job_serial'];

  InspectionDraft({
    required this.id,
    this.username,
    required this.formData,
    required this.savedAt,
    this.synced = false,
    this.isLocal = true,
  });

  factory InspectionDraft.fromLocalJson(Map<String, dynamic> json) {
    return InspectionDraft(
      id: json['id']?.toString() ?? '',
      username: json['username'],
      formData: json['form_data'] ?? {},
      savedAt: DateTime.tryParse(json['saved_at'] ?? '') ?? DateTime.now(),
      synced: json['synced'] ?? false,
      isLocal: true,
    );
  }

  factory InspectionDraft.fromServerJson(Map<String, dynamic> json) {
    return InspectionDraft(
      id: json['id']?.toString() ?? '',
      username: json['inspector_username'],
      formData: json, // Server returns full form data
      savedAt: DateTime.tryParse(json['draft_saved_at'] ?? json['created_at'] ?? '') ?? DateTime.now(),
      synced: true,
      isLocal: false,
    );
  }

  String get displayLabel {
    if (customerName.isNotEmpty) return customerName;
    if (workizJobSerial != null) return 'Job #$workizJobSerial';
    return 'Draft';
  }

  String get subtitle {
    final parts = <String>[];
    if (address.isNotEmpty) parts.add(address);
    if (systemType.isNotEmpty) parts.add(systemType);
    return parts.join(' - ');
  }
}

/// Result of saving a draft
class DraftSaveResult {
  final bool success;
  final int? reportId;
  final String message;

  DraftSaveResult({
    required this.success,
    this.reportId,
    this.message = '',
  });
}

/// Result of syncing drafts
class SyncResult {
  final bool success;
  final int syncedCount;
  final String message;
  final List<String> errors;

  SyncResult({
    required this.success,
    this.syncedCount = 0,
    this.message = '',
    this.errors = const [],
  });
}
