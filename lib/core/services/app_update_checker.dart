// lib/app_update_checker.dart
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// NEW: bring window to front when an update is found (desktop)
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';

class AppUpdateChecker {
 // ---- iOS App Store ----
 static String get _appStoreUrl => ApiConfig.appStoreUrl;

 // ---- Windows (Desktop) ----
 static String get _winManifestUrl => ApiConfig.latestVersion;
 static String get _winLandingUrl => ApiConfig.installerBase;

 // Prevent redundant checks on non-periodic calls in a single session
 static bool _checkedThisSession = false;
 // Prevent multiple popups for the *same* store version in a single session
 static String? _lastNotifiedVersion;

 /// Call once after HomeScreen's first frame.
 ///
 /// - `force`: bypasses the "checked this session" guard (useful for dev).
 /// - `periodic`: set to true for background timers (every 2 minutes, etc).
 /// Periodic checks will still avoid showing the same popup repeatedly for
 /// the same version.
 static Future<void> checkForUpdate(
 BuildContext context, {
 bool force = false,
 bool periodic = false,
 }) async {
 // For non-periodic use (startup, manual), only run once per session
 if (!periodic && _checkedThisSession && !force) return;
 if (!periodic) {
 _checkedThisSession = true;
 }

 try {
 if (io.Platform.isIOS) {
 await _checkIOS(context, force: force);
 } else if (io.Platform.isWindows) {
 await _checkWindows(context, force: force);
 }
 } catch (e) {
 if (kDebugMode) debugPrint('Update check error: $e');
 }
 }

 // Prefer build-time define from the script; fallback to PackageInfo.
 static Future<String> _currentVersion() async {
 const defined = String.fromEnvironment('APP_VERSION');
 if (defined.isNotEmpty) return defined;
 final info = await PackageInfo.fromPlatform();
 return info.version;
 }

 // Bring the desktop window to front before showing an update dialog
 static Future<void> _bringToFrontForDesktop() async {
 // Only meaningful on desktop platforms
 if (!(io.Platform.isWindows || io.Platform.isLinux || io.Platform.isMacOS)) {
 return;
 }

 try {
 if (await windowManager.isMinimized()) {
 await windowManager.restore();
 }

 await windowManager.show();
 await windowManager.setSkipTaskbar(false);

 // Small delay so the OS catches up, then focus
 await Future.delayed(const Duration(milliseconds: 150));
 await windowManager.focus();
 } catch (e) {
 // Ignore any issues (e.g., if window_manager not fully initialized)
 debugPrint('[AppUpdateChecker] Window manager error: $e');
 }
 }

 // -------------------- iOS --------------------
 static Future<void> _checkIOS(BuildContext context,
 {bool force = false}) async {
 final currentVersion = await _currentVersion();

 final resp = await http
 .get(
 Uri.parse(ApiConfig.appStoreLookup),
 headers: const {'Cache-Control': 'no-cache'},
 )
 .timeout(const Duration(seconds: 10));
 if (resp.statusCode != 200) return;

 final json = jsonDecode(resp.body);
 if (json is! Map || (json['resultCount'] ?? 0) == 0) return;
 final results = (json['results'] as List? ?? const []);
 if (results.isEmpty) return;

 final storeVersion = (results.first['version'] ?? '').toString();
 if (storeVersion.isEmpty) return;

 if (kDebugMode) {
 debugPrint('[iOS] current=$currentVersion, latest=$storeVersion');
 }

 if (_isStoreNewer(storeVersion, currentVersion)) {
 // If we've already shown this exact version in this session and we are
 // not forcing, don't nag again.
 if (!force && _lastNotifiedVersion == storeVersion) {
 return;
 }
 _lastNotifiedVersion = storeVersion;

 if (!context.mounted) return;
 await showDialog<void>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Update Available'),
 content: Text(
 'A newer version ($storeVersion) of A1 Tools is available.\n'
 "You're on $currentVersion.",
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Later'),
 ),
 FilledButton(
 onPressed: () async {
 Navigator.of(ctx).pop();
 await _openExternalUrl(context, _appStoreUrl);
 },
 child: const Text('Update'),
 ),
 ],
 ),
 );
 }
 }

 // -------------------- Windows --------------------
 static Future<void> _checkWindows(BuildContext context,
 {bool force = false}) async {
 final currentVersion = await _currentVersion();

 // cache-buster to avoid CDN/browser caching stale latest.json while testing
 final uri = Uri.parse(
 '$_winManifestUrl?ts=${DateTime.now().millisecondsSinceEpoch}',
 );
 final resp = await http
 .get(uri, headers: const {'Cache-Control': 'no-cache'})
 .timeout(const Duration(seconds: 10));
 if (resp.statusCode != 200) return;

 final data = jsonDecode(resp.body);
 if (data is! Map) return;

 final storeVersion = (data['latest_version'] ?? '').toString();
 final directUrl = (data['download_url'] ?? '').toString();
 if (storeVersion.isEmpty) return;

 if (kDebugMode) {
 debugPrint(
 '[Windows] current=$currentVersion, '
 'latest=$storeVersion, url=$directUrl',
 );
 }

 if (_isStoreNewer(storeVersion, currentVersion)) {
 // Avoid nagging for the same version multiple times in one session
 if (!force && _lastNotifiedVersion == storeVersion) {
 return;
 }
 _lastNotifiedVersion = storeVersion;

 // Bring the window to front like the alert system
 await _bringToFrontForDesktop();

 if (!context.mounted) return;
 await showDialog<void>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Update Available (Windows)'),
 content: Text(
 'A newer version ($storeVersion) of A1 Tools for Windows is available.\n'
 "You're on $currentVersion.",
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.of(ctx).pop(),
 child: const Text('Later'),
 ),
 FilledButton(
 onPressed: () async {
 Navigator.of(ctx).pop();
 final target =
 directUrl.isNotEmpty ? directUrl : _winLandingUrl;
 await _openExternalUrl(context, target);
 },
 child: const Text('Update'),
 ),
 ],
 ),
 );
 }
 }

 /// Robust external opener with Windows fallbacks and user feedback.
 static Future<bool> _openExternalUrl(
 BuildContext context,
 String url,
 ) async {
 final uri = Uri.parse(url);

 // 1) Try url_launcher
 try {
 if (await canLaunchUrl(uri)) {
 final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
 if (ok) return true;
 }
 } catch (e) {
 debugPrint('[AppUpdateChecker] url_launcher error: $e');
 }

 // 2) Windows fallbacks (PowerShell -> cmd -> explorer)
 if (io.Platform.isWindows) {
 try {
 final p = await io.Process.start(
 'powershell',
 ['-NoProfile', '-Command', 'Start-Process', url],
 runInShell: true,
 );
 if (p.pid > 0) return true;
 } catch (e) {
 debugPrint('[AppUpdateChecker] PowerShell launch failed: $e');
 try {
 final p2 = await io.Process.start(
 'cmd',
 ['/c', 'start', '', url],
 runInShell: true,
 );
 if (p2.pid > 0) return true;
 } catch (e2) {
 debugPrint('[AppUpdateChecker] cmd launch failed: $e2');
 try {
 final p3 = await io.Process.start(
 'explorer.exe',
 [url],
 runInShell: true,
 );
 if (p3.pid > 0) return true;
 } catch (e3) {
 debugPrint('[AppUpdateChecker] explorer.exe launch failed: $e3');
 }
 }
 }
 }

 if (context.mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Could not open the update link')),
 );
 }
 return false;
 }

 /// Compares dotted version strings like "1.2.10" vs "1.2.2".
 static bool _isStoreNewer(String store, String current) {
 final s = store.split('.').map((e) => int.tryParse(e) ?? 0).toList();
 final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
 final n = s.length > c.length ? s.length : c.length;
 for (var i = 0; i < n; i++) {
 final sv = i < s.length ? s[i] : 0;
 final cv = i < c.length ? c[i] : 0;
 if (sv > cv) return true;
 if (sv < cv) return false;
 }
 return false;
 }
}
