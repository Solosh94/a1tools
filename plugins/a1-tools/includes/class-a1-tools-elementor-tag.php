<?php
/**
 * A1 Tools Elementor Dynamic Tag
 *
 * Provides dynamic tags for Elementor page builder.
 *
 * @package A1_Tools
 * @since 1.0.0
 */

// Prevent direct access.
if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * A1 Tools Site Variable Dynamic Tag for Elementor
 */
class A1Tools_Elementor_Tag extends \Elementor\Core\DynamicTags\Tag {

	/**
	 * Get tag name.
	 *
	 * @return string
	 */
	public function get_name() {
		return 'a1tools-variable';
	}

	/**
	 * Get tag title.
	 *
	 * @return string
	 */
	public function get_title() {
		return esc_html__( 'A1 Site Variable', 'a1-tools' );
	}

	/**
	 * Get tag group.
	 *
	 * @return string
	 */
	public function get_group() {
		return 'a1-tools';
	}

	/**
	 * Get tag categories.
	 *
	 * @return array
	 */
	public function get_categories() {
		return array(
			\Elementor\Modules\DynamicTags\Module::TEXT_CATEGORY,
			\Elementor\Modules\DynamicTags\Module::URL_CATEGORY,
		);
	}

	/**
	 * Register controls.
	 */
	protected function register_controls() {
		$this->add_control(
			'variable_key',
			array(
				'label'   => esc_html__( 'Variable', 'a1-tools' ),
				'type'    => \Elementor\Controls_Manager::SELECT,
				'options' => array(
					// Business Information
					'business_name'       => esc_html__( 'Business Name', 'a1-tools' ),
					'location_name'       => esc_html__( 'Location Name', 'a1-tools' ),
					'city_name'           => esc_html__( 'City Name', 'a1-tools' ),
					'tagline'             => esc_html__( 'Tagline', 'a1-tools' ),
					'google_maps_url'     => esc_html__( 'Google Maps URL', 'a1-tools' ),

					// Contact Information
					'phone_primary'       => esc_html__( 'Primary Phone', 'a1-tools' ),
					'phone_secondary'     => esc_html__( 'Secondary Phone', 'a1-tools' ),
					'email_primary'       => esc_html__( 'Primary Email', 'a1-tools' ),
					'email_secondary'     => esc_html__( 'Secondary Email', 'a1-tools' ),

					// Address
					'address_line1'       => esc_html__( 'Address Line 1', 'a1-tools' ),
					'address_line2'       => esc_html__( 'Address Line 2', 'a1-tools' ),
					'city'                => esc_html__( 'City', 'a1-tools' ),
					'state'               => esc_html__( 'State', 'a1-tools' ),
					'zip'                 => esc_html__( 'ZIP Code', 'a1-tools' ),
					'country'             => esc_html__( 'Country', 'a1-tools' ),

					// Social Media URLs
					'facebook_url'        => esc_html__( 'Facebook URL', 'a1-tools' ),
					'instagram_url'       => esc_html__( 'Instagram URL', 'a1-tools' ),
					'youtube_url'         => esc_html__( 'YouTube URL', 'a1-tools' ),
					'twitter_url'         => esc_html__( 'Twitter URL', 'a1-tools' ),
					'linkedin_url'        => esc_html__( 'LinkedIn URL', 'a1-tools' ),
					'tiktok_url'          => esc_html__( 'TikTok URL', 'a1-tools' ),
					'yelp_url'            => esc_html__( 'Yelp URL', 'a1-tools' ),
					'google_business_url' => esc_html__( 'Google Business URL', 'a1-tools' ),
					'pinterest_url'       => esc_html__( 'Pinterest URL', 'a1-tools' ),
					'bbb_url'             => esc_html__( 'BBB URL', 'a1-tools' ),
					'nextdoor_url'        => esc_html__( 'Nextdoor URL', 'a1-tools' ),
					'houzz_url'           => esc_html__( 'Houzz URL', 'a1-tools' ),
					'angi_url'            => esc_html__( 'Angi URL', 'a1-tools' ),
					'thumbtack_url'       => esc_html__( 'Thumbtack URL', 'a1-tools' ),
				),
				'default' => 'business_name',
			)
		);
	}

	/**
	 * Render the tag output.
	 */
	public function render() {
		$key = $this->get_settings( 'variable_key' );

		if ( empty( $key ) ) {
			return;
		}

		if ( function_exists( 'a1tools_get_variable' ) ) {
			echo esc_html( a1tools_get_variable( $key ) );
		}
	}
}
