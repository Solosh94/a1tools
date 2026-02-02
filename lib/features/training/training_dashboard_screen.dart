// Training Dashboard Screen
// 
// Admin/Manager view showing:
// - Live progress of users currently taking tests
// - All users' training status
// - Completion statistics
// - Detailed results

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'training_models.dart';
import 'training_service.dart';
import '../../config/api_config.dart';
import '../../app_theme.dart';

class TrainingDashboardScreen extends StatefulWidget {
  final String currentUsername;
  final String currentRole;

  const TrainingDashboardScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  State<TrainingDashboardScreen> createState() => _TrainingDashboardScreenState();
}

class _TrainingDashboardScreenState extends State<TrainingDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const Color _accent = AppColors.accent;
  static const String _pictureUrl = ApiConfig.profilePicture;

  late TabController _tabController;
  Timer? _refreshTimer;

  List<TrainingTest> _tests = [];
  List<LiveProgressData> _liveProgress = [];
  List<UserTrainingStatus> _allUsers = [];
  List<TestResult> _allResults = [];
  List<UserKBProgress> _kbProgress = [];
  List<KnowledgeBaseData> _knowledgeBases = [];
  
  // Profile picture cache
  final Map<String, Uint8List> _profilePictureCache = {};
  
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
    
    // Refresh data periodically
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Load all data in parallel
      final results = await Future.wait([
        TrainingService.instance.getTests(), // Load all tests from database
        TrainingService.instance.getLiveProgress(),
        TrainingService.instance.getAllUsersStatus(),
        TrainingService.instance.getAllResults(),
        TrainingService.instance.getAllUsersKBProgress(),
        TrainingService.instance.getKnowledgeBases(), // Load all KBs
      ]);

      if (mounted) {
        setState(() {
          _tests = results[0] as List<TrainingTest>;
          _liveProgress = results[1] as List<LiveProgressData>;
          _allUsers = results[2] as List<UserTrainingStatus>;
          _allResults = results[3] as List<TestResult>;
          _kbProgress = results[4] as List<UserKBProgress>;
          _knowledgeBases = results[5] as List<KnowledgeBaseData>;
          _loading = false;
        });
        
        // Load profile pictures
        for (final user in _allUsers) {
          _loadProfilePicture(user.username);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load dashboard data: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadProfilePicture(String username) async {
    if (_profilePictureCache.containsKey(username)) return;
    
    try {
      final response = await http.get(
        Uri.parse('$_pictureUrl?username=${Uri.encodeComponent(username)}'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['picture'] != null) {
          final bytes = base64Decode(data['picture']);
          if (mounted) {
            setState(() {
              _profilePictureCache[username] = bytes;
            });
          }
        }
      }
    } catch (e) {
  debugPrint('[TrainingDashboardScreen] Error: $e');
}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadData(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Badge(
                isLabelVisible: _liveProgress.isNotEmpty,
                label: Text('${_liveProgress.length}'),
                child: const Icon(Icons.sensors),
              ),
              text: 'Live',
            ),
            const Tab(icon: Icon(Icons.quiz), text: 'Tests'),
            const Tab(icon: Icon(Icons.menu_book), text: 'Guides'),
            const Tab(icon: Icon(Icons.history), text: 'Results'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLiveTab(isDark),
                    _buildUsersTab(isDark),
                    _buildGuidesTab(isDark),
                    _buildResultsTab(isDark),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _loadData(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // LIVE TAB
  // ============================================================================

  Widget _buildLiveTab(bool isDark) {
    // Group live progress by test
    final Map<String, List<LiveProgressData>> progressByTest = {};
    for (final p in _liveProgress) {
      progressByTest.putIfAbsent(p.testId, () => []).add(p);
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats summary
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGuideStat(
                  icon: Icons.sensors,
                  value: '${_liveProgress.length}',
                  label: 'Active Now',
                  color: Colors.green,
                ),
                _buildGuideStat(
                  icon: Icons.quiz,
                  value: '${progressByTest.length}',
                  label: 'Tests In Progress',
                  color: Colors.blue,
                ),
                _buildGuideStat(
                  icon: Icons.trending_up,
                  value: _liveProgress.isNotEmpty
                      ? '${(_liveProgress.map((l) => l.currentAccuracy).reduce((a, b) => a + b) / _liveProgress.length * 100).toStringAsFixed(0)}%'
                      : '0%',
                  label: 'Avg Accuracy',
                  color: _accent,
                ),
              ],
            ),
          ),

          if (_liveProgress.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.sensors_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No Active Tests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No one is currently taking a test.',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            // Group by test like Guides tab
            ...progressByTest.entries.map((entry) {
              final testId = entry.key;
              final users = entry.value;
              final testTitle = users.isNotEmpty ? users.first.testTitle : testId;

              return _buildLiveTestSection(testTitle, users, isDark);
            }),
        ],
      ),
    );
  }

  Widget _buildLiveTestSection(String testTitle, List<LiveProgressData> users, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.quiz, color: Colors.green),
        ),
        title: Text(
          testTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${users.length} user${users.length != 1 ? 's' : ''} testing now',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: users.map((live) => _buildLiveUserRow(live, isDark)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveUserRow(LiveProgressData live, bool isDark) {
    final profilePicture = _profilePictureCache[live.username];
    final progress = live.totalQuestions > 0
        ? live.currentQuestion / live.totalQuestions
        : 0.0;
    final accuracyPercent = (live.currentAccuracy * 100).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: _accent.withValues(alpha: 0.2),
            backgroundImage: profilePicture != null ? MemoryImage(profilePicture) : null,
            child: profilePicture == null
                ? Text(
                    live.displayName.isNotEmpty ? live.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  live.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Q${live.currentQuestion}/${live.totalQuestions} - ${live.mode == "study" ? "Study" : "Test"} Mode',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark ? Colors.white12 : Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$accuracyPercent%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: accuracyPercent >= 70 ? Colors.green : (accuracyPercent >= 50 ? _accent : Colors.red),
                ),
              ),
              Text(
                _formatDuration(live.elapsedTime),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TESTS TAB
  // ============================================================================

  Widget _buildUsersTab(bool isDark) {
    // Calculate stats
    int totalPassed = 0;
    int totalInProgress = 0;

    for (final user in _allUsers) {
      for (final test in _tests) {
        final status = user.tests[test.id];
        if (status?.hasPassed == true) {
          totalPassed++;
        } else if (status?.isInProgress == true || status?.hasStarted == true) {
          totalInProgress++;
        }
      }
    }

    if (_tests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Tests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No tests are configured yet.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats summary
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGuideStat(
                  icon: Icons.quiz,
                  value: '${_tests.length}',
                  label: 'Tests',
                  color: _accent,
                ),
                _buildGuideStat(
                  icon: Icons.check_circle,
                  value: '$totalPassed',
                  label: 'Passed',
                  color: Colors.green,
                ),
                _buildGuideStat(
                  icon: Icons.pending,
                  value: '$totalInProgress',
                  label: 'In Progress',
                  color: Colors.blue,
                ),
              ],
            ),
          ),

          // Tests with users under each
          ..._tests.map((test) => _buildTestProgressSection(test, isDark)),
        ],
      ),
    );
  }

  Widget _buildTestProgressSection(TrainingTest test, bool isDark) {
    // Get users who have status for this test
    final List<_UserTestInfo> usersWithStatus = [];

    for (final user in _allUsers) {
      final status = user.tests[test.id];
      if (status != null && (status.hasStarted || status.attemptsUsed > 0)) {
        usersWithStatus.add(_UserTestInfo(user: user, status: status));
      }
    }

    // Sort: passed first, then in progress, then by attempts
    usersWithStatus.sort((a, b) {
      if (a.status.hasPassed && !b.status.hasPassed) return -1;
      if (!a.status.hasPassed && b.status.hasPassed) return 1;
      if (a.status.isInProgress && !b.status.isInProgress) return -1;
      if (!a.status.isInProgress && b.status.isInProgress) return 1;
      return b.status.attemptsUsed.compareTo(a.status.attemptsUsed);
    });

    final passedCount = usersWithStatus.where((u) => u.status.hasPassed).length;
    final inProgressCount = usersWithStatus.where((u) => u.status.isInProgress && !u.status.hasPassed).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.quiz, color: _accent),
        ),
        title: Text(
          test.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${test.questions.length} questions - ${test.passingScore}% to pass - ${usersWithStatus.length} user${usersWithStatus.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            if (usersWithStatus.isNotEmpty) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: usersWithStatus.isNotEmpty ? passedCount / usersWithStatus.length : 0,
                  backgroundColor: isDark ? Colors.white12 : Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
        trailing: usersWithStatus.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'No users',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: passedCount > 0 ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  passedCount > 0 ? '$passedCount passed' : '$inProgressCount active',
                  style: TextStyle(
                    fontSize: 12,
                    color: passedCount > 0 ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
        children: [
          if (usersWithStatus.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No one has started this test yet.',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: usersWithStatus.map((info) => _buildTestUserRow(info, test, isDark)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTestUserRow(_UserTestInfo info, TrainingTest test, bool isDark) {
    final profilePicture = _profilePictureCache[info.user.username];
    final status = info.status;
    final isPassed = status.hasPassed;
    final isInProgress = status.isInProgress && !isPassed;
    final isFailed = !isPassed && status.attemptsUsed >= status.maxAttempts;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isPassed) {
      statusColor = Colors.green;
      statusText = '${status.bestScore != null ? (status.bestScore! * 100).toStringAsFixed(0) : ''}%';
      statusIcon = Icons.check_circle;
    } else if (isFailed) {
      statusColor = Colors.red;
      statusText = 'Failed';
      statusIcon = Icons.cancel;
    } else if (isInProgress) {
      statusColor = Colors.blue;
      statusText = 'In Progress';
      statusIcon = Icons.pending;
    } else {
      statusColor = Colors.grey;
      statusText = '${status.attemptsUsed}/${status.maxAttempts}';
      statusIcon = Icons.replay;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: _accent.withValues(alpha: 0.2),
            backgroundImage: profilePicture != null ? MemoryImage(profilePicture) : null,
            child: profilePicture == null
                ? Text(
                    info.user.displayName.isNotEmpty ? info.user.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name and info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                Text(
                  '${status.attemptsUsed}/${status.maxAttempts} attempts${status.bestScore != null ? ' - Best: ${(status.bestScore! * 100).toStringAsFixed(0)}%' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),

          // Admin settings button
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _showResetAttemptsDialog(info.user.username, test.id, test.title, status),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.admin_panel_settings,
                size: 18,
                color: isFailed ? Colors.red : _accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show dialog to reset or grant extra attempts
  Future<void> _showResetAttemptsDialog(String username, String testId, String testTitle, TestStatus status) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: _accent),
            SizedBox(width: 12),
            Expanded(child: Text('Manage Attempts')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User & Test info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                      const SizedBox(width: 8),
                      Text(username, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.quiz, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                      const SizedBox(width: 8),
                      Expanded(child: Text(testTitle, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Attempts: ${status.attemptsUsed}/${status.maxAttempts}',
                          style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (status.bestScore != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Best: ${(status.bestScore! * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Choose an action:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            
            // Grant 1 extra attempt button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _grantExtraAttempts(context, username, testId, 1),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Grant 1 Extra Attempt'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Grant 3 extra attempts button  
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _grantExtraAttempts(context, username, testId, 3),
                icon: const Icon(Icons.add_circle),
                label: const Text('Grant 3 Extra Attempts'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Full reset button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _resetAllAttempts(context, username, testId),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Full Reset (Delete All History)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _grantExtraAttempts(BuildContext dialogContext, String username, String testId, int count) async {
    Navigator.pop(dialogContext); // Close dialog
    
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Granting $count extra attempt(s) to $username...'), duration: const Duration(seconds: 1)),
    );
    
    final result = await TrainingService.instance.grantExtraAttempts(
      username: username,
      testId: testId,
      grantedBy: widget.currentUsername,
      extraAttempts: count,
    );
    
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('? Granted ${result['deleted_count']} attempt(s). $username now has ${result['attempts_remaining']} attempt(s) remaining.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Refresh data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${result['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetAllAttempts(BuildContext dialogContext, String username, String testId) async {
    // Confirm reset
    final confirm = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('Confirm Full Reset'),
          ],
        ),
        content: Text(
          'This will delete ALL test history for $username on this test.\n\n'
          'They will start completely fresh with ${3} attempts.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;

    if (!dialogContext.mounted) return;
    Navigator.pop(dialogContext); // Close main dialog

    // Show loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Resetting all attempts for $username...'), duration: const Duration(seconds: 1)),
    );
    
    final result = await TrainingService.instance.resetUserAttempts(
      username: username,
      testId: testId,
      resetBy: widget.currentUsername,
    );
    
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('? Reset complete. Deleted ${result['deleted_results']} result(s) for $username.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Refresh data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${result['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================================
  // GUIDES TAB (KB Progress)
  // ============================================================================

  Widget _buildGuidesTab(bool isDark) {
    // Group progress by knowledge base
    final Map<String, List<UserKBProgress>> progressByKb = {};
    for (final p in _kbProgress) {
      progressByKb.putIfAbsent(p.kbId, () => []).add(p);
    }

    if (_knowledgeBases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Study Guides',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No knowledge bases are configured yet.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats summary
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGuideStat(
                  icon: Icons.menu_book,
                  value: '${_knowledgeBases.length}',
                  label: 'Study Guides',
                  color: _accent,
                ),
                _buildGuideStat(
                  icon: Icons.people,
                  value: '${_kbProgress.map((p) => p.username).toSet().length}',
                  label: 'Active Learners',
                  color: Colors.blue,
                ),
                _buildGuideStat(
                  icon: Icons.check_circle,
                  value: '${_kbProgress.fold<int>(0, (sum, p) => sum + p.completedTopics)}',
                  label: 'Topics Completed',
                  color: Colors.green,
                ),
              ],
            ),
          ),

          // Knowledge base sections
          ..._knowledgeBases.map((kb) {
            final kbUsers = progressByKb[kb.id] ?? [];
            final totalTopics = _countKBTopics(kb);

            return _buildKBProgressSection(kb, kbUsers, totalTopics, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildGuideStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  int _countKBTopics(KnowledgeBaseData kb) {
    // Use pre-computed topic count from API if available (list endpoint)
    if (kb.topicCount != null) {
      return kb.topicCount!;
    }
    // Fallback: count from full structure (when KB is fully loaded)
    int count = 0;
    for (final chapter in kb.chapters) {
      for (final section in chapter.sections) {
        count += section.topics.length;
      }
    }
    // Also count legacy sections (if any)
    for (final section in kb.sections) {
      count += section.topics.length;
    }
    return count;
  }

  Widget _buildKBProgressSection(
    KnowledgeBaseData kb,
    List<UserKBProgress> users,
    int totalTopics,
    bool isDark,
  ) {
    // Sort users by completed topics (descending)
    final sortedUsers = List<UserKBProgress>.from(users)
      ..sort((a, b) => b.completedTopics.compareTo(a.completedTopics));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.menu_book, color: _accent),
        ),
        title: Text(
          kb.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$totalTopics topics • ${users.length} learner${users.length != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            if (users.isNotEmpty) ...[
              const SizedBox(height: 6),
              // Overall progress for this KB
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalTopics > 0
                      ? sortedUsers.fold<int>(0, (sum, u) => sum + u.completedTopics) /
                          (totalTopics * users.length)
                      : 0,
                  backgroundColor: isDark ? Colors.white12 : Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
        trailing: users.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'No users',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${users.length} active',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
        children: [
          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No one has started this guide yet.',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: sortedUsers.map((userProgress) {
                  return _buildKBUserProgressRow(userProgress, totalTopics, isDark);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKBUserProgressRow(UserKBProgress userProgress, int totalTopics, bool isDark) {
    final profilePicture = _profilePictureCache[userProgress.username];
    final progressPercent = totalTopics > 0
        ? (userProgress.completedTopics / totalTopics * 100).toInt()
        : 0;
    final isComplete = userProgress.completedTopics >= totalTopics && totalTopics > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: _accent.withValues(alpha: 0.2),
            backgroundImage: profilePicture != null
                ? MemoryImage(profilePicture)
                : null,
            child: profilePicture == null
                ? Text(
                    userProgress.displayName.isNotEmpty
                        ? userProgress.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userProgress.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: totalTopics > 0
                              ? userProgress.completedTopics / totalTopics
                              : 0,
                          backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isComplete ? Colors.green : _accent,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${userProgress.completedTopics}/$totalTopics',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                if (userProgress.lastAccessedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last active: ${_formatDateTime(userProgress.lastAccessedAt!)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Progress badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isComplete
                  ? Colors.green.withValues(alpha: 0.1)
                  : _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isComplete) ...[
                  const Icon(Icons.check_circle, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                ],
                Text(
                  isComplete ? 'Complete' : '$progressPercent%',
                  style: TextStyle(
                    fontSize: 11,
                    color: isComplete ? Colors.green : _accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // RESULTS TAB
  // ============================================================================

  Widget _buildResultsTab(bool isDark) {
    // Group results by test
    final Map<String, List<TestResult>> resultsByTest = {};
    for (final r in _allResults) {
      resultsByTest.putIfAbsent(r.testId, () => []).add(r);
    }

    // Sort results within each test by date (newest first)
    for (final list in resultsByTest.values) {
      list.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    }

    // Calculate stats
    final totalResults = _allResults.length;
    final passedResults = _allResults.where((r) => r.passed).length;
    final avgScore = _allResults.isNotEmpty
        ? _allResults.map((r) => r.correctAnswers / r.totalQuestions * 100).reduce((a, b) => a + b) / _allResults.length
        : 0.0;

    if (_allResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Results Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Test results will appear here.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadData(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats summary
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildGuideStat(
                  icon: Icons.history,
                  value: '$totalResults',
                  label: 'Total Results',
                  color: Colors.purple,
                ),
                _buildGuideStat(
                  icon: Icons.check_circle,
                  value: '$passedResults',
                  label: 'Passed',
                  color: Colors.green,
                ),
                _buildGuideStat(
                  icon: Icons.trending_up,
                  value: '${avgScore.toStringAsFixed(0)}%',
                  label: 'Avg Score',
                  color: _accent,
                ),
              ],
            ),
          ),

          // Results grouped by test
          ..._tests.map((test) {
            final testResults = resultsByTest[test.id] ?? [];
            if (testResults.isEmpty) return const SizedBox.shrink();
            return _buildResultsTestSection(test, testResults, isDark);
          }),
        ],
      ),
    );
  }

  Widget _buildResultsTestSection(TrainingTest test, List<TestResult> results, bool isDark) {
    final passedCount = results.where((r) => r.passed).length;
    final avgScore = results.isNotEmpty
        ? results.map((r) => r.correctAnswers / r.totalQuestions * 100).reduce((a, b) => a + b) / results.length
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.history, color: Colors.purple),
        ),
        title: Text(
          test.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${results.length} result${results.length != 1 ? 's' : ''} • $passedCount passed • Avg: ${avgScore.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: results.isNotEmpty ? passedCount / results.length : 0,
                backgroundColor: isDark ? Colors.white12 : Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                minHeight: 6,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: passedCount > 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${(passedCount / results.length * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              color: passedCount > 0 ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: results.map((result) => _buildResultUserRow(result, isDark)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultUserRow(TestResult result, bool isDark) {
    final profilePicture = _profilePictureCache[result.username];
    final scorePercent = (result.correctAnswers / result.totalQuestions * 100).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _showResultDetail(result, isDark),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: _accent.withValues(alpha: 0.2),
                backgroundImage: profilePicture != null ? MemoryImage(profilePicture) : null,
                child: profilePicture == null
                    ? Text(
                        result.username.isNotEmpty ? result.username[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Name and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.username,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    ),
                    Text(
                      'Attempt ${result.attemptNumber} - ${result.correctAnswers}/${result.totalQuestions} correct - ${_formatDateTime(result.completedAt)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Score badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (result.passed ? Colors.green : Colors.red).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      result.passed ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: result.passed ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$scorePercent%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: result.passed ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResultDetail(TestResult result, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.username,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${result.testTitle} - Attempt ${result.attemptNumber}',
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: (result.passed ? Colors.green : Colors.red).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Text(
                                result.scorePercent,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: result.passed ? Colors.green : Colors.red,
                                ),
                              ),
                              Text(
                                result.passed ? 'PASSED' : 'FAILED',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: result.passed ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(Icons.check_circle, '${result.correctAnswers}', 'Correct', Colors.green),
                        _buildStatColumn(Icons.cancel, '${result.incorrectAnswers}', 'Wrong', Colors.red),
                        _buildStatColumn(Icons.help_outline, '${result.totalQuestions}', 'Total', Colors.blue),
                        _buildStatColumn(Icons.timer, _formatDuration(result.timeTaken), 'Time', Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Divider(),
              
              // Questions list
              Expanded(
                child: result.answersDetail != null && result.answersDetail!.isNotEmpty
                    ? ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: result.answersDetail!.length,
                        itemBuilder: (context, index) {
                          final answer = result.answersDetail![index];
                          return _buildAnswerDetailCard(answer, index + 1, isDark);
                        },
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Detailed answers not available',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Answer details are only saved for new test attempts.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatColumn(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
  
  Widget _buildAnswerDetailCard(AnswerDetail answer, int questionNumber, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (answer.isCorrect ? Colors.green : Colors.red).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    answer.isCorrect ? Icons.check : Icons.close,
                    color: answer.isCorrect ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question $questionNumber',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: answer.isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                      if (answer.category != null && answer.category!.isNotEmpty)
                        Text(
                          answer.category!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Question text
            Text(
              answer.question,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            
            // Options
            ...List.generate(answer.options.length, (i) {
              final isSelected = i == answer.selectedIndex;
              final isCorrect = i == answer.correctIndex;
              
              Color bgColor;
              Color textColor;
              IconData? icon;
              
              if (isCorrect) {
                bgColor = Colors.green.withValues(alpha: 0.1);
                textColor = Colors.green;
                icon = Icons.check_circle;
              } else if (isSelected && !isCorrect) {
                bgColor = Colors.red.withValues(alpha: 0.1);
                textColor = Colors.red;
                icon = Icons.cancel;
              } else {
                bgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]!;
                textColor = isDark ? Colors.white70 : Colors.black87;
              }
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected ? Border.all(
                    color: isCorrect ? Colors.green : Colors.red,
                    width: 2,
                  ) : null,
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: textColor),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        answer.options[i],
                        style: TextStyle(
                          color: textColor,
                          fontWeight: isSelected || isCorrect ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isCorrect)
                      Text(
                        'Correct',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (isSelected && !isCorrect)
                      Text(
                        'Selected',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              );
            }),
            
            // Explanation
            if (answer.explanation != null && answer.explanation!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        answer.explanation!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.blue[200] : Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

/// Helper class for grouping user test info
class _UserTestInfo {
  final UserTrainingStatus user;
  final TestStatus status;

  _UserTestInfo({required this.user, required this.status});
}
