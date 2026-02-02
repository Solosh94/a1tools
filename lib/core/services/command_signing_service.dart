// Command Signing Service
//
// Provides cryptographic signing and verification for remote control commands.
// Ensures commands are authentic and have not been tampered with.

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// A signed command with verification data
class SignedCommand {
  /// Unique command ID
  final String commandId;

  /// Command type (e.g., 'mouse_click', 'key_press')
  final String commandType;

  /// Command data payload
  final Map<String, dynamic> commandData;

  /// Timestamp when command was created (Unix milliseconds)
  final int timestamp;

  /// Nonce to prevent replay attacks
  final String nonce;

  /// Device/session identifier
  final String deviceId;

  /// HMAC signature of the command
  final String signature;

  const SignedCommand({
    required this.commandId,
    required this.commandType,
    required this.commandData,
    required this.timestamp,
    required this.nonce,
    required this.deviceId,
    required this.signature,
  });

  factory SignedCommand.fromJson(Map<String, dynamic> json) {
    return SignedCommand(
      commandId: json['command_id'] ?? json['id'] ?? '',
      commandType: json['command_type'] ?? '',
      commandData: json['command_data'] is Map
          ? Map<String, dynamic>.from(json['command_data'])
          : {},
      timestamp: json['timestamp'] ?? 0,
      nonce: json['nonce'] ?? '',
      deviceId: json['device_id'] ?? '',
      signature: json['signature'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'command_id': commandId,
      'command_type': commandType,
      'command_data': commandData,
      'timestamp': timestamp,
      'nonce': nonce,
      'device_id': deviceId,
      'signature': signature,
    };
  }

  /// Get the payload that was signed (for verification)
  String get signedPayload {
    final payloadData = {
      'command_id': commandId,
      'command_type': commandType,
      'command_data': commandData,
      'timestamp': timestamp,
      'nonce': nonce,
      'device_id': deviceId,
    };
    // Sort keys for consistent ordering
    final sortedKeys = payloadData.keys.toList()..sort();
    final sortedData = <String, dynamic>{};
    for (final key in sortedKeys) {
      sortedData[key] = payloadData[key];
    }
    return jsonEncode(sortedData);
  }

  @override
  String toString() {
    return 'SignedCommand($commandType, id: $commandId)';
  }
}

/// Result of command verification
class VerificationResult {
  /// Whether the command is valid
  final bool isValid;

  /// Reason for failure (if invalid)
  final String? failureReason;

  /// The verified command (if valid)
  final SignedCommand? command;

  const VerificationResult._({
    required this.isValid,
    this.failureReason,
    this.command,
  });

  factory VerificationResult.valid(SignedCommand command) {
    return VerificationResult._(
      isValid: true,
      command: command,
    );
  }

  factory VerificationResult.invalid(String reason) {
    return VerificationResult._(
      isValid: false,
      failureReason: reason,
    );
  }

  @override
  String toString() {
    return isValid
        ? 'VerificationResult(valid)'
        : 'VerificationResult(invalid: $failureReason)';
  }
}

/// Configuration for command signing
class CommandSigningConfig {
  /// Maximum age of command in milliseconds before considered stale
  final int maxCommandAgeMs;

  /// Maximum allowed time skew in milliseconds
  final int maxTimeSkewMs;

  /// Whether to enforce nonce checking (prevents replay attacks)
  final bool enforceNonceCheck;

  /// Maximum nonces to remember (for replay protection)
  final int maxNonceHistory;

  const CommandSigningConfig({
    this.maxCommandAgeMs = 30000, // 30 seconds
    this.maxTimeSkewMs = 5000, // 5 seconds
    this.enforceNonceCheck = true,
    this.maxNonceHistory = 1000,
  });

  static const standard = CommandSigningConfig();

  static const strict = CommandSigningConfig(
    maxCommandAgeMs: 10000, // 10 seconds
    maxTimeSkewMs: 2000, // 2 seconds
    enforceNonceCheck: true,
    maxNonceHistory: 500,
  );

  static const relaxed = CommandSigningConfig(
    maxCommandAgeMs: 60000, // 60 seconds
    maxTimeSkewMs: 10000, // 10 seconds
    enforceNonceCheck: false,
  );
}

/// Service for signing and verifying remote control commands
class CommandSigningService {
  static final CommandSigningService _instance = CommandSigningService._();
  static CommandSigningService get instance => _instance;
  CommandSigningService._();

  /// Configuration
  CommandSigningConfig config = CommandSigningConfig.standard;

  /// Shared secret for HMAC signing (should be set from server during auth)
  String? _signingSecret;

  /// Device identifier (unique per installation)
  String? _deviceId;

  /// Set of used nonces (for replay protection)
  final Set<String> _usedNonces = {};

  /// Queue of nonce timestamps for cleanup
  final List<(String, int)> _nonceTimestamps = [];

  /// Random number generator for nonces
  final Random _random = Random.secure();

  /// Initialize the signing service
  void initialize({
    required String signingSecret,
    required String deviceId,
    CommandSigningConfig? config,
  }) {
    _signingSecret = signingSecret;
    _deviceId = deviceId;
    if (config != null) this.config = config;
    debugPrint('[CommandSigning] Initialized for device: $deviceId');
  }

  /// Check if service is initialized
  bool get isInitialized => _signingSecret != null && _deviceId != null;

  /// Sign a command for transmission to server
  SignedCommand signCommand({
    required String commandId,
    required String commandType,
    required Map<String, dynamic> commandData,
  }) {
    if (!isInitialized) {
      throw StateError('CommandSigningService not initialized');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final nonce = _generateNonce();

    final command = SignedCommand(
      commandId: commandId,
      commandType: commandType,
      commandData: commandData,
      timestamp: timestamp,
      nonce: nonce,
      deviceId: _deviceId!,
      signature: '', // Will be set below
    );

    final signature = _computeSignature(command.signedPayload);

    return SignedCommand(
      commandId: command.commandId,
      commandType: command.commandType,
      commandData: command.commandData,
      timestamp: command.timestamp,
      nonce: command.nonce,
      deviceId: command.deviceId,
      signature: signature,
    );
  }

  /// Verify an incoming command from the server
  VerificationResult verifyCommand(Map<String, dynamic> json) {
    if (!isInitialized) {
      return VerificationResult.invalid('Service not initialized');
    }

    try {
      final command = SignedCommand.fromJson(json);

      // Check timestamp (prevent replay of old commands)
      final now = DateTime.now().millisecondsSinceEpoch;
      final commandAge = now - command.timestamp;

      if (commandAge < -config.maxTimeSkewMs) {
        return VerificationResult.invalid(
          'Command timestamp is in the future (clock skew: ${-commandAge}ms)',
        );
      }

      if (commandAge > config.maxCommandAgeMs) {
        return VerificationResult.invalid(
          'Command too old (age: ${commandAge}ms, max: ${config.maxCommandAgeMs}ms)',
        );
      }

      // Check device ID
      if (command.deviceId != _deviceId) {
        return VerificationResult.invalid(
          'Device ID mismatch (expected: $_deviceId, got: ${command.deviceId})',
        );
      }

      // Check nonce (prevent replay attacks)
      if (config.enforceNonceCheck) {
        if (_usedNonces.contains(command.nonce)) {
          return VerificationResult.invalid(
            'Nonce already used (replay attack detected)',
          );
        }
        _recordNonce(command.nonce, command.timestamp);
      }

      // Verify signature
      final expectedSignature = _computeSignature(command.signedPayload);
      if (!_secureCompare(command.signature, expectedSignature)) {
        return VerificationResult.invalid('Invalid signature');
      }

      return VerificationResult.valid(command);
    } catch (e) {
      return VerificationResult.invalid('Parse error: $e');
    }
  }

  /// Verify a command and return the command if valid, or null if invalid
  SignedCommand? verifyAndGet(Map<String, dynamic> json) {
    final result = verifyCommand(json);
    if (result.isValid) {
      debugPrint('[CommandSigning] Command verified: ${result.command}');
      return result.command;
    } else {
      debugPrint('[CommandSigning] Command rejected: ${result.failureReason}');
      return null;
    }
  }

  /// Generate a unique nonce
  String _generateNonce() {
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  /// Compute HMAC-SHA256 signature
  String _computeSignature(String payload) {
    final key = utf8.encode(_signingSecret!);
    final data = utf8.encode(payload);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(data);
    return base64Url.encode(digest.bytes);
  }

  /// Constant-time string comparison (prevents timing attacks)
  bool _secureCompare(String a, String b) {
    if (a.length != b.length) return false;

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Record a nonce as used
  void _recordNonce(String nonce, int timestamp) {
    _usedNonces.add(nonce);
    _nonceTimestamps.add((nonce, timestamp));

    // Clean up old nonces
    if (_usedNonces.length > config.maxNonceHistory) {
      _cleanupNonces();
    }
  }

  /// Remove old nonces from memory
  void _cleanupNonces() {
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - config.maxCommandAgeMs * 2;

    // Remove nonces older than cutoff
    _nonceTimestamps.removeWhere((entry) {
      if (entry.$2 < cutoff) {
        _usedNonces.remove(entry.$1);
        return true;
      }
      return false;
    });
  }

  /// Reset the service (for logout/re-initialization)
  void reset() {
    _signingSecret = null;
    _deviceId = null;
    _usedNonces.clear();
    _nonceTimestamps.clear();
    debugPrint('[CommandSigning] Reset');
  }

  /// Get current statistics
  Map<String, dynamic> get statistics => {
        'initialized': isInitialized,
        'deviceId': _deviceId,
        'activeNonces': _usedNonces.length,
        'config': {
          'maxCommandAgeMs': config.maxCommandAgeMs,
          'maxTimeSkewMs': config.maxTimeSkewMs,
          'enforceNonceCheck': config.enforceNonceCheck,
          'maxNonceHistory': config.maxNonceHistory,
        },
      };
}

/// Extension for signing commands in remote control
extension CommandSigningExtension on Map<String, dynamic> {
  /// Sign this command map
  SignedCommand sign(String commandId) {
    return CommandSigningService.instance.signCommand(
      commandId: commandId,
      commandType: this['command_type'] ?? '',
      commandData: this['command_data'] is Map
          ? Map<String, dynamic>.from(this['command_data'])
          : {},
    );
  }

  /// Verify this command map
  VerificationResult verify() {
    return CommandSigningService.instance.verifyCommand(this);
  }
}
