<?php
/**
 * A1 Tools Uninstall
 *
 * Fired when the plugin is uninstalled.
 *
 * @package A1_Tools
 * @since 1.0.0
 */

// If uninstall not called from WordPress, exit.
if ( ! defined( 'WP_UNINSTALL_PLUGIN' ) ) {
	exit;
}

// Delete plugin options.
delete_option( 'a1tools_cache_expiry' );

// Delete transients.
delete_transient( 'a1tools_site_variables' );

// Clear any scheduled hooks.
wp_clear_scheduled_hook( 'a1tools_cache_refresh' );
