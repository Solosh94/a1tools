// Keyboard Shortcuts Utility
//
// Provides keyboard shortcut support for desktop power users.
// Implements common shortcuts and allows custom bindings.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Common application keyboard shortcuts
class AppShortcuts {
  AppShortcuts._();

  // Navigation shortcuts
  static const home = SingleActivator(LogicalKeyboardKey.keyH, control: true);
  static const back = SingleActivator(LogicalKeyboardKey.escape);
  static const settings = SingleActivator(LogicalKeyboardKey.comma, control: true);

  // Action shortcuts
  static const save = SingleActivator(LogicalKeyboardKey.keyS, control: true);
  static const refresh = SingleActivator(LogicalKeyboardKey.keyR, control: true);
  static const search = SingleActivator(LogicalKeyboardKey.keyF, control: true);
  static const newItem = SingleActivator(LogicalKeyboardKey.keyN, control: true);
  static const delete = SingleActivator(LogicalKeyboardKey.delete);
  static const export = SingleActivator(LogicalKeyboardKey.keyE, control: true);
  static const print_ = SingleActivator(LogicalKeyboardKey.keyP, control: true);

  // Selection shortcuts
  static const selectAll = SingleActivator(LogicalKeyboardKey.keyA, control: true);
  static const copy = SingleActivator(LogicalKeyboardKey.keyC, control: true);
  static const paste = SingleActivator(LogicalKeyboardKey.keyV, control: true);
  static const cut = SingleActivator(LogicalKeyboardKey.keyX, control: true);

  // Navigation within lists
  static const moveUp = SingleActivator(LogicalKeyboardKey.arrowUp);
  static const moveDown = SingleActivator(LogicalKeyboardKey.arrowDown);
  static const pageUp = SingleActivator(LogicalKeyboardKey.pageUp);
  static const pageDown = SingleActivator(LogicalKeyboardKey.pageDown);
  static const goToStart = SingleActivator(LogicalKeyboardKey.home, control: true);
  static const goToEnd = SingleActivator(LogicalKeyboardKey.end, control: true);

  // Tab navigation
  static const nextTab = SingleActivator(LogicalKeyboardKey.tab, control: true);
  static const prevTab = SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true);

  // Zoom/View
  static const zoomIn = SingleActivator(LogicalKeyboardKey.equal, control: true);
  static const zoomOut = SingleActivator(LogicalKeyboardKey.minus, control: true);
  static const resetZoom = SingleActivator(LogicalKeyboardKey.digit0, control: true);

  // Help
  static const help = SingleActivator(LogicalKeyboardKey.f1);
  static const showShortcuts = SingleActivator(LogicalKeyboardKey.slash, control: true);
}

/// Shortcut action with metadata
class ShortcutAction {
  final String id;
  final String label;
  final String? description;
  final SingleActivator shortcut;
  final VoidCallback? action;
  final IconData? icon;
  final String? category;

  const ShortcutAction({
    required this.id,
    required this.label,
    required this.shortcut,
    this.description,
    this.action,
    this.icon,
    this.category,
  });

  /// Get human-readable shortcut string
  String get shortcutLabel {
    final parts = <String>[];

    if (shortcut.control) {
      parts.add(Platform.isMacOS ? '⌘' : 'Ctrl');
    }
    if (shortcut.alt) {
      parts.add(Platform.isMacOS ? '⌥' : 'Alt');
    }
    if (shortcut.shift) {
      parts.add('Shift');
    }

    // Get key label
    final keyLabel = _getKeyLabel(shortcut.trigger);
    parts.add(keyLabel);

    return parts.join(Platform.isMacOS ? '' : '+');
  }

  static String _getKeyLabel(LogicalKeyboardKey key) {
    // Common key mappings
    final keyLabels = {
      LogicalKeyboardKey.escape: 'Esc',
      LogicalKeyboardKey.enter: 'Enter',
      LogicalKeyboardKey.backspace: '⌫',
      LogicalKeyboardKey.delete: 'Del',
      LogicalKeyboardKey.tab: 'Tab',
      LogicalKeyboardKey.space: 'Space',
      LogicalKeyboardKey.arrowUp: '↑',
      LogicalKeyboardKey.arrowDown: '↓',
      LogicalKeyboardKey.arrowLeft: '←',
      LogicalKeyboardKey.arrowRight: '→',
      LogicalKeyboardKey.home: 'Home',
      LogicalKeyboardKey.end: 'End',
      LogicalKeyboardKey.pageUp: 'PgUp',
      LogicalKeyboardKey.pageDown: 'PgDn',
      LogicalKeyboardKey.f1: 'F1',
      LogicalKeyboardKey.f2: 'F2',
      LogicalKeyboardKey.f3: 'F3',
      LogicalKeyboardKey.f4: 'F4',
      LogicalKeyboardKey.f5: 'F5',
      LogicalKeyboardKey.f6: 'F6',
      LogicalKeyboardKey.f7: 'F7',
      LogicalKeyboardKey.f8: 'F8',
      LogicalKeyboardKey.f9: 'F9',
      LogicalKeyboardKey.f10: 'F10',
      LogicalKeyboardKey.f11: 'F11',
      LogicalKeyboardKey.f12: 'F12',
      LogicalKeyboardKey.comma: ',',
      LogicalKeyboardKey.period: '.',
      LogicalKeyboardKey.slash: '/',
      LogicalKeyboardKey.equal: '=',
      LogicalKeyboardKey.minus: '-',
    };

    if (keyLabels.containsKey(key)) {
      return keyLabels[key]!;
    }

    // For letter and number keys
    final keyStr = key.keyLabel;
    if (keyStr.length == 1) {
      return keyStr.toUpperCase();
    }

    return keyStr;
  }
}

/// Widget that provides keyboard shortcut support
class KeyboardShortcutScope extends StatelessWidget {
  final Widget child;
  final List<ShortcutAction> shortcuts;
  final bool autofocus;

  const KeyboardShortcutScope({
    super.key,
    required this.child,
    required this.shortcuts,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    // Only enable shortcuts on desktop
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return child;
    }

    final shortcutMap = <ShortcutActivator, Intent>{};
    final actionMap = <Type, Action<Intent>>{};

    for (final shortcut in shortcuts) {
      if (shortcut.action != null) {
        final intentType = _ShortcutIntent(shortcut.id);
        shortcutMap[shortcut.shortcut] = intentType;
        actionMap[intentType.runtimeType] = CallbackAction<_ShortcutIntent>(
          onInvoke: (intent) {
            shortcut.action!();
            return null;
          },
        );
      }
    }

    return Shortcuts(
      shortcuts: shortcutMap,
      child: Actions(
        actions: actionMap,
        child: Focus(
          autofocus: autofocus,
          child: child,
        ),
      ),
    );
  }
}

class _ShortcutIntent extends Intent {
  final String id;
  const _ShortcutIntent(this.id);
}

/// Widget that shows available keyboard shortcuts
class KeyboardShortcutsHelp extends StatelessWidget {
  final List<ShortcutAction> shortcuts;

  const KeyboardShortcutsHelp({
    super.key,
    required this.shortcuts,
  });

  /// Show shortcuts help dialog
  static Future<void> show(BuildContext context, List<ShortcutAction> shortcuts) {
    return showDialog(
      context: context,
      builder: (ctx) => KeyboardShortcutsDialog(shortcuts: shortcuts),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Group shortcuts by category
    final grouped = <String, List<ShortcutAction>>{};
    for (final shortcut in shortcuts) {
      final category = shortcut.category ?? 'General';
      grouped.putIfAbsent(category, () => []).add(shortcut);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries) ...[
          Text(
            entry.key,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...entry.value.map((shortcut) => _buildShortcutRow(context, shortcut)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildShortcutRow(BuildContext context, ShortcutAction shortcut) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (shortcut.icon != null) ...[
            Icon(shortcut.icon, size: 16, color: isDark ? Colors.white54 : Colors.black54),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              shortcut.label,
              style: TextStyle(
                color: isDark ? const Color(0xDEFFFFFF) : const Color(0xDE000000),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey[400]!,
              ),
            ),
            child: Text(
              shortcut.shortcutLabel,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog showing all keyboard shortcuts
class KeyboardShortcutsDialog extends StatelessWidget {
  final List<ShortcutAction> shortcuts;

  const KeyboardShortcutsDialog({
    super.key,
    required this.shortcuts,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.keyboard, size: 24),
          SizedBox(width: 12),
          Text('Keyboard Shortcuts'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: KeyboardShortcutsHelp(shortcuts: shortcuts),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Mixin for screens that support keyboard shortcuts
mixin KeyboardShortcutsMixin<T extends StatefulWidget> on State<T> {
  /// Override to provide shortcuts for this screen
  List<ShortcutAction> get screenShortcuts => [];

  /// Get all shortcuts for this screen (common + screen-specific)
  List<ShortcutAction> get allShortcuts {
    final shortcuts = <ShortcutAction>[
      ShortcutAction(
        id: 'back',
        label: 'Go Back',
        shortcut: AppShortcuts.back,
        icon: Icons.arrow_back,
        category: 'Navigation',
        action: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
    ];

    // Add screen-specific shortcuts
    shortcuts.addAll(screenShortcuts);

    // Add help shortcut last (needs access to all shortcuts)
    shortcuts.add(
      ShortcutAction(
        id: 'help',
        label: 'Show Shortcuts',
        shortcut: AppShortcuts.showShortcuts,
        icon: Icons.help_outline,
        category: 'Help',
        action: () => KeyboardShortcutsHelp.show(context, shortcuts),
      ),
    );

    return shortcuts;
  }

  /// Build the widget with keyboard shortcuts enabled
  Widget buildWithShortcuts(Widget child) {
    return KeyboardShortcutScope(
      shortcuts: allShortcuts,
      child: child,
    );
  }
}

/// Extension to add keyboard shortcut hint to tooltips
extension KeyboardShortcutTooltip on Widget {
  /// Add a tooltip with keyboard shortcut hint
  Widget withShortcutTooltip(String label, ShortcutAction shortcut) {
    return Tooltip(
      message: '$label (${shortcut.shortcutLabel})',
      child: this,
    );
  }
}
