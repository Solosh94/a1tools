import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../../config/api_config.dart';

/// Service to check if app version meets minimum requirements
/// Used to block outdated app versions from accessing the app
class VersionCheckService {
  static VersionCheckService? _instance;
  static VersionCheckService get instance => _instance ??= VersionCheckService._();

  VersionCheckService._();

  String _currentVersion = '0.0.0';
  bool _initialized = false;
  VersionCheckResult? _lastResult;

  /// Get current app version
  String get currentVersion => _currentVersion;

  /// Get last check result
  VersionCheckResult? get lastResult => _lastResult;

  /// Initialize the service and get current version
  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;
      _initialized = true;
      debugPrint('[VersionCheck] Current version: $_currentVersion');
    } catch (e) {
      debugPrint('[VersionCheck] Failed to get version: $e');
      _currentVersion = '0.0.0';
    }
  }

  /// Check if current version meets minimum requirements
  /// Returns VersionCheckResult with blocked status and details
  Future<VersionCheckResult> checkVersion() async {
    await _ensureInitialized();

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url =
          '${ApiConfig.appUpdate}?action=check_minimum&version=$_currentVersion&_t=$timestamp';

      debugPrint('[VersionCheck] Checking: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final result = VersionCheckResult(
            blocked: data['blocked'] ?? false,
            currentVersion: _currentVersion,
            minimumVersion: data['minimum_version'] ?? '0.0.0',
            message: data['message'] ?? 'Your app is outdated. Please update.',
            downloadUrl: data['download_url'],
          );

          _lastResult = result;

          debugPrint('[VersionCheck] Result: blocked=${result.blocked}, '
              'current=$_currentVersion, minimum=${result.minimumVersion}');

          return result;
        }
      }

      debugPrint('[VersionCheck] Server returned non-success, allowing access');
      return VersionCheckResult.allowed(_currentVersion);
    } catch (e) {
      // On network error, don't block the user
      debugPrint('[VersionCheck] Error: $e - allowing access');
      return VersionCheckResult.allowed(_currentVersion);
    }
  }

  /// Compare two version strings
  /// Returns true if version1 < version2
  static bool isVersionOlder(String version1, String version2) {
    final v1Parts = version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final v2Parts = version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final v1 = i < v1Parts.length ? v1Parts[i] : 0;
      final v2 = i < v2Parts.length ? v2Parts[i] : 0;
      if (v1 < v2) return true;
      if (v1 > v2) return false;
    }
    return false;
  }
}

/// Result of a version check
class VersionCheckResult {
  final bool blocked;
  final String currentVersion;
  final String minimumVersion;
  final String message;
  final String? downloadUrl;

  VersionCheckResult({
    required this.blocked,
    required this.currentVersion,
    required this.minimumVersion,
    required this.message,
    this.downloadUrl,
  });

  /// Create an allowed result (not blocked)
  factory VersionCheckResult.allowed(String currentVersion) {
    return VersionCheckResult(
      blocked: false,
      currentVersion: currentVersion,
      minimumVersion: '0.0.0',
      message: '',
    );
  }
}
