import 'dart:io';
import 'package:flutter/material.dart';
import '../features/admin/dependencies_screen.dart';
import '../features/legal/terms_of_service_screen.dart';

class UpdateCheckerFooter extends StatelessWidget {
  final String version;

  const UpdateCheckerFooter({
    required this.version,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark ? Colors.white38 : Colors.black54;
    final iconColor = isDark ? Colors.white30 : Colors.black38;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 24.0, right: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Terms of Service - extreme left
          _FooterIconButton(
            icon: Icons.description_outlined,
            tooltip: 'Terms of Service',
            color: iconColor,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TermsOfServiceScreen(),
                ),
              );
            },
          ),
          // Center content - copyright and version
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'A1 Tools - All rights reserved',
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                version.isNotEmpty ? 'v$version' : 'v-',
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          // Settings (Dependencies) - extreme right, Windows only
          if (Platform.isWindows)
            _FooterIconButton(
              icon: Icons.settings,
              tooltip: 'Settings',
              color: iconColor,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DependenciesScreen(),
                  ),
                );
              },
            ),
          // Placeholder for non-Windows to keep text centered
          if (!Platform.isWindows)
            const SizedBox(width: 36),
        ],
      ),
    );
  }
}

/// Small icon button for footer
class _FooterIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _FooterIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }
}
