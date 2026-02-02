import 'dart:async';
import 'dart:io' show Platform, Directory, exit;
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_windows/webview_windows.dart' as webview_windows;
import 'package:http/http.dart' as http;
import 'features/monitoring/capture_protection_service.dart';

// Crash Recovery (Layer 1)
import 'core/services/crash_recovery_service.dart';

// Desktop window + tray
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';

// Dependency Injection
import 'core/di/service_locator.dart';

// VM Detection
import 'core/services/vm_detection_service.dart';
import 'core/services/vm_monitor_service.dart';
import 'features/security/vm_blocked_screen.dart';

// Version Check
import 'core/services/version_check_service.dart';
import 'features/admin/version_blocked_screen.dart';

// Theme
import 'app_theme.dart';
import 'core/providers/theme_provider.dart';

// Start at the MP4 splash
import 'splash_video_screen.dart';

// Screens (for routes)
import 'home_screen.dart';
// Note: InspectionFormScreen requires user context, accessed from within the app
import 'features/admin/report_lookup_screen.dart';
import 'core/services/notification_service.dart';
import 'config/api_config.dart';

/// ---- System tray globals (desktop only) ------------------------------------

final SystemTray _systemTray = SystemTray();

Future<void> _initSystemTray() async {
  const String iconPath = 'assets/icons/tray_icon.ico';

  await _systemTray.initSystemTray(
    title: 'A1 Tools',
    iconPath: iconPath,
    toolTip: 'A1 Tools',
  );

  // No context menu - app should always be running
  // Right-click does nothing

  _systemTray.registerSystemTrayEventHandler((eventName) async {
    if (eventName == kSystemTrayEventClick) {
      // Left click - show and focus window
      await windowManager.show();
      await windowManager.focus();
    }
    // Right click does nothing (no menu)
  });

  windowManager.addListener(_TrayWindowListener());
}

class _TrayWindowListener extends WindowListener {
  @override
  Future<bool> onWindowClose() async {
    final bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
      return false;
    }
    return true;
  }
}

/// ---- WebView2 Environment Initialization ------------------------------------
/// Must be called before any WebviewController is created.
/// Sets user data path to AppData and configures browser arguments
/// to handle common issues like GPU problems on older machines.
///
/// Common causes of environment_creation_failed:
/// 1. WebView2 Runtime not installed (check with getWebViewVersion)
/// 2. Corrupted user data folder (fix: use fresh folder or delete old one)
/// 3. GPU/graphics driver issues (fix: --disable-gpu flag)
/// 4. Another WebView2 using same folder with different settings

Future<void> _initWebView2Environment() async {
  if (!Platform.isWindows) return;

  try {
    // First check if WebView2 runtime is installed
    final version = await webview_windows.WebviewController.getWebViewVersion();
    if (version == null) {
      if (kDebugMode) debugPrint('[WebView2] Runtime NOT installed - videos will not work in-app');
      return;
    }
    if (kDebugMode) debugPrint('[WebView2] Runtime version: $version');

    // Get a writable directory for WebView2 user data
    // Using LocalAppData since that's where our app is installed
    final appDataDir = await getApplicationSupportDirectory();
    final webViewDataPath = '${appDataDir.path}\\WebView2Data';

    // Ensure directory exists
    final dir = Directory(webViewDataPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Initialize WebView2 environment with custom user data path
    // and --disable-gpu to prevent GPU-related crashes on some machines
    // For video playback, software rendering is acceptable
    // This must be done BEFORE creating any WebviewController instances
    await webview_windows.WebviewController.initializeEnvironment(
      userDataPath: webViewDataPath,
      additionalArguments: '--disable-gpu --autoplay-policy=no-user-gesture-required',
    );

    if (kDebugMode) debugPrint('[WebView2] Environment initialized with userDataPath: $webViewDataPath');
  } catch (e) {
    if (kDebugMode) debugPrint('[WebView2] Failed to initialize environment: $e');

    // If initialization failed, try to clear the user data folder and retry
    // This can fix corrupted profile issues
    try {
      final appDataDir = await getApplicationSupportDirectory();
      final webViewDataPath = '${appDataDir.path}\\WebView2Data';
      final dir = Directory(webViewDataPath);

      if (await dir.exists()) {
        if (kDebugMode) debugPrint('[WebView2] Attempting to clear corrupted user data folder...');
        await dir.delete(recursive: true);
        await dir.create(recursive: true);

        // Retry initialization
        await webview_windows.WebviewController.initializeEnvironment(
          userDataPath: webViewDataPath,
          additionalArguments: '--disable-gpu --autoplay-policy=no-user-gesture-required',
        );
        if (kDebugMode) debugPrint('[WebView2] Environment initialized after clearing user data');
      }
    } catch (retryError) {
      if (kDebugMode) debugPrint('[WebView2] Retry also failed: $retryError');
      // At this point, WebView will fall back to default behavior
    }
  }
}

/// ---- VM Detection -----------------------------------------------------------
/// Checks if the app is running in a virtual machine and blocks if detected.
/// Developers and admins can bypass this restriction.
/// The feature can be disabled remotely via the API.
/// Now supports real-time monitoring - changes take effect immediately.

VmDetectionResult? _vmDetectionResult;
bool _vmBypassAllowed = false;

/// Check if VM detection is enabled on the server
Future<bool> _isVmDetectionEnabled() async {
  try {
    final response = await http.get(
      Uri.parse('${ApiConfig.apiBase}/vm_settings.php?action=get_setting'),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final enabled = data['vm_detection_enabled'] == true;
        if (kDebugMode) debugPrint('[VM Detection] Remote setting: ${enabled ? "ENABLED" : "DISABLED"}');
        return enabled;
      }
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[VM Detection] Failed to check remote setting: $e');
  }
  // Default to disabled if we can't reach the server
  return false;
}

Future<bool> _checkForVirtualMachine() async {
  if (!Platform.isWindows) {
    // VM detection only implemented for Windows currently
    return false;
  }

  try {
    // Initialize the VM monitor service for real-time checking
    await VmMonitorService.instance.initialize();

    // First check if VM detection is enabled remotely
    final isEnabled = await _isVmDetectionEnabled();
    if (!isEnabled) {
      if (kDebugMode) debugPrint('[VM Detection] Disabled via remote setting - skipping detection');
      return false;
    }

    _vmDetectionResult = await VmDetectionService.instance.detect();
    if (kDebugMode) debugPrint('[VM Detection] Result: $_vmDetectionResult');

    // If VM detected, check if user has bypass privilege
    if (_vmDetectionResult?.isVirtualMachine == true) {
      _vmBypassAllowed = await VmDetectionService.instance.hasVmBypass();
      if (kDebugMode) debugPrint('[VM Detection] Bypass allowed: $_vmBypassAllowed');

      if (_vmBypassAllowed) {
        if (kDebugMode) debugPrint('[VM Detection] Developer/Admin bypass - allowing VM');
        return false; // Don't block
      }

      // Report VM status to server for admin visibility
      await VmMonitorService.instance.reportVmStatus();
    }

    return _vmDetectionResult?.isVirtualMachine ?? false;
  } catch (e) {
    if (kDebugMode) debugPrint('[VM Detection] Error during detection: $e');
    // On error, allow the app to run (fail open)
    return false;
  }
}

/// ---- Main -------------------------------------------------------------------

/// Global key to allow navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Track if we're currently showing the blocked screen
bool _isShowingBlockedScreen = false;

/// Handle notification tap - navigate to appropriate screen based on payload
void _handleNotificationTap(String? payload) {
  if (payload == null) return;

  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final type = data['type'] as String?;

    if (type == 'sunday') {
      final boardId = data['boardId'] as int?;
      final itemId = data['itemId'] as int?;

      // Navigate to Sunday board
      if (boardId != null) {
        navigatorKey.currentState?.pushNamed(
          '/sunday/board',
          arguments: {
            'boardId': boardId,
            'itemId': itemId,
          },
        );
      }
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[NotificationTap] Error parsing payload: $e');
  }
}

/// Launch the main app (can be called after unblocking)
Future<void> _launchMainApp() async {
  // Initialize dependency injection
  await setupServiceLocator();

  // Initialize NotificationService (skip on Windows/Linux - not supported by flutter_local_notifications)
  if (!Platform.isWindows && !Platform.isLinux) {
    await NotificationService().init(
      onTap: _handleNotificationTap,
    );
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // Initialize WebView2 environment early (Windows only)
    await _initWebView2Environment();

    const windowOptions = WindowOptions(
      size: Size(1100, 700),
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    await windowManager.setPreventClose(true);
    await _initSystemTray();
  }

  // Start VM monitoring in the background (for users who log in on VM later)
  if (Platform.isWindows) {
    VmMonitorService.instance.startMonitoring(
      onStatusChanged: (status) async {
        if (status.isBlocked && !_isShowingBlockedScreen) {
          // User should be blocked - show blocked screen immediately
          if (kDebugMode) debugPrint('[VM Monitor] User now blocked, showing blocked screen');
          _isShowingBlockedScreen = true;

          // Get VM detection details for the blocked screen
          final vmResult = await VmDetectionService.instance.detect();

          // Navigate to blocked screen using the global navigator key
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => VmBlockedScreen(
                detectedVm: vmResult.detectedVm,
                indicators: vmResult.indicators,
                onUnblocked: () async {
                  if (kDebugMode) debugPrint('[VM Monitor] User unblocked, returning to app');
                  _isShowingBlockedScreen = false;
                  navigatorKey.currentState?.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const SplashVideoScreen()),
                    (route) => false,
                  );
                },
                onBypassSuccess: () async {
                  if (kDebugMode) debugPrint('[VM Monitor] Bypass successful, returning to app');
                  _isShowingBlockedScreen = false;
                  navigatorKey.currentState?.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const SplashVideoScreen()),
                    (route) => false,
                  );
                },
              ),
            ),
            (route) => false,
          );
        }
      },
    );
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

/// Check if app version meets minimum requirements
Future<VersionCheckResult> _checkMinimumVersion() async {
  try {
    final result = await VersionCheckService.instance.checkVersion();
    if (kDebugMode) {
      debugPrint('[Version Check] blocked=${result.blocked}, '
          'current=${result.currentVersion}, minimum=${result.minimumVersion}');
    }
    return result;
  } catch (e) {
    if (kDebugMode) debugPrint('[Version Check] Error: $e - allowing access');
    return VersionCheckResult.allowed('0.0.0');
  }
}

/// Track restart source for telemetry
String? _restartSource;

Future<void> main() async {
  // Parse command line args for restart tracking
  _restartSource = _parseRestartSource();
  if (_restartSource != null && kDebugMode) {
    debugPrint('[Main] App started via: $_restartSource');
  }

  // Initialize crash recovery service FIRST (Layer 1)
  // This must happen before anything else to catch early crashes
  await CrashRecoveryService.instance.initialize();
  await CrashRecoveryService.instance.cleanupOnStart();

  // Check if we're in a restart loop
  if (!CrashRecoveryService.instance.shouldRestart()) {
    if (kDebugMode) debugPrint('[Main] Too many restarts detected - showing error screen');
    WidgetsFlutterBinding.ensureInitialized();
    runApp(_buildFatalErrorApp());
    return;
  }

  // Wrap everything in runZonedGuarded to catch async errors
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Set up Flutter error handler for framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('[FlutterError] ${details.exception}');
      debugPrint('[FlutterError] Stack: ${details.stack}');

      // Log but don't restart for rendering errors (they're usually recoverable)
      CrashRecoveryService.instance.logCrash(
        details.exception,
        details.stack ?? StackTrace.current,
        source: 'FlutterError.onError',
      );

      // Use default handler for debug builds
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    // Set up platform dispatcher for async errors not caught by zones
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        debugPrint('[PlatformError] $error');
        debugPrint('[PlatformError] Stack: $stack');
      }

      // Handle crash with potential restart
      CrashRecoveryService.instance.handleCrash(
        error,
        stack,
        source: 'PlatformDispatcher.onError',
      );

      return true; // Mark as handled
    };

    // Check for virtual machine FIRST before any other initialization
    final isVm = await _checkForVirtualMachine();
    if (isVm) {
      _isShowingBlockedScreen = true;
      // Show blocked screen with real-time monitoring
      // When unblocked, launch the main app
      runApp(VmBlockedScreen(
        detectedVm: _vmDetectionResult?.detectedVm,
        indicators: _vmDetectionResult?.indicators ?? [],
        onUnblocked: () async {
          if (kDebugMode) debugPrint('[VM Detection] User unblocked! Launching main app...');
          _isShowingBlockedScreen = false;
          await _launchMainApp();
        },
        onBypassSuccess: () async {
          if (kDebugMode) debugPrint('[VM Detection] Bypass successful! Launching main app...');
          _isShowingBlockedScreen = false;
          await _launchMainApp();
        },
      ));
      return;
    }

    // Check minimum version requirements
    final versionResult = await _checkMinimumVersion();
    if (versionResult.blocked) {
      _isShowingBlockedScreen = true;
      runApp(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: VersionBlockedScreen(
          currentVersion: versionResult.currentVersion,
          minimumVersion: versionResult.minimumVersion,
          message: versionResult.message,
          downloadUrl: versionResult.downloadUrl,
          onRetry: () async {
            // Re-check version and restart if now allowed
            final newResult = await _checkMinimumVersion();
            if (!newResult.blocked) {
              if (kDebugMode) debugPrint('[Version Check] Now allowed! Launching main app...');
              _isShowingBlockedScreen = false;
              await _launchMainApp();
            }
          },
        ),
      ));
      return;
    }

    // Not blocked - launch the main app normally
    await _launchMainApp();

    // Mark successful start (resets restart counter)
    await CrashRecoveryService.instance.markSuccessfulStart();

  }, (error, stackTrace) {
    // Zone-level error handler - catches all uncaught async errors
    if (kDebugMode) {
      debugPrint('[ZoneError] Uncaught error: $error');
      debugPrint('[ZoneError] Stack: $stackTrace');
    }

    // Handle crash with potential restart
    CrashRecoveryService.instance.handleCrash(
      error,
      stackTrace,
      source: 'runZonedGuarded',
    );
  });
}

/// Parse restart source from command line arguments
String? _parseRestartSource() {
  try {
    // Check for restart flags in command line args
    // These would be passed by the crash recovery service or watchdog
    final args = Platform.environment['FLUTTER_TOOL_ARGS'] ?? '';

    // Check common restart indicators
    if (args.contains('--crash-restart')) {
      return 'crash_recovery';
    }
    if (args.contains('--watchdog-restart')) {
      return 'watchdog';
    }
    if (args.contains('--auto-start')) {
      return 'auto_start';
    }
  } catch (e) {
    // Ignore errors parsing args
  }
  return null;
}

/// Build a fatal error app when too many restarts occur
Widget _buildFatalErrorApp() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                'Application Error',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'A1 Tools has encountered repeated errors and cannot start properly.\n\n'
                'Please try the following:\n'
                '1. Restart your computer\n'
                '2. Check for Windows updates\n'
                '3. Contact your manager if the problem persists',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Reset counter and try again
                  CrashRecoveryService.instance.markSuccessfulStart().then((_) {
                    CrashRecoveryService.instance.triggerColdRestart(reason: 'manual_retry');
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => exit(0),
                child: const Text('Exit Application'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Enable capture protection by default (will be disabled for developers after login)
    CaptureProtectionService.instance.enableProtection();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'A1 Tools',
          navigatorKey: navigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          debugShowCheckedModeBanner: false,
          home: const SplashVideoScreen(),
          routes: {
            '/home': (context) => const HomeScreen(),
            // '/inspection' route removed - requires user context (username, firstName, lastName)
            // Accessed from within HomeScreen with user data
            '/reports': (context) => const ReportLookupScreen(
                  siteUrl: ApiConfig.baseUrl,
                  basicAuthHeader: '',
                ),
          },
        );
      },
    );
  }
}
