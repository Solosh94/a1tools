<?php
/**
 * Plugin Name:       A1 Tools
 * Plugin URI:        https://tools.a-1chimney.com
 * Description:       Connects your WordPress site to the A1 Tools platform for centralized management of contact information, social media links, and business details.
 * Version:           1.3.1
 * Requires at least: 5.0
 * Requires PHP:      7.4
 * Author:            A1 Chimney
 * Author URI:        https://a-1chimney.com
 * Text Domain:       a1-tools
 * License:           GPLv2 or later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 */

// Prevent direct file access.
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

// Plugin constants.
define( 'A1TOOLS_VERSION', '1.3.1' );
define( 'A1TOOLS_PLUGIN_DIR', plugin_dir_path( __FILE__ ) );
define( 'A1TOOLS_PLUGIN_URL', plugin_dir_url( __FILE__ ) );
define( 'A1TOOLS_DEFAULT_API_URL', 'https://tools.a-1chimney.com/api/website_variables.php' );
define( 'A1TOOLS_CACHE_KEY', 'a1tools_site_variables' );
define( 'A1TOOLS_DEFAULT_CACHE_EXPIRY', 300 ); // 5 minutes default

/**
 * Get site variables from API or cache.
 *
 * @since 1.0.0
 * @param bool $force_refresh Force a fresh API call.
 * @return array|null Variables array or null on error.
 */
function a1tools_get_site_variables( $force_refresh = false ) {
	// Check cache first.
	if ( ! $force_refresh ) {
		$cached = get_transient( A1TOOLS_CACHE_KEY );
		if ( false !== $cached ) {
			return $cached;
		}
	}

	// Fetch from API.
	$site_url = site_url();

	/**
	 * Filter the A1 Tools API URL.
	 *
	 * Allows developers to override the API endpoint for development or staging environments.
	 *
	 * @since 1.0.0
	 * @param string $api_url The API base URL.
	 */
	$api_base_url = apply_filters( 'a1tools_api_url', A1TOOLS_DEFAULT_API_URL );

	$api_url = add_query_arg(
		array(
			'action' => 'public',
			'url'    => $site_url,
		),
		$api_base_url
	);

	$response = wp_remote_get(
		$api_url,
		array(
			'timeout'   => 10,
			'sslverify' => true,
		)
	);

	if ( is_wp_error( $response ) ) {
		return null;
	}

	$body = wp_remote_retrieve_body( $response );
	$data = json_decode( $body, true );

	if ( ! isset( $data['success'] ) || true !== $data['success'] ) {
		return null;
	}

	$variables = isset( $data['variables'] ) ? $data['variables'] : array();

	// Cache the result.
	$cache_expiry = (int) get_option( 'a1tools_cache_expiry', A1TOOLS_DEFAULT_CACHE_EXPIRY );
	if ( $cache_expiry > 0 ) {
		set_transient( A1TOOLS_CACHE_KEY, $variables, $cache_expiry );
	}

	return $variables;
}

/**
 * Get a single site variable.
 *
 * @since 1.0.0
 * @param string $key     Variable key (e.g., 'phone_primary', 'facebook_url').
 * @param string $default Default value if not found.
 * @return string Variable value.
 */
function a1tools_get_variable( $key, $default = '' ) {
	$variables = a1tools_get_site_variables();

	if ( null === $variables || ! isset( $variables[ $key ] ) ) {
		return $default;
	}

	return $variables[ $key ];
}

/**
 * Clear the site variables cache.
 *
 * @since 1.0.0
 * @return void
 */
function a1tools_clear_cache() {
	delete_transient( A1TOOLS_CACHE_KEY );
}

// ============================================================================
// SHORTCODES
// ============================================================================

/**
 * Shortcode: [a1tools_var key="phone_primary"]
 * Outputs a site variable value.
 *
 * @since 1.0.0
 * @param array $atts Shortcode attributes.
 * @return string Shortcode output.
 */
function a1tools_shortcode_var( $atts ) {
	$atts = shortcode_atts(
		array(
			'key'     => '',
			'link'    => 'false',
			'target'  => '_blank',
			'class'   => '',
			'default' => '',
		),
		$atts,
		'a1tools_var'
	);

	if ( empty( $atts['key'] ) ) {
		return '';
	}

	$value = a1tools_get_variable( $atts['key'], $atts['default'] );

	if ( empty( $value ) ) {
		return esc_html( $atts['default'] );
	}

	// Wrap in link if requested and value is a URL.
	if ( 'true' === $atts['link'] && filter_var( $value, FILTER_VALIDATE_URL ) ) {
		$class_attr = ! empty( $atts['class'] ) ? ' class="' . esc_attr( $atts['class'] ) . '"' : '';
		$rel_attr   = '_blank' === $atts['target'] ? ' rel="noopener noreferrer"' : '';
		return '<a href="' . esc_url( $value ) . '" target="' . esc_attr( $atts['target'] ) . '"' . $rel_attr . $class_attr . '>' . esc_html( $value ) . '</a>';
	}

	// Wrap in span if class provided.
	if ( ! empty( $atts['class'] ) ) {
		return '<span class="' . esc_attr( $atts['class'] ) . '">' . esc_html( $value ) . '</span>';
	}

	return esc_html( $value );
}
add_shortcode( 'a1tools_var', 'a1tools_shortcode_var' );

/**
 * Shortcode: [a1tools_address format="full"]
 * Outputs formatted address.
 *
 * @since 1.0.0
 * @param array $atts Shortcode attributes.
 * @return string Shortcode output.
 */
function a1tools_shortcode_address( $atts ) {
	$atts = shortcode_atts(
		array(
			'format'    => 'full',
			'separator' => '<br>',
		),
		$atts,
		'a1tools_address'
	);

	$vars = a1tools_get_site_variables();
	if ( ! $vars ) {
		return '';
	}

	$parts = array();

	switch ( $atts['format'] ) {
		case 'street':
			$parts = array_filter(
				array(
					isset( $vars['address_line1'] ) ? $vars['address_line1'] : '',
					isset( $vars['address_line2'] ) ? $vars['address_line2'] : '',
				)
			);
			break;

		case 'city_state_zip':
			$city_state = array_filter(
				array(
					isset( $vars['city'] ) ? $vars['city'] : '',
					isset( $vars['state'] ) ? $vars['state'] : '',
				)
			);
			$zip        = isset( $vars['zip'] ) ? $vars['zip'] : '';
			$parts      = array( implode( ', ', $city_state ) . ' ' . $zip );
			break;

		case 'full':
		default:
			$city        = isset( $vars['city'] ) ? $vars['city'] : '';
			$state       = isset( $vars['state'] ) ? $vars['state'] : '';
			$zip         = isset( $vars['zip'] ) ? $vars['zip'] : '';
			$state_zip   = trim( $state . ' ' . $zip );
			$city_line   = $city ? $city . ( $state_zip ? ', ' . $state_zip : '' ) : $state_zip;

			$parts = array_filter(
				array(
					isset( $vars['address_line1'] ) ? $vars['address_line1'] : '',
					isset( $vars['address_line2'] ) ? $vars['address_line2'] : '',
					$city_line,
					isset( $vars['country'] ) ? $vars['country'] : '',
				)
			);
			break;
	}

	// Handle separator - allow <br> for HTML output, otherwise escape.
	$separator = $atts['separator'];
	if ( '<br>' === $separator || '<br/>' === $separator || '<br />' === $separator ) {
		return implode( '<br>', array_map( 'esc_html', $parts ) );
	}

	return esc_html( implode( $separator, $parts ) );
}
add_shortcode( 'a1tools_address', 'a1tools_shortcode_address' );

/**
 * Shortcode: [a1tools_full_address]
 * Outputs the complete address in a single line.
 *
 * @since 1.2.0
 * @param array $atts Shortcode attributes.
 * @return string Shortcode output.
 */
function a1tools_shortcode_full_address( $atts ) {
	$atts = shortcode_atts(
		array(
			'separator' => ', ',
			'class'     => '',
		),
		$atts,
		'a1tools_full_address'
	);

	$vars = a1tools_get_site_variables();
	if ( ! $vars ) {
		return '';
	}

	$parts = array();

	// Address Line 1.
	if ( ! empty( $vars['address_line1'] ) ) {
		$parts[] = $vars['address_line1'];
	}

	// Address Line 2.
	if ( ! empty( $vars['address_line2'] ) ) {
		$parts[] = $vars['address_line2'];
	}

	// City.
	if ( ! empty( $vars['city'] ) ) {
		$parts[] = $vars['city'];
	}

	// State + ZIP (combined).
	$state = ! empty( $vars['state'] ) ? $vars['state'] : '';
	$zip   = ! empty( $vars['zip'] ) ? $vars['zip'] : '';
	if ( $state || $zip ) {
		$parts[] = trim( $state . ' ' . $zip );
	}

	if ( empty( $parts ) ) {
		return '';
	}

	$output = esc_html( implode( $atts['separator'], $parts ) );

	if ( ! empty( $atts['class'] ) ) {
		$output = '<span class="' . esc_attr( $atts['class'] ) . '">' . $output . '</span>';
	}

	return $output;
}
add_shortcode( 'a1tools_full_address', 'a1tools_shortcode_full_address' );

/**
 * Shortcode: [a1tools_hours]
 * Outputs formatted operating hours table.
 *
 * @since 1.0.0
 * @param array $atts Shortcode attributes.
 * @return string Shortcode output.
 */
function a1tools_shortcode_hours( $atts ) {
	$atts = shortcode_atts(
		array(
			'format' => 'table',
			'class'  => 'a1tools-hours',
		),
		$atts,
		'a1tools_hours'
	);

	$vars = a1tools_get_site_variables();
	if ( ! $vars || empty( $vars['operating_hours'] ) ) {
		return '';
	}

	$hours = $vars['operating_hours'];
	$days  = array(
		'mon' => __( 'Monday', 'a1-tools' ),
		'tue' => __( 'Tuesday', 'a1-tools' ),
		'wed' => __( 'Wednesday', 'a1-tools' ),
		'thu' => __( 'Thursday', 'a1-tools' ),
		'fri' => __( 'Friday', 'a1-tools' ),
		'sat' => __( 'Saturday', 'a1-tools' ),
		'sun' => __( 'Sunday', 'a1-tools' ),
	);

	$output = '';

	if ( 'list' === $atts['format'] ) {
		$output = '<ul class="' . esc_attr( $atts['class'] ) . '">';
		foreach ( $days as $key => $label ) {
			$time    = isset( $hours[ $key ] ) && ! empty( $hours[ $key ] ) ? esc_html( $hours[ $key ] ) : esc_html__( 'Closed', 'a1-tools' );
			$output .= '<li><strong>' . esc_html( $label ) . ':</strong> ' . $time . '</li>';
		}
		$output .= '</ul>';
	} else {
		$output = '<table class="' . esc_attr( $atts['class'] ) . '">';
		foreach ( $days as $key => $label ) {
			$time    = isset( $hours[ $key ] ) && ! empty( $hours[ $key ] ) ? esc_html( $hours[ $key ] ) : esc_html__( 'Closed', 'a1-tools' );
			$output .= '<tr><td>' . esc_html( $label ) . '</td><td>' . $time . '</td></tr>';
		}
		$output .= '</table>';
	}

	return $output;
}
add_shortcode( 'a1tools_hours', 'a1tools_shortcode_hours' );

/**
 * Shortcode: [a1tools_social_links]
 * Outputs social media icons/links with optional styling.
 *
 * @since 1.0.0
 * @since 1.2.0 Added styling parameters.
 * @param array $atts Shortcode attributes.
 * @return string Shortcode output.
 */
function a1tools_shortcode_social_links( $atts ) {
	$atts = shortcode_atts(
		array(
			'class'        => 'a1tools-social-links',
			'icon_class'   => '',
			'style'        => '',          // default, outline, minimal, light, dark
			'shape'        => 'rounded',   // rounded, circle, square
			'size'         => '40',        // button size in px
			'icon_size'    => '18',        // icon size in px
			'spacing'      => '8',         // spacing between icons in px
			'alignment'    => 'left',      // left, center, right
			'color'        => '',          // custom color (hex)
			'hover'        => 'scale',     // scale, lift, rotate, pulse, none
		),
		$atts,
		'a1tools_social_links'
	);

	$vars = a1tools_get_site_variables();
	if ( ! $vars ) {
		return '';
	}

	$platforms = array(
		'facebook_url'        => array( 'label' => 'Facebook', 'icon' => 'fab fa-facebook-f', 'color' => '#1877F2' ),
		'instagram_url'       => array( 'label' => 'Instagram', 'icon' => 'fab fa-instagram', 'color' => '#E4405F' ),
		'youtube_url'         => array( 'label' => 'YouTube', 'icon' => 'fab fa-youtube', 'color' => '#FF0000' ),
		'twitter_url'         => array( 'label' => 'Twitter', 'icon' => 'fab fa-x-twitter', 'color' => '#000000' ),
		'linkedin_url'        => array( 'label' => 'LinkedIn', 'icon' => 'fab fa-linkedin-in', 'color' => '#0A66C2' ),
		'tiktok_url'          => array( 'label' => 'TikTok', 'icon' => 'fab fa-tiktok', 'color' => '#000000' ),
		'yelp_url'            => array( 'label' => 'Yelp', 'icon' => 'fab fa-yelp', 'color' => '#D32323' ),
		'google_business_url' => array( 'label' => 'Google', 'icon' => 'fab fa-google', 'color' => '#4285F4' ),
		'pinterest_url'       => array( 'label' => 'Pinterest', 'icon' => 'fab fa-pinterest-p', 'color' => '#E60023' ),
		'bbb_url'             => array( 'label' => 'BBB', 'icon' => 'fas fa-shield-alt', 'color' => '#006CB7' ),
		'nextdoor_url'        => array( 'label' => 'Nextdoor', 'icon' => 'fas fa-home', 'color' => '#8ED500' ),
		'houzz_url'           => array( 'label' => 'Houzz', 'icon' => 'fab fa-houzz', 'color' => '#4DBC15' ),
		'angi_url'            => array( 'label' => 'Angi', 'icon' => 'fas fa-tools', 'color' => '#FF6153' ),
		'thumbtack_url'       => array( 'label' => 'Thumbtack', 'icon' => 'fas fa-thumbtack', 'color' => '#009FD9' ),
	);

	// If no style is set, use simple output (backwards compatible).
	if ( empty( $atts['style'] ) ) {
		$output = '<div class="' . esc_attr( $atts['class'] ) . '">';

		foreach ( $platforms as $key => $data ) {
			if ( ! empty( $vars[ $key ] ) ) {
				$icon_class = ! empty( $atts['icon_class'] ) ? $atts['icon_class'] : $data['icon'];
				$output    .= '<a href="' . esc_url( $vars[ $key ] ) . '" target="_blank" rel="noopener noreferrer" title="' . esc_attr( $data['label'] ) . '">';
				$output    .= '<i class="' . esc_attr( $icon_class ) . '" aria-hidden="true"></i>';
				$output    .= '<span class="screen-reader-text">' . esc_html( $data['label'] ) . '</span>';
				$output    .= '</a>';
			}
		}

		$output .= '</div>';
		return $output;
	}

	// Styled output.
	$style        = $atts['style'];
	$shape        = $atts['shape'];
	$size         = (int) $atts['size'];
	$icon_size    = (int) $atts['icon_size'];
	$spacing      = (int) $atts['spacing'];
	$alignment    = $atts['alignment'];
	$custom_color = $atts['color'];
	$hover_effect = $atts['hover'];

	// Generate unique ID.
	static $instance_count = 0;
	$instance_count++;
	$widget_id = 'a1tools-social-sc-' . $instance_count;

	// Border radius based on shape.
	$border_radius = '8px';
	if ( 'circle' === $shape ) {
		$border_radius = '50%';
	} elseif ( 'square' === $shape ) {
		$border_radius = '0';
	}

	// Build output with inline styles.
	$output = '<style>';
	$output .= '#' . esc_attr( $widget_id ) . ' { text-align:' . esc_attr( $alignment ) . '; }';
	$output .= '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon { ';
	$output .= 'width:' . $size . 'px;height:' . $size . 'px;';
	$output .= 'margin:0 ' . ( $spacing / 2 ) . 'px ' . $spacing . 'px;';
	$output .= 'font-size:' . $icon_size . 'px;';
	$output .= 'display:inline-flex;align-items:center;justify-content:center;';
	$output .= 'text-decoration:none;transition:all 0.3s ease;';
	$output .= 'border-radius:' . $border_radius . ';';
	$output .= '}';

	// Style-specific CSS.
	if ( 'default' === $style || 'official' === $style ) {
		$output .= '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon { color: #fff; }';
	} elseif ( 'outline' === $style ) {
		$output .= '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon { background: transparent; border: 2px solid; }';
	} elseif ( 'minimal' === $style ) {
		$output .= '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon { background: transparent; }';
	} elseif ( 'light' === $style ) {
		$output .= '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon { background: #f5f5f5; }';
	} elseif ( 'dark' === $style ) {
		$output .= '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon { background: #333; color: #fff; }';
	}

	// Hover effects.
	if ( 'scale' === $hover_effect ) {
		$output .= '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon:hover { transform: scale(1.1); }';
	} elseif ( 'lift' === $hover_effect ) {
		$output .= '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon:hover { transform: translateY(-3px); box-shadow: 0 4px 12px rgba(0,0,0,0.2); }';
	} elseif ( 'rotate' === $hover_effect ) {
		$output .= '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon:hover { transform: rotate(15deg); }';
	} elseif ( 'pulse' === $hover_effect ) {
		$output .= '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon:hover { animation: a1tools-pulse 0.5s ease; }';
		$output .= '@keyframes a1tools-pulse { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.15); } }';
	}

	$output .= '</style>';

	$output .= '<div id="' . esc_attr( $widget_id ) . '" class="' . esc_attr( $atts['class'] ) . ' a1tools-social-icons-styled">';

	foreach ( $platforms as $key => $data ) {
		if ( ! empty( $vars[ $key ] ) ) {
			$item_color = $custom_color ? $custom_color : $data['color'];

			$inline_style = '';
			if ( 'default' === $style || 'official' === $style ) {
				$inline_style = 'background-color:' . esc_attr( $item_color ) . ';';
			} elseif ( 'outline' === $style ) {
				$inline_style = 'border-color:' . esc_attr( $item_color ) . ';color:' . esc_attr( $item_color ) . ';';
			} elseif ( 'minimal' === $style || 'light' === $style ) {
				$inline_style = 'color:' . esc_attr( $item_color ) . ';';
			}

			$icon_class = ! empty( $atts['icon_class'] ) ? $atts['icon_class'] : $data['icon'];
			$output    .= '<a href="' . esc_url( $vars[ $key ] ) . '" class="a1tools-social-icon" target="_blank" rel="noopener noreferrer" title="' . esc_attr( $data['label'] ) . '" style="' . $inline_style . '">';
			$output    .= '<i class="' . esc_attr( $icon_class ) . '" aria-hidden="true"></i>';
			$output    .= '<span class="screen-reader-text">' . esc_html( $data['label'] ) . '</span>';
			$output    .= '</a>';
		}
	}

	$output .= '</div>';

	return $output;
}
add_shortcode( 'a1tools_social_links', 'a1tools_shortcode_social_links' );

/**
 * Shortcode: [a1tools_city_name]
 * Outputs the city name (for geo-targeting).
 *
 * @since 1.0.8
 * @param array $atts Shortcode attributes.
 * @return string Shortcode output.
 */
function a1tools_shortcode_city_name( $atts ) {
	$atts = shortcode_atts(
		array(
			'default' => '',
			'class'   => '',
		),
		$atts,
		'a1tools_city_name'
	);

	$value = a1tools_get_variable( 'city_name', $atts['default'] );

	if ( empty( $value ) ) {
		return esc_html( $atts['default'] );
	}

	if ( ! empty( $atts['class'] ) ) {
		return '<span class="' . esc_attr( $atts['class'] ) . '">' . esc_html( $value ) . '</span>';
	}

	return esc_html( $value );
}
add_shortcode( 'a1tools_city_name', 'a1tools_shortcode_city_name' );

/**
 * Shortcode: [a1tools_state]
 * Outputs the state/location name (for geo-targeting).
 *
 * @since 1.0.8
 * @param array $atts Shortcode attributes.
 * @return string Shortcode output.
 */
function a1tools_shortcode_state( $atts ) {
	$atts = shortcode_atts(
		array(
			'default' => '',
			'class'   => '',
		),
		$atts,
		'a1tools_state'
	);

	$value = a1tools_get_variable( 'location_name', $atts['default'] );

	if ( empty( $value ) ) {
		return esc_html( $atts['default'] );
	}

	if ( ! empty( $atts['class'] ) ) {
		return '<span class="' . esc_attr( $atts['class'] ) . '">' . esc_html( $value ) . '</span>';
	}

	return esc_html( $value );
}
add_shortcode( 'a1tools_state', 'a1tools_shortcode_state' );

/**
 * Shortcode: [a1tools_google_map]
 * Outputs a Google Maps embed or link.
 *
 * @since 1.0.8
 * @param array $atts Shortcode attributes.
 * @return string Shortcode output.
 */
function a1tools_shortcode_google_map( $atts ) {
	$atts = shortcode_atts(
		array(
			'type'   => 'link',
			'width'  => '100%',
			'height' => '400',
			'class'  => 'a1tools-google-map',
			'text'   => __( 'View on Google Maps', 'a1-tools' ),
			'target' => '_blank',
		),
		$atts,
		'a1tools_google_map'
	);

	$url = a1tools_get_variable( 'google_maps_url', '' );

	if ( empty( $url ) ) {
		return '';
	}

	// If type is 'embed', create an iframe
	if ( 'embed' === $atts['type'] ) {
		// Check if URL is already an embed URL or convert it
		$embed_url = $url;

		// If it's a regular Google Maps URL, try to convert to embed format
		if ( false !== strpos( $url, 'google.com/maps' ) && false === strpos( $url, '/embed' ) ) {
			// Extract place or coordinates and create embed URL
			if ( preg_match( '/place\/([^\/]+)/', $url, $matches ) ) {
				$place      = $matches[1];
				$embed_url = 'https://www.google.com/maps/embed/v1/place?key=&q=' . urlencode( $place );
			} elseif ( preg_match( '/@(-?\d+\.\d+),(-?\d+\.\d+)/', $url, $matches ) ) {
				$lat        = $matches[1];
				$lng        = $matches[2];
				$embed_url = 'https://maps.google.com/maps?q=' . $lat . ',' . $lng . '&output=embed';
			}
		}

		return '<iframe class="' . esc_attr( $atts['class'] ) . '" src="' . esc_url( $embed_url ) . '" width="' . esc_attr( $atts['width'] ) . '" height="' . esc_attr( $atts['height'] ) . '" style="border:0;" allowfullscreen="" loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe>';
	}

	// Default: return a link
	$rel = '_blank' === $atts['target'] ? ' rel="noopener noreferrer"' : '';
	return '<a href="' . esc_url( $url ) . '" target="' . esc_attr( $atts['target'] ) . '"' . $rel . ' class="' . esc_attr( $atts['class'] ) . '">' . esc_html( $atts['text'] ) . '</a>';
}
add_shortcode( 'a1tools_google_map', 'a1tools_shortcode_google_map' );

// ============================================================================
// REST API ENDPOINTS
// ============================================================================

/**
 * Register REST API routes.
 *
 * @since 1.0.0
 * @return void
 */
function a1tools_register_rest_routes() {
	// Get site variables (public).
	register_rest_route(
		'a1-tools/v1',
		'/site-variables',
		array(
			'methods'             => 'GET',
			'callback'            => 'a1tools_rest_get_variables',
			'permission_callback' => '__return_true',
		)
	);

	// Clear cache (requires admin).
	register_rest_route(
		'a1-tools/v1',
		'/site-variables/clear-cache',
		array(
			'methods'             => 'POST',
			'callback'            => 'a1tools_rest_clear_cache',
			'permission_callback' => function () {
				return current_user_can( 'manage_options' );
			},
		)
	);

	// Yoast meta endpoints.
	register_rest_route(
		'a1-tools/v1',
		'/yoast-meta/(?P<id>\d+)',
		array(
			'methods'             => 'POST',
			'callback'            => 'a1tools_update_yoast_meta',
			'permission_callback' => function () {
				return current_user_can( 'edit_posts' );
			},
			'args'                => array(
				'id' => array(
					'description'       => 'Post ID',
					'type'              => 'integer',
					'required'          => true,
					'validate_callback' => function ( $param ) {
						return is_numeric( $param ) && $param > 0;
					},
				),
			),
		)
	);

	register_rest_route(
		'a1-tools/v1',
		'/yoast-meta/(?P<id>\d+)',
		array(
			'methods'             => 'GET',
			'callback'            => 'a1tools_get_yoast_meta',
			'permission_callback' => function () {
				return current_user_can( 'edit_posts' );
			},
			'args'                => array(
				'id' => array(
					'description'       => 'Post ID',
					'type'              => 'integer',
					'required'          => true,
					'validate_callback' => function ( $param ) {
						return is_numeric( $param ) && $param > 0;
					},
				),
			),
		)
	);
}
add_action( 'rest_api_init', 'a1tools_register_rest_routes' );

/**
 * REST: Get site variables.
 *
 * @since 1.0.0
 * @return WP_REST_Response|WP_Error Response object.
 */
function a1tools_rest_get_variables() {
	$variables = a1tools_get_site_variables();

	if ( null === $variables ) {
		return new WP_Error( 'fetch_error', __( 'Could not fetch site variables', 'a1-tools' ), array( 'status' => 500 ) );
	}

	return new WP_REST_Response(
		array(
			'success'   => true,
			'variables' => $variables,
			'cached'    => false !== get_transient( A1TOOLS_CACHE_KEY ),
		),
		200
	);
}

/**
 * REST: Clear variables cache.
 *
 * @since 1.0.0
 * @return WP_REST_Response Response object.
 */
function a1tools_rest_clear_cache() {
	a1tools_clear_cache();

	return new WP_REST_Response(
		array(
			'success' => true,
			'message' => __( 'Cache cleared', 'a1-tools' ),
		),
		200
	);
}

// ============================================================================
// YOAST SEO INTEGRATION
// ============================================================================

/**
 * Get Yoast meta field mapping.
 *
 * @since 1.0.0
 * @return array Mapping of API keys to Yoast meta keys.
 */
function a1tools_get_yoast_meta_mapping() {
	return array(
		'title'                 => '_yoast_wpseo_title',
		'metadesc'              => '_yoast_wpseo_metadesc',
		'focuskw'               => '_yoast_wpseo_focuskw',
		'focuskeywords'         => '_yoast_wpseo_focuskeywords',
		'keywordsynonyms'       => '_yoast_wpseo_keywordsynonyms',
		'meta-robots-noindex'   => '_yoast_wpseo_meta-robots-noindex',
		'meta-robots-nofollow'  => '_yoast_wpseo_meta-robots-nofollow',
		'meta-robots-adv'       => '_yoast_wpseo_meta-robots-adv',
		'canonical'             => '_yoast_wpseo_canonical',
		'redirect'              => '_yoast_wpseo_redirect',
		'is_cornerstone'        => '_yoast_wpseo_is_cornerstone',
		'opengraph-title'       => '_yoast_wpseo_opengraph-title',
		'opengraph-description' => '_yoast_wpseo_opengraph-description',
		'opengraph-image'       => '_yoast_wpseo_opengraph-image',
		'opengraph-image-id'    => '_yoast_wpseo_opengraph-image-id',
		'twitter-title'         => '_yoast_wpseo_twitter-title',
		'twitter-description'   => '_yoast_wpseo_twitter-description',
		'twitter-image'         => '_yoast_wpseo_twitter-image',
		'twitter-image-id'      => '_yoast_wpseo_twitter-image-id',
		'schema_page_type'      => '_yoast_wpseo_schema_page_type',
		'schema_article_type'   => '_yoast_wpseo_schema_article_type',
		'linkdex'               => '_yoast_wpseo_linkdex',
		'content_score'         => '_yoast_wpseo_content_score',
		'primary_category'      => '_yoast_wpseo_primary_category',
	);
}

/**
 * Sanitize Yoast meta value based on field type.
 *
 * @since 1.0.0
 * @param string $key   Field key.
 * @param mixed  $value Value to sanitize.
 * @return mixed Sanitized value.
 */
function a1tools_sanitize_yoast_value( $key, $value ) {
	$json_fields = array( 'focuskeywords', 'keywordsynonyms' );
	if ( in_array( $key, $json_fields, true ) ) {
		if ( is_array( $value ) ) {
			return wp_json_encode( $value );
		}
		if ( is_string( $value ) ) {
			$decoded = json_decode( $value );
			if ( JSON_ERROR_NONE === json_last_error() ) {
				return $value;
			}
			return wp_json_encode( array( $value ) );
		}
		return '';
	}

	$bool_fields = array( 'is_cornerstone', 'meta-robots-noindex', 'meta-robots-nofollow' );
	if ( in_array( $key, $bool_fields, true ) ) {
		return $value ? '1' : '0';
	}

	$int_fields = array( 'linkdex', 'content_score', 'primary_category', 'opengraph-image-id', 'twitter-image-id' );
	if ( in_array( $key, $int_fields, true ) ) {
		return (int) $value;
	}

	$url_fields = array( 'canonical', 'redirect', 'opengraph-image', 'twitter-image' );
	if ( in_array( $key, $url_fields, true ) ) {
		return esc_url_raw( $value );
	}

	$text_fields = array( 'title', 'metadesc', 'opengraph-title', 'opengraph-description', 'twitter-title', 'twitter-description' );
	if ( in_array( $key, $text_fields, true ) ) {
		return sanitize_text_field( $value );
	}

	if ( is_string( $value ) ) {
		return sanitize_text_field( $value );
	}

	return $value;
}

/**
 * Update Yoast SEO meta fields for a post.
 *
 * @since 1.0.0
 * @param WP_REST_Request $request Request object.
 * @return WP_REST_Response|WP_Error Response object.
 */
function a1tools_update_yoast_meta( $request ) {
	$post_id = (int) $request['id'];

	$post = get_post( $post_id );
	if ( ! $post ) {
		return new WP_Error( 'post_not_found', __( 'Post not found', 'a1-tools' ), array( 'status' => 404 ) );
	}

	if ( ! current_user_can( 'edit_post', $post_id ) ) {
		return new WP_Error( 'forbidden', __( 'You do not have permission to edit this post', 'a1-tools' ), array( 'status' => 403 ) );
	}

	$body = $request->get_json_params();
	if ( empty( $body ) ) {
		return new WP_Error( 'no_data', __( 'No data provided', 'a1-tools' ), array( 'status' => 400 ) );
	}

	$mapping = a1tools_get_yoast_meta_mapping();
	$updated = array();
	$errors  = array();

	foreach ( $body as $key => $value ) {
		if ( isset( $mapping[ $key ] ) ) {
			$meta_key = $mapping[ $key ];
		} elseif ( 0 === strpos( $key, '_yoast_wpseo_' ) ) {
			$meta_key = $key;
		} else {
			continue;
		}

		$sanitized_value = a1tools_sanitize_yoast_value( $key, $value );
		$result          = update_post_meta( $post_id, $meta_key, $sanitized_value );

		if ( false !== $result ) {
			$updated[ $key ] = $sanitized_value;
		} else {
			$current_value = get_post_meta( $post_id, $meta_key, true );
			if ( $current_value === $sanitized_value || $current_value === (string) $sanitized_value ) {
				$updated[ $key ] = $sanitized_value;
			} else {
				$errors[ $key ] = 'Failed to update';
			}
		}
	}

	if ( class_exists( 'WPSEO_Meta' ) ) {
		// Trigger Yoast SEO's native action hook to refresh their internal cache.
		// phpcs:ignore WordPress.NamingConventions.PrefixAllGlobals.NonPrefixedHooknameFound -- This is Yoast's hook, not ours.
		do_action( 'wpseo_saved_postdata' );
	}

	return new WP_REST_Response(
		array(
			'success' => true,
			'post_id' => $post_id,
			'updated' => $updated,
			'errors'  => $errors,
		),
		200
	);
}

/**
 * Get Yoast SEO meta fields for a post.
 *
 * @since 1.0.0
 * @param WP_REST_Request $request Request object.
 * @return WP_REST_Response|WP_Error Response object.
 */
function a1tools_get_yoast_meta( $request ) {
	$post_id = (int) $request['id'];

	$post = get_post( $post_id );
	if ( ! $post ) {
		return new WP_Error( 'post_not_found', __( 'Post not found', 'a1-tools' ), array( 'status' => 404 ) );
	}

	$mapping = a1tools_get_yoast_meta_mapping();
	$meta    = array();

	foreach ( $mapping as $api_key => $meta_key ) {
		$value = get_post_meta( $post_id, $meta_key, true );
		if ( '' !== $value && false !== $value ) {
			$meta[ $api_key ] = $value;
		}
	}

	return new WP_REST_Response(
		array(
			'success' => true,
			'post_id' => $post_id,
			'meta'    => $meta,
		),
		200
	);
}

// ============================================================================
// ELEMENTOR INTEGRATION
// ============================================================================

/**
 * Register Elementor dynamic tags.
 *
 * @since 1.0.0
 * @param \Elementor\Core\DynamicTags\Manager $dynamic_tags_manager Dynamic tags manager.
 * @return void
 */
function a1tools_register_elementor_tags( $dynamic_tags_manager ) {
	// Register dynamic tag group.
	$dynamic_tags_manager->register_group(
		'a1-tools',
		array(
			'title' => __( 'A1 Tools', 'a1-tools' ),
		)
	);

	// Include and register the dynamic tag class.
	require_once A1TOOLS_PLUGIN_DIR . 'includes/class-a1-tools-elementor-tag.php';

	if ( class_exists( 'A1Tools_Elementor_Tag' ) ) {
		$dynamic_tags_manager->register( new A1Tools_Elementor_Tag() );
	}
}
add_action( 'elementor/dynamic_tags/register', 'a1tools_register_elementor_tags' );

/**
 * Register Elementor widgets.
 *
 * @since 1.2.0
 * @param \Elementor\Widgets_Manager $widgets_manager Widgets manager.
 * @return void
 */
function a1tools_register_elementor_widgets( $widgets_manager ) {
	// Include and register the Social Icons widget.
	require_once A1TOOLS_PLUGIN_DIR . 'includes/class-a1-tools-elementor-widget.php';

	if ( class_exists( 'A1Tools_Social_Icons_Elementor_Widget' ) ) {
		$widgets_manager->register( new A1Tools_Social_Icons_Elementor_Widget() );
	}
}
add_action( 'elementor/widgets/register', 'a1tools_register_elementor_widgets' );

// ============================================================================
// ADMIN NOTICES
// ============================================================================

/**
 * Display admin notice if site variables cannot be fetched.
 *
 * @since 1.0.0
 * @return void
 */
function a1tools_admin_notices() {
	// Only show on plugins page.
	$screen = get_current_screen();
	if ( ! $screen || 'plugins' !== $screen->id ) {
		return;
	}

	$variables = a1tools_get_site_variables();
	if ( null === $variables ) {
		?>
		<div class="notice notice-warning is-dismissible">
			<p>
				<strong><?php esc_html_e( 'A1 Tools:', 'a1-tools' ); ?></strong>
				<?php esc_html_e( 'Unable to fetch site variables. Make sure this site is configured in A1 Tools.', 'a1-tools' ); ?>
			</p>
		</div>
		<?php
	}
}
add_action( 'admin_notices', 'a1tools_admin_notices' );

// ============================================================================
// ADMIN SETTINGS PAGE
// ============================================================================

/**
 * Register admin menu.
 *
 * @since 1.0.9
 * @return void
 */
function a1tools_admin_menu() {
	add_menu_page(
		__( 'A1 Tools', 'a1-tools' ),
		__( 'A1 Tools', 'a1-tools' ),
		'manage_options',
		'a1-tools',
		'a1tools_settings_page',
		'dashicons-admin-tools',
		80
	);
}
add_action( 'admin_menu', 'a1tools_admin_menu' );

/**
 * Register settings.
 *
 * @since 1.0.9
 * @return void
 */
function a1tools_register_settings() {
	register_setting( 'a1tools_settings', 'a1tools_cache_expiry', array(
		'type'              => 'integer',
		'default'           => A1TOOLS_DEFAULT_CACHE_EXPIRY,
		'sanitize_callback' => 'absint',
	) );
}
add_action( 'admin_init', 'a1tools_register_settings' );

/**
 * Render settings page.
 *
 * @since 1.0.9
 * @return void
 */
function a1tools_settings_page() {
	// Handle cache clear action.
	if ( isset( $_POST['a1tools_clear_cache'] ) && check_admin_referer( 'a1tools_clear_cache_nonce' ) ) {
		a1tools_clear_cache();
		echo '<div class="notice notice-success is-dismissible"><p>' . esc_html__( 'Cache cleared successfully!', 'a1-tools' ) . '</p></div>';
	}

	$cache_expiry = (int) get_option( 'a1tools_cache_expiry', A1TOOLS_DEFAULT_CACHE_EXPIRY );
	$cached_data  = get_transient( A1TOOLS_CACHE_KEY );
	$is_cached    = false !== $cached_data;
	?>
	<div class="wrap">
		<h1><?php esc_html_e( 'A1 Tools Settings', 'a1-tools' ); ?></h1>

		<form method="post" action="options.php">
			<?php settings_fields( 'a1tools_settings' ); ?>

			<table class="form-table">
				<tr>
					<th scope="row">
						<label for="a1tools_cache_expiry"><?php esc_html_e( 'Cache Duration', 'a1-tools' ); ?></label>
					</th>
					<td>
						<select name="a1tools_cache_expiry" id="a1tools_cache_expiry">
							<option value="0" <?php selected( $cache_expiry, 0 ); ?>><?php esc_html_e( 'No caching (always fresh)', 'a1-tools' ); ?></option>
							<option value="60" <?php selected( $cache_expiry, 60 ); ?>><?php esc_html_e( '1 minute', 'a1-tools' ); ?></option>
							<option value="300" <?php selected( $cache_expiry, 300 ); ?>><?php esc_html_e( '5 minutes', 'a1-tools' ); ?></option>
							<option value="600" <?php selected( $cache_expiry, 600 ); ?>><?php esc_html_e( '10 minutes', 'a1-tools' ); ?></option>
							<option value="1800" <?php selected( $cache_expiry, 1800 ); ?>><?php esc_html_e( '30 minutes', 'a1-tools' ); ?></option>
							<option value="3600" <?php selected( $cache_expiry, 3600 ); ?>><?php esc_html_e( '1 hour', 'a1-tools' ); ?></option>
							<option value="86400" <?php selected( $cache_expiry, 86400 ); ?>><?php esc_html_e( '24 hours', 'a1-tools' ); ?></option>
						</select>
						<p class="description">
							<?php esc_html_e( 'How long to cache data from A1 Tools. Lower values mean faster updates but more API requests.', 'a1-tools' ); ?>
						</p>
					</td>
				</tr>
				<tr>
					<th scope="row"><?php esc_html_e( 'Cache Status', 'a1-tools' ); ?></th>
					<td>
						<?php if ( $is_cached ) : ?>
							<span style="color: green;"><?php esc_html_e( 'Data is cached', 'a1-tools' ); ?></span>
						<?php else : ?>
							<span style="color: orange;"><?php esc_html_e( 'No cached data', 'a1-tools' ); ?></span>
						<?php endif; ?>
					</td>
				</tr>
			</table>

			<?php submit_button( __( 'Save Settings', 'a1-tools' ) ); ?>
		</form>

		<hr>

		<h2><?php esc_html_e( 'Clear Cache', 'a1-tools' ); ?></h2>
		<p><?php esc_html_e( 'Clear the cached data to fetch fresh information from A1 Tools immediately.', 'a1-tools' ); ?></p>

		<form method="post">
			<?php wp_nonce_field( 'a1tools_clear_cache_nonce' ); ?>
			<button type="submit" name="a1tools_clear_cache" class="button button-secondary">
				<?php esc_html_e( 'Clear Cache Now', 'a1-tools' ); ?>
			</button>
		</form>

		<hr>

		<h2><?php esc_html_e( 'Connection Status', 'a1-tools' ); ?></h2>

		<style>
			.a1tools-shortcode-cell {
				display: flex;
				align-items: center;
				gap: 8px;
			}
			.a1tools-shortcode-cell code {
				font-size: 11px;
				flex: 1;
			}
			.a1tools-copy-btn {
				background: none;
				border: 1px solid #ddd;
				border-radius: 4px;
				padding: 4px 8px;
				cursor: pointer;
				display: inline-flex;
				align-items: center;
				gap: 4px;
				font-size: 12px;
				color: #666;
				transition: all 0.2s ease;
			}
			.a1tools-copy-btn:hover {
				background: #f0f0f0;
				border-color: #999;
				color: #333;
			}
			.a1tools-copy-btn.copied {
				background: #46b450;
				border-color: #46b450;
				color: #fff;
			}
			.a1tools-copy-btn .dashicons {
				font-size: 14px;
				width: 14px;
				height: 14px;
			}
		</style>

		<script>
		function a1toolsCopyShortcode(btn, shortcode) {
			navigator.clipboard.writeText(shortcode).then(function() {
				btn.classList.add('copied');
				btn.innerHTML = '<span class="dashicons dashicons-yes"></span> Copied!';
				setTimeout(function() {
					btn.classList.remove('copied');
					btn.innerHTML = '<span class="dashicons dashicons-admin-page"></span> Copy';
				}, 2000);
			}).catch(function(err) {
				// Fallback for older browsers
				var textarea = document.createElement('textarea');
				textarea.value = shortcode;
				document.body.appendChild(textarea);
				textarea.select();
				document.execCommand('copy');
				document.body.removeChild(textarea);
				btn.classList.add('copied');
				btn.innerHTML = '<span class="dashicons dashicons-yes"></span> Copied!';
				setTimeout(function() {
					btn.classList.remove('copied');
					btn.innerHTML = '<span class="dashicons dashicons-admin-page"></span> Copy';
				}, 2000);
			});
		}
		</script>

		<?php
		$variables = a1tools_get_site_variables( true ); // Force fresh fetch.
		if ( null !== $variables ) :
			// Define all fields with their labels and shortcodes
			$field_groups = array(
				'Business Information' => array(
					'business_name'   => array( 'label' => 'Business Name', 'shortcode' => '[a1tools_var key="business_name"]' ),
					'city_name'       => array( 'label' => 'City Name', 'shortcode' => '[a1tools_city_name]' ),
					'location_name'   => array( 'label' => 'State', 'shortcode' => '[a1tools_state]' ),
					'tagline'         => array( 'label' => 'Tagline', 'shortcode' => '[a1tools_var key="tagline"]' ),
					'google_maps_url' => array( 'label' => 'Google Maps URL', 'shortcode' => '[a1tools_google_map]' ),
				),
				'Contact Information' => array(
					'phone_primary'   => array( 'label' => 'Primary Phone', 'shortcode' => '[a1tools_var key="phone_primary"]' ),
					'phone_secondary' => array( 'label' => 'Secondary Phone', 'shortcode' => '[a1tools_var key="phone_secondary"]' ),
					'email_primary'   => array( 'label' => 'Primary Email', 'shortcode' => '[a1tools_var key="email_primary"]' ),
					'email_secondary' => array( 'label' => 'Secondary Email', 'shortcode' => '[a1tools_var key="email_secondary"]' ),
				),
				'Address' => array(
					'address_line1'     => array( 'label' => 'Address Line 1', 'shortcode' => '[a1tools_var key="address_line1"]' ),
					'address_line2'     => array( 'label' => 'Address Line 2', 'shortcode' => '[a1tools_var key="address_line2"]' ),
					'city'              => array( 'label' => 'City', 'shortcode' => '[a1tools_var key="city"]' ),
					'state'             => array( 'label' => 'State', 'shortcode' => '[a1tools_var key="state"]' ),
					'zip'               => array( 'label' => 'ZIP Code', 'shortcode' => '[a1tools_var key="zip"]' ),
					'country'           => array( 'label' => 'Country', 'shortcode' => '[a1tools_var key="country"]' ),
					'address_formatted' => array( 'label' => 'Full Address (multi-line)', 'shortcode' => '[a1tools_address]' ),
					'address_single'    => array( 'label' => 'Full Address (single line)', 'shortcode' => '[a1tools_full_address]' ),
				),
				'Social Media' => array(
					'facebook_url'        => array( 'label' => 'Facebook', 'shortcode' => '[a1tools_var key="facebook_url"]' ),
					'instagram_url'       => array( 'label' => 'Instagram', 'shortcode' => '[a1tools_var key="instagram_url"]' ),
					'youtube_url'         => array( 'label' => 'YouTube', 'shortcode' => '[a1tools_var key="youtube_url"]' ),
					'twitter_url'         => array( 'label' => 'Twitter/X', 'shortcode' => '[a1tools_var key="twitter_url"]' ),
					'linkedin_url'        => array( 'label' => 'LinkedIn', 'shortcode' => '[a1tools_var key="linkedin_url"]' ),
					'tiktok_url'          => array( 'label' => 'TikTok', 'shortcode' => '[a1tools_var key="tiktok_url"]' ),
					'yelp_url'            => array( 'label' => 'Yelp', 'shortcode' => '[a1tools_var key="yelp_url"]' ),
					'google_business_url' => array( 'label' => 'Google Business', 'shortcode' => '[a1tools_var key="google_business_url"]' ),
					'pinterest_url'       => array( 'label' => 'Pinterest', 'shortcode' => '[a1tools_var key="pinterest_url"]' ),
					'bbb_url'             => array( 'label' => 'BBB', 'shortcode' => '[a1tools_var key="bbb_url"]' ),
					'nextdoor_url'        => array( 'label' => 'Nextdoor', 'shortcode' => '[a1tools_var key="nextdoor_url"]' ),
					'houzz_url'           => array( 'label' => 'Houzz', 'shortcode' => '[a1tools_var key="houzz_url"]' ),
					'angi_url'            => array( 'label' => 'Angi', 'shortcode' => '[a1tools_var key="angi_url"]' ),
					'thumbtack_url'       => array( 'label' => 'Thumbtack', 'shortcode' => '[a1tools_var key="thumbtack_url"]' ),
				),
			);
			?>
			<p style="color: green;"><?php esc_html_e( 'Connected to A1 Tools successfully', 'a1-tools' ); ?></p>

			<?php foreach ( $field_groups as $group_name => $fields ) : ?>
				<h3><?php echo esc_html( $group_name ); ?></h3>
				<table class="widefat" style="max-width: 800px; margin-bottom: 20px;">
					<thead>
						<tr>
							<th style="width: 150px;"><?php esc_html_e( 'Field', 'a1-tools' ); ?></th>
							<th><?php esc_html_e( 'Value', 'a1-tools' ); ?></th>
							<th style="width: 280px;"><?php esc_html_e( 'Shortcode', 'a1-tools' ); ?></th>
						</tr>
					</thead>
					<tbody>
						<?php foreach ( $fields as $key => $info ) : ?>
							<?php
							$value = isset( $variables[ $key ] ) ? $variables[ $key ] : '';
							if ( is_array( $value ) ) {
								$value = wp_json_encode( $value );
							}
							?>
							<tr>
								<td><strong><?php echo esc_html( $info['label'] ); ?></strong></td>
								<td>
									<?php if ( ! empty( $value ) ) : ?>
										<?php if ( filter_var( $value, FILTER_VALIDATE_URL ) ) : ?>
											<a href="<?php echo esc_url( $value ); ?>" target="_blank"><?php echo esc_html( $value ); ?></a>
										<?php else : ?>
											<?php echo esc_html( $value ); ?>
										<?php endif; ?>
									<?php else : ?>
										<em style="color: #999;"><?php esc_html_e( '(not set)', 'a1-tools' ); ?></em>
									<?php endif; ?>
								</td>
								<td>
									<div class="a1tools-shortcode-cell">
										<code><?php echo esc_html( $info['shortcode'] ); ?></code>
										<button type="button" class="a1tools-copy-btn" onclick="a1toolsCopyShortcode(this, '<?php echo esc_js( $info['shortcode'] ); ?>')">
											<span class="dashicons dashicons-admin-page"></span> Copy
										</button>
									</div>
								</td>
							</tr>
						<?php endforeach; ?>
					</tbody>
				</table>
			<?php endforeach; ?>

			<?php if ( ! empty( $variables['operating_hours'] ) && is_array( $variables['operating_hours'] ) ) : ?>
				<h3><?php esc_html_e( 'Operating Hours', 'a1-tools' ); ?></h3>
				<table class="widefat" style="max-width: 400px; margin-bottom: 20px;">
					<thead>
						<tr>
							<th><?php esc_html_e( 'Day', 'a1-tools' ); ?></th>
							<th><?php esc_html_e( 'Hours', 'a1-tools' ); ?></th>
						</tr>
					</thead>
					<tbody>
						<?php
						$days = array(
							'mon' => 'Monday',
							'tue' => 'Tuesday',
							'wed' => 'Wednesday',
							'thu' => 'Thursday',
							'fri' => 'Friday',
							'sat' => 'Saturday',
							'sun' => 'Sunday',
						);
						foreach ( $days as $key => $label ) :
							$hours = isset( $variables['operating_hours'][ $key ] ) ? $variables['operating_hours'][ $key ] : '';
							?>
							<tr>
								<td><strong><?php echo esc_html( $label ); ?></strong></td>
								<td><?php echo esc_html( $hours ? $hours : '(not set)' ); ?></td>
							</tr>
						<?php endforeach; ?>
					</tbody>
				</table>
				<p style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
					<strong><?php esc_html_e( 'Shortcodes:', 'a1-tools' ); ?></strong>
					<span class="a1tools-shortcode-cell" style="display: inline-flex;">
						<code>[a1tools_hours]</code>
						<button type="button" class="a1tools-copy-btn" onclick="a1toolsCopyShortcode(this, '[a1tools_hours]')">
							<span class="dashicons dashicons-admin-page"></span> Copy
						</button>
					</span>
					<?php esc_html_e( 'or', 'a1-tools' ); ?>
					<span class="a1tools-shortcode-cell" style="display: inline-flex;">
						<code>[a1tools_hours format="list"]</code>
						<button type="button" class="a1tools-copy-btn" onclick="a1toolsCopyShortcode(this, '[a1tools_hours format=\"list\"]')">
							<span class="dashicons dashicons-admin-page"></span> Copy
						</button>
					</span>
				</p>
			<?php endif; ?>

		<?php else : ?>
			<p style="color: red;"><?php esc_html_e( 'Unable to connect to A1 Tools. Make sure this site is configured.', 'a1-tools' ); ?></p>
			<p><strong><?php esc_html_e( 'Site URL:', 'a1-tools' ); ?></strong> <?php echo esc_html( site_url() ); ?></p>
		<?php endif; ?>
	</div>
	<?php
}

// ============================================================================
// SOCIAL ICONS WIDGET
// ============================================================================

/**
 * A1 Tools Social Icons Widget.
 *
 * @since 1.2.0
 */
class A1Tools_Social_Icons_Widget extends WP_Widget {

	/**
	 * Constructor.
	 */
	public function __construct() {
		parent::__construct(
			'a1tools_social_icons',
			__( 'A1 Tools Social Icons', 'a1-tools' ),
			array(
				'description' => __( 'Display social media icons from A1 Tools with customizable styling.', 'a1-tools' ),
				'classname'   => 'a1tools-social-widget',
			)
		);
	}

	/**
	 * Frontend display.
	 *
	 * @param array $args     Widget arguments.
	 * @param array $instance Widget instance.
	 */
	public function widget( $args, $instance ) {
		$vars = a1tools_get_site_variables();
		if ( ! $vars ) {
			return;
		}

		// Widget settings with defaults.
		$title         = ! empty( $instance['title'] ) ? $instance['title'] : '';
		$shape         = ! empty( $instance['shape'] ) ? $instance['shape'] : 'rounded';
		$style         = ! empty( $instance['style'] ) ? $instance['style'] : 'default';
		$size          = ! empty( $instance['size'] ) ? (int) $instance['size'] : 40;
		$icon_size     = ! empty( $instance['icon_size'] ) ? (int) $instance['icon_size'] : 18;
		$spacing       = ! empty( $instance['spacing'] ) ? (int) $instance['spacing'] : 8;
		$alignment     = ! empty( $instance['alignment'] ) ? $instance['alignment'] : 'left';
		$custom_color  = ! empty( $instance['custom_color'] ) ? $instance['custom_color'] : '';
		$hover_effect  = ! empty( $instance['hover_effect'] ) ? $instance['hover_effect'] : 'scale';

		// Platform configurations with official colors.
		$platforms = array(
			'facebook_url'        => array( 'label' => 'Facebook', 'icon' => 'fab fa-facebook-f', 'color' => '#1877F2' ),
			'instagram_url'       => array( 'label' => 'Instagram', 'icon' => 'fab fa-instagram', 'color' => '#E4405F' ),
			'youtube_url'         => array( 'label' => 'YouTube', 'icon' => 'fab fa-youtube', 'color' => '#FF0000' ),
			'twitter_url'         => array( 'label' => 'Twitter', 'icon' => 'fab fa-x-twitter', 'color' => '#000000' ),
			'linkedin_url'        => array( 'label' => 'LinkedIn', 'icon' => 'fab fa-linkedin-in', 'color' => '#0A66C2' ),
			'tiktok_url'          => array( 'label' => 'TikTok', 'icon' => 'fab fa-tiktok', 'color' => '#000000' ),
			'yelp_url'            => array( 'label' => 'Yelp', 'icon' => 'fab fa-yelp', 'color' => '#D32323' ),
			'google_business_url' => array( 'label' => 'Google', 'icon' => 'fab fa-google', 'color' => '#4285F4' ),
			'pinterest_url'       => array( 'label' => 'Pinterest', 'icon' => 'fab fa-pinterest-p', 'color' => '#E60023' ),
			'bbb_url'             => array( 'label' => 'BBB', 'icon' => 'fas fa-shield-alt', 'color' => '#006CB7' ),
			'nextdoor_url'        => array( 'label' => 'Nextdoor', 'icon' => 'fas fa-home', 'color' => '#8ED500' ),
			'houzz_url'           => array( 'label' => 'Houzz', 'icon' => 'fab fa-houzz', 'color' => '#4DBC15' ),
			'angi_url'            => array( 'label' => 'Angi', 'icon' => 'fas fa-tools', 'color' => '#FF6153' ),
			'thumbtack_url'       => array( 'label' => 'Thumbtack', 'icon' => 'fas fa-thumbtack', 'color' => '#009FD9' ),
		);

		// Check if any platforms have URLs.
		$has_platforms = false;
		foreach ( $platforms as $key => $data ) {
			if ( ! empty( $vars[ $key ] ) ) {
				$has_platforms = true;
				break;
			}
		}

		if ( ! $has_platforms ) {
			return;
		}

		// Generate unique ID for this widget instance.
		$widget_id = 'a1tools-social-' . $this->number;

		// Build inline styles.
		$container_styles = array(
			'text-align' => $alignment,
		);

		$link_styles = array(
			'width'           => $size . 'px',
			'height'          => $size . 'px',
			'margin'          => '0 ' . ( $spacing / 2 ) . 'px ' . $spacing . 'px',
			'font-size'       => $icon_size . 'px',
			'display'         => 'inline-flex',
			'align-items'     => 'center',
			'justify-content' => 'center',
			'text-decoration' => 'none',
			'transition'      => 'all 0.3s ease',
		);

		// Shape styles.
		switch ( $shape ) {
			case 'circle':
				$link_styles['border-radius'] = '50%';
				break;
			case 'square':
				$link_styles['border-radius'] = '0';
				break;
			case 'rounded':
			default:
				$link_styles['border-radius'] = '8px';
				break;
		}

		// Output widget.
		// phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- Widget args are pre-escaped by WordPress.
		echo $args['before_widget'];

		if ( $title ) {
			// phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- Widget args are pre-escaped by WordPress.
			echo $args['before_title'] . esc_html( apply_filters( 'widget_title', $title ) ) . $args['after_title'];
		}

		// Output custom styles.
		echo '<style>';
		echo '#' . esc_attr( $widget_id ) . ' { ';
		foreach ( $container_styles as $prop => $val ) {
			echo esc_attr( $prop ) . ':' . esc_attr( $val ) . ';';
		}
		echo '}';
		echo '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon { ';
		foreach ( $link_styles as $prop => $val ) {
			echo esc_attr( $prop ) . ':' . esc_attr( $val ) . ';';
		}
		echo '}';

		// Style-specific CSS.
		if ( 'default' === $style || 'official' === $style ) {
			// Official colors or custom color background.
			echo '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon { color: #fff; }';
		} elseif ( 'outline' === $style ) {
			echo '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon { background: transparent; border: 2px solid; }';
		} elseif ( 'minimal' === $style ) {
			echo '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon { background: transparent; }';
		} elseif ( 'light' === $style ) {
			echo '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon { background: #f5f5f5; }';
		} elseif ( 'dark' === $style ) {
			echo '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon { background: #333; color: #fff; }';
		}

		// Hover effects.
		if ( 'scale' === $hover_effect ) {
			echo '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon:hover { transform: scale(1.1); }';
		} elseif ( 'lift' === $hover_effect ) {
			echo '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon:hover { transform: translateY(-3px); box-shadow: 0 4px 12px rgba(0,0,0,0.2); }';
		} elseif ( 'rotate' === $hover_effect ) {
			echo '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon:hover { transform: rotate(15deg); }';
		} elseif ( 'pulse' === $hover_effect ) {
			echo '#' . esc_attr( $widget_id ) . ' .a1tools-social-icon:hover { animation: a1tools-pulse 0.5s ease; }';
			echo '@keyframes a1tools-pulse { 0%, 100% { transform: scale(1); } 50% { transform: scale(1.15); } }';
		}

		echo '</style>';

		// Output icons container.
		echo '<div id="' . esc_attr( $widget_id ) . '" class="a1tools-social-icons-styled">';

		foreach ( $platforms as $key => $data ) {
			if ( ! empty( $vars[ $key ] ) ) {
				// Determine background/border color.
				$item_color = $custom_color ? $custom_color : ( 'official' === $style || 'default' === $style ? $data['color'] : '' );

				$inline_style = '';
				if ( 'default' === $style || 'official' === $style ) {
					$inline_style = 'background-color:' . esc_attr( $item_color ) . ';';
				} elseif ( 'outline' === $style ) {
					$icon_color   = $custom_color ? $custom_color : $data['color'];
					$inline_style = 'border-color:' . esc_attr( $icon_color ) . ';color:' . esc_attr( $icon_color ) . ';';
				} elseif ( 'minimal' === $style ) {
					$icon_color   = $custom_color ? $custom_color : $data['color'];
					$inline_style = 'color:' . esc_attr( $icon_color ) . ';';
				} elseif ( 'light' === $style ) {
					$icon_color   = $custom_color ? $custom_color : $data['color'];
					$inline_style = 'color:' . esc_attr( $icon_color ) . ';';
				}

				echo '<a href="' . esc_url( $vars[ $key ] ) . '" class="a1tools-social-icon" target="_blank" rel="noopener noreferrer" title="' . esc_attr( $data['label'] ) . '" style="' . esc_attr( $inline_style ) . '">';
				echo '<i class="' . esc_attr( $data['icon'] ) . '" aria-hidden="true"></i>';
				echo '<span class="screen-reader-text">' . esc_html( $data['label'] ) . '</span>';
				echo '</a>';
			}
		}

		echo '</div>';

		// phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- Widget args are pre-escaped by WordPress.
		echo $args['after_widget'];
	}

	/**
	 * Backend form.
	 *
	 * @param array $instance Widget instance.
	 */
	public function form( $instance ) {
		$title        = ! empty( $instance['title'] ) ? $instance['title'] : '';
		$shape        = ! empty( $instance['shape'] ) ? $instance['shape'] : 'rounded';
		$style        = ! empty( $instance['style'] ) ? $instance['style'] : 'default';
		$size         = ! empty( $instance['size'] ) ? (int) $instance['size'] : 40;
		$icon_size    = ! empty( $instance['icon_size'] ) ? (int) $instance['icon_size'] : 18;
		$spacing      = ! empty( $instance['spacing'] ) ? (int) $instance['spacing'] : 8;
		$alignment    = ! empty( $instance['alignment'] ) ? $instance['alignment'] : 'left';
		$custom_color = ! empty( $instance['custom_color'] ) ? $instance['custom_color'] : '';
		$hover_effect = ! empty( $instance['hover_effect'] ) ? $instance['hover_effect'] : 'scale';
		?>
		<p>
			<label for="<?php echo esc_attr( $this->get_field_id( 'title' ) ); ?>"><?php esc_html_e( 'Title:', 'a1-tools' ); ?></label>
			<input class="widefat" id="<?php echo esc_attr( $this->get_field_id( 'title' ) ); ?>" name="<?php echo esc_attr( $this->get_field_name( 'title' ) ); ?>" type="text" value="<?php echo esc_attr( $title ); ?>">
		</p>

		<p>
			<label for="<?php echo esc_attr( $this->get_field_id( 'style' ) ); ?>"><?php esc_html_e( 'Style:', 'a1-tools' ); ?></label>
			<select class="widefat" id="<?php echo esc_attr( $this->get_field_id( 'style' ) ); ?>" name="<?php echo esc_attr( $this->get_field_name( 'style' ) ); ?>">
				<option value="default" <?php selected( $style, 'default' ); ?>><?php esc_html_e( 'Official Colors (Filled)', 'a1-tools' ); ?></option>
				<option value="outline" <?php selected( $style, 'outline' ); ?>><?php esc_html_e( 'Outline', 'a1-tools' ); ?></option>
				<option value="minimal" <?php selected( $style, 'minimal' ); ?>><?php esc_html_e( 'Minimal (Icon Only)', 'a1-tools' ); ?></option>
				<option value="light" <?php selected( $style, 'light' ); ?>><?php esc_html_e( 'Light Background', 'a1-tools' ); ?></option>
				<option value="dark" <?php selected( $style, 'dark' ); ?>><?php esc_html_e( 'Dark Background', 'a1-tools' ); ?></option>
			</select>
		</p>

		<p>
			<label for="<?php echo esc_attr( $this->get_field_id( 'shape' ) ); ?>"><?php esc_html_e( 'Shape:', 'a1-tools' ); ?></label>
			<select class="widefat" id="<?php echo esc_attr( $this->get_field_id( 'shape' ) ); ?>" name="<?php echo esc_attr( $this->get_field_name( 'shape' ) ); ?>">
				<option value="rounded" <?php selected( $shape, 'rounded' ); ?>><?php esc_html_e( 'Rounded', 'a1-tools' ); ?></option>
				<option value="circle" <?php selected( $shape, 'circle' ); ?>><?php esc_html_e( 'Circle', 'a1-tools' ); ?></option>
				<option value="square" <?php selected( $shape, 'square' ); ?>><?php esc_html_e( 'Square', 'a1-tools' ); ?></option>
			</select>
		</p>

		<p>
			<label for="<?php echo esc_attr( $this->get_field_id( 'size' ) ); ?>"><?php esc_html_e( 'Button Size (px):', 'a1-tools' ); ?></label>
			<input class="widefat" id="<?php echo esc_attr( $this->get_field_id( 'size' ) ); ?>" name="<?php echo esc_attr( $this->get_field_name( 'size' ) ); ?>" type="number" min="20" max="100" value="<?php echo esc_attr( $size ); ?>">
		</p>

		<p>
			<label for="<?php echo esc_attr( $this->get_field_id( 'icon_size' ) ); ?>"><?php esc_html_e( 'Icon Size (px):', 'a1-tools' ); ?></label>
			<input class="widefat" id="<?php echo esc_attr( $this->get_field_id( 'icon_size' ) ); ?>" name="<?php echo esc_attr( $this->get_field_name( 'icon_size' ) ); ?>" type="number" min="10" max="60" value="<?php echo esc_attr( $icon_size ); ?>">
		</p>

		<p>
			<label for="<?php echo esc_attr( $this->get_field_id( 'spacing' ) ); ?>"><?php esc_html_e( 'Spacing (px):', 'a1-tools' ); ?></label>
			<input class="widefat" id="<?php echo esc_attr( $this->get_field_id( 'spacing' ) ); ?>" name="<?php echo esc_attr( $this->get_field_name( 'spacing' ) ); ?>" type="number" min="0" max="50" value="<?php echo esc_attr( $spacing ); ?>">
		</p>

		<p>
			<label for="<?php echo esc_attr( $this->get_field_id( 'alignment' ) ); ?>"><?php esc_html_e( 'Alignment:', 'a1-tools' ); ?></label>
			<select class="widefat" id="<?php echo esc_attr( $this->get_field_id( 'alignment' ) ); ?>" name="<?php echo esc_attr( $this->get_field_name( 'alignment' ) ); ?>">
				<option value="left" <?php selected( $alignment, 'left' ); ?>><?php esc_html_e( 'Left', 'a1-tools' ); ?></option>
				<option value="center" <?php selected( $alignment, 'center' ); ?>><?php esc_html_e( 'Center', 'a1-tools' ); ?></option>
				<option value="right" <?php selected( $alignment, 'right' ); ?>><?php esc_html_e( 'Right', 'a1-tools' ); ?></option>
			</select>
		</p>

		<p>
			<label for="<?php echo esc_attr( $this->get_field_id( 'hover_effect' ) ); ?>"><?php esc_html_e( 'Hover Effect:', 'a1-tools' ); ?></label>
			<select class="widefat" id="<?php echo esc_attr( $this->get_field_id( 'hover_effect' ) ); ?>" name="<?php echo esc_attr( $this->get_field_name( 'hover_effect' ) ); ?>">
				<option value="scale" <?php selected( $hover_effect, 'scale' ); ?>><?php esc_html_e( 'Scale', 'a1-tools' ); ?></option>
				<option value="lift" <?php selected( $hover_effect, 'lift' ); ?>><?php esc_html_e( 'Lift with Shadow', 'a1-tools' ); ?></option>
				<option value="rotate" <?php selected( $hover_effect, 'rotate' ); ?>><?php esc_html_e( 'Rotate', 'a1-tools' ); ?></option>
				<option value="pulse" <?php selected( $hover_effect, 'pulse' ); ?>><?php esc_html_e( 'Pulse', 'a1-tools' ); ?></option>
				<option value="none" <?php selected( $hover_effect, 'none' ); ?>><?php esc_html_e( 'None', 'a1-tools' ); ?></option>
			</select>
		</p>

		<p>
			<label for="<?php echo esc_attr( $this->get_field_id( 'custom_color' ) ); ?>"><?php esc_html_e( 'Custom Color (optional):', 'a1-tools' ); ?></label>
			<input class="widefat" id="<?php echo esc_attr( $this->get_field_id( 'custom_color' ) ); ?>" name="<?php echo esc_attr( $this->get_field_name( 'custom_color' ) ); ?>" type="text" value="<?php echo esc_attr( $custom_color ); ?>" placeholder="#000000">
			<small><?php esc_html_e( 'Leave empty to use official brand colors', 'a1-tools' ); ?></small>
		</p>
		<?php
	}

	/**
	 * Save widget settings.
	 *
	 * @param array $new_instance New instance values.
	 * @param array $old_instance Old instance values.
	 * @return array Sanitized instance.
	 */
	public function update( $new_instance, $old_instance ) {
		$instance                 = array();
		$instance['title']        = ! empty( $new_instance['title'] ) ? sanitize_text_field( $new_instance['title'] ) : '';
		$instance['shape']        = ! empty( $new_instance['shape'] ) ? sanitize_text_field( $new_instance['shape'] ) : 'rounded';
		$instance['style']        = ! empty( $new_instance['style'] ) ? sanitize_text_field( $new_instance['style'] ) : 'default';
		$instance['size']         = ! empty( $new_instance['size'] ) ? absint( $new_instance['size'] ) : 40;
		$instance['icon_size']    = ! empty( $new_instance['icon_size'] ) ? absint( $new_instance['icon_size'] ) : 18;
		$instance['spacing']      = isset( $new_instance['spacing'] ) ? absint( $new_instance['spacing'] ) : 8;
		$instance['alignment']    = ! empty( $new_instance['alignment'] ) ? sanitize_text_field( $new_instance['alignment'] ) : 'left';
		$instance['custom_color'] = ! empty( $new_instance['custom_color'] ) ? sanitize_hex_color( $new_instance['custom_color'] ) : '';
		$instance['hover_effect'] = ! empty( $new_instance['hover_effect'] ) ? sanitize_text_field( $new_instance['hover_effect'] ) : 'scale';

		return $instance;
	}
}

/**
 * Register the social icons widget.
 *
 * @since 1.2.0
 * @return void
 */
function a1tools_register_widgets() {
	register_widget( 'A1Tools_Social_Icons_Widget' );
}
add_action( 'widgets_init', 'a1tools_register_widgets' );

/**
 * Enqueue plugin styles.
 *
 * Note: Font Awesome is required for social icons but is NOT bundled with this plugin.
 * Most themes include Font Awesome. If icons don't appear, add Font Awesome to your theme
 * or use a Font Awesome plugin.
 *
 * @since 1.2.0
 * @return void
 */
function a1tools_enqueue_scripts() {
	// Register inline styles for social icons if needed.
	wp_register_style( 'a1tools-social', false, array(), A1TOOLS_VERSION );
	wp_enqueue_style( 'a1tools-social' );

	// Add basic screen-reader-text class if not provided by theme.
	$inline_css = '.a1tools-social-links .screen-reader-text,
.a1tools-social-icons-styled .screen-reader-text {
	clip: rect(1px, 1px, 1px, 1px);
	position: absolute !important;
	height: 1px;
	width: 1px;
	overflow: hidden;
}';
	wp_add_inline_style( 'a1tools-social', $inline_css );
}
add_action( 'wp_enqueue_scripts', 'a1tools_enqueue_scripts' );
