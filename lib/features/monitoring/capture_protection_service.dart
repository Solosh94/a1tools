import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:no_screenshot/no_screenshot.dart';

/// Service to control screen capture protection on Windows and mobile.
///
/// On Windows: Uses SetWindowDisplayAffinity to exclude window from capture
/// On iOS/Android: Uses no_screenshot package to prevent screenshots
class CaptureProtectionService {
  CaptureProtectionService._();
  static final CaptureProtectionService instance = CaptureProtectionService._();

  static const _windowsChannel = MethodChannel('com.a1chimney.a1tools/capture_protection');
  final _noScreenshot = NoScreenshot.instance;

  bool _isProtected = true;

  /// Check if capture protection is currently enabled
  bool get isProtected => _isProtected;

  /// Enable capture protection (default state)
  /// - On Windows: Window appears invisible in recordings/screenshots
  /// - On mobile: Screenshots show black screen
  Future<void> enableProtection() async {
    if (Platform.isWindows) {
      try {
        await _windowsChannel.invokeMethod('setCaptureProtection', true);
        _isProtected = true;
        debugPrint('[CaptureProtection] Windows protection ENABLED');
      } catch (e) {
        debugPrint('[CaptureProtection] Failed to enable Windows protection: $e');
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _noScreenshot.screenshotOff();
        _isProtected = true;
        debugPrint('[CaptureProtection] Mobile protection ENABLED');
      } catch (e) {
        debugPrint('[CaptureProtection] Failed to enable mobile protection: $e');
      }
    }
  }

  /// Disable capture protection (for developers)
  /// - On Windows: Window can be captured normally
  /// - On mobile: Screenshots work normally
  Future<void> disableProtection() async {
    if (Platform.isWindows) {
      try {
        await _windowsChannel.invokeMethod('setCaptureProtection', false);
        _isProtected = false;
        debugPrint('[CaptureProtection] Windows protection DISABLED');
      } catch (e) {
        debugPrint('[CaptureProtection] Failed to disable Windows protection: $e');
      }
    } else if (Platform.isAndroid || Platform.isIOS) {
      try {
        await _noScreenshot.screenshotOn();
        _isProtected = false;
        debugPrint('[CaptureProtection] Mobile protection DISABLED');
      } catch (e) {
        debugPrint('[CaptureProtection] Failed to disable mobile protection: $e');
      }
    }
  }

  /// Set protection based on user role
  /// Developers and admins can bypass capture protection
  Future<void> setProtectionForRole(String? role) async {
    final roleLower = role?.toLowerCase() ?? '';

    if (roleLower == 'developer') {
      debugPrint('[CaptureProtection] Developer role detected - disabling protection');
      await disableProtection();
    } else {
      debugPrint('[CaptureProtection] Non-developer role ($role) - enabling protection');
      await enableProtection();
    }
  }
}
