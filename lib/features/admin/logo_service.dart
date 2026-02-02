import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';

/// Logo Service
///
/// Handles fetching the configured company logo for PDF reports.
/// Implements caching and fallback to default asset logo.
class LogoService {
  static String get _baseUrl => ApiConfig.logoConfig;
  static final ApiClient _api = ApiClient.instance;

  // Cache the logo to avoid repeated API calls
  static Uint8List? _cachedLogo;
  static String? _cachedLogoType;
  static DateTime? _lastFetch;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Get the company logo for PDF reports
  ///
  /// Returns the configured custom logo if available,
  /// otherwise returns the default asset logo.
  /// Implements caching to avoid repeated API calls.
  static Future<Uint8List?> getCompanyLogo() async {
    // Check cache
    if (_cachedLogo != null && _lastFetch != null) {
      final age = DateTime.now().difference(_lastFetch!);
      if (age < _cacheExpiry) {
        return _cachedLogo;
      }
    }

    try {
      // Fetch from server
      final response = await _api.get(
        '$_baseUrl?action=get_logo',
        timeout: const Duration(seconds: 10),
      );

      if (response.success) {
        final data = response.rawJson;
        if (data?['logo_type'] == 'custom' && data?['logo_base64'] != null) {
          // Use custom logo
          _cachedLogo = base64Decode(data!['logo_base64']);
          _cachedLogoType = 'custom';
          _lastFetch = DateTime.now();
          return _cachedLogo;
        }
      }
    } catch (e) {
      // Log error but continue to fallback
      debugPrint('LogoService: Failed to fetch custom logo: $e');
    }

    // Fallback to default asset logo
    return _getDefaultLogo();
  }

  /// Get the default logo from assets
  static Future<Uint8List?> _getDefaultLogo() async {
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      _cachedLogo = logoData.buffer.asUint8List();
      _cachedLogoType = 'default';
      _lastFetch = DateTime.now();
      return _cachedLogo;
    } catch (e) {
      debugPrint('LogoService: Failed to load default logo: $e');
      return null;
    }
  }

  /// Force refresh the logo cache
  static Future<Uint8List?> refreshLogo() async {
    _cachedLogo = null;
    _cachedLogoType = null;
    _lastFetch = null;
    return getCompanyLogo();
  }

  /// Check if current logo is custom or default
  static String? get currentLogoType => _cachedLogoType;

  /// Clear the cache (useful after uploading a new logo)
  static void clearCache() {
    _cachedLogo = null;
    _cachedLogoType = null;
    _lastFetch = null;
  }
}
