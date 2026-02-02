import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../admin/batch_image_editor_screen.dart';
import '../admin/image_resizer_screen.dart';
import 'blog_editor_screen.dart';
import 'email_marketing_screen.dart';
import 'sms_marketing_screen.dart';
import 'youtube_downloader_screen.dart';
import 'web_management/web_management_screen.dart';

class MarketingToolsScreen extends StatelessWidget {
  final String username;
  final String role;

  const MarketingToolsScreen({
    required this.username,
    required this.role,
    super.key,
  });

  static const Color _accent = AppColors.accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
          height: 40,
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
          child: isWide
              ? _buildWideLayout(context, cardColor)
              : _buildNarrowLayout(context, cardColor),
        ),
      ),
    );
  }

  /// Two-column layout for wide screens
  Widget _buildWideLayout(BuildContext context, Color cardColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column
        Expanded(
          child: Column(
            children: [
              _buildSection(
                context: context,
                title: 'Content Creation',
                icon: Icons.create,
                cardColor: cardColor,
                items: _contentCreationItems(context, cardColor),
              ),
              const SizedBox(height: 24),
              _buildSection(
                context: context,
                title: 'Video Tools',
                icon: Icons.video_library,
                cardColor: cardColor,
                items: _videoToolsItems(context, cardColor),
              ),
              const SizedBox(height: 24),
              _buildSection(
                context: context,
                title: 'Web Management',
                icon: Icons.language,
                cardColor: cardColor,
                items: _webManagementItems(context, cardColor),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Right Column
        Expanded(
          child: Column(
            children: [
              _buildSection(
                context: context,
                title: 'Image Tools',
                icon: Icons.image,
                cardColor: cardColor,
                items: _imageToolsItems(context, cardColor),
              ),
              const SizedBox(height: 24),
              _buildSection(
                context: context,
                title: 'Campaigns',
                icon: Icons.campaign,
                cardColor: cardColor,
                items: _campaignsItems(context, cardColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Single-column layout for narrow screens
  Widget _buildNarrowLayout(BuildContext context, Color cardColor) {
    return Column(
      children: [
        _buildSection(
          context: context,
          title: 'Content Creation',
          icon: Icons.create,
          cardColor: cardColor,
          items: _contentCreationItems(context, cardColor),
        ),
        const SizedBox(height: 24),
        _buildSection(
          context: context,
          title: 'Video Tools',
          icon: Icons.video_library,
          cardColor: cardColor,
          items: _videoToolsItems(context, cardColor),
        ),
        const SizedBox(height: 24),
        _buildSection(
          context: context,
          title: 'Image Tools',
          icon: Icons.image,
          cardColor: cardColor,
          items: _imageToolsItems(context, cardColor),
        ),
        const SizedBox(height: 24),
        _buildSection(
          context: context,
          title: 'Campaigns',
          icon: Icons.campaign,
          cardColor: cardColor,
          items: _campaignsItems(context, cardColor),
        ),
        const SizedBox(height: 24),
        _buildSection(
          context: context,
          title: 'Web Management',
          icon: Icons.language,
          cardColor: cardColor,
          items: _webManagementItems(context, cardColor),
        ),
      ],
    );
  }

  /// Content Creation tools
  List<Widget> _contentCreationItems(BuildContext context, Color cardColor) {
    return [
      _buildToolButton(
        context: context,
        icon: Icons.edit_note,
        title: 'Blog Creator',
        subtitle: 'Create and publish articles to WordPress sites',
        cardColor: cardColor,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlogEditorScreen(
                username: username,
                role: role,
              ),
            ),
          );
        },
      ),
    ];
  }

  /// Video tools
  List<Widget> _videoToolsItems(BuildContext context, Color cardColor) {
    return [
      _buildToolButton(
        context: context,
        icon: Icons.download,
        title: 'YouTube Downloader',
        subtitle: 'Download videos in various formats and resolutions',
        cardColor: cardColor,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => YouTubeDownloaderScreen(
                username: username,
                role: role,
              ),
            ),
          );
        },
      ),
    ];
  }

  /// Image tools
  List<Widget> _imageToolsItems(BuildContext context, Color cardColor) {
    return [
      _buildToolButton(
        context: context,
        icon: Icons.photo_library_outlined,
        title: 'Image Editor',
        subtitle: 'Batch process images with overlays and watermarks',
        cardColor: cardColor,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const BatchImageEditorScreen(),
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      _buildToolButton(
        context: context,
        icon: Icons.compress_outlined,
        title: 'Image Resizer',
        subtitle: 'Compress and resize oversized images for web',
        cardColor: cardColor,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ImageResizerScreen(),
            ),
          );
        },
      ),
    ];
  }

  /// Campaigns tools
  List<Widget> _campaignsItems(BuildContext context, Color cardColor) {
    return [
      _buildToolButton(
        context: context,
        icon: Icons.mail_outline,
        title: 'Email Marketing',
        subtitle: 'Create and send email campaigns via Mailchimp',
        cardColor: cardColor,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EmailMarketingScreen(
                username: username,
                role: role,
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      _buildToolButton(
        context: context,
        icon: Icons.sms_outlined,
        title: 'SMS Marketing',
        subtitle: 'Send SMS campaigns and manage contacts via Twilio',
        cardColor: cardColor,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SmsMarketingScreen(
                username: username,
                role: role,
              ),
            ),
          );
        },
      ),
    ];
  }

  /// Web Management tools
  List<Widget> _webManagementItems(BuildContext context, Color cardColor) {
    return [
      _buildToolButton(
        context: context,
        icon: Icons.tune,
        title: 'Site Variables',
        subtitle: 'Manage contact info, social links, and more for your websites',
        cardColor: cardColor,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const WebManagementScreen(),
            ),
          );
        },
      ),
    ];
  }

  /// Section with header
  Widget _buildSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color cardColor,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: _accent),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items,
      ],
    );
  }

  Widget _buildToolButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _accent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: _accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
