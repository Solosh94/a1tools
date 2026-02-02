import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';

/// Heartbeat manager that tracks online/away/offline status
/// Sends heartbeat to office_map.php every 20 seconds
/// Also receives role updates, remote commands, and version blocking from server
class HeartbeatManager with WidgetsBindingObserver {
  final String Function() getUsername;
  final void Function(String status)? onStatusChanged;
  final void Function(String newRole)? onRoleChanged;
  final void Function(String command, int commandId, String issuedBy)? onRemoteCommand;
  final Future<void> Function()? onCaptureNow; // Callback to trigger immediate screenshot
  final Future<void> Function(String version, String downloadUrl)? onForceUpdate; // Callback to trigger forced update
  final void Function(String minimumVersion, String message, String? downloadUrl)? onVersionBlocked; // Callback when version is blocked

  // Send to office_map.php which updates a1tools_users table
  static String get _heartbeatUrl => ApiConfig.officeMap;
  static const Duration _heartbeatInterval = Duration(seconds: 20);
  final ApiClient _api = ApiClient.instance;

  Timer? _timer;
  String _currentStatus = 'online';
  String _appVersion = '0.0.0';
  String? _lastKnownRole;
  bool _isRunning = false;
  bool _initialized = false;
  bool _versionBlockNotified = false; // Only notify once per session

  HeartbeatManager({
    required this.getUsername,
    this.onStatusChanged,
    this.onRoleChanged,
    this.onRemoteCommand,
    this.onCaptureNow,
    this.onForceUpdate,
    this.onVersionBlocked,
  });

  /// Start sending heartbeats
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    
    // Get app version from pubspec.yaml
    if (!_initialized) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        _appVersion = packageInfo.version;
        debugPrint('[HeartbeatManager] App version: $_appVersion');
      } catch (e) {
        debugPrint('[HeartbeatManager] Failed to get version: $e');
        _appVersion = '0.0.0';
      }
      
      // Register as lifecycle observer
      WidgetsBinding.instance.addObserver(this);
      _initialized = true;
    }
    
    // Send initial heartbeat
    _sendHeartbeat();
    
    // Start periodic heartbeat
    _timer?.cancel();
    _timer = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
    
    debugPrint('[HeartbeatManager] Started for ${getUsername()}');
  }

  /// Stop sending heartbeats
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    debugPrint('[HeartbeatManager] Stopped');
  }

  /// Dispose and cleanup
  void dispose() {
    stop();
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
      _initialized = false;
    }
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
        // App is visible but not focused
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
      debugPrint('[HeartbeatManager] Status changed to: $status');
      onStatusChanged?.call(status);
      _sendHeartbeat(); // Send immediately on status change
    }
  }

  /// Send heartbeat to server
  Future<void> _sendHeartbeat() async {
    final username = getUsername();
    if (username.isEmpty) return;

    try {
      final response = await _api.post(
        _heartbeatUrl,
        body: {
          'action': 'heartbeat',
          'username': username,
          'status': _currentStatus,
          'app_version': _appVersion,
        },
        timeout: const Duration(seconds: 10),
      );

      if (response.success) {
        final data = response.rawJson;
        debugPrint('[HeartbeatManager] Sent: $_currentStatus (v$_appVersion)');

        // Check for role change
        if (data?['role'] != null) {
          final newRole = data!['role'] as String;
          if (_lastKnownRole != null && _lastKnownRole != newRole) {
            debugPrint('[HeartbeatManager] Role changed: $_lastKnownRole -> $newRole');
            onRoleChanged?.call(newRole);
          }
          _lastKnownRole = newRole;
        }

        // Check for pending remote commands
        if (data?['pending_command'] != null) {
          final cmd = data!['pending_command'];
          final command = cmd['command'] as String;
          final commandId = cmd['id'] as int;
          final issuedBy = cmd['issued_by'] as String;
          debugPrint('[HeartbeatManager] Received command: $command from $issuedBy');

          // Handle update command specially - extract version and download_url
          if (command == 'update' && cmd['version'] != null && cmd['download_url'] != null) {
            final version = cmd['version'] as String;
            final downloadUrl = cmd['download_url'] as String;
            debugPrint('[HeartbeatManager] Update command: v$version from $downloadUrl');
            _handleUpdateCommand(commandId, version, downloadUrl, issuedBy);
          } else {
            onRemoteCommand?.call(command, commandId, issuedBy);
          }
        }

        // Check for version blocking (real-time enforcement of minimum version)
        if (data?['version_blocked'] == true && !_versionBlockNotified) {
          final minimumVersion = data!['minimum_version'] as String? ?? '0.0.0';
          final message = data['version_message'] as String? ?? 'Your app is outdated.';
          final downloadUrl = data['version_download_url'] as String?;
          debugPrint('[HeartbeatManager] Version blocked! Minimum: $minimumVersion, Current: $_appVersion');
          _versionBlockNotified = true; // Only notify once
          onVersionBlocked?.call(minimumVersion, message, downloadUrl);
        }
      } else {
        debugPrint('[HeartbeatManager] Server error: ${response.message}');
      }
    } catch (e) {
      debugPrint('[HeartbeatManager] Failed: $e');
    }
  }

  /// Handle update command - triggers forced update download
  Future<void> _handleUpdateCommand(int commandId, String version, String downloadUrl, String issuedBy) async {
    debugPrint('[HeartbeatManager] Processing update command: v$version');
    
    if (onForceUpdate == null) {
      debugPrint('[HeartbeatManager] No update handler registered');
      await acknowledgeCommand(commandId, result: 'No update handler', status: 'failed');
      return;
    }
    
    try {
      // Acknowledge that we're starting the update
      await acknowledgeCommand(commandId, result: 'Starting update to v$version', status: 'executing');
      
      // Trigger the update
      await onForceUpdate!(version, downloadUrl);
      
      // Note: If update succeeds, the app will restart, so we won't reach here
      // If we do reach here, it means update was deferred or failed
      
    } catch (e) {
      debugPrint('[HeartbeatManager] Update failed: $e');
      await acknowledgeCommand(commandId, result: 'Error: $e', status: 'failed');
    }
  }

  /// Acknowledge command execution
  Future<void> acknowledgeCommand(int commandId, {String result = 'executed', String status = 'executed'}) async {
    try {
      await _api.post(
        _heartbeatUrl,
        body: {
          'action': 'command_executed',
          'command_id': commandId,
          'result': result,
          'status': status,
        },
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('[HeartbeatManager] Failed to acknowledge command: $e');
    }
  }

  /// Execute a remote command (shutdown/restart/capture_now)
  Future<void> executeRemoteCommand(String command, int commandId, String issuedBy) async {
    debugPrint('[HeartbeatManager] Executing remote command: $command');
    
    // Handle capture_now command (works on all platforms)
    if (command == 'capture_now') {
      try {
        if (onCaptureNow != null) {
          await onCaptureNow!();
          await acknowledgeCommand(commandId, result: 'Capture triggered', status: 'executed');
        } else {
          await acknowledgeCommand(commandId, result: 'No capture handler', status: 'failed');
        }
      } catch (e) {
        await acknowledgeCommand(commandId, result: 'Error: $e', status: 'failed');
      }
      return;
    }
    
    // Shutdown/restart only on Windows
    if (!Platform.isWindows) {
      debugPrint('[HeartbeatManager] Remote commands only supported on Windows');
      await acknowledgeCommand(commandId, result: 'Not Windows', status: 'failed');
      return;
    }
    
    try {
      String psCommand;
      if (command == 'shutdown') {
        psCommand = 'shutdown /s /f /t 5'; // Force shutdown in 5 seconds
      } else if (command == 'restart') {
        psCommand = 'shutdown /r /f /t 5'; // Force restart in 5 seconds
      } else {
        await acknowledgeCommand(commandId, result: 'Unknown command: $command', status: 'failed');
        return;
      }

      // Acknowledge before executing (since we might not come back online)
      await acknowledgeCommand(commandId, result: 'Executing $command', status: 'executed');
      
      // Small delay to ensure acknowledgment is sent
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Execute the command
      await Process.run('cmd', ['/c', psCommand]);
      
    } catch (e) {
      debugPrint('[HeartbeatManager] Command execution failed: $e');
      await acknowledgeCommand(commandId, result: 'Error: $e', status: 'failed');
    }
  }

  /// Set last known role (for initial sync)
  void setLastKnownRole(String? role) {
    _lastKnownRole = role;
  }

  /// Get current status
  String get currentStatus => _currentStatus;
  
  /// Get app version
  String get appVersion => _appVersion;
}
