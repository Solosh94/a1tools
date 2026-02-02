import 'package:flutter/material.dart';
import 'management_base.dart';
import '../fcm_config_screen.dart';
import '../route_config_screen.dart';
import '../../marketing/mailchimp_integration_screen.dart';
import '../../marketing/smtp_config_screen.dart';
import '../../marketing/twilio_integration_screen.dart';
import '../../integration/wordpress_sites_screen.dart';
import '../../integration/workiz_integration_screen.dart';

/// Integrations management screen (Developer only)
/// Contains: FCM, Google Maps API, Mailchimp, SMTP, Twilio, WordPress, Workiz
class IntegrationsManagementScreen extends StatelessWidget {
  final String currentUsername;
  final String currentRole;

  const IntegrationsManagementScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    return ManagementCategoryScreen(
      title: 'Integrations',
      icon: Icons.extension,
      children: [
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
      ],
    );
  }
}
