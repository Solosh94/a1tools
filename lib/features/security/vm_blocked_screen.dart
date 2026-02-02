// VM Blocked Screen
//
// Displays when the app detects it's running in a virtual machine.
// Prevents the user from using the app in unauthorized environments.
// Features:
// - Developer/admin bypass login
// - Auto-update checking and downloading (even when blocked)
// - Real-time monitoring - unblocks immediately when admin disables VM detection
// - Per-user blocking support

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

import '../auth/auth_service.dart';
import '../../config/api_config.dart';
import '../../core/services/vm_monitor_service.dart';

class VmBlockedScreen extends StatefulWidget {
  final String? detectedVm;
  final List<String> indicators;
  final VoidCallback? onBypassSuccess;
  final VoidCallback? onUnblocked;

  const VmBlockedScreen({
    super.key,
    this.detectedVm,
    this.indicators = const [],
    this.onBypassSuccess,
    this.onUnblocked,
  });

  @override
  State<VmBlockedScreen> createState() => _VmBlockedScreenState();
}

class _VmBlockedScreenState extends State<VmBlockedScreen> {
  bool _showDeveloperLogin = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Update checking
  bool _isCheckingUpdate = false;
  bool _updateAvailable = false;
  String? _latestVersion;
  String? _currentVersion;
  String? _updateUrl;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadError;

  // Real-time monitoring
  Timer? _monitorTimer;
  bool _isCheckingStatus = false;
  String? _blockedReason;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-check for updates when the screen loads
    _checkForUpdate();
    // Start real-time monitoring
    _startMonitoring();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _monitorTimer?.cancel();
    super.dispose();
  }

  /// Start monitoring for VM detection status changes
  void _startMonitoring() {
    // Check every 15 seconds for status changes
    _monitorTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkIfUnblocked();
    });
    // Also check immediately
    _checkIfUnblocked();
  }

  /// Check if the user has been unblocked (admin disabled VM detection)
  Future<void> _checkIfUnblocked() async {
    if (_isCheckingStatus) return;

    setState(() {
      _isCheckingStatus = true;
    });

    try {
      final status = await VmMonitorService.instance.checkNow();

      if (!status.isBlocked) {
        // User is no longer blocked - trigger callback to return to app
        debugPrint('[VM Blocked] User unblocked, returning to app');
        _monitorTimer?.cancel();
        widget.onUnblocked?.call();
      } else {
        setState(() {
          _blockedReason = status.blockedReason;
        });
      }
    } catch (e) {
      debugPrint('[VM Blocked] Status check failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
        });
      }
    }
  }

  /// Check for available updates even though VM is detected
  /// This allows users to get VM detection fixes
  Future<void> _checkForUpdate() async {
    if (!Platform.isWindows) return;

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      // Get current version
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;

      // Fetch latest version from API
      final response = await http.get(
        Uri.parse('${ApiConfig.apiBase}/update_check.php?platform=windows'),
        headers: const {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _latestVersion = data['version'];
          _updateUrl = data['download_url'];

          // Compare versions
          if (_latestVersion != null && _isNewerVersion(_latestVersion!, _currentVersion!)) {
            setState(() {
              _updateAvailable = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[VM Blocked] Update check failed: $e');
    } finally {
      setState(() {
        _isCheckingUpdate = false;
      });
    }
  }

  /// Compare version strings (e.g., "3.9.61" > "3.9.60")
  bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestParts.length > currentParts.length;
  }

  /// Download and install the update
  Future<void> _downloadUpdate() async {
    if (_updateUrl == null || _latestVersion == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadError = null;
    });

    try {
      // Get download directory
      final tempDir = await getTemporaryDirectory();
      final fileName = 'A1-Tools-Setup-$_latestVersion.exe';
      final filePath = '${tempDir.path}\\$fileName';
      final file = File(filePath);

      // Download with progress
      final request = http.Request('GET', Uri.parse(_updateUrl!));
      final response = await http.Client().send(request);

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      final sink = file.openWrite();

      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          received += chunk.length;
          if (contentLength > 0) {
            setState(() {
              _downloadProgress = received / contentLength;
            });
          }
        },
        onDone: () async {
          await sink.close();

          // Launch installer
          debugPrint('[VM Blocked] Download complete, launching installer: $filePath');
          await Process.start(filePath, [], mode: ProcessStartMode.detached);

          // Exit app so installer can replace files
          exit(0);
        },
        onError: (e) {
          setState(() {
            _downloadError = 'Download failed: $e';
            _isDownloading = false;
          });
        },
        cancelOnError: true,
      ).asFuture();
    } catch (e) {
      setState(() {
        _downloadError = 'Download failed: $e';
        _isDownloading = false;
      });
      debugPrint('[VM Blocked] Failed to download update: $e');
    }
  }

  /// Open update URL in browser as fallback
  Future<void> _openUpdateInBrowser() async {
    if (_updateUrl == null) return;

    try {
      final uri = Uri.parse(_updateUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[VM Blocked] Failed to launch update URL: $e');
    }
  }

  Future<void> _attemptDeveloperLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter username and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Attempt login
      final user = await AuthService.loginRemote(
        username: username,
        password: password,
      );

      // Check if user has bypass role
      final allowedRoles = ['developer', 'administrator'];
      if (allowedRoles.contains(user.role.toLowerCase())) {
        // Success - user has bypass privileges
        debugPrint('[VM Bypass] Login successful for ${user.role}: ${user.username}');

        if (widget.onBypassSuccess != null) {
          widget.onBypassSuccess!();
        } else {
          // Restart the app to apply bypass
          setState(() {
            _errorMessage = 'Login successful! Please restart the application.';
            _isLoading = false;
          });
        }
      } else {
        // User logged in but doesn't have bypass privileges
        setState(() {
          _errorMessage = 'Access denied. Only developers and admins can use VM bypass.';
          _isLoading = false;
        });
        // Logout since they don't have permission
        await AuthService.logout();
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      ),
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: _showDeveloperLogin
                ? _buildDeveloperLoginForm()
                : _buildBlockedMessage(),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedMessage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Warning Icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.block,
            size: 64,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 32),

        // Title
        const Text(
          'Virtual Machine Detected',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Subtitle with detected VM
        if (widget.detectedVm != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Detected: ${widget.detectedVm}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Blocked reason if specific
        if (_blockedReason != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  _blockedReason!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Message
        Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: const Text(
            'A1 Tools cannot run in a virtual machine environment.\n\n'
            'This restriction is in place to ensure the security and '
            'integrity of the application and its data.\n\n'
            'Please install and run A1 Tools directly on your physical computer.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),

        // Real-time monitoring indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: _isCheckingStatus
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Monitoring for access changes...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Contact Support Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: const Column(
            children: [
              Text(
                'Need Help?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'If you believe this is an error, please contact IT support.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white60,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: 18,
                    color: Color(0xFFF49320),
                  ),
                  SizedBox(width: 8),
                  SelectableText(
                    'support@a-1chimney.com',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFF49320),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Update Available Banner
        if (_updateAvailable && _latestVersion != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.system_update,
                      color: Colors.green,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Update Available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Version $_latestVersion is available (current: $_currentVersion)',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This update may fix the VM detection issue.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isDownloading) ...[
                  // Download progress
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ] else if (_downloadError != null) ...[
                  // Download error with retry
                  Column(
                    children: [
                      Text(
                        _downloadError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _downloadUpdate,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _openUpdateInBrowser,
                            icon: const Icon(Icons.open_in_browser, size: 18),
                            label: const Text('Open in Browser'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              side: const BorderSide(color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ] else ...[
                  // Download buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _downloadUpdate,
                        icon: const Icon(Icons.download),
                        label: const Text('Download & Install'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _openUpdateInBrowser,
                        icon: const Icon(Icons.open_in_browser, size: 18),
                        label: const Text('Browser'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ] else if (_isCheckingUpdate) ...[
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Checking for updates...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],

        // Buttons Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Exit Button
            ElevatedButton.icon(
              onPressed: () {
                if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                  exit(0);
                } else {
                  SystemNavigator.pop();
                }
              },
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Exit Application'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Developer Login Button
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showDeveloperLogin = true;
                });
              },
              icon: const Icon(Icons.developer_mode),
              label: const Text('Developer Login'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),

        // Debug info (only visible in debug mode)
        if (widget.indicators.isNotEmpty) ...[
          const SizedBox(height: 48),
          ExpansionTile(
            title: const Text(
              'Technical Details',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white38,
              ),
            ),
            collapsedIconColor: Colors.white38,
            iconColor: Colors.white38,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.indicators
                      .map((i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '• $i',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white38,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDeveloperLoginForm() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Back Button
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showDeveloperLogin = false;
                  _errorMessage = null;
                });
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white60,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Developer Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF49320).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF49320).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.developer_mode,
              size: 40,
              color: Color(0xFFF49320),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          const Text(
            'Developer Login',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in with a developer or admin account to bypass VM restriction',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white60,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Error Message
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Username Field
          TextField(
            controller: _usernameController,
            enabled: !_isLoading,
            decoration: InputDecoration(
              labelText: 'Username',
              prefixIcon: const Icon(Icons.person_outline),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFF49320)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          // Password Field
          TextField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFF49320)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _attemptDeveloperLogin(),
          ),
          const SizedBox(height: 24),

          // Login Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _attemptDeveloperLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF49320),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: const Color(0xFFF49320).withValues(alpha: 0.5),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Info text
          const Text(
            'After successful login, please restart the application.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
