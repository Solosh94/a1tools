import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

/// Model representing a privacy exclusion entry
class PrivacyExclusion {
  final int id;
  final String programName;
  final String displayName;
  final String matchType; // 'exact' or 'contains'
  final bool isActive;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;

  PrivacyExclusion({
    required this.id,
    required this.programName,
    required this.displayName,
    required this.matchType,
    required this.isActive,
    this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  factory PrivacyExclusion.fromJson(Map<String, dynamic> json) {
    return PrivacyExclusion(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      programName: json['program_name'] ?? '',
      displayName: json['display_name'] ?? json['program_name'] ?? '',
      matchType: json['match_type'] ?? 'exact',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      notes: json['notes'],
      createdBy: json['created_by'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'program_name': programName,
      'display_name': displayName,
      'match_type': matchType,
      'is_active': isActive ? 1 : 0,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Service for managing privacy exclusions
/// Programs in this list will be hidden from screenshots and dashboard program lists
class PrivacyExclusionsService {
  static const String _baseUrl = ApiConfig.privacyExclusions;

  // Cache for exclusions (used by monitoring services)
  static List<PrivacyExclusion> _cachedExclusions = [];
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// List all privacy exclusions
  static Future<List<PrivacyExclusion>> list() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=list'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final exclusions = (data['exclusions'] as List? ?? [])
              .map((e) => PrivacyExclusion.fromJson(e))
              .toList();

          // Update cache
          _cachedExclusions = exclusions;
          _cacheTime = DateTime.now();

          return exclusions;
        } else {
          debugPrint('[PrivacyExclusionsService] List failed: ${data['error']}');
        }
      } else {
        debugPrint('[PrivacyExclusionsService] HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[PrivacyExclusionsService] List error: $e');
    }
    return [];
  }

  /// Add a new privacy exclusion
  static Future<bool> add({
    required String programName,
    required String displayName,
    String matchType = 'exact',
    String? notes,
    required String createdBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'program_name': programName.toLowerCase().trim(),
          'display_name': displayName.trim(),
          'match_type': matchType,
          'notes': notes?.trim(),
          'created_by': createdBy,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Invalidate cache
          _cacheTime = null;
          return true;
        } else {
          debugPrint('[PrivacyExclusionsService] Add failed: ${data['error']}');
        }
      }
    } catch (e) {
      debugPrint('[PrivacyExclusionsService] Add error: $e');
    }
    return false;
  }

  /// Remove a privacy exclusion by ID
  static Future<bool> remove(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=remove'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Invalidate cache
          _cacheTime = null;
          return true;
        } else {
          debugPrint('[PrivacyExclusionsService] Remove failed: ${data['error']}');
        }
      }
    } catch (e) {
      debugPrint('[PrivacyExclusionsService] Remove error: $e');
    }
    return false;
  }

  /// Get cached exclusions (for use by monitoring services)
  /// Returns immediately from cache if available and not expired
  static Future<List<PrivacyExclusion>> getCachedExclusions() async {
    // Check if cache is valid
    if (_cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration &&
        _cachedExclusions.isNotEmpty) {
      return _cachedExclusions;
    }

    // Refresh cache
    return await list();
  }

  /// Get just the program names for quick matching
  /// Used by screenshot capture and metrics filtering
  static Future<List<String>> getExcludedProgramNames() async {
    final exclusions = await getCachedExclusions();
    return exclusions
        .where((e) => e.isActive)
        .map((e) => e.programName.toLowerCase())
        .toList();
  }

  /// Check if a program name matches any exclusion
  static Future<bool> isExcluded(String programName) async {
    final exclusions = await getCachedExclusions();
    final lowerName = programName.toLowerCase();

    for (final exclusion in exclusions) {
      if (!exclusion.isActive) continue;

      if (exclusion.matchType == 'exact') {
        if (lowerName == exclusion.programName.toLowerCase()) {
          return true;
        }
      } else if (exclusion.matchType == 'contains') {
        if (lowerName.contains(exclusion.programName.toLowerCase())) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if a program name matches any exclusion (synchronous, uses cache only)
  /// Use this in hot paths where async is not desirable
  static bool isExcludedSync(String programName) {
    if (_cachedExclusions.isEmpty) return false;

    final lowerName = programName.toLowerCase();

    for (final exclusion in _cachedExclusions) {
      if (!exclusion.isActive) continue;

      if (exclusion.matchType == 'exact') {
        if (lowerName == exclusion.programName.toLowerCase()) {
          return true;
        }
      } else if (exclusion.matchType == 'contains') {
        if (lowerName.contains(exclusion.programName.toLowerCase())) {
          return true;
        }
      }
    }
    return false;
  }

  /// Invalidate cache (call when exclusions change)
  static void invalidateCache() {
    _cacheTime = null;
    _cachedExclusions = [];
  }

  /// Pre-warm the cache (call on app startup)
  static Future<void> warmCache() async {
    await getCachedExclusions();
  }

  /// Get suggested programs based on common usage across all monitored users
  /// Returns programs that are commonly used but not yet excluded
  static Future<List<ProgramSuggestion>> getSuggestions({int limit = 20}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?action=suggestions&limit=$limit'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return (data['suggestions'] as List? ?? [])
              .map((e) => ProgramSuggestion.fromJson(e))
              .toList();
        } else {
          debugPrint('[PrivacyExclusionsService] Suggestions failed: ${data['error']}');
        }
      } else {
        debugPrint('[PrivacyExclusionsService] HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[PrivacyExclusionsService] Suggestions error: $e');
    }
    return [];
  }
}

/// Model representing a program suggestion
class ProgramSuggestion {
  final String programName;
  final String displayName;
  final int userCount;
  final int occurrenceCount;
  final String category;
  final bool isPrivacySensitive;

  ProgramSuggestion({
    required this.programName,
    required this.displayName,
    required this.userCount,
    required this.occurrenceCount,
    required this.category,
    required this.isPrivacySensitive,
  });

  factory ProgramSuggestion.fromJson(Map<String, dynamic> json) {
    return ProgramSuggestion(
      programName: json['program_name'] ?? '',
      displayName: json['display_name'] ?? json['program_name'] ?? '',
      userCount: json['user_count'] is int
          ? json['user_count']
          : int.tryParse(json['user_count']?.toString() ?? '0') ?? 0,
      occurrenceCount: json['occurrence_count'] is int
          ? json['occurrence_count']
          : int.tryParse(json['occurrence_count']?.toString() ?? '0') ?? 0,
      category: json['category'] ?? 'other',
      isPrivacySensitive: json['is_privacy_sensitive'] == true ||
          json['is_privacy_sensitive'] == 1,
    );
  }

  /// Get a user-friendly category label
  String get categoryLabel {
    switch (category) {
      case 'browser':
        return 'Browser';
      case 'communication':
        return 'Communication';
      case 'email':
        return 'Email';
      case 'password_manager':
        return 'Password Manager';
      case 'vpn':
        return 'VPN';
      case 'development':
        return 'Development';
      case 'office':
        return 'Office';
      case 'media':
        return 'Media';
      case 'graphics':
        return 'Graphics';
      case 'finance':
        return 'Finance';
      case 'gaming':
        return 'Gaming';
      case 'cloud_storage':
        return 'Cloud Storage';
      default:
        return 'Other';
    }
  }
}
