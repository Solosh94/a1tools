import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:local_notifier/local_notifier.dart' as desktop_notifier;
import 'package:window_manager/window_manager.dart';
import 'config/api_config.dart';
import 'core/constants/app_constants.dart';
import 'core/services/api_client.dart';
import 'core/services/app_update_checker.dart';
import 'core/services/auto_updater.dart';
import 'core/services/update_manager.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/register_screen.dart';
import 'features/admin/user_delete_screen.dart';
import 'features/alerts/alerts_manager.dart';
import 'features/alerts/alert_admin_screen.dart';
import 'features/compliance/heartbeat_manager.dart';

// Extracted components
import 'widgets/home_app_bar.dart';
import 'widgets/auth_dialog.dart';
import 'widgets/home_content_buttons.dart';
import 'widgets/update_checker_footer.dart';
import 'widgets/push_update_overlay.dart';
import 'widgets/preview_mode_banner.dart';
import 'widgets/alert_popup_dialog.dart';

// Remote Monitoring (new unified service)
import 'features/monitoring/remote_monitoring_service.dart';
import 'features/alerts/chat_notification_service.dart';
import 'features/monitoring/system_metrics_service.dart';
import 'features/admin/privacy_exclusions_service.dart';

// Time Clock
import 'features/timeclock/time_clock_service.dart';
import 'features/timeclock/time_clock_manager.dart';
import 'features/timeclock/clock_lock_screen.dart';

// Capture Protection
import 'features/monitoring/capture_protection_service.dart';

// Compliance
import 'features/compliance/compliance_service.dart';

class HomeScreen extends StatefulWidget {
  final bool skipClockCheck;
  
  const HomeScreen({
    super.key,
    this.skipClockCheck = false,
  });
  
  // Static flag to prevent clock check immediately after clocking in
  static DateTime? _lastClockInTime;
  static bool get justClockedIn {
    if (_lastClockInTime == null) return false;
    final diff = DateTime.now().difference(_lastClockInTime!);
    return diff.inSeconds < TimeConstants.clockInGracePeriodSeconds;
  }
  
  static void markJustClockedIn() {
    _lastClockInTime = DateTime.now();
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> implements AlertsHost {
  String _version = '';

  // Auth state
  String? _username;
  String? _firstName;
  String? _lastName;
  String? _role;
  bool _loadingUser = true;
  bool _authBusy = false;
  
  // Developer-only: Role preview feature
  String? _previewRole;
  
  /// Returns the effective role (preview role if set, otherwise actual role)
  /// Use this for all UI/permission checks to enable role preview feature
  String? get _effectiveRole => _previewRole ?? _role;
  
  // Status tracking (for developer debug indicator)
  String _currentStatus = 'online';
  
  // Push update state
  bool _showPushUpdateOverlay = false;
  double _pushUpdateProgress = 0;
  String _pushUpdateStatus = '';

  // Managers
  AlertsManager? _alertsManager;
  HeartbeatManager? _heartbeatManager;
  UpdateManager? _updateManager;
  TimeClockManager? _timeClockManager;
  
  // Time clock state
  bool _isClockedIn = false;
  bool _isClockingOut = false;
  bool _isClockingIn = false;

  // Unread message count for badge
  int _unreadMessageCount = 0;
  Timer? _unreadCountTimer;

  // Sunday notification count for badge
  int _sundayNotificationCount = 0;
  Timer? _sundayNotificationTimer;

  // Profile completion status
  bool _isProfileIncomplete = false;

  bool get _canSendAlerts =>
      _effectiveRole == 'developer' ||
      _effectiveRole == 'administrator' ||
      _effectiveRole == 'dispatcher' ||
      _effectiveRole == 'management' ||
      _effectiveRole == 'marketing';

  @override
  void initState() {
    super.initState();
    
    debugPrint('[HomeScreen] initState called');
    debugPrint('[HomeScreen] widget.skipClockCheck=${widget.skipClockCheck}');
    debugPrint('[HomeScreen] HomeScreen.justClockedIn=${HomeScreen.justClockedIn}');

    _alertsManager = AlertsManager(
      host: this,
      getUsername: () => _username ?? '',
    );
    _heartbeatManager = HeartbeatManager(
      getUsername: () => _username ?? '',
      onStatusChanged: (status) {
        if (mounted) {
          setState(() => _currentStatus = status);
        }
      },
      onRoleChanged: (newRole) {
        if (mounted && _role != newRole) {
          debugPrint('[HomeScreen] Role changed from $_role to $newRole');
          setState(() => _role = newRole);
          
          // Show notification about role change
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Your role has been updated to: ${_formatRole(newRole)}'),
              backgroundColor: const Color(0xFFF49320),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      onRemoteCommand: (command, commandId, issuedBy) {
        _handleRemoteCommand(command, commandId, issuedBy);
      },
      onCaptureNow: () async {
        // Trigger immediate screen capture via new service
        debugPrint('[HomeScreen] Capture now requested');
        await RemoteMonitoringService.instance.captureNow();
      },
      onForceUpdate: (version, downloadUrl) async {
        // Trigger forced update from admin
        debugPrint('[HomeScreen] Force update requested: v$version from $downloadUrl');
        await _triggerForcedUpdate(version, downloadUrl);
      },
    );
    _updateManager = UpdateManager(state: this);

    _loadVersion();
    _loadLoggedInUser();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Existing update systems
      AppUpdateChecker.checkForUpdate(context);
      _updateManager?.start();
      
      // Push-based auto-updater (checks every minute for admin-pushed updates)
      // Only runs on Windows - mobile apps use store updates
      if (Platform.isWindows) {
        _initPushUpdater();
      }
    });
  }
  
  /// Initialize the push-based auto-updater
  Future<void> _initPushUpdater() async {
    await AutoUpdater.instance.start(
      onUpdateStarted: () {
        if (mounted) {
          setState(() {
            _showPushUpdateOverlay = true;
            _pushUpdateStatus = 'Update found! Downloading...';
            _pushUpdateProgress = 0;
          });
        }
      },
      onDownloadProgress: (progress) {
        if (mounted) {
          setState(() {
            _pushUpdateProgress = progress;
            _pushUpdateStatus = 'Downloading update... ${(progress * 100).toInt()}%';
          });
        }
      },
      onUpdateError: (error) {
        if (mounted) {
          setState(() {
            _showPushUpdateOverlay = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Update failed: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  /// Trigger a forced update from admin push (single computer update)
  Future<void> _triggerForcedUpdate(String version, String downloadUrl) async {
    debugPrint('[HomeScreen] Triggering forced update to v$version from $downloadUrl');
    
    if (!mounted) return;
    setState(() {
      _showPushUpdateOverlay = true;
      _pushUpdateStatus = 'Forced update requested. Downloading v$version...';
      _pushUpdateProgress = 0;
    });
    
    // Create UpdateInfo and trigger the update
    final updateInfo = UpdateInfo(
      version: version,
      downloadUrl: downloadUrl,
      forceUpdate: true,
    );
    
    await AutoUpdater.instance.triggerUpdate(updateInfo);
  }

  @override
  void dispose() {
    _alertsManager?.dispose();
    _heartbeatManager?.dispose();
    _updateManager?.dispose();
    _timeClockManager?.stop();
    _unreadCountTimer?.cancel();
    _sundayNotificationTimer?.cancel();
    ComplianceService.instance.stop();
    ChatNotificationService.instance.stop();
    SystemMetricsService.instance.stop();

    // Stop remote monitoring service
    RemoteMonitoringService.instance.stop();

    if (Platform.isWindows) {
      AutoUpdater.instance.stop();
    }
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      const defined = String.fromEnvironment('APP_VERSION');
      String v;
      if (defined.isNotEmpty) {
        v = defined;
      } else {
        final info = await PackageInfo.fromPlatform();
        v = info.version;
      }
      if (mounted) setState(() => _version = v);
    } catch (e) {
      debugPrint('[HomeScreen] Failed to load version: $e');
      if (mounted) setState(() => _version = '');
    }
  }

  /// Initialize services after successful login/registration
  /// This consolidates the common post-authentication setup logic
  Future<void> _onLoginSuccess(AuthUser user) async {
    if (!mounted) return;

    debugPrint('[HomeScreen] _onLoginSuccess called for user: ${user.username}');

    // Configure ApiClient to include X-Username header in all requests
    // This is required for authentication on protected endpoints
    ApiClient.instance.onGetHeaders = () async {
      final username = await AuthService.getLoggedInUsername();
      if (username != null && username.isNotEmpty) {
        return {'X-Username': username};
      }
      return {};
    };

    // Start core managers
    _alertsManager?.start();
    _heartbeatManager?.start();

    // Set capture protection based on role (developers can bypass)
    await CaptureProtectionService.instance.setProtectionForRole(user.role);

    // Sync last known role for change detection
    _heartbeatManager?.setLastKnownRole(user.role);

    // Start remote monitoring service (screenshots every 15 min, handles streaming and control)
    // Only on Windows and only for non-admin/developer roles
    final roleToCheck = user.role.toLowerCase();
    if (Platform.isWindows && roleToCheck != 'developer' && roleToCheck != 'administrator') {
      debugPrint('[HomeScreen] Starting remote monitoring for role: ${user.role}');

      // Pre-warm the privacy exclusions cache before starting monitoring
      debugPrint('[HomeScreen] Warming privacy exclusions cache...');
      await PrivacyExclusionsService.warmCache();

      await RemoteMonitoringService.instance.initialize(
        computerName: Platform.localHostname,
        username: user.username,
        screenshotIntervalMinutes: 15,
      );
      RemoteMonitoringService.instance.start();
    } else {
      debugPrint('[HomeScreen] Skipping remote monitoring for role: ${user.role} (developer/admin)');
    }

    // Start system metrics collection (every 5 minutes, all users on Windows)
    if (Platform.isWindows) {
      // Pre-warm exclusions cache for system metrics as well
      await PrivacyExclusionsService.warmCache();
      SystemMetricsService.instance.start(user.username);
    }

    // Start chat notification service for push notifications
    ChatNotificationService.instance.start(user.username);

    // Start fetching unread message count for badge
    _startUnreadCountFetching();

    // Start fetching Sunday notification count (Windows only, admin/dispatcher roles)
    if (Platform.isWindows) {
      _startSundayNotificationFetching();
    }

    // Set up notification click handlers to navigate to chat
    ChatNotificationService.instance.onNotificationClicked = (fromUsername) {
      _navigateToChatWith(fromUsername);
    };
    ChatNotificationService.instance.onGroupNotificationClicked = (groupId) {
      _navigateToGroupChat(groupId);
    };

    // Initialize time clock (only on Windows)
    if (Platform.isWindows) {
      debugPrint('[HomeScreen] About to call _initTimeClock');
      _initTimeClock();
    }

    // Check profile completion status
    _checkProfileCompletion(user);
  }

  /// Check if user profile is incomplete (missing phone or birthday)
  void _checkProfileCompletion(AuthUser user) {
    final isIncomplete = user.phone.isEmpty ||
                         user.birthday == null ||
                         user.birthday!.isEmpty;
    if (mounted) {
      setState(() {
        _isProfileIncomplete = isIncomplete;
      });
    }
  }

  Future<void> _loadLoggedInUser() async {
    debugPrint('[HomeScreen] _loadLoggedInUser called');
    debugPrint('[HomeScreen] widget.skipClockCheck=${widget.skipClockCheck}');
    
    try {
      final user = await AuthService.getLoggedInUser();
      debugPrint('[HomeScreen] AuthService returned user: ${user?.username}, role: ${user?.role}');
      
      if (!mounted) {
        debugPrint('[HomeScreen] Widget not mounted, returning');
        return;
      }
      setState(() {
        _username = user?.username;
        _firstName = user?.firstName;
        _lastName = user?.lastName;
        _role = user?.role;
        _loadingUser = false;
      });

      if (user != null && user.username.trim().isNotEmpty) {
        debugPrint('[HomeScreen] User logged in, starting services...');
        await _onLoginSuccess(user);
      } else {
        debugPrint('[HomeScreen] No user logged in');
      }
    } catch (e) {
      debugPrint('[HomeScreen] _loadLoggedInUser error: $e');
      if (!mounted) return;
      setState(() {
        _username = null;
        _firstName = null;
        _lastName = null;
        _role = null;
        _loadingUser = false;
      });
      _alertsManager?.stop();
      _heartbeatManager?.stop();
      RemoteMonitoringService.instance.stop();
      ChatNotificationService.instance.stop();
      SystemMetricsService.instance.stop();
      _unreadCountTimer?.cancel();
    }
  }

  /// Start fetching unread message count periodically
  void _startUnreadCountFetching() {
    // Fetch immediately
    _fetchUnreadMessageCount();

    // Then fetch periodically
    _unreadCountTimer?.cancel();
    _unreadCountTimer = Timer.periodic(
      const Duration(seconds: TimeConstants.unreadMessageFetchIntervalSeconds),
      (_) => _fetchUnreadMessageCount(),
    );
  }

  /// Fetch unread message count from API
  Future<void> _fetchUnreadMessageCount() async {
    if (_username == null || _username!.isEmpty) return;

    try {
      final response = await http.get(Uri.parse(
        '${ApiConfig.chatMessages}?action=get_unread_count&username=${Uri.encodeComponent(_username!)}',
      ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _unreadMessageCount = data['unread_count'] ?? 0;
          });
        }
      }
    } catch (e) {
      // Silently fail - don't interrupt user experience
      debugPrint('[HomeScreen] Failed to fetch unread count: $e');
    }
  }

  /// Start fetching Sunday notification count periodically
  void _startSundayNotificationFetching() {
    // Only fetch for roles that have Sunday access
    final roleCheck = _role?.toLowerCase() ?? '';
    if (roleCheck != 'developer' && roleCheck != 'administrator' &&
        roleCheck != 'management' && roleCheck != 'dispatcher') {
      return;
    }

    // Fetch immediately
    _fetchSundayNotificationCount();

    // Then fetch periodically (less frequent than messages)
    _sundayNotificationTimer?.cancel();
    _sundayNotificationTimer = Timer.periodic(
      const Duration(seconds: TimeConstants.sundayNotificationFetchIntervalSeconds),
      (_) => _fetchSundayNotificationCount(),
    );
  }

  /// Fetch Sunday notification count from API
  Future<void> _fetchSundayNotificationCount() async {
    if (_username == null || _username!.isEmpty) return;

    try {
      final response = await http.get(Uri.parse(
        '${ApiConfig.sundayNotifications}?action=count&username=${Uri.encodeComponent(_username!)}',
      ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _sundayNotificationCount = data['data']?['total_count'] ?? 0;
          });
        }
      }
    } catch (e) {
      // Silently fail - don't interrupt user experience
      debugPrint('[HomeScreen] Failed to fetch Sunday notification count: $e');
    }
  }

  /// Initialize time clock system
  Future<void> _initTimeClock() async {
    debugPrint('[HomeScreen] _initTimeClock called');
    debugPrint('[HomeScreen] _username=$_username, _role=$_role');
    debugPrint('[HomeScreen] widget.skipClockCheck=${widget.skipClockCheck}');
    debugPrint('[HomeScreen] HomeScreen.justClockedIn=${HomeScreen.justClockedIn}');
    debugPrint('[HomeScreen] HomeScreen._lastClockInTime=${HomeScreen._lastClockInTime}');
    
    if (_username == null || _role == null) {
      debugPrint('[HomeScreen] Exiting _initTimeClock - username or role is null');
      return;
    }
    
    // Check if role requires clock in/out
    if (!TimeClockService.requiresClockIn(_role)) {
      debugPrint('[HomeScreen] Role "$_role" does not require clock in/out');
      return;
    }
    
    // If we just clocked in (within grace period), skip the check
    if (widget.skipClockCheck || HomeScreen.justClockedIn) {
      debugPrint('[HomeScreen] SKIPPING clock check - user just clocked in');
      setState(() {
        _isClockedIn = true;
      });
      _startTimeClockManager(assumeClockedIn: true);
      // Start compliance heartbeat when clocked in
      if (_username != null) {
        ComplianceService.instance.start(_username!);
      }
      return;
    }
    
    debugPrint('[HomeScreen] Checking clock status for $_username via API...');
    
    // Check current clock status
    final status = await TimeClockService.getStatus(_username!);
    if (status == null) {
      debugPrint('[HomeScreen] Failed to get clock status - API returned null');
      return;
    }
    
    debugPrint('[HomeScreen] API returned: isClockedIn=${status.isClockedIn}, isTodayOff=${status.isTodayOff}');
    
    // If today is a day off, don't require clock in
    if (status.isTodayOff) {
      debugPrint('[HomeScreen] Today is a day off, no clock in required');
      return;
    }
    
    setState(() {
      _isClockedIn = status.isClockedIn;
    });
    
    // If not clocked in, show lock screen
    if (!status.isClockedIn) {
      debugPrint('[HomeScreen] User not clocked in, showing lock screen');
      _showClockLockScreenOverlay();
    } else {
      debugPrint('[HomeScreen] User already clocked in, starting manager');
      // Start monitoring for end of shift
      _startTimeClockManager();
      // Start compliance heartbeat
      if (_username != null) {
        ComplianceService.instance.start(_username!);
      }
    }
  }

  /// Show the clock lock screen overlay
  void _showClockLockScreenOverlay() {
    if (!mounted) return;

    // Safety check - ensure we have valid user data before navigating
    final username = _username;
    final role = _role;
    if (username == null || username.isEmpty || role == null || role.isEmpty) {
      debugPrint('[HomeScreen] Cannot show clock lock screen - missing username or role');
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ClockLockScreen(
          username: username,
          role: role,
          // onClockIn is optional - ClockLockScreen navigates directly to HomeScreen
        ),
      ),
      (route) => false,
    );
  }
  
  /// Start time clock manager for end-of-shift reminders
  void _startTimeClockManager({bool assumeClockedIn = false}) {
    _timeClockManager = TimeClockManager(
      getUsername: () => _username ?? '',
      getRole: () => _role ?? '',
      getContext: () => context,
      onClockStatusChanged: () {
        if (mounted) {
          setState(() {
            _isClockedIn = _timeClockManager?.isClockedIn ?? false;
          });
        }
      },
    );
    _timeClockManager?.start(assumeClockedIn: assumeClockedIn);
  }

  /// Handle manual clock out from the home screen
  Future<void> _handleManualClockOut() async {
    if (_username == null || !_isClockedIn) return;
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clock Out'),
        content: const Text('Are you sure you want to clock out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF49320)),
            child: const Text('Clock Out'),
          ),
        ],
      ),
    );
    
    if (confirm != true || !mounted) return;
    
    setState(() => _isClockingOut = true);
    
    try {
      final result = await TimeClockService.clockOut(_username!);
      
      if (!mounted) return;
      
      if (result.success) {
        setState(() {
          _isClockedIn = false;
          _isClockingOut = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Clocked out successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // Stop time clock manager
        _timeClockManager?.stop();

        // Stop compliance heartbeat
        ComplianceService.instance.stop();

        // Show lock screen again
        _showClockLockScreenOverlay();
      } else {
        // Check if the error indicates not clocked in - sync the state
        final errorLower = result.message.toLowerCase();
        if (errorLower.contains('not clocked in') || errorLower.contains('no active clock') || errorLower.contains('already clocked out')) {
          // User is not clocked in (maybe clocked out on another device) - sync the state
          setState(() {
            _isClockedIn = false;
            _isClockingOut = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('You are already clocked out (synced from server)'),
                ],
              ),
              backgroundColor: Colors.orange,
            ),
          );
          // Stop time clock manager and compliance heartbeat, then show lock screen
          _timeClockManager?.stop();
          ComplianceService.instance.stop();
          _showClockLockScreenOverlay();
        } else {
          setState(() => _isClockingOut = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Clock out failed: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClockingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle manual clock in from app bar (fallback if lock screen didn't appear)
  Future<void> _handleManualClockIn() async {
    if (_username == null || _isClockedIn) return;
    
    setState(() => _isClockingIn = true);
    
    try {
      final result = await TimeClockService.clockIn(_username!);
      
      if (!mounted) return;
      
      if (result.success) {
        // Mark that we just clocked in to prevent false lock screen triggers
        HomeScreen.markJustClockedIn();
        TimeClockManager.markClockedIn();
        
        setState(() {
          _isClockedIn = true;
          _isClockingIn = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Clocked in successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // Restart time clock manager with assumption we're clocked in
        _timeClockManager?.stop();
        _timeClockManager?.start(assumeClockedIn: true);

        // Start compliance heartbeat
        if (_username != null) {
          ComplianceService.instance.start(_username!);
        }
      } else {
        // Check if the error indicates already clocked in - sync the state
        final errorLower = result.message.toLowerCase();
        if (errorLower.contains('already clocked in') || errorLower.contains('already clock')) {
          // User is already clocked in on another device - sync the state
          setState(() {
            _isClockedIn = true;
            _isClockingIn = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('You are already clocked in (synced from server)'),
                ],
              ),
              backgroundColor: Colors.orange,
            ),
          );
          // Start time clock manager since we're actually clocked in
          _timeClockManager?.stop();
          _timeClockManager?.start(assumeClockedIn: true);

          // Start compliance heartbeat
          if (_username != null) {
            ComplianceService.instance.start(_username!);
          }
        } else {
          setState(() => _isClockingIn = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Clock in failed: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClockingIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openAuthDialog() async {
    final result = await showDialog<AuthDialogResult>(
      context: context,
      builder: (context) => const AuthDialog(),
    );

    if (result == null) return;

    if (result.register) {
      if (!mounted) return;
      final createdUser = await Navigator.of(context).push<AuthUser>(
        MaterialPageRoute(
          builder: (_) => const RegisterScreen(),
        ),
      );

      if (createdUser != null && mounted) {
        setState(() {
          _username = createdUser.username;
          _firstName = createdUser.firstName;
          _lastName = createdUser.lastName;
          _role = createdUser.role;
        });

        await _onLoginSuccess(createdUser);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created: ${createdUser.username}'),
          ),
        );
      }

      return;
    }

    setState(() {
      _authBusy = true;
    });

    try {
      final authUser = await AuthService.loginRemote(
        username: result.username,
        password: result.password,
      );

      if (!mounted) return;
      setState(() {
        _username = authUser.username;
        _firstName = authUser.firstName;
        _lastName = authUser.lastName;
        _role = authUser.role;
      });

      await _onLoginSuccess(authUser);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged in as ${authUser.username}'),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      debugPrint('[HomeScreen] Authentication error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication failed')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _authBusy = false;
        });
      }
    }
  }

  void _openUserDeleteScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const UserDeleteScreen(),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;

    // Clear ApiClient header interceptor on logout
    ApiClient.instance.onGetHeaders = null;

    // Clock out user if clocked in
    if (_isClockedIn && _username != null) {
      await TimeClockService.clockOut(_username!, notes: 'Logged out');
    }

    setState(() {
      _username = null;
      _firstName = null;
      _lastName = null;
      _role = null;
      _previewRole = null;
      _isClockedIn = false;
      _isProfileIncomplete = false;
    });

    _alertsManager?.stop();
    _heartbeatManager?.stop();
    _timeClockManager?.stop();
    ComplianceService.instance.stop();
    RemoteMonitoringService.instance.stop();
    ChatNotificationService.instance.stop();
    SystemMetricsService.instance.stop();

    // Re-enable capture protection when logged out
    await CaptureProtectionService.instance.enableProtection();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out')),
    );
  }

  @override
  Future<void> showAlertPopup({
    required String title,
    required String message,
    String? fromUsername,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) async {
    if (!mounted) return;

    // Show Windows notification (allows user to click it even if they're in another app)
    if (Platform.isWindows) {
      try {
        final notification = desktop_notifier.LocalNotification(
          identifier: 'alert_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          body: message.length > 100 ? '${message.substring(0, 100)}...' : message,
        );
        
        notification.onClick = () async {
          // Bring window to focus when notification is clicked
          try {
            if (await windowManager.isMinimized()) {
              await windowManager.restore();
            }
            await windowManager.show();
            await windowManager.focus();
          } catch (e) {
            debugPrint('[HomeScreen] Window focus on notification click failed: $e');
          }
        };

        await notification.show();
      } catch (e) {
        debugPrint('[HomeScreen] Desktop notification failed: $e');
      }
    }

    try {
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }

      await windowManager.show();
      await windowManager.setSkipTaskbar(false);

      await Future.delayed(const Duration(milliseconds: 150));
      await windowManager.focus();
    } catch (e) {
      // On non-desktop platforms this might throw; log but ignore.
      debugPrint('[HomeScreen] Window manager operation failed (expected on non-desktop): $e');
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertPopupDialog(
        title: title,
        message: message,
        fromUsername: fromUsername,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        attachmentType: attachmentType,
        currentUsername: _username,
        currentRole: _role,
        onReply: fromUsername != null && fromUsername.isNotEmpty
            ? () => _showQuickReplyDialog(fromUsername)
            : null,
        onImageTap: (imageUrl, imageName) => _showFullImageDialog(imageUrl, imageName),
      ),
    );
  }

  Future<void> _showFullImageDialog(String imageUrl, String? imageName) async {
    await showDialog(
      context: context,
      builder: (ctx) => FullImageDialog(
        imageUrl: imageUrl,
        imageName: imageName,
      ),
    );
  }

  /// Show quick reply dialog to reply to an alert
  Future<void> _showQuickReplyDialog(String toUsername) async {
    final TextEditingController replyController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reply to $toUsername'),
        content: TextField(
          controller: replyController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Type your reply...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, replyController.text),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF49320)),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    replyController.dispose();

    if (result != null && result.trim().isNotEmpty && _username != null) {
      // Send the reply as an alert to the original sender
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.alerts),
          body: {
            'title': 'Reply from ${_username!}',
            'message': result.trim(),
            'recipients': toUsername,
            'from_username': _username!,
          },
        );

        if (response.statusCode == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reply sent!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send reply: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _refreshUserData() async {
    try {
      final user = await AuthService.getLoggedInUser();
      if (mounted && user != null) {
        setState(() {
          _username = user.username;
          _firstName = user.firstName;
          _lastName = user.lastName;
          _role = user.role;
        });
        // Update profile completion status
        _checkProfileCompletion(user);
      }
    } catch (e) {
      debugPrint('[HomeScreen] Failed to refresh user state: $e');
    }
  }

  Future<void> _handleRemoteCommand(String command, int commandId, String issuedBy) async {
    debugPrint('[HomeScreen] Remote command received: $command from $issuedBy');
    
    if (!mounted) return;
    
    // Remote monitoring commands are now handled by the new service via heartbeat polling
    // Legacy commands are still supported for backward compatibility
    
    if (command == 'capture_now') {
      debugPrint('[HomeScreen] Capture screenshot now');
      await RemoteMonitoringService.instance.captureNow();
      await _heartbeatManager?.acknowledgeCommand(commandId, result: 'Screenshot captured', status: 'executed');
      return;
    }
    
    // Execute immediately without confirmation - this is for remote management
    // when no one is at the computer
    debugPrint('[HomeScreen] Executing remote command immediately: $command');
    
    // Execute the command
    await _heartbeatManager?.executeRemoteCommand(command, commandId, issuedBy);
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'developer': return 'Developer';
      case 'administrator': return 'Administrator';
      case 'management': return 'Management';
      case 'dispatcher': return 'Dispatcher';
      case 'remote_dispatcher': return 'Remote Dispatcher';
      case 'technician': return 'Technician';
      case 'marketing': return 'Marketing';
      default: return role;
    }
  }

  /// Navigate to chat with a specific user when notification is clicked
  void _navigateToChatWith(String username) {
    if (_username == null || _role == null) return;
    if (!mounted) return;
    
    // Navigate to alert admin screen with chat tab selected and user pre-selected
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertAdminScreen(
          currentUsername: _username!,
          currentRole: _role!,
          initialChatUsername: username,
        ),
      ),
    );
  }

  /// Navigate to group chat when notification is clicked
  void _navigateToGroupChat(int groupId) {
    if (_username == null || _role == null) return;
    if (!mounted) return;
    
    // Navigate to alert admin screen with chat tab and group pre-selected
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertAdminScreen(
          currentUsername: _username!,
          currentRole: _role!,
          initialGroupId: groupId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: HomeAppBar(
            loadingUser: _loadingUser,
            authBusy: _authBusy,
            username: _username,
            role: _role,
            currentStatus: _currentStatus,
            onLogin: _openAuthDialog,
            onLogout: _logout,
            onOpenUserManager: _openUserDeleteScreen,
            onProfileUpdated: _refreshUserData,
            previewRole: _previewRole,
            isClockedIn: _isClockedIn,
            isClockingOut: _isClockingOut,
            isClockingIn: _isClockingIn,
            onClockOut: _handleManualClockOut,
            onClockIn: _handleManualClockIn,
            isProfileIncomplete: _isProfileIncomplete,
            onPreviewRoleChanged: _role == 'developer' ? (newRole) {
              setState(() {
                _previewRole = newRole;
              });
              if (newRole != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.visibility, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Now viewing app as ${_formatRole(newRole)}'),
                      ],
                    ),
                    backgroundColor: Colors.purple,
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.close, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Exited role preview mode'),
                      ],
                    ),
                    backgroundColor: Colors.grey,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } : null,
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Preview mode banner
                if (_previewRole != null)
                  PreviewModeBanner(
                    previewRole: _previewRole!,
                    onExit: () => setState(() => _previewRole = null),
                  ),
                Expanded(
                  child: HomeContentButtons(
                    canSendAlerts: _canSendAlerts,
                    username: _username,
                    firstName: _firstName,
                    lastName: _lastName,
                    role: _effectiveRole,
                    onLoginPressed: _openAuthDialog,
                    unreadMessageCount: _unreadMessageCount,
                    sundayNotificationCount: _sundayNotificationCount,
                  ),
                ),
                UpdateCheckerFooter(
                  version: _version,
                ),
              ],
            ),
          ),
        ),
        // Push update overlay
        if (_showPushUpdateOverlay)
          PushUpdateOverlay(
            progress: _pushUpdateProgress,
            status: _pushUpdateStatus,
          ),
      ],
    );
  }
}
