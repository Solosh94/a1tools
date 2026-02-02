=== A1 Tools ===
Contributors: a1tools
Tags: site variables, contact info, business information, multi-site, shortcodes
Requires at least: 5.0
Tested up to: 6.9
Stable tag: 1.3.1
Requires PHP: 7.4
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Centrally manage contact information, social media links, and business details across your WordPress sites from the A1 Tools platform.

== Description ==

A1 Tools connects your WordPress site to the A1 Tools platform, enabling centralized management of business information that can be displayed anywhere on your site using simple shortcodes.

**Perfect for businesses with multiple websites** - update your phone number, address, or social media links once in the A1 Tools dashboard, and all your connected sites update automatically.

= Features =

* **Centralized Management** - Manage all your site variables from one dashboard
* **Simple Shortcodes** - Display any variable with `[a1tools_var key="phone_primary"]`
* **Address Formatting** - Multiple address display formats available
* **Operating Hours** - Display business hours as tables or lists
* **Social Media Links** - Output all social icons with one shortcode or widget
* **Social Icons Widget** - Customizable widget with style, shape, size, and hover effects
* **Elementor Support** - Dynamic tags for Elementor page builder
* **Performance Optimized** - Configurable caching (default 5 minutes)
* **Developer Friendly** - PHP functions available for theme developers

= Available Variables =

* Business name, city name, state/location name, tagline
* Google Maps URL for location
* Primary and secondary phone numbers
* Primary and secondary email addresses
* Full address (line 1, line 2, city, state, ZIP, country)
* Social media URLs (Facebook, Instagram, YouTube, Twitter, LinkedIn, TikTok, Yelp, Google Business)
* Operating hours for each day of the week

= Shortcode Examples =

`[a1tools_var key="phone_primary"]` - Display primary phone number

`[a1tools_var key="facebook_url" link="true"]` - Display Facebook URL as clickable link

`[a1tools_address format="full"]` - Display complete formatted address (multi-line)

`[a1tools_full_address]` - Display full address in a single line (e.g., "123 Main St, Suite 101, Miami, FL 30001")

`[a1tools_hours format="table"]` - Display operating hours as a table

`[a1tools_social_links]` - Display all configured social media icons

`[a1tools_social_links style="default" shape="circle" size="50"]` - Styled social icons

`[a1tools_city_name]` - Display the city name for geo-targeting

`[a1tools_state]` - Display the state name for geo-targeting

`[a1tools_google_map type="link"]` - Display Google Maps link

`[a1tools_google_map type="embed" width="100%" height="400"]` - Embed Google Maps iframe

= Requirements =

* Your WordPress site must be registered in the A1 Tools platform
* An active A1 Tools account with site variables configured
* Font Awesome 6 for social icons (most themes include this; if not, use a Font Awesome plugin)

== External Services ==

This plugin relies on a third-party service to retrieve site variables (business information, contact details, social media URLs, etc.) that you configure in the A1 Tools dashboard.

= A1 Tools API =

**What it is:** A1 Tools is a business management platform operated by A1 Chimney Service that allows businesses to centrally manage their contact information, addresses, operating hours, and social media links across multiple websites.

**What data is sent:** When this plugin is activated and the site loads (or when a shortcode is used), the plugin sends your WordPress site URL to the A1 Tools API to retrieve the site variables you have configured for that specific site.

**When data is sent:**
- When a page containing A1 Tools shortcodes is loaded
- When the plugin's admin settings page is accessed
- When the cache expires and fresh data is needed (configurable, default 5 minutes)

**What data is received:** The plugin receives only the site variables you have configured in your A1 Tools dashboard, such as business name, phone numbers, email addresses, physical address, operating hours, and social media URLs.

**Service Provider:** A1 Chimney Service
**API Endpoint:** https://tools.a-1chimney.com/api/website_variables.php
**Terms of Service:** https://a-1chimney.com/terms-of-service/
**Privacy Policy:** https://a-1chimney.com/privacy-policy/

== Installation ==

1. Upload the `a1-tools` folder to the `/wp-content/plugins/` directory
2. Activate the plugin through the 'Plugins' menu in WordPress
3. Ensure your site is registered in your A1 Tools dashboard under Integrations > WordPress Sites
4. Configure your site variables in A1 Tools under Marketing Tools > Web Management > Site Variables
5. Use the shortcodes in your pages, posts, or widgets

== Frequently Asked Questions ==

= How do I get an A1 Tools account? =

A1 Tools is a business management platform. Contact A1 Chimney Service for access information.

= Why are my variables not showing? =

1. Verify your site URL in A1 Tools matches your WordPress site URL exactly (including https://)
2. Check that you have saved variables for this site in A1 Tools
3. Go to A1 Tools in your admin menu and click "Clear Cache Now" to fetch fresh data

= How often do variables update? =

Variables are cached based on your settings (default 5 minutes). You can configure the cache duration or disable caching entirely in the A1 Tools settings page. To force an immediate update, use the "Clear Cache Now" button on the settings page.

= Can I use this with Elementor? =

Yes! The plugin registers dynamic tags that appear under the "A1 Tools" group in Elementor. You can also use the Shortcode widget with any of the available shortcodes.

= Is this plugin free? =

The plugin is free and open source. However, it requires an A1 Tools account to function, as it retrieves data from the A1 Tools platform.

= What data does this plugin send to external services? =

See the "External Services" section above for complete details. In summary, the plugin sends your site URL to the A1 Tools API to retrieve the site variables you have configured. No personal user data from your visitors is collected or transmitted.

== Screenshots ==

1. Site Variables management in A1 Tools dashboard
2. Using shortcodes in the WordPress editor
3. Elementor dynamic tags integration

== Changelog ==

= 1.3.1 =
* Fixed output escaping issues in Social Icons Widget for WordPress.org compliance
* Removed external CDN dependency for Font Awesome (now requires theme or plugin to provide)
* Added PHPCS ignore comments for legitimate unescaped outputs
* Fixed non-prefixed hook warning for Yoast SEO integration

= 1.3.0 =
* Updated all function, class, and constant prefixes to use `a1tools_` (4+ characters) for WordPress.org compliance
* Added External Services documentation for third-party API usage disclosure
* Updated all shortcode names to use `a1tools_` prefix (e.g., `[a1tools_var]`, `[a1tools_address]`)
* Fixed uninstall.php to properly clean up all plugin options and transients
* Added missing variables to Elementor dynamic tags
* Improved Font Awesome loading to prevent duplicate enqueuing

= 1.2.0 =
* Added Social Icons Widget with full styling customization
* Widget options: Style (Official Colors, Outline, Minimal, Light, Dark)
* Widget options: Shape (Rounded, Circle, Square)
* Widget options: Size, Icon Size, Spacing, Alignment
* Widget options: Hover Effects (Scale, Lift, Rotate, Pulse)
* Widget options: Custom Color override
* Enhanced social links shortcode with styling parameters
* Automatic Font Awesome 6 loading for social icons
* Added full address shortcode for single-line address display
* Added A1 Social Icons Elementor widget

= 1.1.0 =
* Added 6 new social media platforms: Pinterest, BBB, Nextdoor, Houzz, Angi, Thumbtack
* Settings page now shows all available fields with their shortcodes
* Updated social links shortcode to include all platforms

= 1.0.9 =
* Added admin settings page under A1 Tools menu
* Configurable cache duration (No caching, 1 min, 5 min, 10 min, 30 min, 1 hour, 24 hours)
* Manual "Clear Cache Now" button for instant updates
* Connection status display showing current values from A1 Tools
* Changed default cache from 1 hour to 5 minutes

= 1.0.8 =
* Added new geo-targeting fields: City Name and State
* Added Google Maps URL field for location linking/embedding
* New shortcodes: city name, state, google map
* Google Maps shortcode supports both link and embed modes

= 1.0.0 =
* Initial release
* Site variables shortcodes
* Elementor dynamic tags integration
* REST API endpoints for variable retrieval
* Caching for performance
* Yoast SEO meta field integration via REST API

== Upgrade Notice ==

= 1.3.1 =
Fixed Plugin Check errors. Font Awesome is no longer auto-loaded - ensure your theme includes it or install a Font Awesome plugin.

= 1.3.0 =
**Important:** All shortcode names have changed from `[a1_*]` to `[a1tools_*]`. Please update your shortcodes after upgrading. Example: `[a1_var]` is now `[a1tools_var]`.

= 1.2.0 =
New Social Icons Widget with full styling customization. Enhanced shortcode with style, shape, size, and hover effect options.

= 1.1.0 =
Added 6 new social media platforms: Pinterest, BBB, Nextdoor, Houzz, Angi, Thumbtack.

= 1.0.9 =
Added settings page with configurable cache duration and manual cache clear button. Default cache reduced to 5 minutes.

= 1.0.8 =
Added city name, state, and Google Maps location fields with new shortcodes.

= 1.0.0 =
Initial release of A1 Tools plugin.
