// lib/authenticator_screen.dart
// TOTP Authenticator for secure operations

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import '../../app_theme.dart';

class AuthenticatorScreen extends StatefulWidget {
  final String username;
  final String role;

  const AuthenticatorScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<AuthenticatorScreen> createState() => _AuthenticatorScreenState();
}

class _AuthenticatorScreenState extends State<AuthenticatorScreen> {
  static const Color _accent = AppColors.accent;
  
  late Timer _timer;
  String _currentCode = '';
  int _secondsRemaining = 30;
  
  // Shared secret - in production this should be securely stored/synced
  // Using a deterministic secret based on a fixed key for the company
  static const String _masterSecret = 'A1TOOLSSECURE2024INVENTORY';

  @override
  void initState() {
    super.initState();
    _generateCode();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final remaining = 30 - (now % 30);
      
      setState(() {
        _secondsRemaining = remaining;
        if (remaining == 30) {
          _generateCode();
        }
      });
    });
  }

  void _generateCode() {
    _currentCode = TOTPGenerator.generateTOTP(_masterSecret);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _secondsRemaining / 30.0;
    final isLow = _secondsRemaining <= 5;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Authenticator'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security, size: 40, color: _accent),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Security Code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Use this code for sensitive operations',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 32),

              // Code display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLow ? Colors.red.withValues(alpha: 0.5) : _accent.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    // The code
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentCode.substring(0, 3),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 8,
                            color: isLow ? Colors.red : _accent,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _currentCode.substring(3),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 8,
                            color: isLow ? Colors.red : _accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation(isLow ? Colors.red : _accent),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Time remaining
                    Text(
                      '$_secondsRemaining seconds',
                      style: TextStyle(
                        color: isLow ? Colors.red : (isDark ? Colors.white54 : Colors.black54),
                        fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Copy button
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _currentCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Code copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 32),

              // Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This code is required for deleting locations and other sensitive operations. '
                        'The code changes every 30 seconds.',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TOTP Generator - RFC 6238 compliant
class TOTPGenerator {
  static const int _digits = 6;
  static const int _period = 30; // seconds

  /// Generate a TOTP code
  static String generateTOTP(String secret) {
    final time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final counter = time ~/ _period;
    return _generateHOTP(secret, counter);
  }

  /// Verify a TOTP code (with 1 period tolerance)
  static bool verifyTOTP(String secret, String code) {
    final time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final counter = time ~/ _period;
    
    // Check current period and previous period (for timing tolerance)
    for (int i = -1; i <= 1; i++) {
      if (_generateHOTP(secret, counter + i) == code) {
        return true;
      }
    }
    return false;
  }

  /// Generate HOTP (HMAC-based OTP)
  static String _generateHOTP(String secret, int counter) {
    // Convert counter to 8-byte big-endian
    final counterBytes = Uint8List(8);
    var c = counter;
    for (int i = 7; i >= 0; i--) {
      counterBytes[i] = c & 0xff;
      c >>= 8;
    }

    // Create HMAC-SHA1
    final key = utf8.encode(secret);
    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(counterBytes);
    final hash = digest.bytes;

    // Dynamic truncation
    final offset = hash[hash.length - 1] & 0x0f;
    final binary = ((hash[offset] & 0x7f) << 24) |
                   ((hash[offset + 1] & 0xff) << 16) |
                   ((hash[offset + 2] & 0xff) << 8) |
                   (hash[offset + 3] & 0xff);

    // Generate digits
    final otp = binary % _pow(10, _digits);
    return otp.toString().padLeft(_digits, '0');
  }

  static int _pow(int base, int exp) {
    int result = 1;
    for (int i = 0; i < exp; i++) {
      result *= base;
    }
    return result;
  }
}

/// Dialog to verify TOTP code before sensitive operations
class TOTPVerificationDialog extends StatefulWidget {
  final String title;
  final String message;
  final Future<void> Function() onVerified;

  const TOTPVerificationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onVerified,
  });

  @override
  State<TOTPVerificationDialog> createState() => _TOTPVerificationDialogState();
}

class _TOTPVerificationDialogState extends State<TOTPVerificationDialog> {
  static const String _masterSecret = 'A1TOOLSSECURE2024INVENTORY';
  
  final _codeController = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    
    if (code.length != 6) {
      setState(() => _error = 'Please enter a 6-digit code');
      return;
    }

    if (!TOTPGenerator.verifyTOTP(_masterSecret, code)) {
      setState(() => _error = 'Invalid code. Please check the Authenticator.');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      await widget.onVerified();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifying = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.security, color: Colors.orange),
          const SizedBox(width: 12),
          Text(widget.title),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enter the 6-digit code from the Authenticator tool',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: 'Security Code',
              hintText: '000000',
              border: const OutlineInputBorder(),
              errorText: _error,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              fontFamily: 'monospace',
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            onSubmitted: (_) => _verify(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _verifying ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _verifying ? null : _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _verifying
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Verify & Proceed'),
        ),
      ],
    );
  }
}
