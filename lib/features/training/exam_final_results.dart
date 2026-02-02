import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

enum UserRole { technician, dispatcher }

class ExamFinalResultsScreen extends StatefulWidget {
  final String siteUrl;
  final String basicAuthHeader;

  const ExamFinalResultsScreen({
    super.key,
    required this.siteUrl,
    required this.basicAuthHeader,
  });

  @override
  State<ExamFinalResultsScreen> createState() => _ExamFinalResultsScreenState();
}

class _ExamFinalResultsScreenState extends State<ExamFinalResultsScreen> {
  // UI state
  UserRole _selectedRole = UserRole.dispatcher; // default to dispatcher
  bool _loadingUsers = false;
  bool _loadingResult = false;
  String? _errorUsers;
  String? _errorResult;
  String _search = '';

  // Data
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _selectedUser;
  Map<String, dynamic>? _quizResult;

  static const _accent = Color(0xFFF49320);

  // Dispatcher Final Exam info
  static const int _dispatcherQuizId = 5660;
  static const String _dispatcherQuizTitle = 'Dispatcher Final Exam';

  @override
  void initState() {
    super.initState();
    _loadUsersForRole(_selectedRole);
  }

  // ---------- Networking helpers ----------

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

  Future<void> _loadUsersForRole(UserRole role) async {
    setState(() {
      _selectedRole = role;
      _loadingUsers = true;
      _errorUsers = null;
      _users = [];
      _selectedUser = null;
      _quizResult = null;
      _errorResult = null;
    });

    final roleSlug = role == UserRole.dispatcher ? 'dispatcher' : 'technician';

    try {
      // WordPress core users endpoint supports ?roles=<role>
      final data = await _httpJson(
        'GET',
        '/wp-json/wp/v2/users?per_page=100&roles=$roleSlug&context=edit',
        headers: {'Authorization': widget.basicAuthHeader},
      );

      if (data is List) {
        final parsed = data.map<Map<String, dynamic>>((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return {
            'id': m['id'],
            'name': (m['name'] ?? m['username'] ?? m['slug'] ?? 'Unknown').toString(),
            'username': (m['slug'] ?? m['name'] ?? '').toString(),
            'email': (m['email'] ?? '').toString(),
          };
        }).toList();

        parsed.sort((a, b) => (a['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b['name'] ?? '').toString().toLowerCase()));

        setState(() {
          _users = parsed;
        });
      } else {
        setState(() => _errorUsers = 'Unexpected users response.');
      }
    } catch (e) {
      debugPrint('[ExamFinalResults] Failed to load users: \$e');
      setState(() => _errorUsers = 'Failed to load users.');
    } finally {
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadDispatcherQuizResultForUser(Map<String, dynamic> user) async {
    setState(() {
      _selectedUser = user;
      _quizResult = null;
      _errorResult = null;
      _loadingResult = true;
    });

    try {
      final data = await _httpJson(
        'GET',
        '/wp-json/a1tools/v1/quiz_result?user_id=${user["id"]}&quiz_id=$_dispatcherQuizId',
        headers: {'Authorization': widget.basicAuthHeader},
      );

      if (data is Map && data.isNotEmpty) {
        // Expect fields: score, total, percentage, passed, time_spent, date, quiz_title
        setState(() => _quizResult = data.cast<String, dynamic>());
      } else if (data is List && data.isNotEmpty) {
        // Some implementations may return a single-item list
        final first = Map<String, dynamic>.from(data.first as Map);
        setState(() => _quizResult = first);
      } else {
        setState(() => _errorResult = 'No attempt found for $_dispatcherQuizTitle.');
      }
    } catch (e) {
      debugPrint('[ExamFinalResults] Failed to load quiz result: \$e');
      setState(() => _errorResult = 'Failed to load quiz result.');
    } finally {
      setState(() => _loadingResult = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Results'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadingUsers
                ? null
                : () => _loadUsersForRole(_selectedRole),
          ),
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
                  // Left: users list
                  Flexible(
                    flex: 2,
                    child: _buildUsersPane(isDark, cardColor),
                  ),
                  const SizedBox(width: 16),
                  // Right: result details (only relevant for dispatcher)
                  Flexible(
                    flex: 3,
                    child: _buildResultPane(isDark, cardColor),
                  ),
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
                if (_selectedRole == UserRole.technician) {
                  return _accent.withValues(alpha: isDark ? 0.2 : 0.08);
                }
                return isDark ? const Color(0xFF1E1E1E) : Colors.white;
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
                if (_selectedRole == UserRole.dispatcher) {
                  return _accent.withValues(alpha: isDark ? 0.2 : 0.08);
                }
                return isDark ? const Color(0xFF1E1E1E) : Colors.white;
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
      decoration: const InputDecoration(
        hintText: 'Search by name or username',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
    );
  }

  Widget _buildUsersPane(bool isDark, Color cardColor) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    if (_loadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorUsers != null) {
      return Center(
        child: Text(
          _errorUsers!,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_users.isEmpty) {
      return Center(
        child: Text(
          'No users found.',
          style: TextStyle(color: subtitleColor),
        ),
      );
    }

    final filtered = _users.where((u) {
      if (_search.isEmpty) return true;
      final name = (u['name'] ?? '').toString().toLowerCase();
      final username = (u['username'] ?? '').toString().toLowerCase();
      return name.contains(_search) || username.contains(_search);
    }).toList();

    return Card(
      elevation: 2,
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final u = filtered[i];
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
                    style: TextStyle(color: subtitleColor),
                  )
                : null,
            selected: isSelected,
            selectedTileColor: _accent.withValues(alpha: isDark ? 0.2 : 0.08),
            onTap: () {
              if (_selectedRole == UserRole.dispatcher) {
                _loadDispatcherQuizResultForUser(u);
              } else {
                // Technician exam not configured yet
                setState(() {
                  _selectedUser = u;
                  _quizResult = null;
                  _errorResult = 'Technician final exam not configured yet.';
                });
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildResultPane(bool isDark, Color cardColor) {
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;
    final dividerColor = isDark ? const Color(0xFF3A3A3A) : Colors.black12;

    // If no user selected yet
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

    if (_loadingResult) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorResult != null) {
      return Card(
        elevation: 2,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _errorResult!,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // For dispatcher: show progress bar and score
    if (_selectedRole == UserRole.dispatcher) {
      if (_quizResult == null || _quizResult!.isEmpty) {
        return Card(
          elevation: 2,
          color: cardColor,
          surfaceTintColor: Colors.transparent,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No attempt found for Dispatcher Final Exam.',
                style: TextStyle(color: subtitleColor),
              ),
            ),
          ),
        );
      }

      final userName = (_selectedUser!['name'] ?? 'User').toString();
      final quizTitle = (_quizResult!['quiz_title'] ?? _dispatcherQuizTitle).toString();
      final score = _toDouble(_quizResult!['score']);
      final total = _toDouble(_quizResult!['total']);
      final pct = _computePct(score, total);
      final passed = (_quizResult!['passed']?.toString().toLowerCase() == 'true') ||
          (_quizResult!['passed'] == true);
      final timeSpent = (_quizResult!['time_spent'] ?? '-').toString();
      final date = (_quizResult!['date'] ?? '-').toString();

      final barColor = passed ? Colors.green : Colors.blue;

      return Card(
        elevation: 2,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                userName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                quizTitle,
                style: TextStyle(color: subtitleColor),
              ),
              const SizedBox(height: 12),

              // Progress bar
              LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                color: barColor,
                backgroundColor: isDark ? const Color(0xFF3A3A3A) : Colors.grey[300],
                minHeight: 10,
              ),
              const SizedBox(height: 8),

              // Percentage + score out of total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${pct.toStringAsFixed(2)}%',
                    style: TextStyle(fontWeight: FontWeight.w700, color: barColor),
                  ),
                  Text(
                    '${_fmt(score)} / ${_fmt(total)} points',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: dividerColor),
              const SizedBox(height: 8),

              _kv('Passed', passed ? 'YES' : 'NO', subtitleColor, textColor),
              _kv('Date', date, subtitleColor, textColor),
              _kv('Time Spent', timeSpent, subtitleColor, textColor),
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recheck'),
                  onPressed: () {
                    final u = _selectedUser;
                    if (u != null) _loadDispatcherQuizResultForUser(u);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Technician role selected (not configured)
    return Card(
      elevation: 2,
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Technician final exam not configured yet.',
            style: TextStyle(color: subtitleColor),
          ),
        ),
      ),
    );
  }

  // ---------- Helpers ----------

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  double _computePct(double score, double total) {
    if (total <= 0) return 0.0;
    return (score / total) * 100.0;
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
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