import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_theme.dart';
import 'web_management_service.dart';

/// Tab for editing social media links
class SocialMediaTab extends StatefulWidget {
  final WebsiteVariables variables;
  final Function(WebsiteVariables) onChanged;
  final GroupSocialDefaults? groupDefaults;

  const SocialMediaTab({
    super.key,
    required this.variables,
    required this.onChanged,
    this.groupDefaults,
  });

  @override
  State<SocialMediaTab> createState() => _SocialMediaTabState();
}

class _SocialMediaTabState extends State<SocialMediaTab> {
  static const Color _accent = AppColors.accent;

  late Map<String, TextEditingController> _controllers;

  static const List<_SocialPlatform> _platforms = [
    _SocialPlatform(
      key: 'facebook_url',
      name: 'Facebook',
      icon: Icons.facebook,
      color: Color(0xFF1877F2),
      placeholder: 'https://facebook.com/yourpage',
    ),
    _SocialPlatform(
      key: 'instagram_url',
      name: 'Instagram',
      icon: Icons.camera_alt,
      color: Color(0xFFE4405F),
      placeholder: 'https://instagram.com/yourprofile',
    ),
    _SocialPlatform(
      key: 'youtube_url',
      name: 'YouTube',
      icon: Icons.play_circle_filled,
      color: Color(0xFFFF0000),
      placeholder: 'https://youtube.com/@yourchannel',
    ),
    _SocialPlatform(
      key: 'twitter_url',
      name: 'Twitter / X',
      icon: Icons.alternate_email,
      color: Color(0xFF1DA1F2),
      placeholder: 'https://twitter.com/yourhandle',
    ),
    _SocialPlatform(
      key: 'linkedin_url',
      name: 'LinkedIn',
      icon: Icons.business,
      color: Color(0xFF0A66C2),
      placeholder: 'https://linkedin.com/company/yourcompany',
    ),
    _SocialPlatform(
      key: 'tiktok_url',
      name: 'TikTok',
      icon: Icons.music_note,
      color: Color(0xFF000000),
      placeholder: 'https://tiktok.com/@yourprofile',
    ),
    _SocialPlatform(
      key: 'yelp_url',
      name: 'Yelp',
      icon: Icons.star,
      color: Color(0xFFD32323),
      placeholder: 'https://yelp.com/biz/yourbusiness',
    ),
    _SocialPlatform(
      key: 'google_business_url',
      name: 'Google Business',
      icon: Icons.store,
      color: Color(0xFF4285F4),
      placeholder: 'https://g.page/yourbusiness',
    ),
    _SocialPlatform(
      key: 'pinterest_url',
      name: 'Pinterest',
      icon: Icons.push_pin,
      color: Color(0xFFE60023),
      placeholder: 'https://pinterest.com/yourprofile',
    ),
    _SocialPlatform(
      key: 'bbb_url',
      name: 'BBB',
      icon: Icons.verified,
      color: Color(0xFF006CB7),
      placeholder: 'https://bbb.org/us/your-business',
    ),
    _SocialPlatform(
      key: 'nextdoor_url',
      name: 'Nextdoor',
      icon: Icons.home,
      color: Color(0xFF8ED500),
      placeholder: 'https://nextdoor.com/pages/yourbusiness',
    ),
    _SocialPlatform(
      key: 'houzz_url',
      name: 'Houzz',
      icon: Icons.house,
      color: Color(0xFF4DBC15),
      placeholder: 'https://houzz.com/pro/yourprofile',
    ),
    _SocialPlatform(
      key: 'angi_url',
      name: 'Angi',
      icon: Icons.handyman,
      color: Color(0xFFFF6153),
      placeholder: 'https://angi.com/companylist/yourcompany',
    ),
    _SocialPlatform(
      key: 'thumbtack_url',
      name: 'Thumbtack',
      icon: Icons.thumb_up,
      color: Color(0xFF009FD9),
      placeholder: 'https://thumbtack.com/yourprofile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final v = widget.variables;
    _controllers = {
      'facebook_url': TextEditingController(text: v.facebookUrl ?? ''),
      'instagram_url': TextEditingController(text: v.instagramUrl ?? ''),
      'youtube_url': TextEditingController(text: v.youtubeUrl ?? ''),
      'twitter_url': TextEditingController(text: v.twitterUrl ?? ''),
      'linkedin_url': TextEditingController(text: v.linkedinUrl ?? ''),
      'tiktok_url': TextEditingController(text: v.tiktokUrl ?? ''),
      'yelp_url': TextEditingController(text: v.yelpUrl ?? ''),
      'google_business_url': TextEditingController(text: v.googleBusinessUrl ?? ''),
      'pinterest_url': TextEditingController(text: v.pinterestUrl ?? ''),
      'bbb_url': TextEditingController(text: v.bbbUrl ?? ''),
      'nextdoor_url': TextEditingController(text: v.nextdoorUrl ?? ''),
      'houzz_url': TextEditingController(text: v.houzzUrl ?? ''),
      'angi_url': TextEditingController(text: v.angiUrl ?? ''),
      'thumbtack_url': TextEditingController(text: v.thumbtackUrl ?? ''),
    };
  }

  @override
  void didUpdateWidget(SocialMediaTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variables.siteId != widget.variables.siteId) {
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _initControllers();
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _notifyChange() {
    final updated = WebsiteVariables(
      id: widget.variables.id,
      siteId: widget.variables.siteId,
      businessName: widget.variables.businessName,
      cityName: widget.variables.cityName,
      locationName: widget.variables.locationName,
      tagline: widget.variables.tagline,
      googleMapsUrl: widget.variables.googleMapsUrl,
      phonePrimary: widget.variables.phonePrimary,
      phoneSecondary: widget.variables.phoneSecondary,
      emailPrimary: widget.variables.emailPrimary,
      emailSecondary: widget.variables.emailSecondary,
      addressLine1: widget.variables.addressLine1,
      addressLine2: widget.variables.addressLine2,
      city: widget.variables.city,
      state: widget.variables.state,
      zip: widget.variables.zip,
      country: widget.variables.country,
      operatingHours: widget.variables.operatingHours,
      facebookUrl: _getControllerValue('facebook_url'),
      instagramUrl: _getControllerValue('instagram_url'),
      youtubeUrl: _getControllerValue('youtube_url'),
      twitterUrl: _getControllerValue('twitter_url'),
      linkedinUrl: _getControllerValue('linkedin_url'),
      tiktokUrl: _getControllerValue('tiktok_url'),
      yelpUrl: _getControllerValue('yelp_url'),
      googleBusinessUrl: _getControllerValue('google_business_url'),
      pinterestUrl: _getControllerValue('pinterest_url'),
      bbbUrl: _getControllerValue('bbb_url'),
      nextdoorUrl: _getControllerValue('nextdoor_url'),
      houzzUrl: _getControllerValue('houzz_url'),
      angiUrl: _getControllerValue('angi_url'),
      thumbtackUrl: _getControllerValue('thumbtack_url'),
    );

    widget.onChanged(updated);
  }

  String? _getControllerValue(String key) {
    final value = _controllers[key]?.text.trim();
    return (value?.isEmpty ?? true) ? null : value;
  }

  /// Get list of platforms that should be visible (not disabled by group defaults)
  List<_SocialPlatform> _getVisiblePlatforms() {
    if (widget.groupDefaults == null) return _platforms;

    return _platforms.where((platform) {
      return widget.groupDefaults!.isEnabled(platform.key);
    }).toList();
  }

  /// Get the placeholder text for a platform (group default if available, otherwise generic)
  String _getPlaceholder(_SocialPlatform platform) {
    if (widget.groupDefaults != null) {
      final groupUrl = widget.groupDefaults!.getUrl(platform.key);
      if (groupUrl != null && groupUrl.isNotEmpty) {
        return 'Group default: $groupUrl';
      }
    }
    return platform.placeholder;
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.share, color: _accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Social Media Links',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.groupDefaults != null
                                ? 'Configure site-specific URLs. Empty fields will use group defaults (shown in placeholder). Disabled platforms are hidden.'
                                : 'Configure your social media URLs. These will be available on your website via shortcodes.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Platform cards grid - filter out disabled platforms if group defaults exist
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 450,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 2.2,
                ),
                itemCount: _getVisiblePlatforms().length,
                itemBuilder: (context, index) {
                  final platform = _getVisiblePlatforms()[index];
                  return _buildPlatformCard(platform, cardColor, isDark);
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformCard(_SocialPlatform platform, Color cardColor, bool isDark) {
    final controller = _controllers[platform.key]!;
    final hasUrl = controller.text.trim().isNotEmpty;
    final hasGroupDefault = widget.groupDefaults != null &&
        (widget.groupDefaults!.getUrl(platform.key)?.isNotEmpty ?? false);
    final placeholder = _getPlaceholder(platform);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasUrl
              ? platform.color.withValues(alpha: 0.5)
              : hasGroupDefault
                  ? Colors.purple.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: platform.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(platform.icon, color: platform.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      platform.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (!hasUrl && hasGroupDefault)
                      Text(
                        'Using group default',
                        style: TextStyle(fontSize: 10, color: Colors.purple.shade400),
                      ),
                  ],
                ),
              ),
              if (hasUrl)
                IconButton(
                  icon: Icon(Icons.open_in_new, size: 18, color: platform.color),
                  onPressed: () => _openUrl(controller.text),
                  tooltip: 'Open in browser',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
            ],
          ),
          const Spacer(),
          TextFormField(
            controller: controller,
            onChanged: (_) => _notifyChange(),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(
                fontSize: 11,
                color: hasGroupDefault ? Colors.purple.shade300 : Colors.grey.shade500,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: platform.color, width: 2),
              ),
              prefixIcon: Icon(Icons.link, size: 18, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialPlatform {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  final String placeholder;

  const _SocialPlatform({
    required this.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.placeholder,
  });
}
