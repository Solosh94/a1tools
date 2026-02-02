// Signature Capture Widget
//
// A reusable widget for capturing digital signatures.
// Can be used in inspection forms, work orders, etc.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignatureCaptureWidget extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Function(String base64, Uint8List bytes)? onSignatureCaptured;
  final double height;
  final Color penColor;
  final double strokeWidth;
  final bool showClearButton;
  final bool showSaveButton;

  const SignatureCaptureWidget({
    super.key,
    this.title = 'Sign Here',
    this.subtitle,
    this.onSignatureCaptured,
    this.height = 200,
    this.penColor = Colors.black,
    this.strokeWidth = 3.0,
    this.showClearButton = true,
    this.showSaveButton = true,
  });

  @override
  State<SignatureCaptureWidget> createState() => _SignatureCaptureWidgetState();
}

class _SignatureCaptureWidgetState extends State<SignatureCaptureWidget> {
  late SignatureController _controller;
  bool _hasSigned = false;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: widget.strokeWidth,
      penColor: widget.penColor,
      exportBackgroundColor: Colors.white,
      exportPenColor: Colors.black,
      onDrawStart: () {
        setState(() {
          _hasSigned = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign before saving'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final bytes = await _controller.toPngBytes();
      if (bytes != null) {
        final base64 = base64Encode(bytes);
        widget.onSignatureCaptured?.call(base64, bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving signature: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearSignature() {
    _controller.clear();
    setState(() {
      _hasSigned = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
        const SizedBox(height: 8),

        // Signature pad
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              children: [
                Signature(
                  controller: _controller,
                  backgroundColor: Colors.white,
                ),
                // "Sign here" placeholder
                if (!_hasSigned)
                  Positioned.fill(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.gesture,
                            size: 32,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign here',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // X marker line
                Positioned(
                  left: 16,
                  bottom: 40,
                  child: Row(
                    children: [
                      Text(
                        'X',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 100,
                        height: 1,
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Buttons
        Row(
          children: [
            if (widget.showClearButton)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _hasSigned ? _clearSignature : null,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ),
            if (widget.showClearButton && widget.showSaveButton)
              const SizedBox(width: 12),
            if (widget.showSaveButton)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _hasSigned ? _saveSignature : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Save Signature'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF49320),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Get current signature as base64 (for external use)
  Future<String?> getSignatureBase64() async {
    if (_controller.isEmpty) return null;
    final bytes = await _controller.toPngBytes();
    if (bytes != null) {
      return base64Encode(bytes);
    }
    return null;
  }

  /// Get current signature as bytes (for external use)
  Future<Uint8List?> getSignatureBytes() async {
    if (_controller.isEmpty) return null;
    return await _controller.toPngBytes();
  }

  /// Check if signature is empty
  bool get isEmpty => _controller.isEmpty;
  bool get isNotEmpty => _controller.isNotEmpty;

  /// Clear signature (for external use)
  void clear() => _clearSignature();
}

/// Full-screen signature capture dialog
class SignatureCaptureDialog extends StatefulWidget {
  final String title;
  final String? description;
  final String signerNameHint;
  final bool requireName;
  final bool requireEmail;

  const SignatureCaptureDialog({
    super.key,
    this.title = 'Customer Signature',
    this.description,
    this.signerNameHint = 'Customer Name',
    this.requireName = true,
    this.requireEmail = false,
  });

  @override
  State<SignatureCaptureDialog> createState() => _SignatureCaptureDialogState();
}

class _SignatureCaptureDialogState extends State<SignatureCaptureDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  late SignatureController _signatureController;
  bool _hasSigned = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 3.0,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
      exportPenColor: Colors.black,
      onDrawStart: () {
        setState(() {
          _hasSigned = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Validate
    if (widget.requireName && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (widget.requireEmail && _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign before saving'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final bytes = await _signatureController.toPngBytes();
      if (bytes != null && mounted) {
        Navigator.of(context).pop(SignatureCaptureResult(
          signatureBase64: base64Encode(bytes),
          signatureBytes: bytes,
          signerName: _nameController.text.trim(),
          signerEmail: _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accent = Color(0xFFF49320);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description
            if (widget.description != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Name field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: widget.signerNameHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Email field (if required or optional)
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: widget.requireEmail ? 'Email *' : 'Email (optional)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),

            // Signature pad
            Text(
              'Signature *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasSigned ? accent : (isDark ? Colors.white24 : Colors.black12),
                  width: _hasSigned ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  children: [
                    Signature(
                      controller: _signatureController,
                      backgroundColor: Colors.white,
                    ),
                    if (!_hasSigned)
                      Positioned.fill(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.draw_outlined,
                                size: 48,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign here with your finger or stylus',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Clear button
            Center(
              child: TextButton.icon(
                onPressed: _hasSigned
                    ? () {
                        _signatureController.clear();
                        setState(() {
                          _hasSigned = false;
                        });
                      }
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Clear Signature'),
              ),
            ),

            const SizedBox(height: 32),

            // Legal text
            Text(
              'By signing above, you acknowledge that you have reviewed the '
              'work performed and agree to the terms of service.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving || !_hasSigned ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Confirm Signature',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Result from signature capture dialog
class SignatureCaptureResult {
  final String signatureBase64;
  final Uint8List signatureBytes;
  final String signerName;
  final String? signerEmail;

  SignatureCaptureResult({
    required this.signatureBase64,
    required this.signatureBytes,
    required this.signerName,
    this.signerEmail,
  });
}

/// Helper function to show signature capture dialog
Future<SignatureCaptureResult?> showSignatureCaptureDialog(
  BuildContext context, {
  String title = 'Customer Signature',
  String? description,
  String signerNameHint = 'Customer Name',
  bool requireName = true,
  bool requireEmail = false,
}) async {
  return Navigator.of(context).push<SignatureCaptureResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SignatureCaptureDialog(
        title: title,
        description: description,
        signerNameHint: signerNameHint,
        requireName: requireName,
        requireEmail: requireEmail,
      ),
    ),
  );
}
