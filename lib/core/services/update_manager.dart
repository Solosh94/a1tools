// lib/update_manager.dart
//
// Periodically checks for app updates while the app is running.

import 'dart:async';
import 'package:flutter/material.dart';
import 'app_update_checker.dart';

class UpdateManager {
  final State state;

  Timer? _timer;
  bool _running = false;

  // How often to check for updates
  static const Duration _interval = Duration(minutes: 2);

  UpdateManager({required this.state});

  /// Start periodic update checks (no-op if already running).
  void start() {
    if (_running) return;
    _running = true;

    // We do NOT call check immediately here, because HomeScreen
    // already runs an update check on startup.
    _timer = Timer.periodic(_interval, (_) {
      _checkForUpdate();
    });
  }

  /// Stop periodic checks.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  void dispose() => stop();

  Future<void> _checkForUpdate() async {
    if (!state.mounted) return;

    // `periodic: true` -> ignore the "checked once per session" guard,
    // BUT app_update_checker itself will avoid re-showing the same
    // version popup thanks to _lastNotifiedVersion.
    await AppUpdateChecker.checkForUpdate(
      state.context,
      periodic: true,
    );
  }
}
