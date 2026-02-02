// Training Test Screen
// 
// The actual test-taking interface supporting both:
// - Study Mode: Shows correct answer after each question, no scoring
// - Test Mode: Real test with scoring and attempt tracking

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'training_models.dart';
import 'training_service.dart';

class TrainingTestScreen extends StatefulWidget {
  final String username;
  final TrainingTest test;
  final String mode; // 'study' or 'test'
  final TestStatus? status;

  const TrainingTestScreen({
    super.key,
    required this.username,
    required this.test,
    required this.mode,
    this.status,
  });

  @override
  State<TrainingTestScreen> createState() => _TrainingTestScreenState();
}

class _TrainingTestScreenState extends State<TrainingTestScreen> {
  static const Color _accent = AppColors.accent;

  late List<TrainingQuestion> _questions;
  late List<QuestionAnswer> _answers;
  
  // For randomized answer orders: maps question index -> list of shuffled option indices
  // e.g., [2, 0, 3, 1] means: display option 2 first, then 0, then 3, then 1
  Map<int, List<int>> _shuffledOptions = {};
  
  int _currentIndex = 0;
  int? _selectedOption; // This is the DISPLAY index (after shuffle)
  bool _showingResult = false;

  int _correctCount = 0;
  int _incorrectCount = 0;
  
  DateTime? _startTime;
  Timer? _progressSyncTimer;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  
  bool _loading = true;
  bool _submitting = false;
  bool _testComplete = false;
  TestResult? _result;

  bool get _isStudyMode => widget.mode == 'study';
  int get _attemptNumber => (widget.status?.attemptsUsed ?? 0) + 1;

  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  @override
  void dispose() {
    _progressSyncTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTest() async {
    try {
      // Check if there's existing progress to resume
      TestProgress? existingProgress;
      if (!_isStudyMode && widget.status?.isInProgress == true) {
        existingProgress = widget.status?.currentProgress;
      }

      if (existingProgress != null) {
        // Resume from existing progress
        debugPrint('[TrainingTestScreen] Resuming from existing progress');

        // Get the question order from saved answers
        final savedAnswers = existingProgress.answers;
        if (savedAnswers.isNotEmpty) {
          // Reconstruct question order from saved answers
          final questionMap = {for (var q in widget.test.questions) q.id: q};
          _questions = [];
          for (final answer in savedAnswers) {
            final question = questionMap[answer.questionId];
            if (question != null) {
              _questions.add(question);
            }
          }
          // Add any missing questions (shouldn't happen but just in case)
          for (final q in widget.test.questions) {
            if (!_questions.any((existing) => existing.id == q.id)) {
              _questions.add(q);
            }
          }

          // Restore answers
          _answers = savedAnswers;
          _currentIndex = existingProgress.currentQuestionIndex;
          _correctCount = existingProgress.correctAnswers;
          _incorrectCount = existingProgress.incorrectAnswers;

          // Calculate elapsed time from when test was started
          _startTime = existingProgress.startedAt;
          _elapsed = DateTime.now().difference(_startTime!);
        } else {
          // No saved answers, start fresh but don't create new progress entry
          _questions = List.from(widget.test.questions);
          _questions.shuffle(Random());
          _answers = _questions.map((q) => QuestionAnswer(questionId: q.id)).toList();
          _startTime = DateTime.now();
          _elapsed = Duration.zero;
        }
      } else {
        // Start fresh
        debugPrint('[TrainingTestScreen] Starting fresh test');
        _questions = List.from(widget.test.questions);
        _questions.shuffle(Random());
        _answers = _questions.map((q) => QuestionAnswer(questionId: q.id)).toList();
        _startTime = DateTime.now();
        _elapsed = Duration.zero;

        // Start test on server (for tracking) - only for new tests
        if (!_isStudyMode) {
          try {
            await TrainingService.instance.startTest(
              username: widget.username,
              testId: widget.test.id,
              mode: widget.mode,
              totalQuestions: _questions.length,
            );
          } catch (e) {
            debugPrint('[TrainingTestScreen] Failed to start test on server: $e');
            // Continue anyway - we can still take the test locally
          }
        }
      }

      // Start elapsed time timer
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !_testComplete) {
          setState(() {
            _elapsed = DateTime.now().difference(_startTime!);
          });
        }
      });

      // Sync progress periodically (for both new and resumed tests)
      if (!_isStudyMode) {
        _progressSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          _syncProgress();
        });
      }

      // Initialize shuffled options if randomization is enabled
      if (widget.test.randomizeAnswers) {
        _initializeShuffledOptions();
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[TrainingTestScreen] Error initializing test: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting test: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }
  
  /// Initialize shuffled option indices for each question
  void _initializeShuffledOptions() {
    _shuffledOptions = {};
    final random = Random();
    for (int i = 0; i < _questions.length; i++) {
      final optionCount = _questions[i].options.length;
      final indices = List.generate(optionCount, (index) => index);
      indices.shuffle(random);
      _shuffledOptions[i] = indices;
    }
  }
  
  /// Get the original option index from a display index
  int _getOriginalIndex(int displayIndex) {
    if (!widget.test.randomizeAnswers || !_shuffledOptions.containsKey(_currentIndex)) {
      return displayIndex;
    }
    return _shuffledOptions[_currentIndex]![displayIndex];
  }
  
  /// Get options in display order (shuffled if enabled)
  List<String> _getDisplayOptions(TrainingQuestion question) {
    if (!widget.test.randomizeAnswers || !_shuffledOptions.containsKey(_currentIndex)) {
      return question.options;
    }
    final indices = _shuffledOptions[_currentIndex]!;
    return indices.map((i) => question.options[i]).toList();
  }

  Future<void> _syncProgress() async {
    if (_testComplete) return;

    try {
      await TrainingService.instance.updateProgress(
        username: widget.username,
        testId: widget.test.id,
        currentQuestionIndex: _currentIndex,
        correctAnswers: _correctCount,
        incorrectAnswers: _incorrectCount,
        answers: _answers,
      );
    } catch (e) {
      debugPrint('[TrainingTestScreen] Failed to sync progress: $e');
      // Silent failure - don't interrupt the test
    }
  }

  void _selectOption(int index) {
    if (_showingResult) return;
    setState(() {
      _selectedOption = index;
    });
  }

  Future<void> _submitAnswer() async {
    if (_selectedOption == null) return;
    
    final question = _questions[_currentIndex];
    // Convert display index to original index for correctness check
    final originalSelectedIndex = _getOriginalIndex(_selectedOption!);
    final isCorrect = originalSelectedIndex == question.correctIndex;
    
    setState(() {
      _showingResult = true;

      if (isCorrect) {
        _correctCount++;
      } else {
        _incorrectCount++;
      }
      
      // Update answer with ORIGINAL index (not display index)
      _answers[_currentIndex] = QuestionAnswer(
        questionId: question.id,
        selectedIndex: originalSelectedIndex,
        isCorrect: isCorrect,
        answeredAt: DateTime.now(),
      );
    });
    
    // Sync progress immediately after each answer (for real-time dashboard updates)
    if (!_isStudyMode) {
      _syncProgress();
    }
    
    // In study mode, show result immediately
    // In test mode, also show result but with less emphasis on correctness
  }
  
  /// Build detailed answers for result submission
  List<AnswerDetail> _buildAnswersDetail() {
    final details = <AnswerDetail>[];
    
    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      final answer = _answers[i];
      
      details.add(AnswerDetail(
        questionId: question.id,
        question: question.question,
        options: question.options,
        selectedIndex: answer.selectedIndex ?? -1,
        correctIndex: question.correctIndex,
        isCorrect: answer.isCorrect,
        explanation: question.explanation,
        category: question.category,
      ));
    }
    
    return details;
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _showingResult = false;
      });
    } else {
      // Test complete
      _finishTest();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0 && _isStudyMode) {
      setState(() {
        _currentIndex--;
        _selectedOption = _answers[_currentIndex].selectedIndex;
        _showingResult = _answers[_currentIndex].selectedIndex != null;
      });
    }
  }

  Future<void> _finishTest() async {
    debugPrint('[TrainingTestScreen] _finishTest called, isStudyMode: $_isStudyMode');

    setState(() {
      _testComplete = true;
      _submitting = true;
    });

    _progressSyncTimer?.cancel();
    _elapsedTimer?.cancel();

    final score = _correctCount / _questions.length;
    final passed = score >= widget.test.passingScore;

    debugPrint('[TrainingTestScreen] Score: $score, Passed: $passed, Mode: ${widget.mode}');

    if (!_isStudyMode) {
      debugPrint('[TrainingTestScreen] Submitting test result...');

      // Build detailed answers
      final answersDetail = _buildAnswersDetail();

      TestResult? result;
      try {
        // Submit result to server
        result = await TrainingService.instance.submitResult(
          username: widget.username,
          testId: widget.test.id,
          testTitle: widget.test.title,
          totalQuestions: _questions.length,
          correctAnswers: _correctCount,
          incorrectAnswers: _incorrectCount,
          score: score,
          passed: passed,
          attemptNumber: _attemptNumber,
          timeTaken: _elapsed,
          answersDetail: answersDetail,
        );
        debugPrint('[TrainingTestScreen] Submit result returned: ${result != null ? "success" : "null"}');
      } catch (e) {
        debugPrint('[TrainingTestScreen] Failed to submit result: $e');
        // Continue anyway - we'll show a local result
      }

      if (mounted) {
        setState(() {
          _result = result ?? TestResult(
            username: widget.username,
            testId: widget.test.id,
            testTitle: widget.test.title,
            totalQuestions: _questions.length,
            correctAnswers: _correctCount,
            incorrectAnswers: _incorrectCount,
            score: score,
            passed: passed,
            attemptNumber: _attemptNumber,
            timeTaken: _elapsed,
            completedAt: DateTime.now(),
            answersDetail: answersDetail,
          );
          _submitting = false;
        });
      }
    } else {
      debugPrint('[TrainingTestScreen] Study mode - not submitting result');
      if (mounted) {
        setState(() {
          _result = TestResult(
            username: widget.username,
            testId: widget.test.id,
            testTitle: widget.test.title,
            totalQuestions: _questions.length,
            correctAnswers: _correctCount,
            incorrectAnswers: _incorrectCount,
            score: score,
            passed: passed,
            attemptNumber: 0, // Study mode doesn't count
            timeTaken: _elapsed,
            completedAt: DateTime.now(),
          );
          _submitting = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_testComplete) return true;
    
    if (_isStudyMode) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exit Study Session?'),
          content: const Text('Your study progress will not be saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      return confirm ?? false;
    }
    
    // Test mode - offer pause option
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pause Test?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress: ${_currentIndex + 1} of ${_questions.length} questions',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can pause and resume this test later. Your progress will be saved.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('Continue Test'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'pause'),
            child: const Text('Pause & Save'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'abandon'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Abandon (Fail)'),
          ),
        ],
      ),
    );
    
    if (action == 'pause') {
      // Progress is already being synced, just leave
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test paused. You can resume from where you left off.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return true;
    } else if (action == 'abandon') {
      // Submit as failed attempt
      await _finishTestAsAbandoned();
      return true;
    }
    
    return false;
  }
  
  Future<void> _finishTestAsAbandoned() async {
    setState(() {
      _testComplete = true;
      _submitting = true;
    });

    _progressSyncTimer?.cancel();
    _elapsedTimer?.cancel();

    // Calculate score based on answered questions only
    final answeredCount = _answers.where((a) => a.selectedIndex != null).length;
    final score = answeredCount > 0 ? _correctCount / _questions.length : 0.0;

    // Build answers detail
    final answersDetail = _buildAnswersDetail();

    TestResult? result;
    try {
      result = await TrainingService.instance.submitResult(
        username: widget.username,
        testId: widget.test.id,
        testTitle: widget.test.title,
        totalQuestions: _questions.length,
        correctAnswers: _correctCount,
        incorrectAnswers: _questions.length - _correctCount, // Unanswered count as incorrect
        score: score,
        passed: false, // Abandoned tests always fail
        attemptNumber: _attemptNumber,
        timeTaken: _elapsed,
        answersDetail: answersDetail,
      );
    } catch (e) {
      debugPrint('[TrainingTestScreen] Failed to submit abandoned result: $e');
      // Continue anyway - we'll show a local result
    }

    if (mounted) {
      setState(() {
        _result = result ?? TestResult(
          username: widget.username,
          testId: widget.test.id,
          testTitle: widget.test.title,
          totalQuestions: _questions.length,
          correctAnswers: _correctCount,
          incorrectAnswers: _questions.length - _correctCount,
          score: score,
          passed: false,
          attemptNumber: _attemptNumber,
          timeTaken: _elapsed,
          completedAt: DateTime.now(),
        );
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _testComplete,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          if (!context.mounted) return;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(isDark),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _testComplete
                ? _buildResultScreen(isDark)
                : _buildQuestionScreen(isDark),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.test.title,
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            _isStudyMode ? 'Study Mode' : 'Test Mode (Attempt $_attemptNumber)',
            style: TextStyle(
              fontSize: 12,
              color: _isStudyMode ? Colors.blue : _accent,
            ),
          ),
        ],
      ),
      actions: [
        // Timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 16),
              const SizedBox(width: 4),
              Text(
                _formatDuration(_elapsed),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionScreen(bool isDark) {
    final question = _questions[_currentIndex];
    
    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
          valueColor: AlwaysStoppedAnimation(_isStudyMode ? Colors.blue : _accent),
        ),
        
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentIndex + 1} of ${_questions.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  _buildStatChip(Icons.check_circle, '$_correctCount', Colors.green),
                  const SizedBox(width: 8),
                  _buildStatChip(Icons.cancel, '$_incorrectCount', Colors.red),
                ],
              ),
            ],
          ),
        ),
        
        // Question content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge
                if (question.category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      question.category!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                
                // Question text
                Text(
                  question.question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Options (in shuffled order if randomization is enabled)
                ...List.generate(question.options.length, (displayIndex) {
                  final displayOptions = _getDisplayOptions(question);
                  final originalIndex = _getOriginalIndex(displayIndex);
                  return _buildOptionTile(
                    index: displayIndex,
                    text: displayOptions[displayIndex],
                    isCorrect: originalIndex == question.correctIndex,
                    isDark: isDark,
                  );
                }),
                
                // Explanation (study mode, after answer)
                if (_showingResult && _isStudyMode && question.explanation != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Explanation',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                question.explanation!,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        
        // Bottom action bar
        Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Previous (study mode only)
              if (_isStudyMode && _currentIndex > 0)
                IconButton(
                  onPressed: _previousQuestion,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Previous Question',
                ),
              
              const Spacer(),
              
              // Submit / Next button
              if (!_showingResult)
                ElevatedButton(
                  onPressed: _selectedOption != null ? _submitAnswer : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isStudyMode ? Colors.blue : _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  child: const Text('Submit Answer'),
                )
              else
                ElevatedButton.icon(
                  onPressed: _nextQuestion,
                  icon: Icon(
                    _currentIndex < _questions.length - 1
                        ? Icons.arrow_forward
                        : Icons.done,
                  ),
                  label: Text(
                    _currentIndex < _questions.length - 1
                        ? 'Next Question'
                        : 'Finish ${_isStudyMode ? "Study" : "Test"}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isStudyMode ? Colors.blue : _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required int index,
    required String text,
    required bool isCorrect,
    required bool isDark,
  }) {
    final isSelected = _selectedOption == index;
    final showResult = _showingResult;
    
    Color? bgColor;
    Color? borderColor;
    Color? textColor;
    IconData? trailingIcon;
    
    if (showResult) {
      if (isCorrect) {
        bgColor = Colors.green.withValues(alpha: 0.1);
        borderColor = Colors.green;
        textColor = Colors.green;
        trailingIcon = Icons.check_circle;
      } else if (isSelected && !isCorrect) {
        bgColor = Colors.red.withValues(alpha: 0.1);
        borderColor = Colors.red;
        textColor = Colors.red;
        trailingIcon = Icons.cancel;
      }
    } else if (isSelected) {
      bgColor = (_isStudyMode ? Colors.blue : _accent).withValues(alpha: 0.1);
      borderColor = _isStudyMode ? Colors.blue : _accent;
    }
    
    return GestureDetector(
      onTap: () => _selectOption(index),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor ?? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor ?? (isDark ? Colors.white24 : Colors.grey[300]!),
            width: isSelected || (showResult && isCorrect) ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Letter badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: borderColor?.withValues(alpha: 0.2) ?? 
                    (isDark ? Colors.white10 : Colors.grey[200]),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                String.fromCharCode(65 + index), // A, B, C, D
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor ?? (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Option text
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor ?? (isDark ? Colors.white : Colors.black87),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            
            // Result icon
            if (trailingIcon != null)
              Icon(trailingIcon, color: textColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen(bool isDark) {
    if (_submitting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Submitting results...'),
          ],
        ),
      );
    }
    
    final result = _result!;
    final passed = result.passed;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Result icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (passed ? Colors.green : Colors.red).withValues(alpha: 0.1),
            ),
            child: Icon(
              passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              size: 60,
              color: passed ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          
          // Result title
          Text(
            _isStudyMode
                ? 'Study Session Complete!'
                : (passed ? 'Congratulations!' : 'Not Quite There'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isStudyMode
                ? 'Great job practicing!'
                : (passed
                    ? 'You passed the ${widget.test.title}!'
                    : 'You need ${(widget.test.passingScore * 100).toInt()}% to pass'),
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Score card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Score circle
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: result.score,
                        strokeWidth: 12,
                        backgroundColor: isDark ? Colors.white12 : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation(
                          passed ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          result.scorePercent,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: passed ? Colors.green : Colors.red,
                          ),
                        ),
                        const Text(
                          'Score',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Stats grid
                Row(
                  children: [
                    Expanded(
                      child: _buildResultStat(
                        'Correct',
                        '${result.correctAnswers}',
                        Colors.green,
                        Icons.check_circle,
                      ),
                    ),
                    Expanded(
                      child: _buildResultStat(
                        'Incorrect',
                        '${result.incorrectAnswers}',
                        Colors.red,
                        Icons.cancel,
                      ),
                    ),
                    Expanded(
                      child: _buildResultStat(
                        'Time',
                        _formatDuration(result.timeTaken),
                        Colors.blue,
                        Icons.timer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Attempt info (test mode only)
          if (!_isStudyMode) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (passed ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    passed ? Icons.verified : Icons.info,
                    color: passed ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      passed
                          ? 'This was attempt #${result.attemptNumber}. Your certification is complete!'
                          : 'This was attempt #${result.attemptNumber} of ${widget.test.maxAttempts}. '
                              '${widget.test.maxAttempts - result.attemptNumber > 0 
                                  ? "You have ${widget.test.maxAttempts - result.attemptNumber} attempts remaining." 
                                  : "No attempts remaining."}',
                      style: TextStyle(
                        color: passed ? Colors.green[700] : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Training'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (!passed && !_isStudyMode && (widget.test.maxAttempts - result.attemptNumber) > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Let the parent screen handle retry
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
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
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
