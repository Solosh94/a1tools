// alerts_manager.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../core/services/api_client.dart';

/// Host interface for alerts â€” implemented by HomeScreen state.
abstract class AlertsHost {
  BuildContext get context;
  bool get mounted;

  /// Called when a new alert message arrives.
  /// We pass title, message, fromUsername, and optional attachment data.
  Future<void> showAlertPopup({
    required String title,
    required String message,
    String? fromUsername,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  });
}

class AlertsManager {
  final AlertsHost host;
  final String Function() getUsername;

  Timer? _timer;
  bool _inProgress = false;

  // Use the new standalone alerts API
  static String get _alertsBaseUrl => ApiConfig.alerts;

  AlertsManager({
    required this.host,
    required this.getUsername,
  });

  /// Start polling every 10s (no-op if already running or no username).
  void start() {
    if (_timer != null) return;

    final username = getUsername().trim();
    if (username.isEmpty) return;

    // Immediate first check so we don't wait 10 seconds on a fresh login.
    _checkForAlerts();

    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkForAlerts();
    });
  }

  /// Stop polling.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  Future<void> _checkForAlerts() async {
    if (!host.mounted) return;

    final username = getUsername().trim();
    if (username.isEmpty) return;
    if (_inProgress) return;

    _inProgress = true;

    try {
      // Use ApiClient for consistent error handling and logging
      // The alerts API returns a raw JSON array for poll action
      final response = await ApiClient.instance.get(
        '$_alertsBaseUrl?action=poll&username=${Uri.encodeQueryComponent(username)}',
        timeout: const Duration(seconds: 10),
      );

      if (!response.success) {
        return;
      }

      // Handle raw array response
      final body = response.message ?? '';
      if (body.isEmpty || body == '[]') {
        // No alerts
        return;
      }

      dynamic decoded;
      try {
        decoded = response.rawJson ?? jsonDecode(body);
      } catch (_) {
        return;
      }

      if (decoded == null) {
        return;
      }

      // Normal case: array of alerts
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map && item['message'] != null) {
            final msg = item['message'].toString();
            if (msg.isEmpty) continue;
            if (!host.mounted) break;

            // Read from_username and build title
            final from = (item['from_username'] ?? '').toString().trim();
            final title = from.isNotEmpty
                ? 'New Alert from $from'
                : 'New Alert';

            // Extract attachment data
            final attachmentUrl = item['attachment_url']?.toString();
            final attachmentName = item['attachment_name']?.toString();
            final attachmentType = item['attachment_type']?.toString();

            // Delegate popup + window-focus behavior to the host (HomeScreen)
            await host.showAlertPopup(
              title: title,
              message: msg,
              fromUsername: from.isNotEmpty ? from : null,
              attachmentUrl: attachmentUrl,
              attachmentName: attachmentName,
              attachmentType: attachmentType,
            );
          }
        }
      } else if (decoded is Map) {
        // Error payload: { success:false, error:"..." }
        final String? errorMsg =
            (decoded['error'] ?? decoded['message'])?.toString().trim();
        if (errorMsg != null &&
            errorMsg.isNotEmpty &&
            decoded['success'] != true) {
          if (!host.context.mounted) return;
          ScaffoldMessenger.of(host.context).showSnackBar(
            SnackBar(
              content: Text('Alert error: $errorMsg'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Swallow errors; we don't want to crash polling.
      debugPrint('[AlertsManager] Error: $e');
    } finally {
      _inProgress = false;
    }
  }
}
