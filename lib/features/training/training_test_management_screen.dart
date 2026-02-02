// Training Test Management Screen
// 
// Admin/Developer interface for managing all training tests.
// Shows list of tests with options to create, edit, delete.

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'training_models.dart';
import 'training_service.dart';
import 'training_test_editor_screen.dart';

class TrainingTestManagementScreen extends StatefulWidget {
  final String currentUserRole;
  
  const TrainingTestManagementScreen({
    super.key,
    required this.currentUserRole,
  });

  @override
  State<TrainingTestManagementScreen> createState() => _TrainingTestManagementScreenState();
}

class _TrainingTestManagementScreenState extends State<TrainingTestManagementScreen> {
  static const Color _accent = AppColors.accent;

  List<TrainingTest> _tests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tests = await TrainingService.instance.getTests(includeQuestions: true);
      if (mounted) {
        setState(() {
          _tests = tests;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load tests: $e';
          _loading = false;
        });
      }
    }
  }

  void _createTest() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingTestEditorScreen(
          currentUserRole: widget.currentUserRole,
        ),
      ),
    );
    if (result == true) {
      _loadTests();
    }
  }

  void _editTest(TrainingTest test) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingTestEditorScreen(
          testId: test.id,
          currentUserRole: widget.currentUserRole,
        ),
      ),
    );
    if (result == true) {
      _loadTests();
    }
  }

  /// Delete test - Developer only with password confirmation
  Future<void> _deleteTest(TrainingTest test) async {
    // Check if user is developer
    if (widget.currentUserRole != 'developer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only developers can delete tests'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Password confirmation dialog
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            const Expanded(child: Text('Delete Test?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action is PERMANENT!',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete "${test.title}"?\n\n'
              'This will permanently delete the test and all ${test.questions.length} questions.',
            ),
            const SizedBox(height: 16),
            const Text('Enter password to confirm:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter deletion password',
                prefixIcon: Icon(Icons.lock),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text == 'deletea1') {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect password'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await TrainingService.instance.deleteTest(test.id);
      if (success && mounted) {
        _loadTests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test deleted'), backgroundColor: Colors.green),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete test'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Management'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTests,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildContent(isDark),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTest,
        backgroundColor: _accent,
        icon: const Icon(Icons.add),
        label: const Text('Create Test'),
      ),
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
              onPressed: _loadTests,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_tests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Tests Created',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to create your first test',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final totalQuestions = _tests.fold<int>(0, (sum, t) => sum + t.questions.length);

    return RefreshIndicator(
      onRefresh: _loadTests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header stats
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
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.quiz, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Training Tests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_tests.length} tests - $totalQuestions total questions',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tests list
          ..._tests.map((test) => _buildTestCard(test, isDark)),
          
          const SizedBox(height: 80), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildTestCard(TrainingTest test, bool isDark) {
    final questionCount = test.questions.length;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _editTest(test),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          'ID: ${test.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      // Delete option - Developer only
                      if (widget.currentUserRole == 'developer')
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editTest(test);
                      } else if (value == 'delete') {
                        _deleteTest(test);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (test.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    test.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Row(
                children: [
                  _buildStatChip(Icons.quiz, '$questionCount questions', Colors.blue),
                  const SizedBox(width: 8),
                  _buildStatChip(Icons.check_circle, '${(test.passingScore * 100).toInt()}% to pass', Colors.green),
                  const SizedBox(width: 8),
                  _buildStatChip(Icons.replay, '${test.maxAttempts} attempts', Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 14, color: _accent),
                    const SizedBox(width: 4),
                    Text(
                      'For: ${_formatRoles(test.targetRoles.isNotEmpty ? test.targetRoles : test.targetRole.split(','))}',
                      style: const TextStyle(fontSize: 12, color: _accent, fontWeight: FontWeight.w600),
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

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatRoles(List<String> roles) {
    if (roles.isEmpty) return 'All';
    
    final formatted = roles.map((role) {
      switch (role.toLowerCase().trim()) {
        case 'technician':
          return 'Technicians';
        case 'dispatcher':
          return 'Dispatchers';
        case 'administrator':
          return 'Administrators';
        case 'management':
          return 'Management';
        case 'marketing':
          return 'Marketing';
        default:
          return role;
      }
    }).toList();
    
    if (formatted.length == 1) return formatted.first;
    if (formatted.length == 2) return '${formatted[0]} & ${formatted[1]}';
    return '${formatted.sublist(0, formatted.length - 1).join(', ')} & ${formatted.last}';
  }
}
