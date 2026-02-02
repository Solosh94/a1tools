import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_theme.dart';
import 'web_management_service.dart';

/// Editor for group-level social media defaults with enable/disable toggles
class GroupSocialDefaultsEditor extends StatefulWidget {
  final GroupSocialDefaults defaults;
  final Function(GroupSocialDefaults) onChanged;

  const GroupSocialDefaultsEditor({
    super.key,
    required this.defaults,
    required this.onChanged,
  });

  @override
  State<GroupSocialDefaultsEditor> createState() => _GroupSocialDefaultsEditorState();
}

class _GroupSocialDefaultsEditorState extends State<GroupSocialDefaultsEditor> {
  static const Color _accent = AppColors.accent;

  late Map<String, TextEditingController> _controllers;

  static const List<_SocialPlatform> _platforms = [
    _SocialPlatform(
      key: 'facebook_url',
      enabledKey: 'facebook_enabled',
      name: 'Facebook',
      icon: Icons.facebook,
      color: Color(0xFF1877F2),
      placeholder: 'https://facebook.com/yourpage',
    ),
    _SocialPlatform(
      key: 'instagram_url',
      enabledKey: 'instagram_enabled',
      name: 'Instagram',
      icon: Icons.camera_alt,
      color: Color(0xFFE4405F),
      placeholder: 'https://instagram.com/yourprofile',
    ),
    _SocialPlatform(
      key: 'youtube_url',
      enabledKey: 'youtube_enabled',
      name: 'YouTube',
      icon: Icons.play_circle_filled,
      color: Color(0xFFFF0000),
      placeholder: 'https://youtube.com/@yourchannel',
    ),
    _SocialPlatform(
      key: 'twitter_url',
      enabledKey: 'twitter_enabled',
      name: 'Twitter / X',
      icon: Icons.alternate_email,
      color: Color(0xFF1DA1F2),
      placeholder: 'https://twitter.com/yourhandle',
    ),
    _SocialPlatform(
      key: 'linkedin_url',
      enabledKey: 'linkedin_enabled',
      name: 'LinkedIn',
      icon: Icons.business,
      color: Color(0xFF0A66C2),
      placeholder: 'https://linkedin.com/company/yourcompany',
    ),
    _SocialPlatform(
      key: 'tiktok_url',
      enabledKey: 'tiktok_enabled',
      name: 'TikTok',
      icon: Icons.music_note,
      color: Color(0xFF000000),
      placeholder: 'https://tiktok.com/@yourprofile',
    ),
    _SocialPlatform(
      key: 'yelp_url',
      enabledKey: 'yelp_enabled',
      name: 'Yelp',
      icon: Icons.star,
      color: Color(0xFFD32323),
      placeholder: 'https://yelp.com/biz/yourbusiness',
    ),
    _SocialPlatform(
      key: 'google_business_url',
      enabledKey: 'google_business_enabled',
      name: 'Google Business',
      icon: Icons.store,
      color: Color(0xFF4285F4),
      placeholder: 'https://g.page/yourbusiness',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final d = widget.defaults;
    _controllers = {
      'facebook_url': TextEditingController(text: d.facebookUrl ?? ''),
      'instagram_url': TextEditingController(text: d.instagramUrl ?? ''),
      'youtube_url': TextEditingController(text: d.youtubeUrl ?? ''),
      'twitter_url': TextEditingController(text: d.twitterUrl ?? ''),
      'linkedin_url': TextEditingController(text: d.linkedinUrl ?? ''),
      'tiktok_url': TextEditingController(text: d.tiktokUrl ?? ''),
      'yelp_url': TextEditingController(text: d.yelpUrl ?? ''),
      'google_business_url': TextEditingController(text: d.googleBusinessUrl ?? ''),
    };
  }

  @override
  void didUpdateWidget(GroupSocialDefaultsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaults.groupId != widget.defaults.groupId) {
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
    final updated = GroupSocialDefaults(
      id: widget.defaults.id,
      groupId: widget.defaults.groupId,
      facebookUrl: _getControllerValue('facebook_url'),
      instagramUrl: _getControllerValue('instagram_url'),
      youtubeUrl: _getControllerValue('youtube_url'),
      twitterUrl: _getControllerValue('twitter_url'),
      linkedinUrl: _getControllerValue('linkedin_url'),
      tiktokUrl: _getControllerValue('tiktok_url'),
      yelpUrl: _getControllerValue('yelp_url'),
      googleBusinessUrl: _getControllerValue('google_business_url'),
      facebookEnabled: widget.defaults.facebookEnabled,
      instagramEnabled: widget.defaults.instagramEnabled,
      youtubeEnabled: widget.defaults.youtubeEnabled,
      twitterEnabled: widget.defaults.twitterEnabled,
      linkedinEnabled: widget.defaults.linkedinEnabled,
      tiktokEnabled: widget.defaults.tiktokEnabled,
      yelpEnabled: widget.defaults.yelpEnabled,
      googleBusinessEnabled: widget.defaults.googleBusinessEnabled,
    );

    widget.onChanged(updated);
  }

  void _toggleEnabled(String enabledKey, bool value) {
    final updated = GroupSocialDefaults(
      id: widget.defaults.id,
      groupId: widget.defaults.groupId,
      facebookUrl: _getControllerValue('facebook_url'),
      instagramUrl: _getControllerValue('instagram_url'),
      youtubeUrl: _getControllerValue('youtube_url'),
      twitterUrl: _getControllerValue('twitter_url'),
      linkedinUrl: _getControllerValue('linkedin_url'),
      tiktokUrl: _getControllerValue('tiktok_url'),
      yelpUrl: _getControllerValue('yelp_url'),
      googleBusinessUrl: _getControllerValue('google_business_url'),
      facebookEnabled: enabledKey == 'facebook_enabled' ? value : widget.defaults.facebookEnabled,
      instagramEnabled: enabledKey == 'instagram_enabled' ? value : widget.defaults.instagramEnabled,
      youtubeEnabled: enabledKey == 'youtube_enabled' ? value : widget.defaults.youtubeEnabled,
      twitterEnabled: enabledKey == 'twitter_enabled' ? value : widget.defaults.twitterEnabled,
      linkedinEnabled: enabledKey == 'linkedin_enabled' ? value : widget.defaults.linkedinEnabled,
      tiktokEnabled: enabledKey == 'tiktok_enabled' ? value : widget.defaults.tiktokEnabled,
      yelpEnabled: enabledKey == 'yelp_enabled' ? value : widget.defaults.yelpEnabled,
      googleBusinessEnabled: enabledKey == 'google_business_enabled' ? value : widget.defaults.googleBusinessEnabled,
    );

    widget.onChanged(updated);
  }

  bool _isEnabled(String enabledKey) {
    switch (enabledKey) {
      case 'facebook_enabled': return widget.defaults.facebookEnabled;
      case 'instagram_enabled': return widget.defaults.instagramEnabled;
      case 'youtube_enabled': return widget.defaults.youtubeEnabled;
      case 'twitter_enabled': return widget.defaults.twitterEnabled;
      case 'linkedin_enabled': return widget.defaults.linkedinEnabled;
      case 'tiktok_enabled': return widget.defaults.tiktokEnabled;
      case 'yelp_enabled': return widget.defaults.yelpEnabled;
      case 'google_business_enabled': return widget.defaults.googleBusinessEnabled;
      default: return true;
    }
  }

  String? _getControllerValue(String key) {
    final value = _controllers[key]?.text.trim();
    return (value?.isEmpty ?? true) ? null : value;
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
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_shared, color: Colors.purple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Group Social Media Defaults',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Set default URLs for all sites in this group. Individual sites will inherit these values unless they have their own settings. Toggle off to disable a platform for all sites in this group.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Platform cards grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 450,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.8,
                ),
                itemCount: _platforms.length,
                itemBuilder: (context, index) {
                  final platform = _platforms[index];
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
    final isEnabled = _isEnabled(platform.enabledKey);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEnabled ? cardColor : cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: !isEnabled
              ? Colors.grey.withValues(alpha: 0.2)
              : hasUrl
                  ? platform.color.withValues(alpha: 0.5)
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
                  color: isEnabled
                      ? platform.color.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  platform.icon,
                  color: isEnabled ? platform.color : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  platform.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isEnabled ? null : Colors.grey,
                  ),
                ),
              ),
              if (hasUrl && isEnabled)
                IconButton(
                  icon: Icon(Icons.open_in_new, size: 18, color: platform.color),
                  onPressed: () => _openUrl(controller.text),
                  tooltip: 'Open in browser',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              // Enable/disable toggle
              Switch(
                value: isEnabled,
                onChanged: (value) => _toggleEnabled(platform.enabledKey, value),
                activeColor: platform.color,
              ),
            ],
          ),
          const Spacer(),
          TextFormField(
            controller: controller,
            onChanged: (_) => _notifyChange(),
            enabled: isEnabled,
            style: TextStyle(
              fontSize: 13,
              color: isEnabled ? null : Colors.grey,
            ),
            decoration: InputDecoration(
              hintText: platform.placeholder,
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: platform.color, width: 2),
              ),
              prefixIcon: Icon(
                Icons.link,
                size: 18,
                color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),
          ),
          if (!isEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Disabled for all sites in this group',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}

class _SocialPlatform {
  final String key;
  final String enabledKey;
  final String name;
  final IconData icon;
  final Color color;
  final String placeholder;

  const _SocialPlatform({
    required this.key,
    required this.enabledKey,
    required this.name,
    required this.icon,
    required this.color,
    required this.placeholder,
  });
}
