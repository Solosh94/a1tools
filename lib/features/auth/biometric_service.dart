// Biometric Authentication Service
//
// Provides Face ID / Touch ID authentication for quick login.
// Uses local_auth package for platform biometric APIs.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Result of a biometric authentication attempt
enum BiometricResult {
  success,
  failed,
  cancelled,
  notAvailable,
  notEnrolled,
  lockedOut,
  error,
}

/// Service for managing biometric (Face ID / Touch ID) authentication
class BiometricService {
  BiometricService._();
  static final BiometricService _instance = BiometricService._();
  factory BiometricService() => _instance;
  static BiometricService get instance => _instance;

  final LocalAuthentication _localAuth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();

  // Storage keys
  static const _keyBiometricEnabled = 'a1_biometric_enabled';
  static const _keyBiometricUsername = 'a1_biometric_username';

  /// Check if device supports biometrics
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      debugPrint('[BiometricService] Error checking device support: $e');
      return false;
    }
  }

  /// Check if biometrics can be used (device supports AND user has enrolled)
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('[BiometricService] Error checking biometrics availability: $e');
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('[BiometricService] Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if Face ID is available
  Future<bool> isFaceIdAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.face);
  }

  /// Check if Touch ID / Fingerprint is available
  Future<bool> isTouchIdAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.contains(BiometricType.fingerprint);
  }

  /// Check if any biometric is available
  Future<bool> isAnyBiometricAvailable() async {
    final biometrics = await getAvailableBiometrics();
    return biometrics.isNotEmpty;
  }

  /// Get a human-readable name for the available biometric type
  Future<String> getBiometricTypeName() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Touch ID';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (biometrics.contains(BiometricType.strong)) {
      return 'Biometric';
    } else if (biometrics.contains(BiometricType.weak)) {
      return 'Biometric';
    }
    return 'Biometric';
  }

  /// Check if biometric login is enabled for a user
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _storage.read(key: _keyBiometricEnabled);
      return enabled == 'true';
    } catch (e) {
      debugPrint('[BiometricService] Error checking if biometric enabled: $e');
      return false;
    }
  }

  /// Get the username associated with biometric login
  Future<String?> getBiometricUsername() async {
    try {
      return await _storage.read(key: _keyBiometricUsername);
    } catch (e) {
      debugPrint('[BiometricService] Error getting biometric username: $e');
      return null;
    }
  }

  /// Enable biometric login for a user
  /// Should be called after successful password authentication
  Future<bool> enableBiometric(String username) async {
    try {
      // First verify biometrics are available
      if (!await canCheckBiometrics()) {
        debugPrint('[BiometricService] Biometrics not available');
        return false;
      }

      // Authenticate to confirm user wants to enable
      final result = await authenticate(
        reason: 'Authenticate to enable biometric login',
      );

      if (result != BiometricResult.success) {
        debugPrint('[BiometricService] Failed to authenticate for enabling');
        return false;
      }

      // Store the association
      await _storage.write(key: _keyBiometricEnabled, value: 'true');
      await _storage.write(key: _keyBiometricUsername, value: username);

      debugPrint('[BiometricService] Biometric enabled for $username');
      return true;
    } catch (e) {
      debugPrint('[BiometricService] Error enabling biometric: $e');
      return false;
    }
  }

  /// Disable biometric login
  Future<void> disableBiometric() async {
    try {
      await _storage.delete(key: _keyBiometricEnabled);
      await _storage.delete(key: _keyBiometricUsername);
      debugPrint('[BiometricService] Biometric disabled');
    } catch (e) {
      debugPrint('[BiometricService] Error disabling biometric: $e');
    }
  }

  /// Authenticate using biometrics
  Future<BiometricResult> authenticate({
    String reason = 'Authenticate to continue',
    bool biometricOnly = true,
  }) async {
    try {
      // Check if device supports biometrics
      if (!await isDeviceSupported()) {
        return BiometricResult.notAvailable;
      }

      // Check if biometrics are enrolled
      if (!await canCheckBiometrics()) {
        return BiometricResult.notEnrolled;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      return authenticated ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException catch (e) {
      debugPrint('[BiometricService] Platform exception: ${e.code} - ${e.message}');

      // Handle specific error codes
      switch (e.code) {
        case 'NotAvailable':
          return BiometricResult.notAvailable;
        case 'NotEnrolled':
          return BiometricResult.notEnrolled;
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return BiometricResult.lockedOut;
        case 'UserCancel':
          return BiometricResult.cancelled;
        default:
          return BiometricResult.error;
      }
    } catch (e) {
      debugPrint('[BiometricService] Error during authentication: $e');
      return BiometricResult.error;
    }
  }

  /// Attempt biometric login
  /// Returns the username if successful, null otherwise
  Future<String?> attemptBiometricLogin() async {
    try {
      // Check if biometric is enabled
      if (!await isBiometricEnabled()) {
        debugPrint('[BiometricService] Biometric not enabled');
        return null;
      }

      // Get stored username
      final username = await getBiometricUsername();
      if (username == null || username.isEmpty) {
        debugPrint('[BiometricService] No username stored');
        return null;
      }

      // Authenticate
      final biometricName = await getBiometricTypeName();
      final result = await authenticate(
        reason: 'Use $biometricName to sign in as $username',
      );

      if (result == BiometricResult.success) {
        debugPrint('[BiometricService] Biometric login successful for $username');
        return username;
      }

      debugPrint('[BiometricService] Biometric login failed: $result');
      return null;
    } catch (e) {
      debugPrint('[BiometricService] Error during biometric login: $e');
      return null;
    }
  }

  /// Cancel any ongoing authentication
  Future<void> cancelAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      debugPrint('[BiometricService] Error cancelling authentication: $e');
    }
  }
}
