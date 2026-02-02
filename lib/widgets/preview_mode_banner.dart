import 'package:flutter/material.dart';

/// Banner displayed when developer is previewing the app as another role
class PreviewModeBanner extends StatelessWidget {
  final String previewRole;
  final VoidCallback onExit;

  const PreviewModeBanner({
    required this.previewRole,
    required this.onExit,
    super.key,
  });

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'developer':
        return 'Developer';
      case 'administrator':
        return 'Administrator';
      case 'management':
        return 'Management';
      case 'dispatcher':
        return 'Dispatcher';
      case 'remote_dispatcher':
        return 'Remote Dispatcher';
      case 'technician':
        return 'Technician';
      case 'marketing':
        return 'Marketing';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: Colors.purple,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.visibility, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            'Preview Mode: Viewing as ${_formatRole(previewRole)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onExit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Exit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
