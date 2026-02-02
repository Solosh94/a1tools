# A1 Tools WordPress Plugin - Development Notes

## Issues Fixed for WordPress.org Submission

### Version 1.3.0 - WordPress Review Fixes

#### 1. Prefix Length Issue (CRITICAL)
**Error:** `The prefix "a1" is too short, we require prefixes to be over 4 characters.`

**Solution:**
Changed all prefixes from `a1_` to `a1tools_`:
- Constants: `A1_TOOLS_*` → `A1TOOLS_*`
- Functions: `a1_tools_*` → `a1tools_*`
- Classes: `A1_Tools_*` → `A1Tools_*`
- Shortcodes: `[a1_var]` → `[a1tools_var]`
- Options: `a1_tools_*` → `a1tools_*`
- Transients: `a1_tools_*` → `a1tools_*`
- CSS classes: `a1-tools-*` → `a1tools-*`
- JavaScript functions: `a1CopyShortcode` → `a1toolsCopyShortcode`

**Affected Files:**
- `a1-tools.php` (main plugin file)
- `includes/class-a1-tools-elementor-tag.php`
- `includes/class-a1-tools-elementor-widget.php`
- `uninstall.php`
- `readme.txt`

---

#### 2. External Services Documentation (CRITICAL)
**Error:** `Undocumented use of a 3rd Party / external service`

**Solution:**
Added `== External Services ==` section to readme.txt documenting:
- A1 Tools API (https://tools.a-1chimney.com/api/website_variables.php)
- Font Awesome CDN (https://cdnjs.cloudflare.com)

Each service documented with:
- What it is
- What data is sent
- When data is sent
- Links to Terms of Service and Privacy Policy

---

#### 3. Contributor Username
**Error:** `None of the listed contributors "a1chimney" is the WordPress.org username of the owner`

**Solution:**
Changed contributor in readme.txt to `a1tools` (matching the plugin owner's WordPress.org username).

---

### Version 1.0.7 - Previous Fixes

#### 1. Plugin Header Format Errors
**Errors:**
- `plugin_header_missing_plugin_description`
- `plugin_header_missing_plugin_version`
- `plugin_header_no_license`

**Solution:**
The plugin header must use PHPDoc style (`/**`) with properly aligned fields:

```php
<?php
/**
 * Plugin Name:       A1 Tools
 * Plugin URI:        https://tools.a-1chimney.com
 * Description:       Your description here.
 * Version:           1.3.0
 * Requires at least: 5.0
 * Requires PHP:      7.4
 * Author:            A1 Chimney Service
 * Author URI:        https://a-1chimney.com
 * Text Domain:       a1-tools
 * License:           GPLv2 or later
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 */
```

**Key points:**
- Use `/**` not `/*`
- Align values with spaces for readability
- Use `GPLv2 or later` for license (matches readme.txt format)

---

#### 2. "Plugin file does not exist" Error on Activation
**Problem:**
WordPress couldn't find the plugin file after extracting the zip, even though the file was present.

**Root Cause:**
PowerShell's `Compress-Archive` creates zip files with **backslashes** (`a1-tools\a1-tools.php`), but WordPress/PHP expects **forward slashes** (`a1-tools/a1-tools.php`).

**Solution:**
Use a custom PowerShell script (`create-zip.ps1`) that creates the zip with forward slashes:

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem

$sourceDir = 'H:/A1Chimney/a1_tools/plugins/a1-tools'
$zipPath = 'H:/A1Chimney/a1_tools/plugins/a1-tools-1.3.0.zip'
$folderName = 'a1-tools'

if (Test-Path $zipPath) { Remove-Item $zipPath }

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')

Get-ChildItem -Path $sourceDir -Recurse -File | ForEach-Object {
    $fullPath = $_.FullName
    $relativePath = $fullPath.Substring($sourceDir.Length)
    $entryPath = $folderName + $relativePath.Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $fullPath, $entryPath) | Out-Null
    Write-Host "Added: $entryPath"
}

$zip.Dispose()
Write-Host 'Zip created successfully!'
```

**DO NOT USE:** `Compress-Archive` on Windows for WordPress plugins.

---

#### 3. Debug Code Warning
**Error:**
`WordPress.PHP.DevelopmentFunctions.error_log_error_log` - "error_log() found. Debug code should not normally be used in production."

**Solution:**
Remove all `error_log()` calls from the production code. If logging is needed, use WordPress's built-in logging or make it conditional in a way that the checker accepts.

**Before:**
```php
if ( is_wp_error( $response ) ) {
    if ( defined( 'WP_DEBUG' ) && WP_DEBUG ) {
        error_log( 'A1 Tools API Error: ' . $response->get_error_message() );
    }
    return null;
}
```

**After:**
```php
if ( is_wp_error( $response ) ) {
    return null;
}
```

---

## Version History

| Version | Changes |
|---------|---------|
| 1.0.0 | Initial version |
| 1.0.1 - 1.0.5 | Header format fixes, testing different formats |
| 1.0.6 | Fixed zip file path separators (backslash to forward slash) |
| 1.0.7 | Removed error_log() debug code |
| 1.0.8 | Added geo-targeting fields (city_name, location_name, google_maps_url) |
| 1.0.9 | Added admin settings page with cache configuration |
| 1.1.0 | Added 6 new social platforms |
| 1.2.0 | Added Social Icons Widget with styling options, Elementor widget |
| 1.3.0 | Fixed prefix length (a1_ → a1tools_), added External Services docs, fixed contributor |

---

## Build Instructions

1. Make changes to files in `a1-tools/` folder
2. Update version number in three places:
   - `a1-tools.php` header (`Version:`)
   - `a1-tools.php` constant (`A1TOOLS_VERSION`)
   - `readme.txt` (`Stable tag:`)
3. Update `create-zip.ps1` with new version number in `$zipPath`
4. Run: `powershell -ExecutionPolicy Bypass -File create-zip.ps1`
5. Test the zip by installing on a WordPress site
6. Run Plugin Check (PCP) to verify no errors

---

## Shortcode Migration (1.2.0 → 1.3.0)

**BREAKING CHANGE:** All shortcodes have been renamed.

| Old Shortcode | New Shortcode |
|---------------|---------------|
| `[a1_var]` | `[a1tools_var]` |
| `[a1_address]` | `[a1tools_address]` |
| `[a1_full_address]` | `[a1tools_full_address]` |
| `[a1_hours]` | `[a1tools_hours]` |
| `[a1_social_links]` | `[a1tools_social_links]` |
| `[a1_city_name]` | `[a1tools_city_name]` |
| `[a1_state]` | `[a1tools_state]` |
| `[a1_google_map]` | `[a1tools_google_map]` |

---

## Useful Links

- [WordPress Plugin Header Requirements](https://developer.wordpress.org/plugins/plugin-basics/header-requirements/)
- [Plugin Check (PCP)](https://wordpress.org/plugins/plugin-check/)
- [Common Plugin Issues](https://developer.wordpress.org/plugins/wordpress-org/common-issues/)
- [Plugin Guidelines](https://developer.wordpress.org/plugins/wordpress-org/detailed-plugin-guidelines/)
