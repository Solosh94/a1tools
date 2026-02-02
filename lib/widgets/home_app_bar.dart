import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../app_theme.dart';
import '../core/providers/theme_provider.dart';
import '../features/profile/profile_screen.dart';
import '../features/auth/auth_service.dart';
import '../features/timeclock/time_clock_service.dart';
import '../config/api_config.dart';

class HomeAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool loadingUser;
  final bool authBusy;
  final String? username;
  final String? role;
  final String currentStatus;
  final VoidCallback onLogin;
  final VoidCallback onLogout;
  final VoidCallback onOpenUserManager;
  final VoidCallback? onProfileUpdated;

  // Developer role preview feature
  final String? previewRole; // null = not previewing
  final ValueChanged<String?>? onPreviewRoleChanged;

  // Clock in/out status
  final bool isClockedIn;
  final bool isClockingOut;
  final bool isClockingIn;
  final VoidCallback? onClockOut;
  final VoidCallback? onClockIn;

  // Profile completion indicator - true when phone or birthday is missing
  final bool isProfileIncomplete;

  const HomeAppBar({
    required this.loadingUser,
    required this.authBusy,
    required this.username,
    required this.role,
    this.currentStatus = 'online',
    required this.onLogin,
    required this.onLogout,
    required this.onOpenUserManager,
    this.onProfileUpdated,
    this.previewRole,
    this.onPreviewRoleChanged,
    this.isClockedIn = false,
    this.isClockingOut = false,
    this.isClockingIn = false,
    this.onClockOut,
    this.onClockIn,
    this.isProfileIncomplete = false,
    super.key,
  });

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _HomeAppBarState extends State<HomeAppBar> with SingleTickerProviderStateMixin {
  static const String _pictureUrl = ApiConfig.profilePicture;

  // All available roles for preview
  static const List<String> _allRoles = [
    'developer',
    'administrator',
    'management',
    'dispatcher',
    'remote_dispatcher',
    'technician',
    'marketing',
  ];

  Uint8List? _profilePicture;
  bool _loadingPicture = false;
  String? _lastLoadedUsername;

  // Pulsating animation for profile incomplete indicator
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'away':
        return Colors.amber;
      case 'offline':
      default:
        return Colors.red;
    }
  }

  String _formatRoleName(String role) {
    switch (role) {
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

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Load picture when username changes
    if (widget.username != oldWidget.username && widget.username != null) {
      _loadProfilePicture();
    }
    // Clear picture on logout
    if (widget.username == null && oldWidget.username != null) {
      setState(() {
        _profilePicture = null;
        _lastLoadedUsername = null;
      });
    }
    // Start/stop pulse animation based on profile completion
    if (widget.isProfileIncomplete != oldWidget.isProfileIncomplete) {
      if (widget.isProfileIncomplete) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start pulsing if profile is incomplete
    if (widget.isProfileIncomplete) {
      _pulseController.repeat(reverse: true);
    }

    if (widget.username != null) {
      _loadProfilePicture();
    }
  }

  Future<void> _loadProfilePicture() async {
    if (widget.username == null || _loadingPicture) return;
    if (_lastLoadedUsername == widget.username && _profilePicture != null) return;
    
    setState(() => _loadingPicture = true);
    
    try {
      final response = await http.get(
        Uri.parse('$_pictureUrl?username=${Uri.encodeComponent(widget.username!)}'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['picture'] != null) {
          final bytes = base64Decode(data['picture']);
          if (mounted) {
            setState(() {
              _profilePicture = bytes;
              _lastLoadedUsername = widget.username;
            });
          }
        }
      }
    } catch (e) {
      // Silently fail
    } finally {
      if (mounted) setState(() => _loadingPicture = false);
    }
  }

  Future<void> _openProfile(BuildContext context) async {
    final user = await AuthService.getLoggedInUser();
    if (user == null) return;

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          user: user,
          onProfileUpdated: widget.onProfileUpdated,
        ),
      ),
    );
    
    // Reload profile picture after returning from profile screen
    if (mounted) {
      _lastLoadedUsername = null; // Force reload
      _loadProfilePicture();
    }
  }

  List<Widget> _buildActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> actions = [];

    if (widget.loadingUser || widget.authBusy) {
      actions.add(
        const Padding(
          padding: EdgeInsets.only(right: 16),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
      return actions;
    }

    if (widget.username == null) {
      actions.add(
        TextButton(
          onPressed: widget.onLogin,
          child: const Text(
            'Login',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
      return actions;
    }

    // Profile picture and username
    actions.add(
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () => _openProfile(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                  backgroundImage: _profilePicture != null
                      ? MemoryImage(_profilePicture!)
                      : null,
                  child: _profilePicture == null
                      ? Text(
                          widget.username!.isNotEmpty ? widget.username![0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.username!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                // Profile incomplete indicator with pulsating animation
                if (widget.isProfileIncomplete) ...[
                  const SizedBox(width: 4),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: child,
                      );
                    },
                    child: Tooltip(
                      message: 'Profile incomplete - click to update',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Text(
                          '!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                // Developer-only status indicator
                if (widget.role == 'developer') ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getStatusColor(widget.currentStatus),
                      border: Border.all(
                        color: isDark ? Colors.grey.shade800 : Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getStatusColor(widget.currentStatus).withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Clock In/Out buttons - only show for roles that require clock in
    // On mobile (iOS/Android), only show for developers
    final isMobile = Platform.isIOS || Platform.isAndroid;
    final showClockButtons = TimeClockService.requiresClockIn(widget.role) &&
        (!isMobile || widget.role == 'developer');

    if (showClockButtons) {
      if (widget.isClockedIn) {
        // Show Clock Out button when clocked in
        if (widget.onClockOut != null) {
          actions.add(
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: widget.isClockingOut ? null : widget.onClockOut,
                icon: widget.isClockingOut
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.logout, size: 16, color: Colors.white),
                label: Text(
                  widget.isClockingOut ? 'Clocking Out...' : 'Clock Out',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          );
        }
      } else {
        // Show Clock In button when NOT clocked in (fallback if lock screen didn't appear)
        if (widget.onClockIn != null) {
          actions.add(
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: widget.isClockingIn ? null : widget.onClockIn,
                icon: widget.isClockingIn
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.login, size: 16, color: Colors.white),
                label: Text(
                  widget.isClockingIn ? 'Clocking In...' : 'Clock In',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          );
        }
      }
    }

    // Developer-only: Role Preview Dropdown
    if (widget.role == 'developer' && widget.onPreviewRoleChanged != null) {
      final isPreviewActive = widget.previewRole != null;
      actions.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isPreviewActive 
                  ? Colors.purple.withValues(alpha: 0.2) 
                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(8),
              border: isPreviewActive 
                  ? Border.all(color: Colors.purple, width: 1.5)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility,
                  size: 16,
                  color: isPreviewActive ? Colors.purple : (isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(width: 4),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: widget.previewRole,
                    hint: Text(
                      'View as',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: isPreviewActive ? Colors.purple : null,
                    ),
                    isDense: true,
                    items: [
                      // Reset option (only show when previewing)
                      if (isPreviewActive)
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Row(
                            children: [
                              Icon(Icons.close, size: 14, color: Colors.red),
                              SizedBox(width: 6),
                              Text(
                                'Exit Preview',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // All roles
                      ..._allRoles.where((r) => r != 'developer').map((role) => DropdownMenuItem(
                        value: role,
                        child: Row(
                          children: [
                            if (widget.previewRole == role)
                              const Icon(Icons.check, size: 14, color: Colors.purple)
                            else
                              const SizedBox(width: 14),
                            const SizedBox(width: 6),
                            Text(
                              _formatRoleName(role),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: widget.previewRole == role ? FontWeight.w600 : FontWeight.normal,
                                color: widget.previewRole == role ? Colors.purple : null,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                    onChanged: widget.onPreviewRoleChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    actions.add(
      TextButton(
        onPressed: widget.onLogout,
        child: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoPath = isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png';
    
    return AppBar(
      centerTitle: true,
      leading: IconButton(
        tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
        onPressed: () => themeProvider.toggleTheme(),
      ),
      title: Image.asset(
        logoPath,
        height: 40,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Text(
            'A1 Tools',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
      actions: _buildActions(context),
    );
  }
}
