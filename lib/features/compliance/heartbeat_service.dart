import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';

/// Heartbeat service that tracks online/away/offline status
/// - Online: App is open and focused
/// - Away: App is minimized or not focused
/// - Offline: App is closed (server determines this via timeout)
class HeartbeatService with WidgetsBindingObserver {
  static HeartbeatService? _instance;
  static HeartbeatService get instance => _instance ??= HeartbeatService._();

  HeartbeatService._();

  static String get _heartbeatUrl => ApiConfig.officeMap;
  static const Duration _heartbeatInterval = Duration(seconds: 20);
  final ApiClient _api = ApiClient.instance;
  
  Timer? _heartbeatTimer;
  String? _currentUsername;
  String _currentStatus = 'online';
  String _appVersion = '0.0.0';
  bool _isInitialized = false;
  
  /// Initialize and start the heartbeat service
  Future<void> start(String username) async {
    _currentUsername = username;
    
    // Get app version from pubspec.yaml
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      debugPrint('[Heartbeat] App version: $_appVersion');
    } catch (e) {
      debugPrint('[Heartbeat] Failed to get version: $e');
    }
    
    if (!_isInitialized) {
      WidgetsBinding.instance.addObserver(this);
      _isInitialized = true;
    }
    
    // Send initial heartbeat
    _sendHeartbeat();
    
    // Start periodic heartbeat
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
    
    debugPrint('[Heartbeat] Started for $username');
  }
  
  /// Stop the heartbeat service
  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
    }
    
    debugPrint('[Heartbeat] Stopped');
  }
  
  /// Called when app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground and focused
        _setStatus('online');
        break;
      case AppLifecycleState.inactive:
        // App is visible but not focused (e.g., during a phone call overlay)
        _setStatus('away');
        break;
      case AppLifecycleState.paused:
        // App is minimized or in background
        _setStatus('away');
        break;
      case AppLifecycleState.detached:
        // App is about to be terminated
        _setStatus('offline');
        break;
      case AppLifecycleState.hidden:
        // App is hidden (Windows specific)
        _setStatus('away');
        break;
    }
  }
  
  void _setStatus(String status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      debugPrint('[Heartbeat] Status changed to: $status');
      _sendHeartbeat(); // Send immediately on status change
    }
  }
  
  /// Manually set status (for testing or custom behavior)
  void setStatus(String status) {
    if (['online', 'away', 'offline'].contains(status)) {
      _setStatus(status);
    }
  }
  
  // Track consecutive failures for error recovery
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 5;

  /// Callback when authentication fails (401 error)
  /// Can be set by HomeScreen to handle logout
  void Function()? onAuthenticationError;

  /// Send heartbeat to server
  Future<void> _sendHeartbeat() async {
    if (_currentUsername == null) return;

    try {
      final response = await _api.post(
        _heartbeatUrl,
        body: {
          'action': 'heartbeat',
          'username': _currentUsername,
          'status': _currentStatus,
          'app_version': _appVersion,
        },
        timeout: const Duration(seconds: 10),
      );

      if (response.success) {
        debugPrint('[Heartbeat] Sent: $_currentStatus');
        _consecutiveFailures = 0; // Reset on success
      } else {
        _handleHeartbeatError(response.statusCode, response.error?.message);
      }
    } catch (e) {
      debugPrint('[Heartbeat] Failed: $e');
      _consecutiveFailures++;

      // Stop heartbeat if too many consecutive failures
      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        debugPrint('[Heartbeat] Too many consecutive failures ($_consecutiveFailures), stopping service');
        stop();
      }
    }
  }

  /// Handle heartbeat error responses
  void _handleHeartbeatError(int? statusCode, String? error) {
    _consecutiveFailures++;
    debugPrint('[Heartbeat] Error: statusCode=$statusCode, error=$error, failures=$_consecutiveFailures');

    // Handle authentication errors (401 Unauthorized)
    if (statusCode == 401) {
      debugPrint('[Heartbeat] Authentication failed - credentials may be stale');
      stop();
      onAuthenticationError?.call();
      return;
    }

    // Handle forbidden errors (403) - user may be blocked or deactivated
    if (statusCode == 403) {
      debugPrint('[Heartbeat] Access forbidden - user may be blocked');
      stop();
      onAuthenticationError?.call();
      return;
    }

    // Stop heartbeat if too many consecutive failures
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      debugPrint('[Heartbeat] Too many consecutive failures, stopping service');
      stop();
    }
  }
  
  /// Get current status
  String get currentStatus => _currentStatus;
  
  /// Get app version
  String get appVersion => _appVersion;
}
