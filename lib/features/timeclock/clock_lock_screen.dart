import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'time_clock_service.dart';
import 'time_clock_manager.dart';
import '../../home_screen.dart';

/// Clock Lock Screen
/// Fullscreen blocking screen that requires clock in to access the PC
/// Shows when user is not clocked in and their role requires it
class ClockLockScreen extends StatefulWidget {
  final String username;
  final String role;
  final VoidCallback? onClockIn;
  
  const ClockLockScreen({
    super.key,
    required this.username,
    required this.role,
    this.onClockIn,
  });
  
  @override
  State<ClockLockScreen> createState() => _ClockLockScreenState();
}

class _ClockLockScreenState extends State<ClockLockScreen> with WindowListener {
  bool _isClockingIn = false;
  String? _errorMessage;
  String _currentTime = '';
  String _currentDate = '';
  Timer? _clockTimer;
  ClockStatus? _status;
  
  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _loadStatus();
    
    // Set up window listener to prevent closing/minimizing
    if (Platform.isWindows) {
      windowManager.addListener(this);
      _setupFullscreen();
    }
  }
  
  Future<void> _setupFullscreen() async {
    await windowManager.setFullScreen(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setPreventClose(true);
    await windowManager.focus();
  }
  
  @override
  void dispose() {
    _clockTimer?.cancel();
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }
  
  @override
  void onWindowClose() async {
    // Prevent closing - just refocus
    await windowManager.focus();
    await windowManager.show();
  }
  
  @override
  void onWindowMinimize() async {
    // Prevent minimizing - restore immediately
    await windowManager.restore();
    await windowManager.focus();
  }
  
  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      _currentDate = _formatDate(now);
    });
  }
  
  String _formatDate(DateTime date) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[date.weekday % 7]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
  
  Future<void> _loadStatus() async {
    final status = await TimeClockService.getStatus(widget.username);
    if (mounted) {
      setState(() => _status = status);
    }
  }
  
  String _formatRoleName(String role) {
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
  
  Future<void> _handleClockIn() async {
    debugPrint('[ClockLockScreen] _handleClockIn called');
    
    setState(() {
      _isClockingIn = true;
      _errorMessage = null;
    });
    
    final result = await TimeClockService.clockIn(widget.username);
    
    debugPrint('[ClockLockScreen] Clock in result: success=${result.success}, message=${result.message}');
    
    if (!mounted) return;
    
    // Treat "Already clocked in" as a success - user IS clocked in, just proceed
    final alreadyClockedIn = result.message.toLowerCase().contains('already');
    final isSuccess = result.success || alreadyClockedIn;
    
    debugPrint('[ClockLockScreen] alreadyClockedIn=$alreadyClockedIn, isSuccess=$isSuccess');
    
    if (isSuccess) {
      // Exit fullscreen mode but keep the prevent-close behavior (minimize to taskbar)
      if (Platform.isWindows) {
        debugPrint('[ClockLockScreen] Exiting fullscreen mode');
        // DON'T set preventClose to false - that breaks the minimize-to-taskbar behavior
        // await windowManager.setPreventClose(false);
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setFullScreen(false);
      }
      
      // Reset state
      setState(() {
        _isClockingIn = false;
      });
      
      // Small delay to ensure window state is updated
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (!mounted) return;
      
      // Call the optional callback
      widget.onClockIn?.call();
      
      // Mark that we just clocked in (static flags to prevent race condition)
      debugPrint('[ClockLockScreen] Calling HomeScreen.markJustClockedIn()');
      HomeScreen.markJustClockedIn();
      TimeClockManager.markClockedIn(); // 5-minute grace period
      debugPrint('[ClockLockScreen] HomeScreen.justClockedIn is now: ${HomeScreen.justClockedIn}');
      debugPrint('[ClockLockScreen] TimeClockManager.isWithinClockInGrace is now: ${TimeClockManager.isWithinClockInGrace}');
      
      // Navigate directly to HomeScreen using this widget's context
      // Pass skipClockCheck to avoid re-checking status immediately
      debugPrint('[ClockLockScreen] Navigating to HomeScreen(skipClockCheck: true)');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen(skipClockCheck: true)),
        (route) => false,
      );
    } else {
      debugPrint('[ClockLockScreen] Clock in failed, showing error');
      setState(() {
        _errorMessage = result.message;
        _isClockingIn = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0a0a0a),
              Color(0xFF1a1a1a),
              Color(0xFF0d0d0d),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Company Logo
                  Image.asset(
                    'assets/images/logo-white.png',
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF49320),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'A1',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  
                  // Current Time
                  Text(
                    _currentTime,
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Current Date
                  Text(
                    _currentDate,
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 60),
                  
                  // Welcome Message
                  Text(
                    'Welcome, ${widget.username}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Schedule Info
                  if (_status?.todaySchedule != null && !_status!.isTodayOff)
                    Text(
                      'Today\'s shift: ${_status!.todaySchedule!.displayText}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    )
                  else if (_status?.isTodayOff == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'Today is your day off',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  const SizedBox(height: 60),
                  
                  // Clock In Button
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _isClockingIn ? null : _handleClockIn,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isClockingIn
                                ? [Colors.grey, Colors.grey.shade700]
                                : [const Color(0xFF4CAF50), const Color(0xFF2E7D32)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isClockingIn ? Colors.grey : const Color(0xFF4CAF50))
                                  .withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isClockingIn
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.fingerprint,
                                      size: 64,
                                      color: Colors.white,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'CLOCK IN',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Instruction Text
                  Text(
                    'Tap to start your work day',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  
                  // Error Message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 60),
                  
                  // Footer - Show Role
                  Text(
                    _formatRoleName(widget.role),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clock Out Reminder Dialog
/// Shown when scheduled end time is reached
/// Auto clocks out after 10 minutes if no response
class ClockOutReminderDialog extends StatefulWidget {
  final String username;
  final VoidCallback onStillWorking;
  final Future<void> Function() onClockOut;
  
  const ClockOutReminderDialog({
    super.key,
    required this.username,
    required this.onStillWorking,
    required this.onClockOut,
  });
  
  @override
  State<ClockOutReminderDialog> createState() => _ClockOutReminderDialogState();
}

class _ClockOutReminderDialogState extends State<ClockOutReminderDialog> {
  Timer? _autoClockOutTimer;
  int _remainingSeconds = 600; // 10 minutes
  Timer? _countdownTimer;
  bool _isClockingOut = false;
  
  @override
  void initState() {
    super.initState();
    // Start 10-minute auto clock-out timer
    _autoClockOutTimer = Timer(const Duration(minutes: 10), _handleAutoClockOut);
    // Start countdown display
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });
  }
  
  @override
  void dispose() {
    _autoClockOutTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _handleAutoClockOut() async {
    if (!mounted) return;
    debugPrint('[ClockOutReminderDialog] Auto clock out triggered after 10 minutes');
    await widget.onClockOut();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
  
  Future<void> _handleClockOut() async {
    setState(() => _isClockingOut = true);
    _autoClockOutTimer?.cancel();
    _countdownTimer?.cancel();
    await widget.onClockOut();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
  
  String _formatRemainingTime() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.access_time, color: Color(0xFFF49320), size: 28),
          SizedBox(width: 12),
          Text(
            'End of Shift',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Your scheduled work hours have ended.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Would you like to clock out?',
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Auto clock out in ${_formatRemainingTime()}',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isClockingOut ? null : () {
            _autoClockOutTimer?.cancel();
            _countdownTimer?.cancel();
            widget.onStillWorking();
          },
          child: const Text(
            'Still Working',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: _isClockingOut ? null : _handleClockOut,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF49320),
            foregroundColor: Colors.white,
          ),
          child: _isClockingOut
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Clock Out'),
        ),
      ],
    );
  }
}
