// VM Monitor Service
//
// Provides real-time monitoring of VM detection settings.
// Periodically checks the server for VM detection status and per-user blocks.
// Allows admins to enable/disable VM blocking in real-time without app restart.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/api_config.dart';
import 'vm_detection_service.dart';

/// VM Monitor status for callbacks
class VmMonitorStatus {
  final bool isBlocked;
  final bool isGloballyEnabled;
  final bool isUserBlocked;
  final String? blockedReason;
  final bool canUpdate;

  const VmMonitorStatus({
    required this.isBlocked,
    required this.isGloballyEnabled,
    required this.isUserBlocked,
    this.blockedReason,
    this.canUpdate = true,
  });

  @override
  String toString() =>
      'VmMonitorStatus(blocked: $isBlocked, global: $isGloballyEnabled, userBlocked: $isUserBlocked)';
}

/// Callback type for VM status changes
typedef VmStatusCallback = void Function(VmMonitorStatus status);

/// Service that monitors VM detection settings in real-time
class VmMonitorService {
  VmMonitorService._();
  static final VmMonitorService instance = VmMonitorService._();

  static const _storage = FlutterSecureStorage();
  static const String _keyUsername = 'a1_tools_username';
  static const String _keyRole = 'a1_tools_role';

  /// Polling interval for checking VM status (30 seconds)
  static const Duration _pollInterval = Duration(seconds: 30);

  Timer? _pollTimer;
  VmStatusCallback? _onStatusChanged;
  VmMonitorStatus? _lastStatus;
  bool _isMonitoring = false;

  /// Cached VM detection result
  VmDetectionResult? _vmDetectionResult;

  /// Whether the local machine is a VM
  bool get isVirtualMachine => _vmDetectionResult?.isVirtualMachine ?? false;

  /// The detected VM type
  String? get detectedVm => _vmDetectionResult?.detectedVm;

  /// Detection indicators
  List<String> get indicators => _vmDetectionResult?.indicators ?? [];

  /// Current monitoring status
  VmMonitorStatus? get currentStatus => _lastStatus;

  /// Whether monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// Initialize the service and perform initial VM detection
  Future<void> initialize() async {
    if (Platform.isWindows) {
      _vmDetectionResult = await VmDetectionService.instance.detect();
      debugPrint('[VmMonitor] Initial detection: $_vmDetectionResult');
    }
  }

  /// Start monitoring VM status with periodic checks
  void startMonitoring({VmStatusCallback? onStatusChanged}) {
    if (_isMonitoring) {
      debugPrint('[VmMonitor] Already monitoring');
      return;
    }

    _onStatusChanged = onStatusChanged;
    _isMonitoring = true;

    // Perform initial check
    _checkVmStatus();

    // Start periodic polling
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkVmStatus());
    debugPrint('[VmMonitor] Started monitoring (interval: ${_pollInterval.inSeconds}s)');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isMonitoring = false;
    debugPrint('[VmMonitor] Stopped monitoring');
  }

  /// Force an immediate status check
  Future<VmMonitorStatus> checkNow() async {
    return await _checkVmStatus();
  }

  /// Report VM status to server (called periodically to update user's VM status)
  Future<void> reportVmStatus() async {
    if (!Platform.isWindows) return;

    try {
      final username = await _storage.read(key: _keyUsername);
      if (username == null) return;

      final response = await http.post(
        Uri.parse('${ApiConfig.vmSettings}?action=report_vm_status'),
        body: {
          'username': username,
          'is_vm': isVirtualMachine ? '1' : '0',
          'vm_type': detectedVm ?? '',
          'indicators': jsonEncode(indicators),
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('[VmMonitor] VM status reported successfully');
        }
      }
    } catch (e) {
      debugPrint('[VmMonitor] Failed to report VM status: $e');
    }
  }

  /// Check VM status from server and notify if changed
  Future<VmMonitorStatus> _checkVmStatus() async {
    try {
      final username = await _storage.read(key: _keyUsername);
      final role = await _storage.read(key: _keyRole);

      // Check if user has bypass privilege
      final bypassRoles = ['developer', 'administrator'];
      final hasBypass = role != null && bypassRoles.contains(role.toLowerCase());

      if (hasBypass) {
        // Developers and administrators are never blocked
        const status = VmMonitorStatus(
          isBlocked: false,
          isGloballyEnabled: false,
          isUserBlocked: false,
          canUpdate: true,
        );
        _updateStatus(status);
        return status;
      }

      // Fetch status from server
      final response = await http.get(
        Uri.parse('${ApiConfig.vmSettings}?action=get_user_status&username=${username ?? ''}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final isGloballyEnabled = data['vm_detection_enabled'] == true;
          final isUserBlocked = data['user_blocked'] == true;

          // If VM detection is now enabled but we haven't detected yet, run detection
          if (isGloballyEnabled && _vmDetectionResult == null && Platform.isWindows) {
            debugPrint('[VmMonitor] VM detection enabled but no cached result, running detection...');
            _vmDetectionResult = await VmDetectionService.instance.detect();
            debugPrint('[VmMonitor] Detection result: $_vmDetectionResult');
          }

          // Determine if user should be blocked
          // Blocked if: (global enabled AND is VM) OR (specifically blocked for this user)
          final shouldBlock = isUserBlocked ||
              (isGloballyEnabled && isVirtualMachine);

          String? reason;
          if (isUserBlocked) {
            reason = 'Your account has been specifically blocked from VM access';
          } else if (isGloballyEnabled && isVirtualMachine) {
            reason = 'VM detection is enabled globally';
          }

          final status = VmMonitorStatus(
            isBlocked: shouldBlock,
            isGloballyEnabled: isGloballyEnabled,
            isUserBlocked: isUserBlocked,
            blockedReason: reason,
            canUpdate: true,
          );

          _updateStatus(status);

          // Report VM status to server periodically
          if (isVirtualMachine) {
            reportVmStatus();
          }

          return status;
        }
      }

      // If we can't reach the server, don't block (fail open)
      final status = VmMonitorStatus(
        isBlocked: _lastStatus?.isBlocked ?? false,
        isGloballyEnabled: _lastStatus?.isGloballyEnabled ?? false,
        isUserBlocked: _lastStatus?.isUserBlocked ?? false,
        canUpdate: true,
      );
      return status;
    } catch (e) {
      debugPrint('[VmMonitor] Status check failed: $e');
      // On error, maintain last known status
      return _lastStatus ??
          const VmMonitorStatus(
            isBlocked: false,
            isGloballyEnabled: false,
            isUserBlocked: false,
            canUpdate: true,
          );
    }
  }

  /// Update status and notify callback if changed
  void _updateStatus(VmMonitorStatus status) {
    final changed = _lastStatus == null ||
        _lastStatus!.isBlocked != status.isBlocked ||
        _lastStatus!.isGloballyEnabled != status.isGloballyEnabled ||
        _lastStatus!.isUserBlocked != status.isUserBlocked;

    _lastStatus = status;

    if (changed) {
      debugPrint('[VmMonitor] Status changed: $status');
      _onStatusChanged?.call(status);
    }
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
  }
}
