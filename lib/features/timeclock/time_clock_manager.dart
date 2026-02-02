import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'time_clock_service.dart';
import 'clock_lock_screen.dart';
import '../../home_screen.dart';

/// Time Clock Manager
/// Manages the clock in/out state, end-of-shift reminders, and screen blocking
class TimeClockManager {
  final String Function() getUsername;
  final String Function() getRole;
  final BuildContext Function() getContext;
  final VoidCallback? onClockStatusChanged;
  
  Timer? _endOfShiftTimer;
  Timer? _reminderTimer;
  Timer? _midnightTimer;
  Timer? _statusCheckTimer;
  bool _isClockedIn = false;
  bool _isShowingReminder = false;
  bool _isShowingLockScreen = false;
  ClockStatus? _currentStatus;
  
  // Track when we last confirmed clock-in to prevent false lock screens
  static DateTime? _lastConfirmedClockIn;
  static const Duration _clockInGracePeriod = Duration(minutes: 5);
  
  /// Mark that user just clocked in (call this after successful clock in)
  static void markClockedIn() {
    _lastConfirmedClockIn = DateTime.now();
    debugPrint('[TimeClockManager] Marked clocked in at $_lastConfirmedClockIn');
  }
  
  /// Check if we're within the grace period after clocking in
  static bool get isWithinClockInGrace {
    if (_lastConfirmedClockIn == null) return false;
    final elapsed = DateTime.now().difference(_lastConfirmedClockIn!);
    return elapsed < _clockInGracePeriod;
  }
  
  TimeClockManager({
    required this.getUsername,
    required this.getRole,
    required this.getContext,
    this.onClockStatusChanged,
  });
  
  bool get isClockedIn => _isClockedIn;
  bool get isShowingLockScreen => _isShowingLockScreen;
  ClockStatus? get currentStatus => _currentStatus;
  
  /// Start the time clock manager
  /// If assumeClockedIn is true, skip the initial status check (user just clocked in)
  Future<void> start({bool assumeClockedIn = false}) async {
    debugPrint('[TimeClockManager] Starting... assumeClockedIn=$assumeClockedIn');
    
    // Check if role requires clock in/out
    final role = getRole();
    if (!TimeClockService.requiresClockIn(role)) {
      debugPrint('[TimeClockManager] Role "$role" does not require clock in/out');
      return;
    }
    
    // If we just clocked in, skip the initial API check
    if (assumeClockedIn || HomeScreen.justClockedIn) {
      debugPrint('[TimeClockManager] Assuming already clocked in, skipping initial check');
      _isClockedIn = true;
      markClockedIn(); // Mark the grace period
      onClockStatusChanged?.call();
      
      // Still set up midnight timer
      _setupMidnightTimer();
      
      // Start periodic status check after a delay (to let API settle)
      _statusCheckTimer = Timer.periodic(
        const Duration(minutes: 2),
        (_) => _checkStatus(),
      );
      return;
    }
    
    // Get initial status
    await _checkStatus();
    
    // Start periodic status check (every 2 minutes)
    _statusCheckTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _checkStatus(),
    );
    
    // Set up midnight auto clock-out timer
    _setupMidnightTimer();
  }
  
  /// Stop the time clock manager
  void stop() {
    debugPrint('[TimeClockManager] Stopping...');
    _endOfShiftTimer?.cancel();
    _reminderTimer?.cancel();
    _midnightTimer?.cancel();
    _statusCheckTimer?.cancel();
    _endOfShiftTimer = null;
    _reminderTimer = null;
    _midnightTimer = null;
    _statusCheckTimer = null;
  }
  
  /// Check current clock status
  Future<void> _checkStatus() async {
    final username = getUsername();
    if (username.isEmpty) return;
    
    debugPrint('[TimeClockManager] _checkStatus called for $username');
    
    final status = await TimeClockService.getStatus(username);
    if (status == null) {
      debugPrint('[TimeClockManager] Status check returned null');
      return;
    }
    
    _currentStatus = status;
    final wasClocked = _isClockedIn;
    
    debugPrint('[TimeClockManager] API returned: clocked_in=${status.isClockedIn}, role=${status.role}');
    debugPrint('[TimeClockManager] Current state: _isClockedIn=$_isClockedIn, isWithinClockInGrace=$isWithinClockInGrace');
    
    // If API says not clocked in, but we're within grace period OR we know we're clocked in, trust our state
    if (!status.isClockedIn && (_isClockedIn || isWithinClockInGrace || HomeScreen.justClockedIn)) {
      debugPrint('[TimeClockManager] API says not clocked in, but within grace period or state says clocked in - ignoring');
      return;
    }
    
    _isClockedIn = status.isClockedIn;
    
    debugPrint('[TimeClockManager] Status: clocked_in=$_isClockedIn, role=${status.role}');
    
    // If status changed, notify
    if (wasClocked != _isClockedIn) {
      onClockStatusChanged?.call();
    }
    
    // If not clocked in and requires clock in, show lock screen
    if (!_isClockedIn && TimeClockService.requiresClockIn(status.role)) {
      // Check if user has lock screen exception (remote workers, work-from-home)
      if (status.hasLockScreenException) {
        debugPrint('[TimeClockManager] User has lock screen exception, not showing lock screen');
        return;
      }

      // Check if today is a day off
      if (status.isTodayOff) {
        debugPrint('[TimeClockManager] Today is a day off, not showing lock screen');
        return;
      }

      // Double-check we're not in grace period
      if (isWithinClockInGrace || HomeScreen.justClockedIn) {
        debugPrint('[TimeClockManager] Within grace period, not showing lock screen');
        return;
      }

      _showLockScreen();
    }
    
    // If clocked in, set up end-of-shift timer
    if (_isClockedIn) {
      _setupEndOfShiftTimer();
    }
  }
  
  /// Show the lock screen
  void _showLockScreen() {
    if (_isShowingLockScreen) return;
    
    final context = getContext();
    final username = getUsername();
    final role = getRole();
    
    debugPrint('[TimeClockManager] Showing lock screen');
    _isShowingLockScreen = true;
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => ClockLockScreen(
          username: username,
          role: role,
          onClockIn: () {
            debugPrint('[TimeClockManager] Clock in successful');
            _isShowingLockScreen = false;
            _isClockedIn = true;
            onClockStatusChanged?.call();
            Navigator.of(context).pop();
            _setupEndOfShiftTimer();
          },
        ),
      ),
      (route) => false,
    );
  }
  
  /// Set up timer for end-of-shift reminder
  void _setupEndOfShiftTimer() {
    _endOfShiftTimer?.cancel();
    
    // Debug: Show what schedule data we have
    debugPrint('[TimeClockManager] Setting up end-of-shift timer');
    debugPrint('[TimeClockManager] todaySchedule: ${_currentStatus?.todaySchedule?.displayText}');
    debugPrint('[TimeClockManager] today: ${_currentStatus?.today}');
    debugPrint('[TimeClockManager] workSchedule: ${_currentStatus?.workSchedule != null ? "exists" : "null"}');
    
    final endTime = _currentStatus?.scheduledEndTime;
    if (endTime == null) {
      debugPrint('[TimeClockManager] No scheduled end time - user has no schedule set');
      return;
    }
    
    final now = DateTime.now();
    debugPrint('[TimeClockManager] Scheduled end time: $endTime');
    
    if (now.isAfter(endTime)) {
      // Already past end time, show reminder immediately
      debugPrint('[TimeClockManager] Already past end time ($endTime), showing reminder');
      _showEndOfShiftReminder();
      return;
    }
    
    // Schedule reminder for end time
    final duration = endTime.difference(now);
    debugPrint('[TimeClockManager] End of shift in ${duration.inHours}h ${duration.inMinutes % 60}m (at $endTime)');
    
    _endOfShiftTimer = Timer(duration, () {
      debugPrint('[TimeClockManager] End of shift reached');
      _showEndOfShiftReminder();
    });
  }
  
  /// Show end-of-shift reminder popup
  Future<void> _showEndOfShiftReminder() async {
    if (_isShowingReminder || !_isClockedIn) return;
    
    _isShowingReminder = true;
    _reminderTimer?.cancel();
    
    // Bring window to front
    if (Platform.isWindows) {
      await windowManager.show();
      await windowManager.focus();
      // If minimized, restore
      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }
    }
    
    final context = getContext();
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ClockOutReminderDialog(
        username: getUsername(),
        onStillWorking: () {
          Navigator.of(ctx).pop();
          _isShowingReminder = false;
          // Set reminder for 10 minutes later
          debugPrint('[TimeClockManager] Still working, will remind in 10 minutes');
          _reminderTimer = Timer(const Duration(minutes: 10), () {
            _showEndOfShiftReminder();
          });
        },
        onClockOut: () async {
          debugPrint('[TimeClockManager] Clocking out from reminder dialog');
          final username = getUsername();
          final role = getRole();
          final result = await TimeClockService.clockOut(username);
          
          if (result.success) {
            _isClockedIn = false;
            _isShowingReminder = false;
            _endOfShiftTimer?.cancel();
            _reminderTimer?.cancel();
            onClockStatusChanged?.call();
            
            // NOTE: The dialog will pop itself after this callback returns.
            // We use pushAndRemoveUntil which clears ALL routes including the dialog,
            // so we need to do the navigation AFTER returning from this callback.
            
            // Use a post-frame callback to navigate after the dialog closes itself
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _isShowingLockScreen = true;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => ClockLockScreen(
                    username: username,
                    role: role,
                  ),
                ),
                (route) => false,
              );
            });
          } else {
            // Clock out failed - dialog will pop itself, then show error
            _isShowingReminder = false;
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Clock out failed: ${result.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            });
          }
        },
      ),
    );
  }
  
  /// Set up midnight auto clock-out timer
  void _setupMidnightTimer() {
    _midnightTimer?.cancel();
    
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    final duration = midnight.difference(now);
    
    debugPrint('[TimeClockManager] Midnight in ${duration.inHours}h ${duration.inMinutes % 60}m');
    
    _midnightTimer = Timer(duration, () async {
      debugPrint('[TimeClockManager] Midnight reached, auto clock out');
      
      if (_isClockedIn) {
        final username = getUsername();
        final role = getRole();
        await TimeClockService.clockOut(username, auto: true, notes: 'Auto clock out at midnight');
        _isClockedIn = false;
        onClockStatusChanged?.call();
        
        // Navigate to lock screen
        final context = getContext();
        if (!context.mounted) return;
        _isShowingLockScreen = true;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ClockLockScreen(
              username: username,
              role: role,
            ),
          ),
          (route) => false,
        );
      }
      
      // Set up for next midnight
      _setupMidnightTimer();
    });
  }
  
  /// Manually clock out (called from UI)
  Future<ClockResult> clockOut({String? notes}) async {
    final username = getUsername();
    final result = await TimeClockService.clockOut(username, notes: notes);

    if (result.success) {
      _isClockedIn = false;
      _endOfShiftTimer?.cancel();
      _reminderTimer?.cancel();
      onClockStatusChanged?.call();

      // Re-check status to see if user has lock screen exception
      // This ensures we respect any exception changes made while app was open
      final status = await TimeClockService.getStatus(username);
      if (status != null) {
        _currentStatus = status;

        // Only show lock screen if user doesn't have an exception
        if (!status.hasLockScreenException && TimeClockService.requiresClockIn(getRole())) {
          _showLockScreen();
        } else {
          debugPrint('[TimeClockManager] User has lock screen exception, not showing lock screen after clock out');
        }
      } else {
        // Fallback: show lock screen if we can't get status
        _showLockScreen();
      }
    }

    return result;
  }
  
  /// Get formatted clock-in duration
  String getClockInDuration() {
    if (!_isClockedIn || _currentStatus?.clockInTime == null) {
      return '0h 0m';
    }
    
    final duration = DateTime.now().difference(_currentStatus!.clockInTime!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}
