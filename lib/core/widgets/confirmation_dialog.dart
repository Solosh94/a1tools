// Confirmation Dialog Widgets
//
// Reusable confirmation dialogs for destructive and important actions.
// Provides consistent UX patterns across the app.

import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Types of confirmation dialogs
enum ConfirmationType {
  /// Destructive action (delete, remove, etc.)
  destructive,

  /// Warning action (requires attention)
  warning,

  /// Informational confirmation
  info,

  /// Success confirmation
  success,
}

/// Result of a confirmation dialog
class ConfirmationResult {
  final bool confirmed;
  final String? inputValue;

  const ConfirmationResult({
    required this.confirmed,
    this.inputValue,
  });

  factory ConfirmationResult.confirmed([String? inputValue]) =>
      ConfirmationResult(confirmed: true, inputValue: inputValue);

  factory ConfirmationResult.cancelled() =>
      const ConfirmationResult(confirmed: false);
}

/// Configuration for confirmation dialog
class ConfirmationConfig {
  final String title;
  final String message;
  final ConfirmationType type;
  final String confirmText;
  final String cancelText;
  final IconData? icon;
  final bool requireInput;
  final String? inputLabel;
  final String? inputHint;
  final String? inputValidation;
  final bool showDoNotAskAgain;

  const ConfirmationConfig({
    required this.title,
    required this.message,
    this.type = ConfirmationType.warning,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.icon,
    this.requireInput = false,
    this.inputLabel,
    this.inputHint,
    this.inputValidation,
    this.showDoNotAskAgain = false,
  });

  /// Create a delete confirmation config
  factory ConfirmationConfig.delete({
    required String itemName,
    String? itemType,
    String? additionalMessage,
  }) {
    return ConfirmationConfig(
      title: 'Delete ${itemType ?? 'Item'}',
      message: 'Are you sure you want to delete "$itemName"?${additionalMessage != null ? '\n\n$additionalMessage' : ''}\n\nThis action cannot be undone.',
      type: ConfirmationType.destructive,
      confirmText: 'Delete',
      icon: Icons.delete_forever,
    );
  }

  /// Create a discard changes confirmation config
  factory ConfirmationConfig.discardChanges() {
    return const ConfirmationConfig(
      title: 'Discard Changes',
      message: 'You have unsaved changes. Are you sure you want to discard them?',
      type: ConfirmationType.warning,
      confirmText: 'Discard',
      icon: Icons.warning_amber,
    );
  }

  /// Create a logout confirmation config
  factory ConfirmationConfig.logout() {
    return const ConfirmationConfig(
      title: 'Log Out',
      message: 'Are you sure you want to log out?',
      type: ConfirmationType.info,
      confirmText: 'Log Out',
      icon: Icons.logout,
    );
  }

  /// Create a type-to-confirm config (for extra dangerous actions)
  factory ConfirmationConfig.typeToConfirm({
    required String title,
    required String message,
    required String confirmationText,
  }) {
    return ConfirmationConfig(
      title: title,
      message: message,
      type: ConfirmationType.destructive,
      confirmText: 'Confirm',
      icon: Icons.warning,
      requireInput: true,
      inputLabel: 'Type "$confirmationText" to confirm',
      inputHint: confirmationText,
      inputValidation: confirmationText,
    );
  }
}

/// Show a confirmation dialog
Future<bool> showConfirmDialog(
  BuildContext context,
  ConfirmationConfig config,
) async {
  final result = await showDialog<ConfirmationResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ConfirmationDialog(config: config),
  );

  return result?.confirmed ?? false;
}

/// Show a confirmation dialog and return result with optional input
Future<ConfirmationResult> showConfirmDialogWithResult(
  BuildContext context,
  ConfirmationConfig config,
) async {
  final result = await showDialog<ConfirmationResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ConfirmationDialog(config: config),
  );

  return result ?? ConfirmationResult.cancelled();
}

class _ConfirmationDialog extends StatefulWidget {
  final ConfirmationConfig config;

  const _ConfirmationDialog({required this.config});

  @override
  State<_ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<_ConfirmationDialog> {
  final _inputController = TextEditingController();
  bool _inputValid = false;
  bool _doNotAskAgain = false;

  @override
  void initState() {
    super.initState();
    _inputValid = !widget.config.requireInput;
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Color _getTypeColor() {
    switch (widget.config.type) {
      case ConfirmationType.destructive:
        return AppColors.error;
      case ConfirmationType.warning:
        return AppColors.warning;
      case ConfirmationType.info:
        return AppColors.info;
      case ConfirmationType.success:
        return AppColors.success;
    }
  }

  IconData _getTypeIcon() {
    if (widget.config.icon != null) return widget.config.icon!;

    switch (widget.config.type) {
      case ConfirmationType.destructive:
        return Icons.delete_forever;
      case ConfirmationType.warning:
        return Icons.warning_amber;
      case ConfirmationType.info:
        return Icons.info_outline;
      case ConfirmationType.success:
        return Icons.check_circle_outline;
    }
  }

  void _validateInput(String value) {
    setState(() {
      if (widget.config.inputValidation != null) {
        _inputValid = value == widget.config.inputValidation;
      } else {
        _inputValid = value.isNotEmpty;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getTypeColor();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getTypeIcon(), color: typeColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.config.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.config.message,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.5,
              ),
            ),
            if (widget.config.requireInput) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _inputController,
                onChanged: _validateInput,
                decoration: InputDecoration(
                  labelText: widget.config.inputLabel,
                  hintText: widget.config.inputHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: typeColor, width: 2),
                  ),
                ),
              ),
            ],
            if (widget.config.showDoNotAskAgain) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _doNotAskAgain,
                      onChanged: (v) => setState(() => _doNotAskAgain = v ?? false),
                      activeColor: typeColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Don't ask me again",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ConfirmationResult.cancelled()),
          child: Text(
            widget.config.cancelText,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _inputValid
              ? () => Navigator.pop(
                    context,
                    ConfirmationResult.confirmed(_inputController.text),
                  )
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: typeColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: typeColor.withValues(alpha: 0.3),
            disabledForegroundColor: Colors.white54,
          ),
          child: Text(widget.config.confirmText),
        ),
      ],
    );
  }
}

/// Extension methods for easier confirmation dialog usage
extension ConfirmationDialogExtension on BuildContext {
  /// Show a delete confirmation dialog
  Future<bool> confirmDelete({
    required String itemName,
    String? itemType,
    String? additionalMessage,
  }) {
    return showConfirmDialog(
      this,
      ConfirmationConfig.delete(
        itemName: itemName,
        itemType: itemType,
        additionalMessage: additionalMessage,
      ),
    );
  }

  /// Show a discard changes confirmation dialog
  Future<bool> confirmDiscardChanges() {
    return showConfirmDialog(this, ConfirmationConfig.discardChanges());
  }

  /// Show a logout confirmation dialog
  Future<bool> confirmLogout() {
    return showConfirmDialog(this, ConfirmationConfig.logout());
  }

  /// Show a custom confirmation dialog
  Future<bool> confirm({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    ConfirmationType type = ConfirmationType.warning,
    IconData? icon,
  }) {
    return showConfirmDialog(
      this,
      ConfirmationConfig(
        title: title,
        message: message,
        type: type,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
      ),
    );
  }

  /// Show a dangerous action confirmation that requires typing to confirm
  Future<bool> confirmDangerous({
    required String title,
    required String message,
    required String typeToConfirm,
  }) {
    return showConfirmDialog(
      this,
      ConfirmationConfig.typeToConfirm(
        title: title,
        message: message,
        confirmationText: typeToConfirm,
      ),
    );
  }
}
