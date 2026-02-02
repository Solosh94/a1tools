import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../admin/report_lookup_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../training/exam_final_results.dart';
import '../timeclock/scheduling_screen.dart';
import '../../summary_screen.dart';
import '../../config/api_config.dart';
import '../../app_theme.dart';

class AdminWpApiScreen extends StatefulWidget {
  /// Optional pre-authenticated header to skip login
  final String? basicAuthHeader;
  
  const AdminWpApiScreen({super.key, this.basicAuthHeader});

  @override
  State<AdminWpApiScreen> createState() => _AdminWpApiScreenState();
}

class _AdminWpApiScreenState extends State<AdminWpApiScreen> {
  final _siteUrl = ApiConfig.baseUrl;

  final _adminUserCtrl = TextEditingController();
  final _adminPassCtrl = TextEditingController();

  final _newUsernameCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();

  // Secure storage (persist for 1 week)
  static const _storage = FlutterSecureStorage();
  static const _kHeader = 'a1_admin_basic_header';
  static const _kSetAt = 'a1_admin_basic_set_at_ms';
  static const _maxAgeDays = 7;

  String _roleSlug = 'technician'; // technician or dispatcher
  String _deleteRoleSlug = 'technician'; // role filter for deletion

  bool _authed = false;
  bool _busy = false;
  bool _showAccountCreation = false;
  bool _showUserDeletion = false;
  String? _message;

  String? _storedHeader;

  // For user deletion list
  List<dynamic> _usersForDeletion = [];
  bool _loadingUsers = false;

  static const Color _accent = AppColors.accent;

  bool get _canSignIn =>
      _adminUserCtrl.text.trim().isNotEmpty &&
      _adminPassCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _adminUserCtrl.addListener(_onCredsChanged);
    _adminPassCtrl.addListener(_onCredsChanged);
    
    // If pre-authenticated header is provided, use it directly
    if (widget.basicAuthHeader != null) {
      _storedHeader = widget.basicAuthHeader;
      _authed = true;
    } else {
      _loadStoredAuth();
    }
  }

  @override
  void dispose() {
    _adminUserCtrl.removeListener(_onCredsChanged);
    _adminPassCtrl.removeListener(_onCredsChanged);
    _adminUserCtrl.dispose();
    _adminPassCtrl.dispose();
    _newUsernameCtrl.dispose();
    _newEmailCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  void _onCredsChanged() => setState(() {});

  // ---- Auth header helpers --------------------------------------------------

  String get _typedBasicHeader {
    final user = _adminUserCtrl.text.trim();
    final pass = _adminPassCtrl.text;
    final pair = '$user:$pass';
    final b64 = base64Encode(utf8.encode(pair));
    return 'Basic $b64';
  }

  String get _effectiveAuthHeader => _storedHeader ?? _typedBasicHeader;

  Future<void> _saveHeader(String header) async {
    final now = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.write(key: _kHeader, value: header);
    await _storage.write(key: _kSetAt, value: now);
  }

  Future<void> _clearHeader() async {
    await _storage.delete(key: _kHeader);
    await _storage.delete(key: _kSetAt);
  }

  Future<String?> _loadHeaderIfFresh() async {
    final header = await _storage.read(key: _kHeader);
    final tsStr = await _storage.read(key: _kSetAt);
    if (header == null || tsStr == null) return null;
    final setAt = int.tryParse(tsStr) ?? 0;
    final ageDays = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(setAt))
        .inDays;
    if (ageDays >= _maxAgeDays) return null;
    return header;
  }

  // ---- HTTP helper ----------------------------------------------------------

  Future<dynamic> _httpJson(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, Uri.parse('$_siteUrl$path'));
      headers?.forEach(req.headers.set);
      if (body != null) {
        final data = utf8.encode(jsonEncode(body));
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        req.add(data);
      }

      final res = await req.close();
      final txt = await utf8.decodeStream(res);
      final status = res.statusCode;

      if (status >= 200 && status < 300) {
        if (txt.isEmpty) return {};
        return jsonDecode(txt);
      } else {
        throw HttpException('HTTP $status: $txt');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _probeAuth(String header) async {
    try {
      final resp = await _httpJson(
        'GET',
        '/wp-json/a1tools/v1/progress?list=users',
        headers: {'Authorization': header},
      );
      return resp is List;
    } catch (e) {
      debugPrint('[AdminWpApiScreen] Error: $e');
      return false;
    }
  }

  // ---- Stored auth bootstrap -----------------------------------------------

  Future<void> _loadStoredAuth() async {
    final header = await _loadHeaderIfFresh();
    if (!mounted) return;

    if (header != null) {
      setState(() {
        _busy = true;
        _message = null;
      });
      final ok = await _probeAuth(header);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _storedHeader = header;
          _authed = true;
          _message = 'Authenticated (saved session)';
        });
      } else {
        await _clearHeader();
      }
      setState(() => _busy = false);
    }
  }

  // ---- Actions --------------------------------------------------------------

  Future<void> _signIn() async {
    if (!_canSignIn) {
      setState(() => _message = 'Please enter both username and password.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    final header = _typedBasicHeader;

    try {
      final ok = await _probeAuth(header);
      if (ok) {
        await _saveHeader(header);
        setState(() {
          _storedHeader = header;
          _authed = true;
          _message = 'Authenticated successfully!';
        });
      } else {
        setState(() => _message = 'Authentication failed.');
      }
    } catch (e) {
      debugPrint('[AdminWpApiScreen] Authentication error: \$e');
      setState(() => _message = 'Authentication failed.');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _createUser() async {
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final body = {
        'username': _newUsernameCtrl.text.trim(),
        'email': _newEmailCtrl.text.trim(),
        'password': _newPasswordCtrl.text,
        'roles': [_roleSlug],
      };

      final response = await _httpJson(
        'POST',
        '/wp-json/wp/v2/users',
        headers: {
          'Authorization': _effectiveAuthHeader,
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response is Map && response.containsKey('id')) {
        setState(() {
          _message = 'User created successfully (ID: ${response['id']}).';
        });
      } else {
        setState(() {
          _message = 'Unexpected response: $response';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Failed to create user: $e';
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  // --- User deletion helpers -------------------------------------------------

  Future<void> _loadUsersForDeletion() async {
    setState(() {
      _busy = true;
      _loadingUsers = true;
      _message = null;
      _usersForDeletion = [];
    });

    try {
      final resp = await _httpJson(
        'GET',
        '/wp-json/wp/v2/users?per_page=100&roles=$_deleteRoleSlug',
        headers: {
          'Authorization': _effectiveAuthHeader,
        },
      );

      if (resp is List) {
        setState(() {
          _usersForDeletion = resp;
        });
      } else {
        setState(() {
          _message = 'Unexpected users response: $resp';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Failed to load users: $e';
      });
    } finally {
      setState(() {
        _busy = false;
        _loadingUsers = false;
      });
    }
  }

  Future<void> _confirmAndDeleteUser(Map<String, dynamic> user) async {
    final idNum = user['id'] as num?;
    final userId = idNum?.toInt();
    if (userId == null) return;

    final username = (user['username'] ?? user['name'] ?? '').toString();

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Permanent Deletion'),
                ],
              ),
              content: const Text(
                'You are about to permanently delete this user.\n\n'
                'WARNING: This action cannot be undone.\n\n'
                'All content will be reassigned to the default admin user.\n\n'
                'Are you sure you want to proceed?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      const reassignTargetUserId = 1;

      await _httpJson(
        'DELETE',
        '/wp-json/wp/v2/users/$userId?force=true&reassign=$reassignTargetUserId',
        headers: {
          'Authorization': _effectiveAuthHeader,
        },
      );

      setState(() {
        _usersForDeletion.removeWhere(
          (u) => (u is Map && (u['id'] as num?)?.toInt() == userId),
        );
        _message = 'User "$username" deleted successfully.';
      });
    } catch (e) {
      setState(() {
        _message = 'Failed to delete user: $e';
      });
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  // --- UI blocks -------------------------------------------------------------

  Widget _buildLoginForm(ButtonStyle btnStyle, bool isDark) {
    return Column(
      children: [
        TextField(
          controller: _adminUserCtrl,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.username],
          decoration: const InputDecoration(labelText: 'Admin Username'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _adminPassCtrl,
          obscureText: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Admin Password'),
          onSubmitted: (_) {
            if (_canSignIn && !_busy) _signIn();
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: btnStyle,
            onPressed: (_canSignIn && !_busy) ? _signIn : null,
            child: Text(
              'Sign In',
              style: TextStyle(
                color: isDark ? _accent : Colors.black,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboard(ButtonStyle btnStyle, bool isDark) {
    if (_showAccountCreation) {
      return _buildAccountCreation(btnStyle, isDark);
    }
    if (_showUserDeletion) {
      return _buildUserDeletion(btnStyle, isDark);
    }

    final buttonTextColor = isDark ? _accent : Colors.black;
    
    // If pre-authenticated from management screen, only show user creation/deletion
    final bool isPreAuthed = widget.basicAuthHeader != null;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: btnStyle,
            onPressed: _busy
                ? null
                : () => setState(() {
                      _showAccountCreation = true;
                      _showUserDeletion = false;
                      _message = null;
                    }),
            child: Text(
              'New User Creation',
              style: TextStyle(color: buttonTextColor, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: btnStyle,
            onPressed: _busy
                ? null
                : () => setState(() {
                      _showUserDeletion = true;
                      _showAccountCreation = false;
                      _message = null;
                    }),
            child: Text(
              'User Deletion',
              style: TextStyle(color: buttonTextColor, fontSize: 16),
            ),
          ),
        ),
        
        // Only show other legacy tools if NOT pre-authenticated (standalone access)
        if (!isPreAuthed) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: btnStyle,
              onPressed: _busy
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReportLookupScreen(
                            siteUrl: _siteUrl,
                            basicAuthHeader: _effectiveAuthHeader,
                          ),
                        ),
                      );
                    },
              child: Text(
                'Training Progress Report',
                style: TextStyle(color: buttonTextColor, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              style: btnStyle,
              onPressed: _busy
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ExamFinalResultsScreen(
                            siteUrl: _siteUrl,
                            basicAuthHeader: _effectiveAuthHeader,
                          ),
                        ),
                      );
                    },
              child: Text(
                'Final Exam Results',
              style: TextStyle(color: buttonTextColor, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: btnStyle,
            onPressed: _busy
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SchedulingScreen(),
                      ),
                    );
                  },
            child: Text(
              'Routing Tool',
              style: TextStyle(color: buttonTextColor, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: btnStyle,
            onPressed: _busy
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SummaryScreen(
                          n8nWebhookUrl: ApiConfig.n8nDispatcherSummary,
                        ),
                      ),
                    );
                  },
            child: Text(
              'Performance Summary',
              style: TextStyle(color: buttonTextColor, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: () async {
              await _clearHeader();
              setState(() {
                _storedHeader = null;
                _authed = false;
                _showAccountCreation = false;
                _showUserDeletion = false;
                _usersForDeletion = [];
                _message = 'Signed out.';
              });
            },
            child: const Text('Sign out'),
          ),
        ),
        ], // End of if (!isPreAuthed)
      ],
    );
  }

  Widget _buildAccountCreation(ButtonStyle btnStyle, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final buttonTextColor = isDark ? _accent : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _showAccountCreation = false;
                  _message = null;
                });
              },
            ),
            Text(
              'Account Creation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButton<String>(
          value: _roleSlug,
          dropdownColor: isDark ? const Color(0xFF252525) : Colors.white,
          items: const [
            DropdownMenuItem(value: 'technician', child: Text('Technician')),
            DropdownMenuItem(value: 'dispatcher', child: Text('Dispatcher')),
            DropdownMenuItem(value: 'remote_dispatcher', child: Text('Remote Dispatcher')),
          ],
          onChanged: (v) => setState(() => _roleSlug = v ?? 'technician'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newUsernameCtrl,
          decoration: const InputDecoration(labelText: 'New Username'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newEmailCtrl,
          decoration: const InputDecoration(labelText: 'New Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPasswordCtrl,
          decoration: const InputDecoration(labelText: 'New Password'),
          obscureText: true,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: btnStyle,
            onPressed: _busy ? null : _createUser,
            child: Text(
              'Create User',
              style: TextStyle(color: buttonTextColor, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserDeletion(ButtonStyle btnStyle, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;
    final buttonTextColor = isDark ? _accent : Colors.black;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _showUserDeletion = false;
                  _usersForDeletion = [];
                  _message = null;
                });
              },
            ),
            Text(
              'User Deletion',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Role: ',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _deleteRoleSlug,
              dropdownColor: cardColor,
              items: const [
                DropdownMenuItem(value: 'technician', child: Text('Technician')),
                DropdownMenuItem(value: 'dispatcher', child: Text('Dispatcher')),
                DropdownMenuItem(value: 'remote_dispatcher', child: Text('Remote Dispatcher')),
              ],
              onChanged: (v) =>
                  setState(() => _deleteRoleSlug = v ?? 'technician'),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 40,
              child: OutlinedButton(
                style: btnStyle,
                onPressed: _busy ? null : _loadUsersForDeletion,
                child: Text(
                  'Load Users',
                  style: TextStyle(color: buttonTextColor),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'WARNING: Deleting a user is permanent and cannot be undone.\n'
          'All their content will be reassigned to the default admin user.',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (_loadingUsers)
          const Center(child: CircularProgressIndicator())
        else if (_usersForDeletion.isEmpty)
          Text(
            'No users loaded. Choose a role and tap "Load Users".',
            style: TextStyle(color: subtitleColor),
          )
        else
          SizedBox(
            height: 320,
            child: Card(
              color: cardColor,
              child: ListView.separated(
                itemCount: _usersForDeletion.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final raw = _usersForDeletion[index];
                  if (raw is! Map) return const SizedBox.shrink();
                  final user = raw.cast<String, dynamic>();
                  final username =
                      (user['username'] ?? user['name'] ?? '').toString();
                  final email = (user['email'] ?? '').toString();
                  final id = (user['id'] as num?)?.toInt();

                  return ListTile(
                    title: Text(username),
                    subtitle: Text(
                      'ID: $id â€¢ $email',
                      style: TextStyle(color: subtitleColor),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed:
                          _busy ? null : () => _confirmAndDeleteUser(user),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // --- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final outlinedBtnStyle = OutlinedButton.styleFrom(
      foregroundColor: isDark ? _accent : Colors.black,
      side: const BorderSide(color: _accent, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      backgroundColor: cardColor,
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return _accent.withValues(alpha: 0.15);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return _accent.withValues(alpha: 0.08);
        }
        return null;
      }),
    );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: _authed ? 480 : 360,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_authed) _buildLoginForm(outlinedBtnStyle, isDark),
                        if (_authed) _buildDashboard(outlinedBtnStyle, isDark),
                        const SizedBox(height: 20),
                        if (_busy) const CircularProgressIndicator(),
                        if (_message != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            _message!,
                            style: TextStyle(
                              color: _message!.toLowerCase().contains('fail') ||
                                      _message!.toLowerCase().contains('error')
                                  ? Colors.red
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}