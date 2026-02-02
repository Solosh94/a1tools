import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app_theme.dart';

/// Comprehensive guide dialog for the Web Management system
class WebManagementGuideDialog extends StatefulWidget {
  const WebManagementGuideDialog({super.key});

  @override
  State<WebManagementGuideDialog> createState() => _WebManagementGuideDialogState();
}

class _WebManagementGuideDialogState extends State<WebManagementGuideDialog>
    with SingleTickerProviderStateMixin {
  static const Color _accent = AppColors.accent;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade50;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book, color: _accent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Web Management Guide',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Learn how to use site variables on your WordPress websites',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: _accent,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _accent,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Shortcodes'),
                Tab(text: 'Elementor'),
                Tab(text: 'Setup'),
              ],
            ),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(cardColor, isDark),
                  _buildShortcodesTab(cardColor, isDark),
                  _buildElementorTab(cardColor, isDark),
                  _buildSetupTab(cardColor, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // OVERVIEW TAB
  // ============================================================================

  Widget _buildOverviewTab(Color cardColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('What is Web Management?'),
          const SizedBox(height: 12),
          const Text(
            'Web Management allows you to centrally manage information for all your WordPress websites. '
            'Instead of manually updating phone numbers, addresses, and social media links on every page '
            'of every website, you configure them once here and your websites pull the data automatically.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('How It Works'),
          const SizedBox(height: 12),
          _buildStepCard(
            cardColor: cardColor,
            step: '1',
            title: 'Configure Variables',
            description: 'Fill in your business information, contact details, and social media links for each WordPress site in this app.',
            icon: Icons.edit_note,
          ),
          const SizedBox(height: 12),
          _buildStepCard(
            cardColor: cardColor,
            step: '2',
            title: 'Install Plugin',
            description: 'Install the "A1 Tools Connector" plugin on your WordPress sites. This connects your site to the A1 Tools platform.',
            icon: Icons.extension,
          ),
          const SizedBox(height: 12),
          _buildStepCard(
            cardColor: cardColor,
            step: '3',
            title: 'Use Shortcodes',
            description: 'Add shortcodes to your pages, headers, footers, or Elementor widgets. The plugin replaces them with your configured values.',
            icon: Icons.code,
          ),
          const SizedBox(height: 12),
          _buildStepCard(
            cardColor: cardColor,
            step: '4',
            title: 'Update Anywhere',
            description: 'When you need to change a phone number or address, update it once in this app. All your websites update automatically!',
            icon: Icons.sync,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('Benefits'),
          const SizedBox(height: 12),
          _buildBenefitRow(Icons.timer, 'Save Time', 'Update once, reflect everywhere'),
          _buildBenefitRow(Icons.check_circle, 'Consistency', 'Same info across all sites'),
          _buildBenefitRow(Icons.error_outline, 'Reduce Errors', 'No more typos on individual pages'),
          _buildBenefitRow(Icons.speed, 'Quick Changes', 'New phone number? 30 seconds to update all sites'),
        ],
      ),
    );
  }

  // ============================================================================
  // SHORTCODES TAB
  // ============================================================================

  Widget _buildShortcodesTab(Color cardColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Basic Variable Shortcode'),
          const SizedBox(height: 8),
          const Text(
            'Use [a1tools_var] to display any variable on your website:',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          _buildCodeBlock(cardColor, '''[a1tools_var key="phone_primary"]
[a1tools_var key="business_name"]
[a1tools_var key="email_primary"]'''),
          const SizedBox(height: 24),

          _buildSectionTitle('Available Variable Keys'),
          const SizedBox(height: 12),
          _buildVariableTable(cardColor),
          const SizedBox(height: 24),

          _buildSectionTitle('Link Shortcode'),
          const SizedBox(height: 8),
          const Text(
            'For social media URLs, use the link attribute to create clickable links:',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          _buildCodeBlock(cardColor, '''[a1tools_var key="facebook_url" link="true" target="_blank"]'''),
          const SizedBox(height: 24),

          _buildSectionTitle('Address Shortcodes'),
          const SizedBox(height: 8),
          const Text(
            'Display formatted addresses with address shortcodes:',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          _buildCodeBlock(cardColor, '''// Full address in single line (e.g., "123 Main St, Suite 101, Miami, FL 30001")
[a1tools_full_address]

// Full address (multi-line with <br> tags)
[a1tools_address format="full"]

// Street only
[a1tools_address format="street"]

// City, State ZIP
[a1tools_address format="city_state_zip"]'''),
          const SizedBox(height: 24),

          _buildSectionTitle('Operating Hours Shortcode'),
          const SizedBox(height: 8),
          const Text(
            'Display your business hours as a table or list:',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          _buildCodeBlock(cardColor, '''// As a table
[a1tools_hours format="table"]

// As a list
[a1tools_hours format="list" class="my-hours"]'''),
          const SizedBox(height: 24),

          _buildSectionTitle('Social Media Links Shortcode'),
          const SizedBox(height: 8),
          const Text(
            'Display all your social media icons at once:',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          _buildCodeBlock(cardColor, '''[a1tools_social_links class="social-icons"]'''),
          const SizedBox(height: 8),
          Text(
            'Note: This requires Font Awesome icons. The shortcode outputs icon elements for each configured social platform (Facebook, Instagram, YouTube, Twitter, LinkedIn, TikTok, Yelp, Google Business, Pinterest, BBB, Nextdoor, Houzz, Angi, Thumbtack).',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('Geo-Targeting Shortcodes'),
          const SizedBox(height: 8),
          const Text(
            'Display city and state names for location-based content:',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          _buildCodeBlock(cardColor, '''// Display city name
[a1tools_city_name]

// Display state name
[a1tools_state]'''),
          const SizedBox(height: 24),

          _buildSectionTitle('Google Maps Shortcode'),
          const SizedBox(height: 8),
          const Text(
            'Display your location as a link or embedded map:',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          _buildCodeBlock(cardColor, '''// As a clickable link
[a1tools_google_map type="link"]

// As an embedded map
[a1tools_google_map type="embed" width="100%" height="400"]'''),
        ],
      ),
    );
  }

  // ============================================================================
  // ELEMENTOR TAB
  // ============================================================================

  Widget _buildElementorTab(Color cardColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Using with Elementor'),
          const SizedBox(height: 12),
          const Text(
            'If you use Elementor page builder, you have two options for displaying site variables:',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('Option 1: Dynamic Tags (Recommended)'),
          const SizedBox(height: 12),
          _buildStepCard(
            cardColor: cardColor,
            step: '1',
            title: 'Edit Any Text Field',
            description: 'Click on any text widget in Elementor (heading, text editor, button text, etc.)',
            icon: Icons.text_fields,
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            cardColor: cardColor,
            step: '2',
            title: 'Click Dynamic Tags Icon',
            description: 'Look for the small database/stack icon next to the text field',
            icon: Icons.dynamic_feed,
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            cardColor: cardColor,
            step: '3',
            title: 'Select A1 Tools > Site Variable',
            description: 'Find the A1 Tools group and select "Site Variable"',
            icon: Icons.widgets,
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            cardColor: cardColor,
            step: '4',
            title: 'Choose Your Variable',
            description: 'Select the variable you want to display from the dropdown',
            icon: Icons.check_circle,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('Option 2: Shortcode Widget'),
          const SizedBox(height: 12),
          const Text(
            'Alternatively, you can use the Elementor Shortcode widget:',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          _buildStepCard(
            cardColor: cardColor,
            step: '1',
            title: 'Add Shortcode Widget',
            description: 'Drag the "Shortcode" widget from the Elementor panel to your page',
            icon: Icons.code,
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            cardColor: cardColor,
            step: '2',
            title: 'Enter Shortcode',
            description: 'Paste your shortcode, e.g., [a1tools_var key="phone_primary"]',
            icon: Icons.paste,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('Where to Use Variables'),
          const SizedBox(height: 12),
          _buildUsageExample(cardColor, 'Header', 'Phone number, email in the top bar'),
          _buildUsageExample(cardColor, 'Footer', 'Address, social media links, hours'),
          _buildUsageExample(cardColor, 'Contact Page', 'All contact details'),
          _buildUsageExample(cardColor, 'About Page', 'Business name, tagline'),
          _buildUsageExample(cardColor, 'Sidebar', 'Phone number, quick links'),
        ],
      ),
    );
  }

  // ============================================================================
  // SETUP TAB
  // ============================================================================

  Widget _buildSetupTab(Color cardColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('WordPress Plugin Installation'),
          const SizedBox(height: 12),
          _buildStepCard(
            cardColor: cardColor,
            step: '1',
            title: 'Download the Plugin',
            description: 'Get the "A1 Tools Connector" plugin from your A1 Tools installation at:\nplugins/a1-tools-connector/',
            icon: Icons.download,
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            cardColor: cardColor,
            step: '2',
            title: 'Upload to WordPress',
            description: 'Go to WordPress Admin > Plugins > Add New > Upload Plugin\nOr upload via FTP to /wp-content/plugins/',
            icon: Icons.upload_file,
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            cardColor: cardColor,
            step: '3',
            title: 'Activate the Plugin',
            description: 'Find "A1 Tools Connector" in your plugins list and click Activate',
            icon: Icons.power_settings_new,
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            cardColor: cardColor,
            step: '4',
            title: 'Verify Connection',
            description: 'The plugin automatically connects using your site URL. Check for any admin notices.',
            icon: Icons.check_circle,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('Registering Your Site'),
          const SizedBox(height: 12),
          const Text(
            'Before using variables, your WordPress site must be registered in A1 Tools:',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          _buildStepCard(
            cardColor: cardColor,
            step: '1',
            title: 'Go to Integrations',
            description: 'In A1 Tools, navigate to Management > Integrations > Blog Site Credentials',
            icon: Icons.settings,
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            cardColor: cardColor,
            step: '2',
            title: 'Add Your Site',
            description: 'Click "Add Site" and enter your WordPress URL, username, and application password',
            icon: Icons.add_circle,
          ),
          const SizedBox(height: 8),
          _buildStepCard(
            cardColor: cardColor,
            step: '3',
            title: 'Test Connection',
            description: 'Use the test button to verify the connection is working',
            icon: Icons.wifi_tethering,
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('Caching'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('About Caching', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'The plugin caches variables for 5 minutes by default to improve performance. '
                  'You can configure the cache duration in the WordPress admin under A1 Tools settings.\n\n'
                  'To force an immediate refresh:\n'
                  '• Go to A1 Tools in WordPress admin\n'
                  '• Click "Clear Cache Now" button\n'
                  '• Or set cache duration to "No caching" for real-time updates',
                  style: TextStyle(height: 1.5, color: Colors.blue.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('Troubleshooting'),
          const SizedBox(height: 12),
          _buildTroubleshootingItem(
            cardColor,
            'Variables not showing',
            'Make sure your site URL in A1 Tools matches exactly (including https:// and no trailing slash)',
          ),
          _buildTroubleshootingItem(
            cardColor,
            'Plugin shows warning',
            'Verify the site is registered in A1 Tools Integrations and has variables configured',
          ),
          _buildTroubleshootingItem(
            cardColor,
            'Changes not appearing',
            'Go to A1 Tools in WordPress admin and click "Clear Cache Now", or wait for the cache to expire (default 5 minutes)',
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPER WIDGETS
  // ============================================================================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: _accent,
      ),
    );
  }

  Widget _buildStepCard({
    required Color cardColor,
    required String step,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: _accent),
                    const SizedBox(width: 6),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(Color cardColor, String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              tooltip: 'Copy',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariableTable(Color cardColor) {
    final variables = [
      ['business_name', 'Business/company name'],
      ['location_name', 'Location identifier'],
      ['tagline', 'Business tagline/slogan'],
      ['phone_primary', 'Primary phone number'],
      ['phone_secondary', 'Secondary phone'],
      ['email_primary', 'Primary email'],
      ['email_secondary', 'Secondary email'],
      ['address_line1', 'Street address line 1'],
      ['address_line2', 'Street address line 2'],
      ['city', 'City'],
      ['state', 'State/Province'],
      ['zip', 'ZIP/Postal code'],
      ['country', 'Country'],
      ['city_name', 'City name (for geo-targeting)'],
      ['location_name', 'State name (for geo-targeting)'],
      ['google_maps_url', 'Google Maps location URL'],
      ['facebook_url', 'Facebook page URL'],
      ['instagram_url', 'Instagram URL'],
      ['youtube_url', 'YouTube channel URL'],
      ['twitter_url', 'Twitter/X URL'],
      ['linkedin_url', 'LinkedIn URL'],
      ['tiktok_url', 'TikTok URL'],
      ['yelp_url', 'Yelp URL'],
      ['google_business_url', 'Google Business URL'],
      ['pinterest_url', 'Pinterest URL'],
      ['bbb_url', 'Better Business Bureau URL'],
      ['nextdoor_url', 'Nextdoor URL'],
      ['houzz_url', 'Houzz URL'],
      ['angi_url', 'Angi URL'],
      ['thumbtack_url', 'Thumbtack URL'],
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Key', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: variables.length,
              itemBuilder: (context, index) {
                final v = variables[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: SelectableText(
                          v[0],
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: _accent,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(v[1], style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageExample(Color cardColor, String location, String example) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              location,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(example, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingItem(Color cardColor, String problem, String solution) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(problem, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            solution,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
          ),
        ],
      ),
    );
  }
}
