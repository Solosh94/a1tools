// Training System Models
//
// Contains data models for questions, tests, results, progress tracking,
// and knowledge base content

import 'dart:convert';
import 'package:flutter/foundation.dart';

/// A section of the knowledge base
class KnowledgeSection {
  final String id;
  final String title;
  final String? icon; // Icon name or emoji
  final List<KnowledgeTopic> topics;

  const KnowledgeSection({
    required this.id,
    required this.title,
    this.icon,
    required this.topics,
  });
}

/// A topic within a knowledge section
class KnowledgeTopic {
  final String id;
  final String title;
  final String content; // Markdown-style content
  final List<String>? keyPoints; // Bullet points for quick reference
  final List<String>? tips; // Pro tips or important notes

  const KnowledgeTopic({
    required this.id,
    required this.title,
    required this.content,
    this.keyPoints,
    this.tips,
  });
}

/// Knowledge base for a specific role/test
class KnowledgeBase {
  final String id;
  final String title;
  final String description;
  final String targetRole;
  final List<KnowledgeSection> sections;

  const KnowledgeBase({
    required this.id,
    required this.title,
    required this.description,
    required this.targetRole,
    required this.sections,
  });
}

// ============================================================================
// DATABASE KNOWLEDGE BASE MODELS
// ============================================================================

/// Content block types for rich content
enum ContentBlockType { text, image, vimeo, youtube, table }

/// A content block (text, image, video, or table)
class ContentBlock {
  final ContentBlockType type;
  final String content; // text content, image URL, Vimeo video ID, or JSON table data
  final String? caption; // optional caption for images/videos/tables

  const ContentBlock({
    required this.type,
    required this.content,
    this.caption,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'content': content,
    'caption': caption,
  };

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      type: ContentBlockType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ContentBlockType.text,
      ),
      content: json['content'] ?? '',
      caption: json['caption'],
    );
  }

  factory ContentBlock.text(String content) => ContentBlock(
    type: ContentBlockType.text,
    content: content,
  );

  factory ContentBlock.image(String url, {String? caption}) => ContentBlock(
    type: ContentBlockType.image,
    content: url,
    caption: caption,
  );

  factory ContentBlock.vimeo(String videoId, {String? caption}) => ContentBlock(
    type: ContentBlockType.vimeo,
    content: videoId,
    caption: caption,
  );

  factory ContentBlock.youtube(String videoId, {String? caption}) => ContentBlock(
    type: ContentBlockType.youtube,
    content: videoId,
    caption: caption,
  );

  /// Create a table block
  /// [tableData] should be a JSON string with format:
  /// {"headers": ["Col1", "Col2"], "rows": [["A", "B"], ["C", "D"]]}
  factory ContentBlock.table(String tableData, {String? caption}) => ContentBlock(
    type: ContentBlockType.table,
    content: tableData,
    caption: caption,
  );

  /// Helper to create a table block from headers and rows
  factory ContentBlock.tableFromData({
    required List<String> headers,
    required List<List<String>> rows,
    String? caption,
  }) {
    final data = {
      'headers': headers,
      'rows': rows,
    };
    return ContentBlock(
      type: ContentBlockType.table,
      content: jsonEncode(data),
      caption: caption,
    );
  }

  /// Get table data as parsed object (for table blocks only)
  Map<String, dynamic>? get tableData {
    if (type != ContentBlockType.table) return null;
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[TrainingModels] Error: $e');
      return {'headers': [], 'rows': []};
    }
  }
}

/// Knowledge base data from database
class KnowledgeBaseData {
  final String id;
  final String? testId;
  final String title;
  final String description;
  final String targetRole;
  final bool isActive;
  final List<KBChapterData> chapters; // New hierarchy
  final List<KBSectionData> sections; // Legacy sections (no chapter)
  final int? topicCount; // Pre-computed topic count from API (for dashboard)

  KnowledgeBaseData({
    required this.id,
    this.testId,
    required this.title,
    required this.description,
    required this.targetRole,
    this.isActive = true,
    this.chapters = const [],
    this.sections = const [],
    this.topicCount,
  });

  factory KnowledgeBaseData.fromJson(Map<String, dynamic> json) {
    return KnowledgeBaseData(
      id: json['id'] ?? '',
      testId: json['test_id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      targetRole: json['target_role'] ?? '',
      isActive: json['is_active'] ?? true,
      chapters: json['chapters'] != null
          ? (json['chapters'] as List).map((c) => KBChapterData.fromJson(c)).toList()
          : [],
      sections: json['sections'] != null
          ? (json['sections'] as List).map((s) => KBSectionData.fromJson(s)).toList()
          : [],
      topicCount: json['topic_count'],
    );
  }
}

/// Chapter data from database (new layer)
class KBChapterData {
  final String id;
  final String kbId;
  final String title;
  final String icon;
  final int sortOrder;
  final bool isActive;
  final List<KBSectionData> sections;

  KBChapterData({
    required this.id,
    required this.kbId,
    required this.title,
    this.icon = '📚',
    this.sortOrder = 0,
    this.isActive = true,
    this.sections = const [],
  });

  factory KBChapterData.fromJson(Map<String, dynamic> json) {
    return KBChapterData(
      id: json['id'] ?? '',
      kbId: json['kb_id'] ?? '',
      title: json['title'] ?? '',
      icon: json['icon'] ?? '📚',
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      sections: json['sections'] != null
          ? (json['sections'] as List).map((s) => KBSectionData.fromJson(s)).toList()
          : [],
    );
  }
}

/// Section data from database
class KBSectionData {
  final String id;
  final String? kbId; // For legacy sections
  final String? chapterId; // New: parent chapter
  final String title;
  final int sortOrder;
  final bool isActive;
  final List<KBTopicData> topics;

  KBSectionData({
    required this.id,
    this.kbId,
    this.chapterId,
    required this.title,
    this.sortOrder = 0,
    this.isActive = true,
    this.topics = const [],
  });

  factory KBSectionData.fromJson(Map<String, dynamic> json) {
    return KBSectionData(
      id: json['id'] ?? '',
      kbId: json['kb_id'],
      chapterId: json['chapter_id'],
      title: json['title'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      topics: json['topics'] != null
          ? (json['topics'] as List).map((t) => KBTopicData.fromJson(t)).toList()
          : [],
    );
  }
}

/// Topic data from database
class KBTopicData {
  final String id;
  final String sectionId;
  final String title;
  final String content; // Legacy plain text content
  final List<ContentBlock> contentBlocks; // Rich content blocks
  final int sortOrder;
  final bool isActive;

  KBTopicData({
    required this.id,
    required this.sectionId,
    required this.title,
    this.content = '',
    this.contentBlocks = const [],
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory KBTopicData.fromJson(Map<String, dynamic> json) {
    List<ContentBlock> blocks = [];
    if (json['content_blocks'] != null && json['content_blocks'] is List) {
      blocks = (json['content_blocks'] as List)
          .map((b) => ContentBlock.fromJson(b))
          .toList();
    }
    
    return KBTopicData(
      id: json['id'] ?? '',
      sectionId: json['section_id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      contentBlocks: blocks,
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }
}

/// A single multiple choice question
class TrainingQuestion {
  final String id;
  final String question;
  final List<String> options; // 4 options (3 incorrect, 1 correct)
  final int correctIndex; // Index of correct answer (0-3)
  final String? explanation; // Optional explanation shown in study mode
  final String? category; // Optional category for organizing questions

  const TrainingQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'options': options,
    'correct_index': correctIndex,
    'explanation': explanation,
    'category': category,
  };

  factory TrainingQuestion.fromJson(Map<String, dynamic> json) => TrainingQuestion(
    id: json['id'] ?? '',
    question: json['question'] ?? '',
    options: List<String>.from(json['options'] ?? []),
    correctIndex: json['correct_index'] ?? 0,
    explanation: json['explanation'],
    category: json['category'],
  );
}

/// A test containing multiple questions
class TrainingTest {
  final String id;
  final String title;
  final String description;
  final String targetRole; // Comma-separated roles for backward compatibility
  final List<String> targetRoles; // List of roles this test is for
  final List<TrainingQuestion> questions;
  final double passingScore; // 0.0 to 1.0 (0.8 = 80%)
  final int maxAttempts;
  final bool randomizeAnswers; // Shuffle answer options when taking test

  const TrainingTest({
    required this.id,
    required this.title,
    required this.description,
    required this.targetRole,
    this.targetRoles = const [],
    required this.questions,
    this.passingScore = 0.8,
    this.maxAttempts = 3,
    this.randomizeAnswers = false,
  });

  int get totalQuestions => questions.length;
  int get questionsToPass => (totalQuestions * passingScore).ceil();
  
  /// Check if this test is available for a given role
  bool isAvailableForRole(String role) {
    final normalizedRole = role.toLowerCase();
    final checkRole = normalizedRole == 'remote_dispatcher' ? 'dispatcher' : normalizedRole;
    
    // Check in targetRoles list first
    if (targetRoles.isNotEmpty) {
      return targetRoles.any((r) => r.toLowerCase() == checkRole);
    }
    
    // Fall back to targetRole string (comma-separated)
    return targetRole.toLowerCase().split(',').map((r) => r.trim()).contains(checkRole);
  }
}

/// User's answer to a question
class QuestionAnswer {
  final String questionId;
  final int? selectedIndex; // null if not answered yet
  final bool isCorrect;
  final DateTime? answeredAt;

  const QuestionAnswer({
    required this.questionId,
    this.selectedIndex,
    this.isCorrect = false,
    this.answeredAt,
  });

  Map<String, dynamic> toJson() => {
    'question_id': questionId,
    'selected_index': selectedIndex,
    'is_correct': isCorrect,
    'answered_at': answeredAt?.toIso8601String(),
  };

  factory QuestionAnswer.fromJson(Map<String, dynamic> json) => QuestionAnswer(
    questionId: json['question_id'] ?? '',
    selectedIndex: json['selected_index'],
    isCorrect: json['is_correct'] == true || json['is_correct'] == 1,
    answeredAt: json['answered_at'] != null 
        ? DateTime.tryParse(json['answered_at']) 
        : null,
  );

  QuestionAnswer copyWith({
    String? questionId,
    int? selectedIndex,
    bool? isCorrect,
    DateTime? answeredAt,
  }) => QuestionAnswer(
    questionId: questionId ?? this.questionId,
    selectedIndex: selectedIndex ?? this.selectedIndex,
    isCorrect: isCorrect ?? this.isCorrect,
    answeredAt: answeredAt ?? this.answeredAt,
  );
}

/// Current progress in a test (real-time tracking)
class TestProgress {
  final int id;
  final String username;
  final String testId;
  final String mode; // 'study' or 'test'
  final int currentQuestionIndex;
  final int correctAnswers;
  final int incorrectAnswers;
  final int skippedAnswers;
  final List<QuestionAnswer> answers;
  final DateTime startedAt;
  final DateTime? lastActivityAt;
  final bool isCompleted;
  final int attemptNumber;

  const TestProgress({
    this.id = 0,
    required this.username,
    required this.testId,
    required this.mode,
    this.currentQuestionIndex = 0,
    this.correctAnswers = 0,
    this.incorrectAnswers = 0,
    this.skippedAnswers = 0,
    this.answers = const [],
    required this.startedAt,
    this.lastActivityAt,
    this.isCompleted = false,
    this.attemptNumber = 1,
  });

  int get totalAnswered => correctAnswers + incorrectAnswers;
  int get totalQuestions => answers.length;
  double get accuracy => totalAnswered > 0 ? correctAnswers / totalAnswered : 0;
  Duration get elapsedTime => DateTime.now().difference(startedAt);

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'test_id': testId,
    'mode': mode,
    'current_question_index': currentQuestionIndex,
    'correct_answers': correctAnswers,
    'incorrect_answers': incorrectAnswers,
    'skipped_answers': skippedAnswers,
    'answers': answers.map((a) => a.toJson()).toList(),
    'started_at': startedAt.toIso8601String(),
    'last_activity_at': lastActivityAt?.toIso8601String(),
    'is_completed': isCompleted,
    'attempt_number': attemptNumber,
  };

  factory TestProgress.fromJson(Map<String, dynamic> json) => TestProgress(
    id: json['id'] ?? 0,
    username: json['username'] ?? '',
    testId: json['test_id'] ?? '',
    mode: json['mode'] ?? 'test',
    currentQuestionIndex: json['current_question_index'] ?? 0,
    correctAnswers: json['correct_answers'] ?? 0,
    incorrectAnswers: json['incorrect_answers'] ?? 0,
    skippedAnswers: json['skipped_answers'] ?? 0,
    answers: (json['answers'] as List?)
        ?.map((a) => QuestionAnswer.fromJson(a))
        .toList() ?? [],
    startedAt: DateTime.tryParse(json['started_at'] ?? '') ?? DateTime.now(),
    lastActivityAt: json['last_activity_at'] != null 
        ? DateTime.tryParse(json['last_activity_at']) 
        : null,
    isCompleted: json['is_completed'] == true || json['is_completed'] == 1,
    attemptNumber: json['attempt_number'] ?? 1,
  );

  TestProgress copyWith({
    int? id,
    String? username,
    String? testId,
    String? mode,
    int? currentQuestionIndex,
    int? correctAnswers,
    int? incorrectAnswers,
    int? skippedAnswers,
    List<QuestionAnswer>? answers,
    DateTime? startedAt,
    DateTime? lastActivityAt,
    bool? isCompleted,
    int? attemptNumber,
  }) => TestProgress(
    id: id ?? this.id,
    username: username ?? this.username,
    testId: testId ?? this.testId,
    mode: mode ?? this.mode,
    currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
    correctAnswers: correctAnswers ?? this.correctAnswers,
    incorrectAnswers: incorrectAnswers ?? this.incorrectAnswers,
    skippedAnswers: skippedAnswers ?? this.skippedAnswers,
    answers: answers ?? this.answers,
    startedAt: startedAt ?? this.startedAt,
    lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    isCompleted: isCompleted ?? this.isCompleted,
    attemptNumber: attemptNumber ?? this.attemptNumber,
  );
}

/// Final result of a completed test
class TestResult {
  final int id;
  final String username;
  final String testId;
  final String testTitle;
  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final double score; // 0.0 to 1.0
  final bool passed;
  final int attemptNumber;
  final Duration timeTaken;
  final DateTime completedAt;
  final List<AnswerDetail>? answersDetail;

  const TestResult({
    this.id = 0,
    required this.username,
    required this.testId,
    required this.testTitle,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.score,
    required this.passed,
    required this.attemptNumber,
    required this.timeTaken,
    required this.completedAt,
    this.answersDetail,
  });

  String get scorePercent => '${(score * 100).toStringAsFixed(0)}%';

  Map<String, dynamic> toJson() => {
    'id': id,
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
    'completed_at': completedAt.toIso8601String(),
    'answers_detail': answersDetail?.map((a) => a.toJson()).toList(),
  };

  factory TestResult.fromJson(Map<String, dynamic> json) => TestResult(
    id: json['id'] ?? 0,
    username: json['username'] ?? '',
    testId: json['test_id'] ?? '',
    testTitle: json['test_title'] ?? '',
    totalQuestions: json['total_questions'] ?? 0,
    correctAnswers: json['correct_answers'] ?? 0,
    incorrectAnswers: json['incorrect_answers'] ?? 0,
    score: (json['score'] ?? 0).toDouble(),
    passed: json['passed'] == true || json['passed'] == 1,
    attemptNumber: json['attempt_number'] ?? 1,
    timeTaken: Duration(seconds: json['time_taken_seconds'] ?? 0),
    completedAt: DateTime.tryParse(json['completed_at'] ?? '') ?? DateTime.now(),
    answersDetail: json['answers_detail'] != null
        ? (json['answers_detail'] as List).map((a) => AnswerDetail.fromJson(a)).toList()
        : null,
  );
}

/// Detail of a single answer in a test result
class AnswerDetail {
  final String questionId;
  final String question;
  final List<String> options;
  final int selectedIndex;
  final int correctIndex;
  final bool isCorrect;
  final String? explanation;
  final String? category;

  const AnswerDetail({
    required this.questionId,
    required this.question,
    required this.options,
    required this.selectedIndex,
    required this.correctIndex,
    required this.isCorrect,
    this.explanation,
    this.category,
  });

  Map<String, dynamic> toJson() => {
    'question_id': questionId,
    'question': question,
    'options': options,
    'selected_index': selectedIndex,
    'correct_index': correctIndex,
    'is_correct': isCorrect,
    'explanation': explanation,
    'category': category,
  };

  factory AnswerDetail.fromJson(Map<String, dynamic> json) => AnswerDetail(
    questionId: json['question_id'] ?? '',
    question: json['question'] ?? '',
    options: List<String>.from(json['options'] ?? []),
    selectedIndex: json['selected_index'] ?? -1,
    correctIndex: json['correct_index'] ?? 0,
    isCorrect: json['is_correct'] == true || json['is_correct'] == 1,
    explanation: json['explanation'],
    category: json['category'],
  );
}

/// User's training status overview
class UserTrainingStatus {
  final String username;
  final String displayName;
  final String role;
  final String? profilePicture;
  final Map<String, TestStatus> tests; // testId -> status

  const UserTrainingStatus({
    required this.username,
    required this.displayName,
    required this.role,
    this.profilePicture,
    this.tests = const {},
  });

  factory UserTrainingStatus.fromJson(Map<String, dynamic> json) {
    final testsMap = <String, TestStatus>{};
    if (json['tests'] != null) {
      (json['tests'] as Map<String, dynamic>).forEach((key, value) {
        testsMap[key] = TestStatus.fromJson(value);
      });
    }
    return UserTrainingStatus(
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      role: json['role'] ?? '',
      profilePicture: json['profile_picture'],
      tests: testsMap,
    );
  }
}

/// Status of a single test for a user
class TestStatus {
  final String testId;
  final bool hasStarted;
  final bool isInProgress;
  final bool hasPassed;
  final int attemptsUsed;
  final int maxAttempts;
  final double? bestScore;
  final DateTime? lastAttemptAt;
  final TestProgress? currentProgress;

  const TestStatus({
    required this.testId,
    this.hasStarted = false,
    this.isInProgress = false,
    this.hasPassed = false,
    this.attemptsUsed = 0,
    this.maxAttempts = 3,
    this.bestScore,
    this.lastAttemptAt,
    this.currentProgress,
  });

  bool get canRetake => !hasPassed && attemptsUsed < maxAttempts;
  int get attemptsRemaining => maxAttempts - attemptsUsed;

  factory TestStatus.fromJson(Map<String, dynamic> json) => TestStatus(
    testId: json['test_id'] ?? '',
    hasStarted: json['has_started'] == true || json['has_started'] == 1,
    isInProgress: json['is_in_progress'] == true || json['is_in_progress'] == 1,
    hasPassed: json['has_passed'] == true || json['has_passed'] == 1,
    attemptsUsed: json['attempts_used'] ?? 0,
    maxAttempts: json['max_attempts'] ?? 3,
    bestScore: json['best_score']?.toDouble(),
    lastAttemptAt: json['last_attempt_at'] != null 
        ? DateTime.tryParse(json['last_attempt_at']) 
        : null,
    currentProgress: json['current_progress'] != null 
        ? TestProgress.fromJson(json['current_progress'])
        : null,
  );
}

/// Live progress data for dashboard (real-time view of a user taking test)
class LiveProgressData {
  final String username;
  final String displayName;
  final String testId;
  final String testTitle;
  final String mode;
  final int currentQuestion;
  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final Duration elapsedTime;
  final DateTime lastActivity;
  final double currentAccuracy;

  const LiveProgressData({
    required this.username,
    required this.displayName,
    required this.testId,
    required this.testTitle,
    required this.mode,
    required this.currentQuestion,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.elapsedTime,
    required this.lastActivity,
    required this.currentAccuracy,
  });

  factory LiveProgressData.fromJson(Map<String, dynamic> json) => LiveProgressData(
    username: json['username'] ?? '',
    displayName: json['display_name'] ?? json['username'] ?? '',
    testId: json['test_id'] ?? '',
    testTitle: json['test_title'] ?? '',
    mode: json['mode'] ?? 'test',
    currentQuestion: json['current_question'] ?? 0,
    totalQuestions: json['total_questions'] ?? 0,
    correctAnswers: json['correct_answers'] ?? 0,
    incorrectAnswers: json['incorrect_answers'] ?? 0,
    elapsedTime: Duration(seconds: json['elapsed_seconds'] ?? 0),
    lastActivity: DateTime.tryParse(json['last_activity'] ?? '') ?? DateTime.now(),
    currentAccuracy: (json['current_accuracy'] ?? 0).toDouble(),
  );
}

// ============================================================================
// KNOWLEDGE BASE PROGRESS TRACKING
// ============================================================================

/// User's KB progress for dashboard display
class UserKBProgress {
  final String username;
  final String displayName;
  final String kbId;
  final int completedTopics;
  final DateTime? lastAccessedAt;

  const UserKBProgress({
    required this.username,
    required this.displayName,
    required this.kbId,
    this.completedTopics = 0,
    this.lastAccessedAt,
  });

  factory UserKBProgress.fromJson(Map<String, dynamic> json) {
    return UserKBProgress(
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      kbId: json['kb_id'] ?? '',
      completedTopics: json['completed_topics'] ?? 0,
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.tryParse(json['last_accessed_at'])
          : null,
    );
  }
}

/// Progress for a knowledge base (step-by-step unlock system)
class KBProgress {
  final String username;
  final String kbId;
  final Set<String> completedTopics; // Set of topic IDs that are completed
  final Set<String> watchedVideos; // Set of video IDs that have been watched
  final String? currentTopicId; // Currently active topic
  final DateTime? lastAccessedAt;

  const KBProgress({
    required this.username,
    required this.kbId,
    this.completedTopics = const {},
    this.watchedVideos = const {},
    this.currentTopicId,
    this.lastAccessedAt,
  });

  /// Check if a topic is completed
  bool isTopicCompleted(String topicId) => completedTopics.contains(topicId);

  /// Check if a video has been watched
  bool isVideoWatched(String videoId) => watchedVideos.contains(videoId);

  factory KBProgress.fromJson(Map<String, dynamic> json) {
    return KBProgress(
      username: json['username'] ?? '',
      kbId: json['kb_id'] ?? '',
      completedTopics: json['completed_topics'] != null
          ? Set<String>.from(json['completed_topics'])
          : {},
      watchedVideos: json['watched_videos'] != null
          ? Set<String>.from(json['watched_videos'])
          : {},
      currentTopicId: json['current_topic_id'],
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.tryParse(json['last_accessed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'username': username,
    'kb_id': kbId,
    'completed_topics': completedTopics.toList(),
    'watched_videos': watchedVideos.toList(),
    'current_topic_id': currentTopicId,
    'last_accessed_at': lastAccessedAt?.toIso8601String(),
  };

  KBProgress copyWith({
    String? username,
    String? kbId,
    Set<String>? completedTopics,
    Set<String>? watchedVideos,
    String? currentTopicId,
    DateTime? lastAccessedAt,
  }) {
    return KBProgress(
      username: username ?? this.username,
      kbId: kbId ?? this.kbId,
      completedTopics: completedTopics ?? this.completedTopics,
      watchedVideos: watchedVideos ?? this.watchedVideos,
      currentTopicId: currentTopicId ?? this.currentTopicId,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    );
  }
}
