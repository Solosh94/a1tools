import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Terms of Service screen for A1 Tools application
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 20, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Terms of Service'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Text(
                        'A1 Tools',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Terms of Service',
                        style: TextStyle(
                          fontSize: 16,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last Updated: January 2025',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Introduction
                _buildSection(
                  title: '1. Introduction',
                  content: '''
Welcome to A1 Tools, the internal business management application developed exclusively for A1 Investment Group LLC ("Company", "we", "us", or "our"). By accessing or using this application, you agree to be bound by these Terms of Service.

A1 Tools is designed for authorized employees and contractors of A1 Investment Group LLC to manage business operations including inspections, scheduling, training, inventory, and communications.''',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                _buildSection(
                  title: '2. Authorized Use',
                  content: '''
This application is intended solely for:
• Current employees of A1 Investment Group LLC
• Authorized contractors working on behalf of the Company
• Individuals granted explicit access by Company management

Unauthorized access or use of this application is strictly prohibited and may result in disciplinary action, termination, and/or legal proceedings.''',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                _buildSection(
                  title: '3. User Accounts & Authentication',
                  content: '''
• You are responsible for maintaining the confidentiality of your login credentials
• You must not share your account credentials with any other person
• You must immediately report any unauthorized use of your account
• The Company reserves the right to disable or terminate accounts at any time
• Multi-factor authentication may be required for certain features''',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                _buildSection(
                  title: '4. Data Collection & Monitoring',
                  content: '''
By using A1 Tools, you acknowledge and consent to the following:

Time & Attendance Monitoring:
• Clock-in and clock-out times are recorded
• Work hours and schedules are tracked
• Compliance monitoring may be performed during work hours

Screen Monitoring (Desktop Application):
• Periodic Screenshots: Screenshots of your screen may be captured at regular intervals during work hours for productivity and compliance purposes
• Live Screen Monitoring: Authorized management personnel may view your screen in real-time during work hours
• Remote Control: In certain situations, authorized personnel may remotely control your workstation for training, support, or supervisory purposes
• Active window titles and application usage may be collected
• All screen monitoring occurs only when you are clocked in and using company devices

Privacy Exclusions:
To protect employee privacy, certain applications are excluded from monitoring. When privacy-excluded applications (such as personal banking, healthcare portals, or other designated private applications) are in the foreground, their content is hidden from viewers and screenshots. The excluded application windows appear invisible to management personnel during live monitoring and are not captured in periodic screenshots. The list of excluded applications is maintained by company administrators.

Location Services (Mobile Application):
• GPS location may be collected for route optimization
• Location data is used for job site verification
• Location tracking is active only during work activities

All collected data is used solely for business operations, compliance, training, and improving work efficiency. Monitoring data is accessible only to authorized management personnel.''',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                _buildSection(
                  title: '5. Application Features',
                  content: '''
A1 Tools provides the following capabilities:

Inspection Management:
• Create, edit, and submit chimney inspection reports
• Capture and upload photos of inspection findings
• Generate PDF reports for customers

Scheduling & Time Management:
• View work schedules and assignments
• Clock in/out for time tracking
• Request time off and view work history

Training & Certification:
• Access training materials and study guides
• Complete certification tests
• Track training progress

Communication:
• Send and receive company messages
• View alerts and announcements
• Contact team members

Inventory Management:
• Scan and track inventory items
• View stock levels and locations
• Request supplies

Sunday Boards & Job Tracking:
• Manage customer relationships
• Track job progress and status
• View boards and assignments''',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                _buildSection(
                  title: '6. Acceptable Use Policy',
                  content: '''
When using A1 Tools, you agree NOT to:
• Use the application for any unlawful purpose
• Attempt to gain unauthorized access to any part of the system
• Share confidential customer or business information
• Falsify time records, inspection reports, or other data
• Use automated tools or scripts to interact with the application
• Reverse engineer, decompile, or modify the application
• Upload malicious content or attempt to disrupt service
• Use the application for personal or non-work activities''',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                _buildSection(
                  title: '7. Confidentiality',
                  content: '''
All information accessed through A1 Tools is confidential and proprietary to A1 Investment Group LLC. This includes but is not limited to:
• Customer information and contact details
• Inspection reports and findings
• Business processes and procedures
• Pricing and financial information
• Employee information
• Trade secrets and proprietary methods

You must not disclose confidential information to any third party without explicit written authorization from Company management.''',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                _buildSection(
                  title: '8. Intellectual Property',
                  content: '''
A1 Tools and all its contents, features, and functionality are owned by A1 Investment Group LLC and are protected by copyright, trademark, and other intellectual property laws.

You are granted a limited, non-exclusive, non-transferable license to use the application solely for authorized business purposes. This license does not include the right to:
• Copy, modify, or distribute the application
• Create derivative works
• Remove any proprietary notices or labels''',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                _buildSection(
                  title: '9. Disclaimer of Warranties',
                  content: '''
A1 Tools is provided "as is" and "as available" without warranties of any kind, either express or implied. The Company does not warrant that:
• The application will be uninterrupted or error-free
• Defects will be corrected
• The application is free of viruses or harmful components

The Company is not liable for any damages resulting from the use or inability to use the application.''',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                _buildSection(
                  title: '10. Termination',
                  content: '''
Your access to A1 Tools may be terminated:
• Upon termination of your employment or contract
• For violation of these Terms of Service
• At the Company's sole discretion

Upon termination, you must immediately cease using the application and return any company devices or materials.''',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                _buildSection(
                  title: '11. Changes to Terms',
                  content: '''
The Company reserves the right to modify these Terms of Service at any time. Continued use of the application after changes constitutes acceptance of the modified terms.

Users will be notified of significant changes through the application or company communications.''',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                _buildSection(
                  title: '12. Contact Information',
                  content: '''
For questions about these Terms of Service or the A1 Tools application, please contact:

A1 Investment Group LLC
Email: support@a-1chimney.com

For technical support or to report issues with the application, please use the Suggestions feature within the app or contact your supervisor.''',
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                ),

                const SizedBox(height: 24),

                // Footer
                Center(
                  child: Text(
                    '© ${DateTime.now().year} A1 Investment Group LLC. All rights reserved.',
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.trim(),
            style: TextStyle(
              fontSize: 14,
              color: textColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
