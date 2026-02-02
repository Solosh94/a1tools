// Training Test Editor Screen
//
// Admin/Developer interface for creating and editing tests and questions.
// Features:
// - Create new tests
// - Edit test settings
// - Add/edit/delete questions
// - Reorder questions via drag & drop

// ignore_for_file: deprecated_member_use
// Radio groupValue/onChanged deprecation will be addressed when migrating to Flutter 3.32+ RadioGroup

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'training_models.dart';
import 'training_service.dart';

class TrainingTestEditorScreen extends StatefulWidget {
  final String? testId; // null = create new test
  final String currentUserRole;

  const TrainingTestEditorScreen({
    super.key,
    this.testId,
    required this.currentUserRole,
  });

  @override
  State<TrainingTestEditorScreen> createState() => _TrainingTestEditorScreenState();
}

class _TrainingTestEditorScreenState extends State<TrainingTestEditorScreen> {
  static const Color _accent = AppColors.accent;

  // All available roles
  static const List<Map<String, String>> _allRoles = [
    {'id': 'technician', 'label': 'Technician'},
    {'id': 'dispatcher', 'label': 'Dispatcher'},
    {'id': 'administrator', 'label': 'Administrator'},
    {'id': 'management', 'label': 'Management'},
    {'id': 'marketing', 'label': 'Marketing'},
  ];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Test data
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  Set<String> _selectedRoles = {'technician'};
  double _passingScore = 0.8;
  int _maxAttempts = 3;
  bool _randomizeAnswers = false;

  // Questions
  List<TrainingQuestion> _questions = [];

  bool get _isNewTest => widget.testId == null;

  @override
  void initState() {
    super.initState();
    if (!_isNewTest) {
      _loadTest();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTest() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final test = await TrainingService.instance.getTest(widget.testId!);
      if (test != null && mounted) {
        setState(() {
          _idController.text = test.id;
          _titleController.text = test.title;
          _descriptionController.text = test.description;
          _selectedRoles = test.targetRoles.isNotEmpty 
              ? Set.from(test.targetRoles)
              : {test.targetRole};
          _passingScore = test.passingScore;
          _maxAttempts = test.maxAttempts;
          _randomizeAnswers = test.randomizeAnswers;
          _questions = List.from(test.questions);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load test';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveTest() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one role'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Convert selected roles to comma-separated string
      final targetRole = _selectedRoles.join(',');
      
      bool success;
      if (_isNewTest) {
        success = await TrainingService.instance.createTest(
          id: _idController.text.trim(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          targetRole: targetRole,
          passingScore: _passingScore,
          maxAttempts: _maxAttempts,
          randomizeAnswers: _randomizeAnswers,
        );
      } else {
        success = await TrainingService.instance.updateTest(
          id: widget.testId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          targetRole: targetRole,
          passingScore: _passingScore,
          maxAttempts: _maxAttempts,
          randomizeAnswers: _randomizeAnswers,
        );
      }

      if (mounted) {
        setState(() => _saving = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isNewTest ? 'Test created!' : 'Test updated!'),
              backgroundColor: Colors.green,
            ),
          );
          if (_isNewTest) {
            Navigator.pop(context, true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save test'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Delete test - Developer only with password confirmation
  Future<void> _deleteTest() async {
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
            const Text('Delete Test?'),
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
                      'This action is PERMANENT and cannot be undone!',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will permanently delete this test and all its questions, '
              'including any user progress and results associated with it.',
            ),
            const SizedBox(height: 16),
            const Text(
              'To confirm deletion, enter the password:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
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
              // Password is "deletea1" (case-sensitive)
              if (passwordController.text == 'deletea1') {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Incorrect password'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _saving = true);
      final success = await TrainingService.instance.deleteTest(widget.testId!);
      if (mounted) {
        if (success) {
          Navigator.pop(context, true);
        } else {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete test'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _addQuestion() {
    _showQuestionEditor(null);
  }

  void _editQuestion(int index) {
    _showQuestionEditor(_questions[index]);
  }

  Future<void> _deleteQuestion(int index) async {
    final question = _questions[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question?'),
        content: Text('Delete: "${question.question.substring(0, question.question.length.clamp(0, 50))}..."?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await TrainingService.instance.deleteQuestion(question.id);
      if (success && mounted) {
        setState(() {
          _questions.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question deleted'), backgroundColor: Colors.green),
        );
      }
    }
  }

  void _showQuestionEditor(TrainingQuestion? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _QuestionEditorSheet(
        testId: _isNewTest ? _idController.text : widget.testId!,
        question: existing,
        onSaved: (question) {
          setState(() {
            if (existing != null) {
              final index = _questions.indexWhere((q) => q.id == existing.id);
              if (index >= 0) {
                _questions[index] = question;
              }
            } else {
              _questions.add(question);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewTest ? 'Create Test' : 'Edit Test'),
        actions: [
          // Delete button - Developer only
          if (!_isNewTest && widget.currentUserRole == 'developer')
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete Test',
              onPressed: _deleteTest,
            ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            tooltip: 'Save Test',
            onPressed: _saving ? null : _saveTest,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadTest, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(isDark),
      floatingActionButton: !_isNewTest && !_loading
          ? FloatingActionButton.extended(
              onPressed: _addQuestion,
              backgroundColor: _accent,
              icon: const Icon(Icons.add),
              label: const Text('Add Question'),
            )
          : null,
    );
  }

  Widget _buildContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Test Settings Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.settings, color: _accent),
                        SizedBox(width: 8),
                        Text(
                          'Test Settings',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Test ID (only for new tests)
                    if (_isNewTest)
                      TextFormField(
                        controller: _idController,
                        decoration: const InputDecoration(
                          labelText: 'Test ID',
                          hintText: 'e.g., technician_test',
                          helperText: 'Unique identifier (no spaces)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          if (value.contains(' ')) {
                            return 'No spaces allowed';
                          }
                          return null;
                        },
                      ),
                    if (_isNewTest) const SizedBox(height: 16),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Test Title',
                        hintText: 'e.g., Technician Certification Test',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe what this test covers...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Target Roles - Multi-select
                    const Text(
                      'Target Roles',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: _allRoles.map((role) {
                          final isSelected = _selectedRoles.contains(role['id']);
                          return CheckboxListTile(
                            title: Text(role['label']!),
                            value: isSelected,
                            activeColor: _accent,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedRoles.add(role['id']!);
                                } else {
                                  _selectedRoles.remove(role['id']!);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    if (_selectedRoles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          'Select at least one role',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Passing Score & Max Attempts row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Passing Score: ${(_passingScore * 100).toInt()}%',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Slider(
                                value: _passingScore,
                                min: 0.5,
                                max: 1.0,
                                divisions: 10,
                                activeColor: _accent,
                                onChanged: (value) {
                                  setState(() => _passingScore = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _maxAttempts,
                            decoration: const InputDecoration(
                              labelText: 'Max Attempts',
                              border: OutlineInputBorder(),
                            ),
                            items: [1, 2, 3, 4, 5, 10].map((n) {
                              return DropdownMenuItem(value: n, child: Text('$n'));
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) setState(() => _maxAttempts = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Randomize Answers Toggle
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SwitchListTile(
                        title: const Text('Randomize Answer Order'),
                        subtitle: Text(
                          _randomizeAnswers
                              ? 'Answer options will be shuffled for each question'
                              : 'Answer options will appear in fixed order (A, B, C, D)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        value: _randomizeAnswers,
                        activeTrackColor: _accent.withValues(alpha: 0.5),
                        activeThumbColor: _accent,
                        onChanged: (value) {
                          setState(() => _randomizeAnswers = value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Questions Section (only for existing tests)
          if (!_isNewTest) ...[
            Row(
              children: [
                const Icon(Icons.quiz, color: _accent),
                const SizedBox(width: 8),
                Text(
                  'Questions (${_questions.length})',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_questions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.quiz_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No questions yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the button below to add questions',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _questions.length,
                onReorder: (oldIndex, newIndex) async {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _questions.removeAt(oldIndex);
                    _questions.insert(newIndex, item);
                  });
                  // Save new order
                  await TrainingService.instance.reorderQuestions(
                    widget.testId!,
                    _questions.map((q) => q.id).toList(),
                  );
                },
                itemBuilder: (context, index) {
                  final question = _questions[index];
                  return _buildQuestionCard(question, index, isDark);
                },
              ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(TrainingQuestion question, int index, bool isDark) {
    return Card(
      key: ValueKey(question.id),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _editQuestion(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Drag handle
              Icon(Icons.drag_handle, color: Colors.grey[400]),
              const SizedBox(width: 12),
              
              // Question number
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Question text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (question.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          question.category!,
                          style: const TextStyle(fontSize: 10, color: Colors.blue),
                        ),
                      ),
                    Text(
                      question.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${question.options.length} options - Correct: ${String.fromCharCode(65 + question.correctIndex)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteQuestion(index),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for adding/editing a question
class _QuestionEditorSheet extends StatefulWidget {
  final String testId;
  final TrainingQuestion? question;
  final ValueChanged<TrainingQuestion> onSaved;

  const _QuestionEditorSheet({
    required this.testId,
    this.question,
    required this.onSaved,
  });

  @override
  State<_QuestionEditorSheet> createState() => _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends State<_QuestionEditorSheet> {
  static const Color _accent = AppColors.accent;

  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _explanationController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int _correctIndex = 0;
  bool _saving = false;

  bool get _isEditing => widget.question != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _questionController.text = widget.question!.question;
      _categoryController.text = widget.question!.category ?? '';
      _explanationController.text = widget.question!.explanation ?? '';
      for (int i = 0; i < widget.question!.options.length && i < 4; i++) {
        _optionControllers[i].text = widget.question!.options[i];
      }
      _correctIndex = widget.question!.correctIndex;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _categoryController.dispose();
    _explanationController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final options = _optionControllers.map((c) => c.text.trim()).toList();

    try {
      TrainingQuestion? result;
      if (_isEditing) {
        result = await TrainingService.instance.updateQuestion(
          id: widget.question!.id,
          question: _questionController.text.trim(),
          options: options,
          correctIndex: _correctIndex,
          category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
          explanation: _explanationController.text.trim().isEmpty ? null : _explanationController.text.trim(),
        );
      } else {
        result = await TrainingService.instance.createQuestion(
          testId: widget.testId,
          question: _questionController.text.trim(),
          options: options,
          correctIndex: _correctIndex,
          category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
          explanation: _explanationController.text.trim().isEmpty ? null : _explanationController.text.trim(),
        );
      }

      if (result != null && mounted) {
        widget.onSaved(result);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Question updated!' : 'Question added!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _saving = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save question'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(_isEditing ? Icons.edit : Icons.add, color: _accent),
                  const SizedBox(width: 8),
                  Text(
                    _isEditing ? 'Edit Question' : 'Add Question',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                        hintText: 'e.g., Safety, Phone Handling',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Question
                    TextFormField(
                      controller: _questionController,
                      decoration: const InputDecoration(
                        labelText: 'Question',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Options
                    const Text(
                      'Answer Options',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the radio button to mark the correct answer',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),

                    ...List.generate(4, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: index,
                              groupValue: _correctIndex,
                              activeColor: Colors.green,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _correctIndex = value);
                                }
                              },
                            ),
                            Text(
                              String.fromCharCode(65 + index),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _correctIndex == index ? Colors.green : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _optionControllers[index],
                                decoration: InputDecoration(
                                  hintText: 'Option ${String.fromCharCode(65 + index)}',
                                  border: const OutlineInputBorder(),
                                  filled: _correctIndex == index,
                                  fillColor: Colors.green.withValues(alpha: 0.1),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Explanation
                    TextFormField(
                      controller: _explanationController,
                      decoration: const InputDecoration(
                        labelText: 'Explanation (optional)',
                        hintText: 'Why is this the correct answer?',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
