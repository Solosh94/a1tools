// Suggestion Service
//
// Handles API communication for the suggestion system.
// Users can submit suggestions for app improvements.
// Admins can view and manage all suggestions.

import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';

/// Model for a suggestion
class Suggestion {
  final int id;
  final String username;
  final String? firstName;
  final String? lastName;
  final String suggestion;
  final String status; // 'pending', 'reviewed', 'implemented', 'declined'
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  Suggestion({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    required this.suggestion,
    required this.status,
    this.adminNotes,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      username: json['username'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      suggestion: json['suggestion'] ?? '',
      status: json['status'] ?? 'pending',
      adminNotes: json['admin_notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'])
          : null,
      reviewedBy: json['reviewed_by'],
    );
  }

  String get displayName {
    if (firstName != null && firstName!.isNotEmpty) {
      if (lastName != null && lastName!.isNotEmpty) {
        return '$firstName $lastName';
      }
      return firstName!;
    }
    return username;
  }
}

class SuggestionService {
  static String get _baseUrl => ApiConfig.suggestions;
  static final ApiClient _api = ApiClient.instance;

  /// Submit a new suggestion
  static Future<bool> submitSuggestion({
    required String username,
    required String suggestion,
  }) async {
    try {
      final response = await _api.post(
        _baseUrl,
        body: {
          'action': 'submit',
          'username': username,
          'suggestion': suggestion,
        },
        timeout: const Duration(seconds: 15),
      );

      return response.success;
    } catch (e) {
      debugPrint('[SuggestionService] Submit error: $e');
      return false;
    }
  }

  /// Get all suggestions (admin only)
  static Future<List<Suggestion>> getAllSuggestions({String? status}) async {
    try {
      var url = '$_baseUrl?action=list';
      if (status != null && status.isNotEmpty) {
        url += '&status=$status';
      }

      final response = await _api.get(url, timeout: const Duration(seconds: 15));

      if (response.success && response.rawJson?['suggestions'] != null) {
        return (response.rawJson!['suggestions'] as List)
            .map((s) => Suggestion.fromJson(s))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[SuggestionService] Get all error: $e');
      return [];
    }
  }

  /// Update suggestion status (admin only)
  static Future<bool> updateSuggestionStatus({
    required int suggestionId,
    required String status,
    String? adminNotes,
    required String reviewedBy,
  }) async {
    try {
      final response = await _api.post(
        _baseUrl,
        body: {
          'action': 'update_status',
          'suggestion_id': suggestionId,
          'status': status,
          'admin_notes': adminNotes,
          'reviewed_by': reviewedBy,
        },
        timeout: const Duration(seconds: 15),
      );

      return response.success;
    } catch (e) {
      debugPrint('[SuggestionService] Update status error: $e');
      return false;
    }
  }

  /// Delete a suggestion (admin only)
  static Future<bool> deleteSuggestion(int suggestionId) async {
    try {
      final response = await _api.post(
        _baseUrl,
        body: {
          'action': 'delete',
          'suggestion_id': suggestionId,
        },
        timeout: const Duration(seconds: 15),
      );

      return response.success;
    } catch (e) {
      debugPrint('[SuggestionService] Delete error: $e');
      return false;
    }
  }
}
