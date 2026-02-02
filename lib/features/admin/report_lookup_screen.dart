import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum UserRole { technician, dispatcher }

class ReportLookupScreen extends StatefulWidget {
  final String siteUrl;
  final String basicAuthHeader;

  const ReportLookupScreen({
    super.key,
    required this.siteUrl,
    required this.basicAuthHeader,
  });

  @override
  State<ReportLookupScreen> createState() => _ReportLookupScreenState();
}

class _ReportLookupScreenState extends State<ReportLookupScreen> {
  // --- State ---
  UserRole _selectedRole = UserRole.technician;
  bool _loadingUsers = false;
  bool _loadingCourses = false;
  String? _errorUsers;
  String? _errorCourses;

  final TextEditingController _searchCtrl = TextEditingController();

  // Users (raw for current role), filtered (by search), and selection
  List<Map<String, dynamic>> _usersAll = [];
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _selectedUser;

  // Courses for the selected user
  List<Map<String, dynamic>> _courses = [];

  static const _accent = Color(0xFFF49320);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applySearch);
    _loadUsersForRole(_selectedRole);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applySearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- HTTP helper ---
  Future<dynamic> _httpJson(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('${widget.siteUrl}$path');
      final req = await client.openUrl(method, uri);
      headers?.forEach(req.headers.set);
      if (body != null) {
        final data = utf8.encode(jsonEncode(body));
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        req.add(data);
      }
      final res = await req.close();
      final txt = await utf8.decodeStream(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return txt.isEmpty ? {} : jsonDecode(txt);
      } else {
        throw HttpException('HTTP ${res.statusCode}: $txt');
      }
    } finally {
      client.close(force: true);
    }
  }

  // --- Data loaders ---
  Future<void> _loadUsersForRole(UserRole role) async {
    setState(() {
      _selectedRole = role;
      _loadingUsers = true;
      _errorUsers = null;
      _usersAll = [];
      _users = [];
      _selectedUser = null;
      _courses = [];
      _errorCourses = null;
    });

    final roleSlug = role == UserRole.dispatcher ? 'dispatcher' : 'technician';

    try {
      // Try your custom endpoint first (and pass role)
      final dynamic data = await _httpJson(
        'GET',
        '/wp-json/a1tools/v1/progress?list=users&role=$roleSlug',
        headers: {'Authorization': widget.basicAuthHeader},
      );

      List<Map<String, dynamic>> parsed = [];
      if (data is List) {
        parsed = data.map<Map<String, dynamic>>((e) {
          final m = Map<String, dynamic>.from(e as Map);
          final roles = (m['roles'] is List)
              ? List<String>.from(m['roles'])
              : const <String>[];
          return {
            'id': m['id'],
            'name': (m['name'] ?? m['username'] ?? 'Unknown').toString(),
            'username': (m['username'] ?? m['name'] ?? '').toString(),
            'roles': roles,
          };
        }).toList();
      }

      // Enforce client-side role filter
      List<Map<String, dynamic>> filtered = parsed
          .where((u) => ((u['roles'] as List?)?.cast<String>() ?? const <String>[])
              .contains(roleSlug))
          .toList();

      final rolesPresent = parsed.any((u) =>
          ((u['roles'] as List?)?.cast<String>() ?? const <String>[]).isNotEmpty);

      // Fallback to WP core users if needed (context=edit exposes 'roles')
      if (filtered.isEmpty || !rolesPresent) {
        final wpUsers = await _httpJson(
          'GET',
          '/wp-json/wp/v2/users?per_page=100&context=edit',
          headers: {'Authorization': widget.basicAuthHeader},
        );
        if (wpUsers is List) {
          final all = wpUsers.map<Map<String, dynamic>>((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final roles = (m['roles'] is List)
                ? List<String>.from(m['roles'])
                : const <String>[];
            return {
              'id': m['id'],
              'name': (m['name'] ?? m['username'] ?? m['slug'] ?? 'Unknown')
                  .toString(),
              'username': (m['slug'] ?? m['name'] ?? '').toString(),
              'roles': roles,
            };
          }).toList();

          filtered = all
              .where((u) =>
                  ((u['roles'] as List?)?.cast<String>() ?? const <String>[])
                      .contains(roleSlug))
              .toList();
        }
      }

      // Sort by display name
      filtered.sort((a, b) => (a['name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b['name'] ?? '').toString().toLowerCase()));

      setState(() {
        _usersAll = filtered;
      });
      _applySearch();
    } catch (e) {
      debugPrint('[ReportLookupScreen] Failed to load users: $e');
      setState(() => _errorUsers = 'Failed to load users.');
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  void _applySearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = _usersAll.where((u) {
      if (q.isEmpty) return true;
      final name = (u['name'] ?? '').toString().toLowerCase();
      final username = (u['username'] ?? '').toString().toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();

    setState(() {
      _users = list;
      if (_selectedUser != null &&
          !_users.any((u) => u['id'] == _selectedUser!['id'])) {
        _selectedUser = null;
        _courses = [];
      }
    });
  }

  Future<void> _loadProgressForUser(Map<String, dynamic> user) async {
    setState(() {
      _loadingCourses = true;
      _errorCourses = null;
      _selectedUser = user;
      _courses = [];
    });

    try {
      final data = await _httpJson(
        'GET',
        '/wp-json/a1tools/v1/progress?user_id=${user["id"]}',
        headers: {'Authorization': widget.basicAuthHeader},
      );

      if (data is List) {
        final list = data.cast<Map<String, dynamic>>();
        setState(() => _courses = list);
      } else {
        setState(() => _errorCourses = 'Unexpected response.');
      }
    } catch (e) {
      debugPrint('[ReportLookupScreen] Failed to load courses: $e');
      setState(() => _errorCourses = 'Failed to load courses.');
    } finally {
      setState(() => _loadingCourses = false);
    }
  }

  // --- UI building ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Report'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadingUsers ? null : () => _loadUsersForRole(_selectedRole),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildRoleButtons(isDark),
            const SizedBox(height: 12),
            _buildSearch(),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  // LEFT: users list
                  Flexible(flex: 2, child: _buildUsersPane(isDark, cardColor)),
                  const SizedBox(width: 16),
                  // RIGHT: courses/details
                  Flexible(flex: 3, child: _buildCoursesPane(isDark, cardColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButtons(bool isDark) {
    final btnStyle = OutlinedButton.styleFrom(
      foregroundColor: isDark ? _accent : Colors.black,
      side: const BorderSide(color: _accent, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    );

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: btnStyle.copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                return _selectedRole == UserRole.technician
                    ? _accent.withValues(alpha: isDark ? 0.2 : 0.08)
                    : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
              }),
            ),
            onPressed: _loadingUsers ? null : () => _loadUsersForRole(UserRole.technician),
            child: const Text('Technicians'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            style: btnStyle.copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                return _selectedRole == UserRole.dispatcher
                    ? _accent.withValues(alpha: isDark ? 0.2 : 0.08)
                    : (isDark ? const Color(0xFF1E1E1E) : Colors.white);
              }),
            ),
            onPressed: _loadingUsers ? null : () => _loadUsersForRole(UserRole.dispatcher),
            child: const Text('Dispatchers'),
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchCtrl,
      decoration: const InputDecoration(
        hintText: 'Search by name or username',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildUsersPane(bool isDark, Color cardColor) {
    final textColor = isDark ? Colors.white : Colors.black;

    if (_loadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorUsers != null) {
      return Card(
        elevation: 2,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _errorUsers!,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (_users.isEmpty) {
      return Card(
        elevation: 2,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No users found for this role.',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      child: ListView.separated(
        itemCount: _users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final u = _users[i];
          final isSelected = _selectedUser != null && _selectedUser!['id'] == u['id'];
          return ListTile(
            dense: true,
            title: Text(
              u['name'] ?? 'Unknown',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor),
            ),
            subtitle: (u['username'] != null && (u['username'] as String).isNotEmpty)
                ? Text(
                    '@${u['username']}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  )
                : null,
            selected: isSelected,
            selectedTileColor: _accent.withValues(alpha: isDark ? 0.2 : 0.08),
            onTap: () => _loadProgressForUser(u),
          );
        },
      ),
    );
  }

  Widget _buildCoursesPane(bool isDark, Color cardColor) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    if (_selectedUser == null) {
      return Card(
        elevation: 2,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select a user to see details.',
              style: TextStyle(color: subtitleColor),
            ),
          ),
        ),
      );
    }

    if (_loadingCourses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorCourses != null) {
      return Card(
        elevation: 2,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _errorCourses!,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return Card(
        elevation: 2,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No course data to show.',
              style: TextStyle(color: subtitleColor),
            ),
          ),
        ),
      );
    }

    // Render the courses list in a single scrollable card
    return Card(
      elevation: 2,
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _courses.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final course = _courses[i];
          final pct = (course['percentage'] ?? 0).toDouble();
          final stepsDone = (course['steps_done'] ?? 0).toString();
          final stepsTotal = (course['steps_total'] ?? 0).toString();
          final color = pct >= 100
              ? Colors.green
              : pct > 0
                  ? Colors.blue
                  : Colors.grey;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF3A3A3A) : Colors.black12,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  (course['title'] ?? 'Untitled').toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),

                // Progress bar
                LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  color: color,
                  backgroundColor: isDark ? const Color(0xFF3A3A3A) : Colors.grey[300],
                  minHeight: 10,
                ),
                const SizedBox(height: 8),

                // Percentage + steps
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${pct.toStringAsFixed(2)}%',
                      style: TextStyle(fontWeight: FontWeight.w700, color: color),
                    ),
                    Text(
                      '$stepsDone / $stepsTotal steps',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: isDark ? const Color(0xFF3A3A3A) : Colors.black12),
                const SizedBox(height: 8),

                _kv('Last Step', (course['last_step_title'] ?? '-').toString(), subtitleColor, textColor),
                _kv('Started On', _fmtDate(course['started_on']), subtitleColor, textColor),
                _kv('Last Updated', _fmtDate(course['last_updated']), subtitleColor, textColor),
                _kv('Last Login', _fmtDate(course['last_login']), subtitleColor, textColor),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Small helpers ---
  String _fmtDate(dynamic raw) {
    if (raw == null || raw == '-' || raw.toString().isEmpty) return '-';
    try {
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return raw.toString();
      return DateFormat('MMM d, yyyy - h:mm a').format(dt);
    } catch (e) {
      debugPrint('[ReportLookupScreen] Error: $e');
      return raw.toString();
    }
  }

  Widget _kv(String k, String v, Color labelColor, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(k, style: TextStyle(color: labelColor)),
          ),
          Expanded(
            flex: 4,
            child: Text(
              v,
              style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}