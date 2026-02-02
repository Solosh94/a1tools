// Training Service
//
// Handles all API communication for the training system including:
// - Test and question management (CRUD)
// - Progress tracking (real-time updates)
// - Result submission
// - Dashboard data retrieval

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import '../../core/services/api_client.dart';
import 'training_models.dart';

class TrainingService {
  /// Singleton instance
  static final TrainingService _instance = TrainingService._();
  static TrainingService get instance => _instance;
  TrainingService._();

  // API client instance
  final ApiClient _api = ApiClient.instance;

  // ============================================================================
  // TEST MANAGEMENT
  // ============================================================================

  /// Get all tests (optionally filtered by role)
  Future<List<TrainingTest>> getTests({String? role, bool includeQuestions = false}) async {
    var url = '${ApiConfig.trainingTests}?';
    if (role != null) url += 'role=$role&';
    if (includeQuestions) url += 'include_questions=1&';

    final response = await _api.get(url, timeout: const Duration(seconds: 15));

    if (response.success && response.rawJson != null) {
      final tests = response.rawJson!['tests'];
      if (tests != null) {
        return (tests as List).map((t) => _parseTest(t)).toList();
      }
    }
    return [];
  }

  /// Get a single test with questions
  Future<TrainingTest?> getTest(String testId) async {
    final response = await _api.get(
      '${ApiConfig.trainingTests}?id=$testId&include_questions=1',
      timeout: const Duration(seconds: 15),
    );

    if (response.success && response.rawJson?['test'] != null) {
      return _parseTest(response.rawJson!['test']);
    }
    return null;
  }

  /// Create a new test
  Future<bool> createTest({
    required String id,
    required String title,
    required String description,
    required String targetRole,
    double passingScore = 0.8,
    int maxAttempts = 3,
    bool randomizeAnswers = false,
  }) async {
    final response = await _api.post(
      ApiConfig.trainingTests,
      body: {
        'action': 'create',
        'id': id,
        'title': title,
        'description': description,
        'target_role': targetRole,
        'passing_score': passingScore,
        'max_attempts': maxAttempts,
        'randomize_answers': randomizeAnswers,
      },
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  /// Update a test
  Future<bool> updateTest({
    required String id,
    String? title,
    String? description,
    String? targetRole,
    double? passingScore,
    int? maxAttempts,
    bool? randomizeAnswers,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      'action': 'update',
      'id': id,
    };
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (targetRole != null) body['target_role'] = targetRole;
    if (passingScore != null) body['passing_score'] = passingScore;
    if (maxAttempts != null) body['max_attempts'] = maxAttempts;
    if (randomizeAnswers != null) body['randomize_answers'] = randomizeAnswers;
    if (isActive != null) body['is_active'] = isActive;

    final response = await _api.post(
      ApiConfig.trainingTests,
      body: body,
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  /// Delete a test
  Future<bool> deleteTest(String id) async {
    final response = await _api.post(
      ApiConfig.trainingTests,
      body: {'action': 'delete', 'id': id},
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  // ============================================================================
  // QUESTION MANAGEMENT
  // ============================================================================

  /// Get questions for a test
  Future<List<TrainingQuestion>> getQuestions(String testId, {bool includeInactive = false}) async {
    var url = '${ApiConfig.trainingQuestions}?test_id=$testId';
    if (includeInactive) url += '&include_inactive=1';

    final response = await _api.get(url, timeout: const Duration(seconds: 15));

    if (response.success && response.rawJson?['questions'] != null) {
      return (response.rawJson!['questions'] as List)
          .map((q) => _parseQuestion(q))
          .toList();
    }
    return [];
  }

  /// Create a new question
  Future<TrainingQuestion?> createQuestion({
    required String testId,
    required String question,
    required List<String> options,
    required int correctIndex,
    String? category,
    String? explanation,
  }) async {
    final response = await _api.post(
      ApiConfig.trainingQuestions,
      body: {
        'action': 'create',
        'test_id': testId,
        'question': question,
        'options': options,
        'correct_index': correctIndex,
        'category': category,
        'explanation': explanation,
      },
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['question'] != null) {
      return _parseQuestion(response.rawJson!['question']);
    }
    return null;
  }

  /// Update a question
  Future<TrainingQuestion?> updateQuestion({
    required String id,
    String? question,
    List<String>? options,
    int? correctIndex,
    String? category,
    String? explanation,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      'action': 'update',
      'id': id,
    };
    if (question != null) body['question'] = question;
    if (options != null) body['options'] = options;
    if (correctIndex != null) body['correct_index'] = correctIndex;
    if (category != null) body['category'] = category;
    if (explanation != null) body['explanation'] = explanation;
    if (isActive != null) body['is_active'] = isActive;

    final response = await _api.post(
      ApiConfig.trainingQuestions,
      body: body,
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['question'] != null) {
      return _parseQuestion(response.rawJson!['question']);
    }
    return null;
  }

  /// Delete a question
  Future<bool> deleteQuestion(String id) async {
    final response = await _api.post(
      ApiConfig.trainingQuestions,
      body: {'action': 'delete', 'id': id},
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  /// Duplicate a question
  Future<TrainingQuestion?> duplicateQuestion(String id) async {
    final response = await _api.post(
      ApiConfig.trainingQuestions,
      body: {'action': 'duplicate', 'id': id},
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['question'] != null) {
      return _parseQuestion(response.rawJson!['question']);
    }
    return null;
  }

  /// Reorder questions
  Future<bool> reorderQuestions(String testId, List<String> questionIds) async {
    final response = await _api.post(
      ApiConfig.trainingQuestions,
      body: {
        'action': 'reorder',
        'test_id': testId,
        'question_ids': questionIds,
      },
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  /// Bulk create questions
  Future<bool> bulkCreateQuestions(String testId, List<Map<String, dynamic>> questions) async {
    final response = await _api.post(
      ApiConfig.trainingQuestions,
      body: {
        'action': 'bulk_create',
        'test_id': testId,
        'questions': questions,
      },
      timeout: const Duration(seconds: 30),
    );
    return response.success;
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  TrainingTest _parseTest(Map<String, dynamic> json) {
    final questions = json['questions'] != null
        ? (json['questions'] as List).map((q) => _parseQuestion(q)).toList()
        : <TrainingQuestion>[];

    // Parse target_roles array if available, otherwise split target_role string
    List<String> targetRoles = [];
    if (json['target_roles'] != null && json['target_roles'] is List) {
      targetRoles = List<String>.from(json['target_roles']);
    } else if (json['target_role'] != null) {
      targetRoles = (json['target_role'] as String).split(',').map((r) => r.trim()).toList();
    }

    return TrainingTest(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      targetRole: json['target_role'] ?? '',
      targetRoles: targetRoles,
      passingScore: (json['passing_score'] ?? 0.8).toDouble(),
      maxAttempts: json['max_attempts'] ?? 3,
      randomizeAnswers: json['randomize_answers'] == true || json['randomize_answers'] == 1,
      questions: questions,
    );
  }

  TrainingQuestion _parseQuestion(Map<String, dynamic> json) {
    return TrainingQuestion(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correct_index'] ?? 0,
      explanation: json['explanation'],
      category: json['category'],
    );
  }

  // ============================================================================
  // KNOWLEDGE BASE MANAGEMENT
  // ============================================================================

  /// Get all knowledge bases
  Future<List<KnowledgeBaseData>> getKnowledgeBases({String? role}) async {
    var url = '${ApiConfig.trainingKnowledgeBase}?action=list&_t=${DateTime.now().millisecondsSinceEpoch}';
    if (role != null) url += '&role=$role';

    final response = await _api.get(url, timeout: const Duration(seconds: 15));

    if (response.success && response.rawJson?['knowledge_bases'] != null) {
      return (response.rawJson!['knowledge_bases'] as List)
          .map((kb) => KnowledgeBaseData.fromJson(kb))
          .toList();
    }
    return [];
  }

  /// Get a knowledge base with all sections and topics
  Future<KnowledgeBaseData?> getKnowledgeBase(String id) async {
    final response = await _api.get(
      '${ApiConfig.trainingKnowledgeBase}?action=get&id=$id&_t=${DateTime.now().millisecondsSinceEpoch}',
      timeout: const Duration(seconds: 15),
    );

    if (response.success && response.rawJson?['knowledge_base'] != null) {
      return KnowledgeBaseData.fromJson(response.rawJson!['knowledge_base']);
    }
    return null;
  }

  /// Get knowledge base for a test
  Future<KnowledgeBaseData?> getKnowledgeBaseForTest(String testId) async {
    final response = await _api.get(
      '${ApiConfig.trainingKnowledgeBase}?action=get_for_test&test_id=$testId&_t=${DateTime.now().millisecondsSinceEpoch}',
      timeout: const Duration(seconds: 15),
    );

    if (response.success && response.rawJson?['knowledge_base'] != null) {
      return KnowledgeBaseData.fromJson(response.rawJson!['knowledge_base']);
    }
    return null;
  }

  /// Get a knowledge base by its ID (for standalone guides)
  Future<KnowledgeBaseData?> getKnowledgeBaseById(String kbId) async {
    final response = await _api.get(
      '${ApiConfig.trainingKnowledgeBase}?action=get&id=$kbId&_t=${DateTime.now().millisecondsSinceEpoch}',
      timeout: const Duration(seconds: 15),
    );

    if (response.success && response.rawJson?['knowledge_base'] != null) {
      return KnowledgeBaseData.fromJson(response.rawJson!['knowledge_base']);
    }
    return null;
  }

  /// Create a knowledge base
  Future<bool> createKnowledgeBase({
    required String id,
    required String title,
    required String description,
    required String targetRole,
    String? testId,
  }) async {
    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: {
        'action': 'create_kb',
        'id': id,
        'title': title,
        'description': description,
        'target_role': targetRole,
        'test_id': testId,
      },
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  /// Update a knowledge base
  Future<bool> updateKnowledgeBase({
    required String id,
    String? title,
    String? description,
    String? targetRole,
    String? testId,
  }) async {
    final body = <String, dynamic>{
      'action': 'update_kb',
      'id': id,
    };
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (targetRole != null) body['target_role'] = targetRole;
    if (testId != null) body['test_id'] = testId;

    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: body,
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  /// Delete a knowledge base
  Future<bool> deleteKnowledgeBase(String id) async {
    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: {'action': 'delete_kb', 'id': id},
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  // Chapter methods
  Future<KBChapterData?> createChapter({
    required String kbId,
    required String title,
    String icon = '📚',
  }) async {
    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: {
        'action': 'create_chapter',
        'kb_id': kbId,
        'title': title,
        'icon': icon,
      },
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['chapter'] != null) {
      return KBChapterData.fromJson(response.rawJson!['chapter']);
    }
    return null;
  }

  Future<bool> updateChapter({
    required String id,
    String? title,
    String? icon,
  }) async {
    final body = <String, dynamic>{
      'action': 'update_chapter',
      'id': id,
    };
    if (title != null) body['title'] = title;
    if (icon != null) body['icon'] = icon;

    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: body,
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  Future<bool> deleteChapter(String id) async {
    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: {'action': 'delete_chapter', 'id': id},
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  Future<bool> reorderChapters(String kbId, List<String> chapterIds) async {
    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: {
        'action': 'reorder_chapters',
        'kb_id': kbId,
        'chapter_ids': chapterIds,
      },
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  // Section methods (updated to support chapter_id)
  Future<KBSectionData?> createSection({
    String? kbId, // For legacy sections
    String? chapterId, // New: parent chapter
    required String title,
  }) async {
    final body = <String, dynamic>{
      'action': 'create_section',
      'title': title,
    };
    if (chapterId != null) body['chapter_id'] = chapterId;
    if (kbId != null) body['kb_id'] = kbId;

    debugPrint('[TrainingService] Creating section with body: $body');

    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: body,
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['section'] != null) {
      debugPrint('[TrainingService] Section created successfully');
      return KBSectionData.fromJson(response.rawJson!['section']);
    } else {
      debugPrint('[TrainingService] Create section failed: ${response.message}');
    }
    return null;
  }

  Future<bool> updateSection({
    required String id,
    String? title,
    String? chapterId,
  }) async {
    final body = <String, dynamic>{
      'action': 'update_section',
      'id': id,
    };
    if (title != null) body['title'] = title;
    if (chapterId != null) body['chapter_id'] = chapterId;

    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: body,
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  Future<bool> deleteSection(String id) async {
    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: {'action': 'delete_section', 'id': id},
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  Future<bool> reorderSections({
    String? kbId, // For legacy sections
    String? chapterId, // New: parent chapter
    required List<String> sectionIds,
  }) async {
    final body = <String, dynamic>{
      'action': 'reorder_sections',
      'section_ids': sectionIds,
    };
    if (chapterId != null) body['chapter_id'] = chapterId;
    if (kbId != null) body['kb_id'] = kbId;

    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: body,
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  // Topic methods
  Future<KBTopicData?> createTopic({
    required String sectionId,
    required String title,
    String content = '',
    List<ContentBlock> contentBlocks = const [],
  }) async {
    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: {
        'action': 'create_topic',
        'section_id': sectionId,
        'title': title,
        'content': content,
        'content_blocks': contentBlocks.map((b) => b.toJson()).toList(),
      },
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['topic'] != null) {
      return KBTopicData.fromJson(response.rawJson!['topic']);
    }
    return null;
  }

  Future<bool> updateTopic({
    required String id,
    String? title,
    String? content,
    List<ContentBlock>? contentBlocks,
  }) async {
    final body = <String, dynamic>{
      'action': 'update_topic',
      'id': id,
    };
    if (title != null) body['title'] = title;
    if (content != null) body['content'] = content;
    if (contentBlocks != null) {
      body['content_blocks'] = contentBlocks.map((b) => b.toJson()).toList();
    }

    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: body,
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  Future<bool> deleteTopic(String id) async {
    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: {'action': 'delete_topic', 'id': id},
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  Future<bool> reorderTopics(String sectionId, List<String> topicIds) async {
    final response = await _api.post(
      ApiConfig.trainingKnowledgeBase,
      body: {
        'action': 'reorder_topics',
        'section_id': sectionId,
        'topic_ids': topicIds,
      },
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  // ============================================================================
  // PROGRESS TRACKING
  // ============================================================================

  /// Start a new test attempt
  Future<TestProgress?> startTest({
    required String username,
    required String testId,
    required String mode, // 'study' or 'test'
    required int totalQuestions,
  }) async {
    final response = await _api.post(
      ApiConfig.trainingProgress,
      body: {
        'action': 'start',
        'username': username,
        'test_id': testId,
        'mode': mode,
        'total_questions': totalQuestions,
      },
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['progress'] != null) {
      return TestProgress.fromJson(response.rawJson!['progress']);
    }
    debugPrint('[TrainingService] Start test failed: ${response.message}');
    return null;
  }

  /// Update progress (called after each question)
  Future<bool> updateProgress({
    required String username,
    required String testId,
    required int currentQuestionIndex,
    required int correctAnswers,
    required int incorrectAnswers,
    required List<QuestionAnswer> answers,
  }) async {
    final response = await _api.post(
      ApiConfig.trainingProgress,
      body: {
        'action': 'update',
        'username': username,
        'test_id': testId,
        'current_question_index': currentQuestionIndex,
        'correct_answers': correctAnswers,
        'incorrect_answers': incorrectAnswers,
        'answers': answers.map((a) => a.toJson()).toList(),
      },
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  /// Get current progress for a user's test
  Future<TestProgress?> getProgress({
    required String username,
    required String testId,
  }) async {
    final response = await _api.get(
      '${ApiConfig.trainingProgress}?username=$username&test_id=$testId',
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['progress'] != null) {
      return TestProgress.fromJson(response.rawJson!['progress']);
    }
    return null;
  }

  /// Clear/abandon current progress (for starting fresh)
  Future<bool> clearProgress({
    required String username,
    required String testId,
  }) async {
    final response = await _api.post(
      ApiConfig.trainingProgress,
      body: {
        'action': 'clear',
        'username': username,
        'test_id': testId,
      },
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  // ============================================================================
  // RESULTS
  // ============================================================================

  /// Submit completed test result
  Future<TestResult?> submitResult({
    required String username,
    required String testId,
    required String testTitle,
    required int totalQuestions,
    required int correctAnswers,
    required int incorrectAnswers,
    required double score,
    required bool passed,
    required int attemptNumber,
    required Duration timeTaken,
    List<AnswerDetail>? answersDetail,
  }) async {
    final body = {
      'action': 'submit',
      'username': username,
      'test_id': testId,
      'test_title': testTitle,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'incorrect_answers': incorrectAnswers,
      'score': score,
      'passed': passed,
      'attempt_number': attemptNumber,
      'time_taken_seconds': timeTaken.inSeconds,
      'answers_detail': answersDetail?.map((a) => a.toJson()).toList(),
    };

    debugPrint('[TrainingService] Submitting result: $body');

    final response = await _api.post(
      ApiConfig.trainingResults,
      body: body,
      timeout: const Duration(seconds: 10),
    );

    debugPrint('[TrainingService] Submit response: ${response.success} - ${response.message}');

    if (response.success && response.rawJson?['result'] != null) {
      debugPrint('[TrainingService] Result submitted successfully');
      return TestResult.fromJson(response.rawJson!['result']);
    }
    debugPrint('[TrainingService] Submit result failed: ${response.message}');
    return null;
  }

  /// Get detailed result including answers
  Future<Map<String, dynamic>?> getResultDetail(int resultId) async {
    final response = await _api.get(
      '${ApiConfig.trainingResults}?action=detail&result_id=$resultId',
      timeout: const Duration(seconds: 10),
    );

    if (response.success) {
      return response.rawJson;
    }
    return null;
  }

  /// Get all results for a user
  Future<List<TestResult>> getUserResults(String username) async {
    final response = await _api.get(
      '${ApiConfig.trainingResults}?username=$username',
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['results'] != null) {
      return (response.rawJson!['results'] as List)
          .map((r) => TestResult.fromJson(r))
          .toList();
    }
    return [];
  }

  /// Get user's status for a specific test (attempts, best score, etc.)
  Future<TestStatus?> getTestStatus({
    required String username,
    required String testId,
  }) async {
    final response = await _api.get(
      '${ApiConfig.trainingResults}?username=$username&test_id=$testId&action=status',
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['status'] != null) {
      return TestStatus.fromJson(response.rawJson!['status']);
    }
    return null;
  }

  // ============================================================================
  // DASHBOARD (Admin/Manager view)
  // ============================================================================

  /// Get all users' training status (for dashboard)
  Future<List<UserTrainingStatus>> getAllUsersStatus() async {
    final response = await _api.get(
      '${ApiConfig.trainingDashboard}?action=all_users',
      timeout: const Duration(seconds: 15),
    );

    if (response.success && response.rawJson?['users'] != null) {
      return (response.rawJson!['users'] as List)
          .map((u) => UserTrainingStatus.fromJson(u))
          .toList();
    }
    return [];
  }

  /// Get live progress data (users currently taking tests)
  Future<List<LiveProgressData>> getLiveProgress() async {
    final response = await _api.get(
      '${ApiConfig.trainingDashboard}?action=live',
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['live'] != null) {
      return (response.rawJson!['live'] as List)
          .map((l) => LiveProgressData.fromJson(l))
          .toList();
    }
    return [];
  }

  /// Get all results for dashboard (optionally filtered by test)
  Future<List<TestResult>> getAllResults({String? testId}) async {
    var url = '${ApiConfig.trainingDashboard}?action=all_results';
    if (testId != null) url += '&test_id=$testId';

    final response = await _api.get(url, timeout: const Duration(seconds: 15));

    if (response.success && response.rawJson?['results'] != null) {
      return (response.rawJson!['results'] as List)
          .map((r) => TestResult.fromJson(r))
          .toList();
    }
    return [];
  }

  /// Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _api.get(
      '${ApiConfig.trainingDashboard}?action=stats',
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['stats'] != null) {
      return Map<String, dynamic>.from(response.rawJson!['stats']);
    }
    return {};
  }

  /// Get detailed progress for a specific user (admin view)
  Future<Map<String, dynamic>> getUserDetailedProgress(String username) async {
    final response = await _api.get(
      '${ApiConfig.trainingDashboard}?action=user_detail&username=$username',
      timeout: const Duration(seconds: 10),
    );

    if (response.success) {
      return Map<String, dynamic>.from(response.rawJson ?? {});
    }
    return {};
  }

  // ============================================================================
  // ADMIN ACTIONS
  // ============================================================================

  /// Reset all attempts for a user on a specific test
  Future<Map<String, dynamic>> resetUserAttempts({
    required String username,
    required String testId,
    required String resetBy,
  }) async {
    final response = await _api.post(
      ApiConfig.trainingDashboard,
      body: {
        'action': 'reset_attempts',
        'username': username,
        'test_id': testId,
        'reset_by': resetBy,
      },
      timeout: const Duration(seconds: 10),
    );

    if (response.success) {
      return Map<String, dynamic>.from(response.rawJson ?? {});
    }
    return {'success': false, 'error': response.message ?? 'Request failed'};
  }

  /// Grant extra attempts by removing oldest failed attempts
  Future<Map<String, dynamic>> grantExtraAttempts({
    required String username,
    required String testId,
    required String grantedBy,
    int extraAttempts = 1,
  }) async {
    final response = await _api.post(
      ApiConfig.trainingDashboard,
      body: {
        'action': 'grant_attempts',
        'username': username,
        'test_id': testId,
        'extra_attempts': extraAttempts,
        'granted_by': grantedBy,
      },
      timeout: const Duration(seconds: 10),
    );

    if (response.success) {
      return Map<String, dynamic>.from(response.rawJson ?? {});
    }
    return {'success': false, 'error': response.message ?? 'Request failed'};
  }

  // ============================================================================
  // KNOWLEDGE BASE PROGRESS TRACKING
  // ============================================================================

  /// Get user's progress for a knowledge base (which topics are completed)
  Future<KBProgress?> getKBProgress({
    required String username,
    required String kbId,
  }) async {
    // Note: kb_progress.php uses its own ApiConfig endpoint
    final response = await _api.get(
      '${ApiConfig.kbProgress}?username=$username&kb_id=$kbId',
      timeout: const Duration(seconds: 10),
    );

    if (response.success && response.rawJson?['progress'] != null) {
      return KBProgress.fromJson(response.rawJson!['progress']);
    }
    return null;
  }

  /// Mark a topic as completed
  Future<bool> markTopicCompleted({
    required String username,
    required String kbId,
    required String topicId,
  }) async {
    // Note: kb_progress.php uses its own ApiConfig endpoint
    final response = await _api.post(
      ApiConfig.kbProgress,
      body: {
        'action': 'complete_topic',
        'username': username,
        'kb_id': kbId,
        'topic_id': topicId,
      },
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  /// Mark a video as watched (for video completion tracking)
  Future<bool> markVideoWatched({
    required String username,
    required String kbId,
    required String topicId,
    required String videoId,
  }) async {
    // Note: kb_progress.php uses its own ApiConfig endpoint
    final response = await _api.post(
      ApiConfig.kbProgress,
      body: {
        'action': 'watch_video',
        'username': username,
        'kb_id': kbId,
        'topic_id': topicId,
        'video_id': videoId,
      },
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  /// Reset user's KB progress (admin action)
  Future<bool> resetKBProgress({
    required String username,
    required String kbId,
  }) async {
    // Note: kb_progress.php uses its own ApiConfig endpoint
    final response = await _api.post(
      ApiConfig.kbProgress,
      body: {
        'action': 'reset',
        'username': username,
        'kb_id': kbId,
      },
      timeout: const Duration(seconds: 10),
    );
    return response.success;
  }

  /// Get all users' KB progress for dashboard
  Future<List<UserKBProgress>> getAllUsersKBProgress() async {
    // Note: kb_progress.php uses its own ApiConfig endpoint
    final response = await _api.get(
      '${ApiConfig.kbProgress}?action=all_users',
      timeout: const Duration(seconds: 15),
    );

    if (response.success && response.rawJson?['progress'] != null) {
      return (response.rawJson!['progress'] as List)
          .map((p) => UserKBProgress.fromJson(p))
          .toList();
    }
    return [];
  }

  /// Bulk sync local progress to server for a single KB
  Future<bool> bulkSyncKBProgress({
    required String username,
    required String kbId,
    required List<String> completedTopics,
    required List<String> watchedVideos,
  }) async {
    if (completedTopics.isEmpty && watchedVideos.isEmpty) {
      return true; // Nothing to sync
    }

    // Note: kb_progress.php uses its own ApiConfig endpoint
    final response = await _api.post(
      ApiConfig.kbProgress,
      body: {
        'action': 'bulk_sync',
        'username': username,
        'kb_id': kbId,
        'completed_topics': completedTopics,
        'watched_videos': watchedVideos,
      },
      timeout: const Duration(seconds: 30),
    );

    debugPrint('[TrainingService] Bulk sync result: ${response.success}');
    return response.success;
  }
}
