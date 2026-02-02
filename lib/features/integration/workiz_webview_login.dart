// lib/workiz_webview_login.dart
// WebView-based login for Workiz that supports 2FA
// Opens Workiz login page, lets user complete full auth flow, extracts session cookies

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

// Platform-specific imports
import 'package:webview_windows/webview_windows.dart' as windows_webview;

/// Result of the WebView login process
class WorkizLoginResult {
  final bool success;
  final String? sessionId;
  final String? userId;
  final String? accountId;
  final String? franchiseId;
  final String? error;

  WorkizLoginResult({
    required this.success,
    this.sessionId,
    this.userId,
    this.accountId,
    this.franchiseId,
    this.error,
  });
}

/// WebView login screen for Workiz
/// Allows completing full login flow including 2FA
class WorkizWebViewLoginScreen extends StatefulWidget {
  final int locationId;
  final String locationName;
  final String userRole;

  const WorkizWebViewLoginScreen({
    super.key,
    required this.locationId,
    required this.locationName,
    required this.userRole,
  });

  @override
  State<WorkizWebViewLoginScreen> createState() => _WorkizWebViewLoginScreenState();
}

class _WorkizWebViewLoginScreenState extends State<WorkizWebViewLoginScreen> {
  static const String _baseUrl = ApiConfig.workizLocations;

  // Windows WebView controller
  windows_webview.WebviewController? _windowsController;
  StreamSubscription<String>? _urlSubscription;

  bool _isLoading = true;
  bool _isExtracting = false;
  String _statusMessage = 'Initializing...';
  String? _error;
  bool _loginDetected = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    if (Platform.isWindows) {
      await _initWindowsWebView();
    } else {
      setState(() {
        _error = 'WebView login is only supported on Windows';
        _isLoading = false;
      });
    }
  }

  Future<void> _initWindowsWebView() async {
    try {
      setState(() => _statusMessage = 'Loading WebView...');

      _windowsController = windows_webview.WebviewController();
      await _windowsController!.initialize();

      // Listen for URL changes to detect successful login
      _urlSubscription = _windowsController!.url.listen((url) {
        _onUrlChanged(url);
      });

      // Navigate to Workiz login
      await _windowsController!.loadUrl(ApiConfig.workizLogin);

      setState(() {
        _isLoading = false;
        _statusMessage = 'Please login to Workiz';
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize WebView: $e';
        _isLoading = false;
      });
    }
  }

  void _onUrlChanged(String url) {
    debugPrint('Workiz WebView URL: $url');

    // Check if user has logged in successfully
    // After login, Workiz redirects to /home/, /jobs/, or similar
    if (!_loginDetected &&
        !url.contains('/login') &&
        !url.contains('/forgot') &&
        (url.contains('app.workiz.com/') &&
         (url.contains('/home') ||
          url.contains('/jobs') ||
          url.contains('/dashboard') ||
          url.contains('/calendar') ||
          url.endsWith('app.workiz.com/')))) {
      _loginDetected = true;
      _extractCredentials();
    }
  }

  Future<void> _extractCredentials() async {
    if (_isExtracting) return;

    setState(() {
      _isExtracting = true;
      _statusMessage = 'Login detected! Extracting session...';
    });

    try {
      // Step 1: Get cookies and basic info (synchronous)
      const cookiesScript = '''
        (function() {
          var cookies = document.cookie;
          var sessionId = null;
          var userId = null;
          var accountId = null;
          var franchiseId = null;

          // Parse cookies
          var cookieParts = cookies.split(';');
          for (var i = 0; i < cookieParts.length; i++) {
            var cookie = cookieParts[i].trim();
            if (cookie.startsWith('sendajob_sessid=')) {
              sessionId = cookie.substring('sendajob_sessid='.length);
            }
            if (cookie.startsWith('sendajob_user=')) {
              var userCookie = cookie.substring('sendajob_user='.length);
              try {
                var decoded = atob(userCookie);
                var match = decoded.match(/userid_(\\d+)/);
                if (match) {
                  userId = match[1];
                }
              } catch(e) {
                console.warn('[WorkizLogin] Failed to decode user cookie:', e.message || e);
              }
            }
            if (cookie.startsWith('sajFranchise=')) {
              franchiseId = cookie.substring('sajFranchise='.length);
            }
          }

          // Try to get info from window object
          try {
            if (window.workiz && window.workiz.accountId) {
              accountId = window.workiz.accountId.toString();
            }
            if (window.workiz && window.workiz.franchiseId) {
              franchiseId = window.workiz.franchiseId.toString();
            }
            if (!userId && window.workiz && window.workiz.userId) {
              userId = window.workiz.userId.toString();
            }
            if (!userId && window.workiz && window.workiz.user && window.workiz.user.id) {
              userId = window.workiz.user.id.toString();
            }
            // Check for user in window.sajUser or similar
            if (!userId && window.sajUser && window.sajUser.id) {
              userId = window.sajUser.id.toString();
            }
            if (!userId && window.USER_ID) {
              userId = window.USER_ID.toString();
            }
          } catch(e) {
            console.warn('[WorkizLogin] Failed to read window object:', e.message || e);
          }

          return JSON.stringify({
            sessionId: sessionId,
            userId: userId,
            accountId: accountId,
            franchiseId: franchiseId,
            cookies: cookies
          });
        })();
      ''';

      String? resultJson;

      if (Platform.isWindows && _windowsController != null) {
        final result = await _windowsController!.executeScript(cookiesScript);
        // Windows webview returns the result directly
        resultJson = result?.toString();
        // Remove surrounding quotes if present
        if (resultJson != null && resultJson.startsWith('"') && resultJson.endsWith('"')) {
          resultJson = resultJson.substring(1, resultJson.length - 1);
          // Unescape JSON
          resultJson = resultJson.replaceAll('\\"', '"').replaceAll('\\\\', '\\');
        }
      }

      if (resultJson == null || resultJson.isEmpty) {
        throw Exception('Failed to extract cookies from WebView');
      }

      debugPrint('Extracted credentials JSON: $resultJson');

      final data = json.decode(resultJson);
      final sessionId = data['sessionId'];
      final userId = data['userId'];
      final accountId = data['accountId'];
      final franchiseId = data['franchiseId'];

      if (sessionId == null || sessionId.isEmpty) {
        throw Exception('No session ID found in cookies. Please try logging in again.');
      }

      // If we don't have userId, fetch via API call in WebView context
      String? finalUserId = userId;
      String? finalAccountId = accountId;

      if (finalUserId == null || finalUserId.isEmpty) {
        setState(() => _statusMessage = 'Getting user information...');

        // Fetch user info via JavaScript in WebView (has proper session context)
        const userInfoScript = '''
          (function() {
            var xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://app.workiz.com/ajaxc/user/load/', false);
            xhr.setRequestHeader('Accept', 'application/json');
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
            try {
              xhr.send();
              if (xhr.status === 200) {
                var data = JSON.parse(xhr.responseText);
                var userInfo = data.data || data.user || data;
                return JSON.stringify({
                  userId: (userInfo.id || userInfo.user_id || '').toString(),
                  accountId: (userInfo.account_id || userInfo.accountId || '').toString()
                });
              } else {
                console.warn('[WorkizLogin] User API returned status:', xhr.status);
              }
            } catch(e) {
              console.warn('[WorkizLogin] Failed to fetch user info:', e.message || e);
            }
            return JSON.stringify({userId: '', accountId: ''});
          })();
        ''';

        if (Platform.isWindows && _windowsController != null) {
          final userResult = await _windowsController!.executeScript(userInfoScript);
          var userJson = userResult?.toString();
          if (userJson != null && userJson.startsWith('"') && userJson.endsWith('"')) {
            userJson = userJson.substring(1, userJson.length - 1);
            userJson = userJson.replaceAll('\\"', '"').replaceAll('\\\\', '\\');
          }
          if (userJson != null && userJson.isNotEmpty) {
            try {
              final userData = json.decode(userJson);
              if (userData['userId'] != null && userData['userId'].toString().isNotEmpty) {
                finalUserId = userData['userId'].toString();
              }
              if (userData['accountId'] != null && userData['accountId'].toString().isNotEmpty) {
                finalAccountId = userData['accountId'].toString();
              }
            } catch (e) {
  debugPrint('[WorkizWebviewLogin] Error: $e');
}
          }
        }
      }

      // If still no userId, try account/info endpoint
      if (finalUserId == null || finalUserId.isEmpty) {
        const accountInfoScript = '''
          (function() {
            var xhr = new XMLHttpRequest();
            xhr.open('GET', 'https://app.workiz.com/ajaxc/account/info/', false);
            xhr.setRequestHeader('Accept', 'application/json');
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
            try {
              xhr.send();
              if (xhr.status === 200) {
                var data = JSON.parse(xhr.responseText);
                var info = data.data || data;
                return JSON.stringify({
                  userId: (info.user_id || info.userId || info.owner_id || '').toString(),
                  accountId: (info.account_id || info.id || '').toString()
                });
              } else {
                console.warn('[WorkizLogin] Account API returned status:', xhr.status);
              }
            } catch(e) {
              console.warn('[WorkizLogin] Failed to fetch account info:', e.message || e);
            }
            return JSON.stringify({userId: '', accountId: ''});
          })();
        ''';

        if (Platform.isWindows && _windowsController != null) {
          final accountResult = await _windowsController!.executeScript(accountInfoScript);
          var accountJson = accountResult?.toString();
          if (accountJson != null && accountJson.startsWith('"') && accountJson.endsWith('"')) {
            accountJson = accountJson.substring(1, accountJson.length - 1);
            accountJson = accountJson.replaceAll('\\"', '"').replaceAll('\\\\', '\\');
          }
          if (accountJson != null && accountJson.isNotEmpty) {
            try {
              final accountData = json.decode(accountJson);
              if (accountData['userId'] != null && accountData['userId'].toString().isNotEmpty) {
                finalUserId = accountData['userId'].toString();
              }
              if (accountData['accountId'] != null && accountData['accountId'].toString().isNotEmpty) {
                finalAccountId = accountData['accountId'].toString();
              }
            } catch (e) {
  debugPrint('[WorkizWebviewLogin] Error: $e');
}
          }
        }
      }

      if (finalUserId == null || finalUserId.isEmpty) {
        throw Exception('Could not determine user ID. Please try again.');
      }

      // Use userId as accountId fallback
      finalAccountId ??= finalUserId;

      // Save credentials to server
      setState(() => _statusMessage = 'Saving credentials...');

      await _saveCredentials(
        sessionId: sessionId,
        userId: finalUserId,
        accountId: finalAccountId,
        franchiseId: franchiseId,
      );

      if (mounted) {
        Navigator.pop(context, WorkizLoginResult(
          success: true,
          sessionId: sessionId,
          userId: finalUserId,
          accountId: finalAccountId,
          franchiseId: franchiseId,
        ));
      }
    } catch (e) {
      debugPrint('Error extracting credentials: $e');
      setState(() {
        _error = e.toString();
        _isExtracting = false;
        _loginDetected = false; // Allow retry
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _saveCredentials({
    required String sessionId,
    required String userId,
    required String accountId,
    String? franchiseId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl?action=save_credentials&requesting_role=${widget.userRole}'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'location_id': widget.locationId,
        'session_id': sessionId,
        'user_id': userId,
        'account_id': accountId,
        'franchise_id': franchiseId,
      }),
    ).timeout(const Duration(seconds: 15));

    final data = json.decode(response.body);
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to save credentials');
    }
  }

  @override
  void dispose() {
    _urlSubscription?.cancel();
    _windowsController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login to Workiz - ${widget.locationName}'),
        actions: [
          if (!_isLoading && _error == null)
            TextButton.icon(
              onPressed: _isExtracting ? null : () => _extractCredentials(),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Done', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, WorkizLoginResult(success: false, error: _error)),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isLoading = true;
                      });
                      _initWebView();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_statusMessage),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Status bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _isExtracting ? Colors.green.shade100 : Colors.blue.shade50,
          child: Row(
            children: [
              if (_isExtracting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  _loginDetected ? Icons.check_circle : Icons.info_outline,
                  size: 18,
                  color: _loginDetected ? Colors.green : Colors.blue,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: _isExtracting ? Colors.green.shade800 : Colors.blue.shade800,
                  ),
                ),
              ),
              if (!_isExtracting && !_loginDetected)
                TextButton(
                  onPressed: _extractCredentials,
                  child: const Text('Done'),
                ),
            ],
          ),
        ),
        // WebView
        Expanded(
          child: _buildWebView(),
        ),
      ],
    );
  }

  Widget _buildWebView() {
    if (Platform.isWindows && _windowsController != null) {
      return windows_webview.Webview(_windowsController!);
    }

    return const Center(
      child: Text('WebView not available on this platform'),
    );
  }
}
