import 'package:flutter/material.dart';
import 'management_base.dart';
import '../logo_config_screen.dart';
import '../user_management_screen.dart';
import '../fcm_config_screen.dart';
import '../route_config_screen.dart';
import '../../marketing/mailchimp_integration_screen.dart';
import '../../marketing/smtp_config_screen.dart';
import '../../marketing/twilio_integration_screen.dart';
import '../../integration/wordpress_sites_screen.dart';
import '../../integration/workiz_integration_screen.dart';

/// General Settings Management screen (Developer only)
/// Contains system-wide configuration settings, PDF Logo, User Management, and all Integrations
class GeneralSettingsManagementScreen extends StatelessWidget {
  final String currentUsername;
  final String currentRole;

  const GeneralSettingsManagementScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    return ManagementCategoryScreen(
      title: 'General Settings',
      icon: Icons.settings_applications,
      children: [
        _buildInfoCard(context),
        const SizedBox(height: 20),
        ManagementButton(
          icon: Icons.image_outlined,
          title: 'PDF Logo Configuration',
          subtitle: 'Configure logo for inspection reports',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LogoConfigScreen(
                username: currentUsername,
                role: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.people_outline,
          title: 'User Management',
          subtitle: 'Create & manage users',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserManagementScreen(
                currentUsername: currentUsername,
                currentRole: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(context, 'Integrations'),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.notifications,
          title: 'FCM (Push Notifications)',
          subtitle: 'Configure Firebase Cloud Messaging',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FcmConfigScreen(
                username: currentUsername,
                role: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.route,
          title: 'Google Maps API',
          subtitle: 'Configure route optimization',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RouteConfigScreen(
                username: currentUsername,
                role: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.mail,
          title: 'Mailchimp',
          subtitle: 'Email marketing integration',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MailchimpIntegrationScreen(
                username: currentUsername,
                role: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.email_outlined,
          title: 'SMTP',
          subtitle: 'Email server settings',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SmtpConfigScreen()),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.sms,
          title: 'Twilio',
          subtitle: 'SMS messaging integration',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TwilioIntegrationScreen(
                username: currentUsername,
                role: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.language,
          title: 'WordPress',
          subtitle: 'Blog site credentials',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WordPressSitesScreen()),
          ),
        ),
        const SizedBox(height: 12),
        ManagementButton(
          icon: Icons.integration_instructions,
          title: 'Workiz',
          subtitle: 'Job management integration',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkizIntegrationScreen(
                username: currentUsername,
                role: currentRole,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(context, 'Coming Soon'),
        const SizedBox(height: 12),
        const ComingSoonButton(
          icon: Icons.color_lens,
          title: 'Theme Settings',
          subtitle: 'App colors & appearance',
        ),
        const SizedBox(height: 12),
        const ComingSoonButton(
          icon: Icons.notifications_active,
          title: 'Notification Defaults',
          subtitle: 'Default notification preferences',
        ),
        const SizedBox(height: 12),
        const ComingSoonButton(
          icon: Icons.backup,
          title: 'Backup & Restore',
          subtitle: 'System data management',
        ),
        const SizedBox(height: 12),
        const ComingSoonButton(
          icon: Icons.speed,
          title: 'Performance Settings',
          subtitle: 'Optimize app performance',
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Colors.blue,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Developer Settings',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'System-wide configuration options for the A1 Tools application. These settings affect all users.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
