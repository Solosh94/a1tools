import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling crash recovery and automatic app restart
/// Part of Layer 1 (1 minute) of the multi-layered restart system
class CrashRecoveryService {
  static CrashRecoveryService? _instance;
  static CrashRecoveryService get instance => _instance ??= CrashRecoveryService._();

  CrashRecoveryService._();

  // Configuration
  static const int _maxRestartCount = 3;
  static const Duration _restartWindow = Duration(minutes: 5);
  static const String _prefsKeyRestartCount = 'crash_restart_count';
  static const String _prefsKeyFirstRestartTime = 'crash_first_restart_time';
  static const String _prefsKeyLastCrashTime = 'crash_last_crash_time';

  // State
  int _restartCount = 0;
  DateTime? _firstRestartTime;
  String? _crashLogDir;
  bool _initialized = false;

  /// Initialize the crash recovery service
  /// Call this at the very start of main() before any other initialization
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load restart count from persistent storage
      final prefs = await SharedPreferences.getInstance();
      _restartCount = prefs.getInt(_prefsKeyRestartCount) ?? 0;

      final firstRestartTimeMs = prefs.getInt(_prefsKeyFirstRestartTime);
      if (firstRestartTimeMs != null) {
        _firstRestartTime = DateTime.fromMillisecondsSinceEpoch(firstRestartTimeMs);
      }

      // Check if we're outside the restart window - reset counter
      if (_firstRestartTime != null &&
          DateTime.now().difference(_firstRestartTime!) > _restartWindow) {
        debugPrint('[CrashRecovery] Outside restart window, resetting counter');
        await _resetRestartCounter();
      }

      // Set up crash log directory
      final appDataDir = await getApplicationSupportDirectory();
      _crashLogDir = '${appDataDir.path}${Platform.pathSeparator}crash_logs';
      final crashLogDirFile = Directory(_crashLogDir!);
      if (!await crashLogDirFile.exists()) {
        await crashLogDirFile.create(recursive: true);
      }

      _initialized = true;
      debugPrint('[CrashRecovery] Initialized - restart count: $_restartCount, '
          'first restart: $_firstRestartTime');
    } catch (e) {
      debugPrint('[CrashRecovery] Failed to initialize: $e');
      // Continue anyway - better to have partial functionality than none
      _initialized = true;
    }
  }

  /// Check if we should attempt a restart (not in a restart loop)
  bool shouldRestart() {
    // Reset counter if outside window
    if (_firstRestartTime != null &&
        DateTime.now().difference(_firstRestartTime!) > _restartWindow) {
      _restartCount = 0;
      _firstRestartTime = null;
    }

    final shouldRestart = _restartCount < _maxRestartCount;
    debugPrint('[CrashRecovery] shouldRestart: $shouldRestart '
        '(count: $_restartCount/$_maxRestartCount)');
    return shouldRestart;
  }

  /// Check if an update is in progress (don't restart during updates)
  Future<bool> isUpdateInProgress() async {
    try {
      final appDataDir = await getApplicationSupportDirectory();
      final lockFile = File('${appDataDir.path}${Platform.pathSeparator}.update_in_progress');

      if (!await lockFile.exists()) {
        return false;
      }

      // Check if lock file is stale (> 10 minutes)
      final stat = await lockFile.stat();
      if (DateTime.now().difference(stat.modified).inMinutes > 10) {
        // Stale lock file - clean it up
        debugPrint('[CrashRecovery] Cleaning up stale update lock file');
        await lockFile.delete();
        return false;
      }

      debugPrint('[CrashRecovery] Update in progress - skipping restart');
      return true;
    } catch (e) {
      debugPrint('[CrashRecovery] Error checking update lock: $e');
      return false;
    }
  }

  /// Log a crash to the crash log directory
  Future<void> logCrash(Object error, StackTrace stackTrace, {String? source}) async {
    try {
      if (_crashLogDir == null) {
        debugPrint('[CrashRecovery] Crash log dir not initialized');
        return;
      }

      final timestamp = DateTime.now();
      final fileName = 'crash_${timestamp.toIso8601String().replaceAll(':', '-')}.log';
      final filePath = '$_crashLogDir${Platform.pathSeparator}$fileName';

      final crashData = {
        'timestamp': timestamp.toIso8601String(),
        'source': source ?? 'unknown',
        'error': error.toString(),
        'error_type': error.runtimeType.toString(),
        'stack_trace': stackTrace.toString(),
        'restart_count': _restartCount,
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
      };

      final file = File(filePath);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(crashData));

      debugPrint('[CrashRecovery] Crash logged to: $filePath');

      // Also update last crash time in prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyLastCrashTime, timestamp.millisecondsSinceEpoch);

      // Clean up old crash logs (keep last 20)
      await _cleanupOldCrashLogs();
    } catch (e) {
      debugPrint('[CrashRecovery] Failed to log crash: $e');
    }
  }

  /// Increment restart counter and persist
  Future<void> _incrementRestartCounter() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Set first restart time if this is the first restart in the window
      if (_firstRestartTime == null) {
        _firstRestartTime = DateTime.now();
        await prefs.setInt(_prefsKeyFirstRestartTime, _firstRestartTime!.millisecondsSinceEpoch);
      }

      _restartCount++;
      await prefs.setInt(_prefsKeyRestartCount, _restartCount);

      debugPrint('[CrashRecovery] Restart counter incremented to $_restartCount');
    } catch (e) {
      debugPrint('[CrashRecovery] Failed to increment restart counter: $e');
    }
  }

  /// Reset the restart counter (called when app runs successfully)
  Future<void> _resetRestartCounter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _restartCount = 0;
      _firstRestartTime = null;
      await prefs.remove(_prefsKeyRestartCount);
      await prefs.remove(_prefsKeyFirstRestartTime);
      debugPrint('[CrashRecovery] Restart counter reset');
    } catch (e) {
      debugPrint('[CrashRecovery] Failed to reset restart counter: $e');
    }
  }

  /// Mark that the app started successfully (call after successful initialization)
  /// This resets the restart counter since the app is running fine
  Future<void> markSuccessfulStart() async {
    await _resetRestartCounter();
    debugPrint('[CrashRecovery] Marked successful start');
  }

  /// Handle a crash and attempt restart if appropriate
  Future<void> handleCrash(Object error, StackTrace stackTrace, {String? source}) async {
    debugPrint('[CrashRecovery] Handling crash from $source: $error');

    // Log the crash
    await logCrash(error, stackTrace, source: source);

    // Check if update is in progress
    if (await isUpdateInProgress()) {
      debugPrint('[CrashRecovery] Update in progress - not restarting');
      return;
    }

    // Check if we should restart
    if (!shouldRestart()) {
      debugPrint('[CrashRecovery] Too many restarts - not restarting');
      // Could optionally show a fatal error screen here
      return;
    }

    // Increment counter before restart
    await _incrementRestartCounter();

    // Trigger cold restart
    await triggerColdRestart(reason: 'crash');
  }

  /// Trigger a cold restart of the app (launches new process, exits current)
  Future<void> triggerColdRestart({String reason = 'manual'}) async {
    if (!Platform.isWindows) {
      debugPrint('[CrashRecovery] Cold restart only supported on Windows');
      return;
    }

    try {
      final execPath = Platform.resolvedExecutable;

      debugPrint('[CrashRecovery] Triggering cold restart (reason: $reason)');
      debugPrint('[CrashRecovery] Executable: $execPath');

      // Create restart pending lock to prevent simultaneous restarts
      await _createRestartLock();

      // Launch new process with restart flag
      await Process.start(
        execPath,
        ['--auto-start', '--crash-restart', '--restart-reason=$reason'],
        mode: ProcessStartMode.detached,
      );

      // Give the new process a moment to start
      await Future.delayed(const Duration(milliseconds: 500));

      // Exit current process
      exit(0);
    } catch (e) {
      debugPrint('[CrashRecovery] Failed to trigger cold restart: $e');
      await _removeRestartLock();
    }
  }

  /// Create a restart pending lock file
  Future<void> _createRestartLock() async {
    try {
      final appDataDir = await getApplicationSupportDirectory();
      final lockFile = File('${appDataDir.path}${Platform.pathSeparator}.restart_pending');

      final lockData = {
        'timestamp': DateTime.now().toIso8601String(),
        'pid': pid,
      };

      await lockFile.writeAsString(jsonEncode(lockData));
      debugPrint('[CrashRecovery] Created restart lock');
    } catch (e) {
      debugPrint('[CrashRecovery] Failed to create restart lock: $e');
    }
  }

  /// Remove the restart pending lock file
  Future<void> _removeRestartLock() async {
    try {
      final appDataDir = await getApplicationSupportDirectory();
      final lockFile = File('${appDataDir.path}${Platform.pathSeparator}.restart_pending');

      if (await lockFile.exists()) {
        await lockFile.delete();
        debugPrint('[CrashRecovery] Removed restart lock');
      }
    } catch (e) {
      debugPrint('[CrashRecovery] Failed to remove restart lock: $e');
    }
  }

  /// Check if a restart is pending (another process is starting)
  Future<bool> isRestartPending() async {
    try {
      final appDataDir = await getApplicationSupportDirectory();
      final lockFile = File('${appDataDir.path}${Platform.pathSeparator}.restart_pending');

      if (!await lockFile.exists()) {
        return false;
      }

      // Check if lock file is stale (> 30 seconds)
      final stat = await lockFile.stat();
      if (DateTime.now().difference(stat.modified).inSeconds > 30) {
        // Stale lock file - clean it up
        await lockFile.delete();
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clean up restart lock on successful start
  Future<void> cleanupOnStart() async {
    await _removeRestartLock();
  }

  /// Clean up old crash logs, keeping only the most recent ones
  Future<void> _cleanupOldCrashLogs({int keepCount = 20}) async {
    try {
      if (_crashLogDir == null) return;

      final dir = Directory(_crashLogDir!);
      if (!await dir.exists()) return;

      final files = await dir.list().where((e) => e is File && e.path.endsWith('.log')).toList();

      if (files.length <= keepCount) return;

      // Sort by modification time (newest first)
      files.sort((a, b) {
        final aStat = (a as File).statSync();
        final bStat = (b as File).statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      // Delete oldest files beyond keepCount
      for (var i = keepCount; i < files.length; i++) {
        await (files[i] as File).delete();
      }

      debugPrint('[CrashRecovery] Cleaned up ${files.length - keepCount} old crash logs');
    } catch (e) {
      debugPrint('[CrashRecovery] Failed to cleanup old crash logs: $e');
    }
  }

  /// Get recent crash logs for debugging/reporting
  Future<List<Map<String, dynamic>>> getRecentCrashLogs({int limit = 5}) async {
    final logs = <Map<String, dynamic>>[];

    try {
      if (_crashLogDir == null) return logs;

      final dir = Directory(_crashLogDir!);
      if (!await dir.exists()) return logs;

      final files = await dir.list()
          .where((e) => e is File && e.path.endsWith('.log'))
          .cast<File>()
          .toList();

      // Sort by modification time (newest first)
      files.sort((a, b) {
        return b.statSync().modified.compareTo(a.statSync().modified);
      });

      // Read the most recent logs
      for (var i = 0; i < files.length && i < limit; i++) {
        try {
          final content = await files[i].readAsString();
          logs.add(jsonDecode(content) as Map<String, dynamic>);
        } catch (e) {
          // Skip invalid log files
        }
      }
    } catch (e) {
      debugPrint('[CrashRecovery] Failed to get recent crash logs: $e');
    }

    return logs;
  }
}
