import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for hiding windows from screen capture using native Windows APIs.
///
/// This uses SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE) to make windows
/// truly invisible to screen capture, rather than minimizing them.
///
/// The hiding is controlled from management and applies to all clients.
class PrivacyInjectionService {
  static const MethodChannel _channel = MethodChannel(
    'com.a1chimney.a1tools/privacy_injection',
  );

  /// Hide or show windows belonging to a specific process
  /// Returns the number of windows affected
  static Future<int> hideProcessWindows(String processName, bool hide) async {
    try {
      final result = await _channel.invokeMethod<int>('hideProcessWindows', {
        'processName': processName,
        'hide': hide,
      });
      debugPrint('[PrivacyInjection] ${hide ? "Hiding" : "Showing"} $processName: $result windows affected');
      return result ?? 0;
    } on PlatformException catch (e) {
      debugPrint('[PrivacyInjection] Error hiding $processName: ${e.message}');
      return 0;
    } catch (e) {
      debugPrint('[PrivacyInjection] Unexpected error: $e');
      return 0;
    }
  }

  /// Hide or show windows belonging to multiple processes at once
  /// Returns the total number of windows affected
  static Future<int> hideMultipleProcesses(List<String> processes, bool hide) async {
    if (processes.isEmpty) return 0;

    try {
      final result = await _channel.invokeMethod<int>('hideMultipleProcesses', {
        'processes': processes,
        'hide': hide,
      });
      debugPrint('[PrivacyInjection] ${hide ? "Hiding" : "Showing"} ${processes.length} processes: $result windows affected');
      return result ?? 0;
    } on PlatformException catch (e) {
      debugPrint('[PrivacyInjection] Error hiding multiple processes: ${e.message}');
      return 0;
    } catch (e) {
      debugPrint('[PrivacyInjection] Unexpected error: $e');
      return 0;
    }
  }

  /// Get list of currently hidden process names
  static Future<List<String>> getHiddenProcesses() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getHiddenProcesses');
      return result?.map((e) => e.toString()).toList() ?? [];
    } on PlatformException catch (e) {
      debugPrint('[PrivacyInjection] Error getting hidden processes: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('[PrivacyInjection] Unexpected error: $e');
      return [];
    }
  }

  /// Restore all hidden windows (make them visible again)
  static Future<void> restoreAll() async {
    try {
      await _channel.invokeMethod<void>('restoreAll');
      debugPrint('[PrivacyInjection] All windows restored');
    } on PlatformException catch (e) {
      debugPrint('[PrivacyInjection] Error restoring windows: ${e.message}');
    } catch (e) {
      debugPrint('[PrivacyInjection] Unexpected error: $e');
    }
  }

  /// Check if a specific process is currently hidden
  static Future<bool> isProcessHidden(String processName) async {
    try {
      final result = await _channel.invokeMethod<bool>('isProcessHidden', processName);
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[PrivacyInjection] Error checking process: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[PrivacyInjection] Unexpected error: $e');
      return false;
    }
  }

  /// Apply privacy exclusions - hide all windows from the exclusion list
  /// This is called when monitoring starts to apply the current exclusion settings
  static Future<int> applyExclusions(List<String> exclusions) async {
    if (exclusions.isEmpty) {
      debugPrint('[PrivacyInjection] No exclusions to apply');
      return 0;
    }

    debugPrint('[PrivacyInjection] Applying ${exclusions.length} exclusions: $exclusions');
    return await hideMultipleProcesses(exclusions, true);
  }

  /// Remove all exclusions - restore all hidden windows
  /// This is called when monitoring stops
  static Future<void> removeAllExclusions() async {
    debugPrint('[PrivacyInjection] Removing all exclusions');
    await restoreAll();
  }

  /// Update exclusions based on new list from management
  /// This compares current hidden processes with the new list and updates accordingly
  static Future<void> updateExclusions(List<String> newExclusions) async {
    final currentlyHidden = await getHiddenProcesses();

    // Normalize names for comparison
    final currentSet = currentlyHidden.map((e) => e.toLowerCase()).toSet();
    final newSet = newExclusions.map((e) => e.toLowerCase()).toSet();

    // Find processes to unhide (in current but not in new)
    final toUnhide = currentSet.difference(newSet);

    // Unhide processes that are no longer excluded
    for (final process in toUnhide) {
      await hideProcessWindows(process, false);
    }

    // Re-apply ALL exclusions (not just new ones) to catch newly opened instances
    // This handles the case where a user opens a new window of an excluded program
    // after the initial exclusion was applied
    int totalHidden = 0;
    for (final process in newExclusions) {
      final result = await hideProcessWindows(process, true);
      totalHidden += result;
    }

    debugPrint('[PrivacyInjection] Updated exclusions: unhid ${toUnhide.length}, re-applied ${newExclusions.length} ($totalHidden windows affected)');
  }

  /// Force refresh all exclusions - re-applies hiding to all excluded processes
  /// This catches any new instances of programs that were opened after initial exclusion
  static Future<int> refreshExclusions(List<String> exclusions) async {
    if (exclusions.isEmpty) {
      debugPrint('[PrivacyInjection] No exclusions to refresh');
      return 0;
    }

    int totalAffected = 0;
    for (final process in exclusions) {
      final result = await hideProcessWindows(process, true);
      totalAffected += result;
    }

    debugPrint('[PrivacyInjection] Refreshed ${exclusions.length} exclusions: $totalAffected windows affected');
    return totalAffected;
  }
}
