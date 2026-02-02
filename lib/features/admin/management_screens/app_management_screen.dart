import 'package:flutter/material.dart';
import 'management_base.dart';
import '../lock_screen_exceptions_screen.dart';
import '../minimum_version_screen.dart';
import '../privacy_exclusions_screen.dart';
import '../push_update_screen.dart';
import '../role_accessibility_screen.dart';
import '../../suggestions/suggestions_review_screen.dart';

/// App Management screen (Developer only)
/// Contains: Lock Screen Exceptions, Minimum Version, Privacy Exclusions,
///           Push App Update, Review Suggestions, Role Accessibility
class AppManagementScreen extends StatelessWidget {
  final String currentUsername;
  final String currentRole;

  const AppManagementScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    return ManagementCategoryScreen(
      title: 'App Settings',
      icon: Icons.apps,
      children: [
        ManagementButton(
          icon: Icons.screen_lock_portrait_outlined,
          title: 'Lock Screen Exceptions',
          subtitle: 'Remote workers & work-from-home',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LockScreenExceptionsScreen(currentUsername: currentUsername),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.security_update,
          title: 'Minimum Version',
          subtitle: 'Block outdated app versions',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MinimumVersionScreen(currentUsername: currentUsername),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.visibility_off,
          title: 'Privacy Exclusions',
          subtitle: 'Hide programs from monitoring',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PrivacyExclusionsScreen(
                currentUsername: currentUsername,
                currentRole: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.system_update,
          title: 'Push App Update',
          subtitle: 'Deploy updates to all clients',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PushUpdateScreen()),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.lightbulb,
          title: 'Review Suggestions',
          subtitle: 'View & manage user suggestions',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SuggestionsReviewScreen(
                currentUsername: currentUsername,
                currentRole: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.lock_open,
          title: 'Role Accessibility',
          subtitle: 'Manage feature access by role',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoleAccessibilityScreen(
                currentUsername: currentUsername,
                currentRole: currentRole,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
