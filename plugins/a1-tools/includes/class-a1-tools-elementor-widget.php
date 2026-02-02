<?php
/**
 * A1 Tools Elementor Widget
 *
 * Provides an Elementor widget for Social Media Icons with full styling controls.
 *
 * @package A1_Tools
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * A1 Tools Social Icons Elementor Widget
 */
class A1Tools_Social_Icons_Elementor_Widget extends \Elementor\Widget_Base {

	/**
	 * Get widget name.
	 */
	public function get_name() {
		return 'a1tools_social_icons';
	}

	/**
	 * Get widget title.
	 */
	public function get_title() {
		return __( 'A1 Social Icons', 'a1-tools' );
	}

	/**
	 * Get widget icon.
	 */
	public function get_icon() {
		return 'eicon-social-icons';
	}

	/**
	 * Get widget categories.
	 */
	public function get_categories() {
		return array( 'general' );
	}

	/**
	 * Get widget keywords.
	 */
	public function get_keywords() {
		return array( 'social', 'icons', 'facebook', 'instagram', 'a1', 'links' );
	}

	/**
	 * Register widget controls.
	 */
	protected function register_controls() {
		// Content Section
		$this->start_controls_section(
			'content_section',
			array(
				'label' => __( 'Content', 'a1-tools' ),
				'tab'   => \Elementor\Controls_Manager::TAB_CONTENT,
			)
		);

		$this->add_control(
			'info_notice',
			array(
				'type'            => \Elementor\Controls_Manager::RAW_HTML,
				'raw'             => __( 'Social media URLs are pulled from your A1 Tools site variables. Configure them in the A1 Tools dashboard.', 'a1-tools' ),
				'content_classes' => 'elementor-panel-alert elementor-panel-alert-info',
			)
		);

		$this->end_controls_section();

		// Style Section
		$this->start_controls_section(
			'style_section',
			array(
				'label' => __( 'Style', 'a1-tools' ),
				'tab'   => \Elementor\Controls_Manager::TAB_STYLE,
			)
		);

		$this->add_control(
			'icon_style',
			array(
				'label'   => __( 'Style', 'a1-tools' ),
				'type'    => \Elementor\Controls_Manager::SELECT,
				'default' => 'default',
				'options' => array(
					'default' => __( 'Official Colors', 'a1-tools' ),
					'outline' => __( 'Outline', 'a1-tools' ),
					'minimal' => __( 'Minimal (Icons Only)', 'a1-tools' ),
					'light'   => __( 'Light Background', 'a1-tools' ),
					'dark'    => __( 'Dark Background', 'a1-tools' ),
				),
			)
		);

		$this->add_control(
			'shape',
			array(
				'label'   => __( 'Shape', 'a1-tools' ),
				'type'    => \Elementor\Controls_Manager::SELECT,
				'default' => 'rounded',
				'options' => array(
					'rounded' => __( 'Rounded', 'a1-tools' ),
					'circle'  => __( 'Circle', 'a1-tools' ),
					'square'  => __( 'Square', 'a1-tools' ),
				),
			)
		);

		$this->add_control(
			'size',
			array(
				'label'      => __( 'Button Size', 'a1-tools' ),
				'type'       => \Elementor\Controls_Manager::SLIDER,
				'size_units' => array( 'px' ),
				'range'      => array(
					'px' => array(
						'min'  => 20,
						'max'  => 100,
						'step' => 1,
					),
				),
				'default'    => array(
					'unit' => 'px',
					'size' => 40,
				),
			)
		);

		$this->add_control(
			'icon_size',
			array(
				'label'      => __( 'Icon Size', 'a1-tools' ),
				'type'       => \Elementor\Controls_Manager::SLIDER,
				'size_units' => array( 'px' ),
				'range'      => array(
					'px' => array(
						'min'  => 10,
						'max'  => 50,
						'step' => 1,
					),
				),
				'default'    => array(
					'unit' => 'px',
					'size' => 18,
				),
			)
		);

		$this->add_control(
			'spacing',
			array(
				'label'      => __( 'Spacing', 'a1-tools' ),
				'type'       => \Elementor\Controls_Manager::SLIDER,
				'size_units' => array( 'px' ),
				'range'      => array(
					'px' => array(
						'min'  => 0,
						'max'  => 30,
						'step' => 1,
					),
				),
				'default'    => array(
					'unit' => 'px',
					'size' => 8,
				),
			)
		);

		$this->add_responsive_control(
			'alignment',
			array(
				'label'     => __( 'Alignment', 'a1-tools' ),
				'type'      => \Elementor\Controls_Manager::CHOOSE,
				'options'   => array(
					'left'   => array(
						'title' => __( 'Left', 'a1-tools' ),
						'icon'  => 'eicon-text-align-left',
					),
					'center' => array(
						'title' => __( 'Center', 'a1-tools' ),
						'icon'  => 'eicon-text-align-center',
					),
					'right'  => array(
						'title' => __( 'Right', 'a1-tools' ),
						'icon'  => 'eicon-text-align-right',
					),
				),
				'default'   => 'left',
				'selectors' => array(
					'{{WRAPPER}} .a1tools-social-icons-wrapper' => 'justify-content: {{VALUE}};',
				),
			)
		);

		$this->add_control(
			'custom_color',
			array(
				'label'       => __( 'Custom Color', 'a1-tools' ),
				'type'        => \Elementor\Controls_Manager::COLOR,
				'description' => __( 'Override icon/background colors with a custom color', 'a1-tools' ),
			)
		);

		$this->end_controls_section();

		// Hover Effects Section
		$this->start_controls_section(
			'hover_section',
			array(
				'label' => __( 'Hover Effects', 'a1-tools' ),
				'tab'   => \Elementor\Controls_Manager::TAB_STYLE,
			)
		);

		$this->add_control(
			'hover_effect',
			array(
				'label'   => __( 'Hover Effect', 'a1-tools' ),
				'type'    => \Elementor\Controls_Manager::SELECT,
				'default' => 'scale',
				'options' => array(
					'none'   => __( 'None', 'a1-tools' ),
					'scale'  => __( 'Scale Up', 'a1-tools' ),
					'lift'   => __( 'Lift (Shadow)', 'a1-tools' ),
					'rotate' => __( 'Rotate', 'a1-tools' ),
					'pulse'  => __( 'Pulse', 'a1-tools' ),
				),
			)
		);

		$this->end_controls_section();
	}

	/**
	 * Render widget output on the frontend.
	 */
	protected function render() {
		$settings = $this->get_settings_for_display();

		// Build shortcode attributes
		$atts = array(
			'style'     => $settings['icon_style'],
			'shape'     => $settings['shape'],
			'size'      => $settings['size']['size'],
			'icon_size' => $settings['icon_size']['size'],
			'spacing'   => $settings['spacing']['size'],
			'alignment' => $settings['alignment'],
			'hover'     => $settings['hover_effect'],
		);

		if ( ! empty( $settings['custom_color'] ) ) {
			$atts['color'] = $settings['custom_color'];
		}

		// Use the existing shortcode function.
		if ( function_exists( 'a1tools_shortcode_social_links' ) ) {
			// phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped -- Shortcode output is escaped internally.
			echo a1tools_shortcode_social_links( $atts );
		} else {
			echo '<p>' . esc_html__( 'A1 Tools plugin is not properly loaded.', 'a1-tools' ) . '</p>';
		}
	}

	/**
	 * Render widget output in the editor.
	 */
	protected function content_template() {
		?>
		<#
		var style = settings.icon_style || 'default';
		var shape = settings.shape || 'rounded';
		var size = settings.size.size || 40;
		var iconSize = settings.icon_size.size || 18;
		var spacing = settings.spacing.size || 8;
		var alignment = settings.alignment || 'left';
		var hover = settings.hover_effect || 'scale';
		var customColor = settings.custom_color || '';

		var borderRadius = shape === 'circle' ? '50%' : (shape === 'rounded' ? '8px' : '0');
		var justifyContent = alignment === 'center' ? 'center' : (alignment === 'right' ? 'flex-end' : 'flex-start');

		// Sample social platforms for preview
		var platforms = [
			{ icon: 'fa-facebook-f', color: '#1877F2', name: 'Facebook' },
			{ icon: 'fa-instagram', color: '#E4405F', name: 'Instagram' },
			{ icon: 'fa-youtube', color: '#FF0000', name: 'YouTube' },
			{ icon: 'fa-linkedin-in', color: '#0A66C2', name: 'LinkedIn' }
		];
		#>
		<div class="a1tools-social-icons-wrapper" style="display: flex; flex-wrap: wrap; gap: {{ spacing }}px; justify-content: {{ justifyContent }};">
			<# _.each(platforms, function(platform) {
				var bgColor = '';
				var iconColor = '';
				var border = 'none';

				if (customColor) {
					if (style === 'outline' || style === 'minimal') {
						iconColor = customColor;
						bgColor = style === 'outline' ? 'transparent' : 'transparent';
						border = style === 'outline' ? '2px solid ' + customColor : 'none';
					} else {
						bgColor = customColor;
						iconColor = '#fff';
					}
				} else {
					switch(style) {
						case 'outline':
							bgColor = 'transparent';
							iconColor = platform.color;
							border = '2px solid ' + platform.color;
							break;
						case 'minimal':
							bgColor = 'transparent';
							iconColor = platform.color;
							break;
						case 'light':
							bgColor = '#f5f5f5';
							iconColor = platform.color;
							break;
						case 'dark':
							bgColor = '#333';
							iconColor = '#fff';
							break;
						default:
							bgColor = platform.color;
							iconColor = '#fff';
					}
				}
			#>
			<a href="#" style="display: inline-flex; align-items: center; justify-content: center; width: {{ size }}px; height: {{ size }}px; background: {{ bgColor }}; color: {{ iconColor }}; border-radius: {{ borderRadius }}; border: {{ border }}; text-decoration: none; transition: all 0.3s ease;">
				<i class="fab {{ platform.icon }}" style="font-size: {{ iconSize }}px;"></i>
			</a>
			<# }); #>
		</div>
		<?php
	}
}
