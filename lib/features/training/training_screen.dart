// Training Screen
//
// Main hub for the training system showing available tests,
// progress, and navigation to test-taking and dashboard.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../app_theme.dart';
import 'training_models.dart';
import 'training_service.dart';
import 'training_test_screen.dart';
import 'training_knowledge_base_screen.dart';

class TrainingScreen extends StatefulWidget {
  final String username;
  final String role;

  const TrainingScreen({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  static const Color _accent = AppColors.accent;
  static const _storage = FlutterSecureStorage();

  List<TrainingTest> _availableTests = [];
  List<KnowledgeBaseData> _standaloneGuides = []; // Study guides not linked to a test
  Map<String, TestStatus> _testStatuses = {};
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Sync all local KB progress to server
  Future<void> _syncLocalProgress() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    try {
      // Get all KB IDs we might have local progress for
      final allKBs = await TrainingService.instance.getKnowledgeBases();
      int totalSynced = 0;

      for (final kb in allKBs) {
        // Read local progress for this KB
        final progressKey = 'kb_progress_${widget.username}_${kb.id}';
        final watchedKey = 'kb_watched_${widget.username}_${kb.id}';

        final completedJson = await _storage.read(key: progressKey);
        final watchedJson = await _storage.read(key: watchedKey);

        List<String> completedTopics = [];
        List<String> watchedVideos = [];

        if (completedJson != null) {
          try {
            completedTopics = List<String>.from(jsonDecode(completedJson));
          } catch (e) {
  debugPrint('[TrainingScreen] Error: $e');
}
        }

        if (watchedJson != null) {
          try {
            watchedVideos = List<String>.from(jsonDecode(watchedJson));
          } catch (e) {
  debugPrint('[TrainingScreen] Error: $e');
}
        }

        // Sync if there's any local progress
        if (completedTopics.isNotEmpty || watchedVideos.isNotEmpty) {
          debugPrint('[Training] Syncing ${kb.id}: ${completedTopics.length} topics, ${watchedVideos.length} videos');
          final success = await TrainingService.instance.bulkSyncKBProgress(
            username: widget.username,
            kbId: kb.id,
            completedTopics: completedTopics,
            watchedVideos: watchedVideos,
          );
          if (success) {
            totalSynced += completedTopics.length + watchedVideos.length;
          }
        }
      }

      if (totalSynced > 0) {
        debugPrint('[Training] Synced $totalSynced items to server');
      }
    } catch (e) {
      debugPrint('[Training] Sync error: $e');
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Sync local progress to server first (in background)
      _syncLocalProgress();

      // Load tests from database
      final tests = await TrainingService.instance.getTests(
        role: widget.role,
        includeQuestions: true,
      );

      _availableTests = tests;

      // Load status for each test
      final statuses = <String, TestStatus>{};
      for (final test in _availableTests) {
        final status = await TrainingService.instance.getTestStatus(
          username: widget.username,
          testId: test.id,
        );
        if (status != null) {
          statuses[test.id] = status;
        } else {
          // No status yet - create default
          statuses[test.id] = TestStatus(
            testId: test.id,
            maxAttempts: test.maxAttempts,
          );
        }
      }

      // Load standalone knowledge bases (not linked to tests)
      final allKBs = await TrainingService.instance.getKnowledgeBases(role: widget.role);
      final testIds = _availableTests.map((t) => t.id).toSet();
      final standalone = allKBs.where((kb) => kb.testId == null || !testIds.contains(kb.testId)).toList();

      if (mounted) {
        setState(() {
          _testStatuses = statuses;
          _standaloneGuides = standalone;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load training data: $e';
          _loading = false;
        });
      }
    }
  }

  void _openTest(TrainingTest test, String mode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainingTestScreen(
          username: widget.username,
          test: test,
          mode: mode,
          status: _testStatuses[test.id],
        ),
      ),
    ).then((_) => _loadData()); // Refresh on return
  }

  void _openKnowledgeBase(TrainingTest test) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainingKnowledgeBaseScreen(
          testId: test.id,
        ),
      ),
    );
  }

  void _openStandaloneGuide(KnowledgeBaseData kb) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainingKnowledgeBaseScreen(
          kbId: kb.id, // Use KB id directly for standalone guides
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Training Center'),
            if (_syncing) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _availableTests.isEmpty && _standaloneGuides.isEmpty
                  ? _buildNoTestsState()
                  : _buildTestList(isDark),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTestsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Training Tests Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no training tests assigned to your role.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accent, _accent.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'A-1 Training',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Complete your certification tests',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
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
                  children: [
                    _buildStatBadge(
                      '${_availableTests.length}',
                      'Tests',
                      Icons.assignment,
                    ),
                    const SizedBox(width: 12),
                    _buildStatBadge(
                      '${_testStatuses.values.where((s) => s.hasPassed).length}',
                      'Passed',
                      Icons.check_circle,
                    ),
                    const SizedBox(width: 12),
                    _buildStatBadge(
                      '${_standaloneGuides.length}',
                      'Guides',
                      Icons.menu_book,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tests list
          if (_availableTests.isNotEmpty) ...[
            Text(
              'Available Tests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ..._availableTests.map((test) => _buildTestCard(test, isDark)),
          ],

          // Standalone Study Guides
          if (_standaloneGuides.isNotEmpty) ...[
            if (_availableTests.isNotEmpty) const SizedBox(height: 24),
            Text(
              'Study Guides',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ..._standaloneGuides.map((kb) => _buildGuideCard(kb, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildGuideCard(KnowledgeBaseData kb, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _openStandaloneGuide(kb),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kb.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kb.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(TrainingTest test, bool isDark) {
    final status = _testStatuses[test.id] ?? TestStatus(testId: test.id);
    
    // Determine card state
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (status.hasPassed) {
      statusColor = Colors.green;
      statusText = 'Passed';
      statusIcon = Icons.check_circle;
    } else if (status.isInProgress) {
      statusColor = Colors.blue;
      statusText = 'In Progress';
      statusIcon = Icons.pending;
    } else if (status.attemptsUsed > 0) {
      statusColor = Colors.orange;
      statusText = '${status.attemptsRemaining} attempts left';
      statusIcon = Icons.replay;
    } else {
      statusColor = Colors.grey;
      statusText = 'Not Started';
      statusIcon = Icons.play_circle_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: status.hasPassed || !status.canRetake && !status.hasPassed && status.attemptsUsed >= status.maxAttempts
            ? null
            : () => _showTestOptions(test, status),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      test.targetRole == 'technician'
                          ? Icons.build
                          : Icons.headset_mic,
                      color: _accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          test.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${test.totalQuestions} questions - ${(test.passingScore * 100).toInt()}% to pass',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
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
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                test.description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              
              // Best score if available
              if (status.bestScore != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 16,
                      color: isDark ? Colors.amber : Colors.amber[700],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Best Score: ${(status.bestScore! * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.amber : Colors.amber[700],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              
              // Action buttons
              if (status.isInProgress)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openKnowledgeBase(test),
                        icon: const Icon(Icons.menu_book, size: 18),
                        label: const Text('Study Guide'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accent,
                          side: const BorderSide(color: _accent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openTest(test, 'test'),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Resume'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                )
              else if (!status.hasPassed && status.canRetake)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openKnowledgeBase(test),
                        icon: const Icon(Icons.menu_book, size: 18),
                        label: const Text('Study Guide'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accent,
                          side: const BorderSide(color: _accent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openTest(test, 'test'),
                        icon: const Icon(Icons.assignment, size: 18),
                        label: Text(status.attemptsUsed > 0 ? 'Retry Test' : 'Take Test'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                )
              else if (status.hasPassed)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openKnowledgeBase(test),
                        icon: const Icon(Icons.menu_book, size: 18),
                        label: const Text('Review Material'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.block, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No attempts remaining. Contact your manager.',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTestOptions(TrainingTest test, TestStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              test.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${test.totalQuestions} questions - ${(test.passingScore * 100).toInt()}% to pass - ${status.attemptsRemaining} attempts left',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            
            // Study Guide
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.menu_book, color: Colors.blue),
              ),
              title: const Text('Study Guide'),
              subtitle: const Text('Read the training material before taking the test'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _openKnowledgeBase(test);
              },
            ),
            const Divider(),
            
            // Test Mode
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assignment, color: _accent),
              ),
              title: const Text('Take Test'),
              subtitle: Text('Graded attempt (${status.attemptsRemaining} remaining)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _openTest(test, 'test');
              },
            ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
