// Training Knowledge Base Screen
//
// Reading interface for study materials organized by chapters, sections and topics.
// Hierarchy: Knowledge Base > Chapters > Sections > Topics > Blocks
// Supports text, images, Vimeo/YouTube video embeds, and tables.
//
// Features step-by-step unlock system:
// - Topics unlock sequentially (must complete in order)
// - Videos must be watched completely before topic is considered complete
// - Progress is tracked per user in the database with local caching fallback

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart' as flutter_webview;
import 'package:webview_windows/webview_windows.dart' as windows_webview;
import 'training_models.dart';
import 'training_service.dart';
import '../../config/api_config.dart';
import '../../app_theme.dart';

// Note: WebView uses system's WebView2 runtime (not bundled with installer)

class TrainingKnowledgeBaseScreen extends StatefulWidget {
  final String? testId; // Load KB linked to this test (optional)
  final String? kbId; // Load KB directly by ID (optional)

  const TrainingKnowledgeBaseScreen({
    super.key,
    this.testId,
    this.kbId,
  }) : assert(testId != null || kbId != null, 'Either testId or kbId must be provided');

  @override
  State<TrainingKnowledgeBaseScreen> createState() => _TrainingKnowledgeBaseScreenState();
}

class _TrainingKnowledgeBaseScreenState extends State<TrainingKnowledgeBaseScreen> {
  static const Color _accent = AppColors.accent;
  static const _storage = FlutterSecureStorage();

  bool _loading = true;
  String? _error;
  KnowledgeBaseData? _kb;
  String? _username;

  // Progress tracking
  Set<String> _completedTopics = {};
  Set<String> _watchedVideos = {};

  // Navigation state
  int _selectedChapterIndex = 0;
  int _selectedSectionIndex = 0;
  int _selectedTopicIndex = 0;
  bool _showingNav = true;

  // Flatten all topics for easier navigation
  List<_TopicLocation> _allTopics = [];

  // Local storage keys for progress caching (includes username for per-user storage)
  String get _localProgressKey => 'kb_progress_${_username ?? 'guest'}_${_kb?.id ?? ''}';
  String get _localWatchedKey => 'kb_watched_${_username ?? 'guest'}_${_kb?.id ?? ''}';

  /// Load progress from local storage
  Future<void> _loadLocalProgress() async {
    if (_kb == null) return;
    try {
      final completedJson = await _storage.read(key: _localProgressKey);
      final watchedJson = await _storage.read(key: _localWatchedKey);

      if (completedJson != null) {
        final completedList = List<String>.from(jsonDecode(completedJson));
        _completedTopics = Set<String>.from(completedList);
        debugPrint('[KB] Loaded ${_completedTopics.length} completed topics from local storage');
      }

      if (watchedJson != null) {
        final watchedList = List<String>.from(jsonDecode(watchedJson));
        _watchedVideos = Set<String>.from(watchedList);
        debugPrint('[KB] Loaded ${_watchedVideos.length} watched videos from local storage');
      }
    } catch (e) {
      debugPrint('[KB] Error loading local progress: $e');
    }
  }

  /// Save progress to local storage
  Future<void> _saveLocalProgress() async {
    if (_kb == null) return;
    try {
      await _storage.write(
        key: _localProgressKey,
        value: jsonEncode(_completedTopics.toList()),
      );
      await _storage.write(
        key: _localWatchedKey,
        value: jsonEncode(_watchedVideos.toList()),
      );
      debugPrint('[KB] Saved progress to local storage: ${_completedTopics.length} topics, ${_watchedVideos.length} videos');
    } catch (e) {
      debugPrint('[KB] Error saving local progress: $e');
    }
  }

  /// Merge local and remote progress (union of both)
  void _mergeProgress(KBProgress? remoteProgress) {
    if (remoteProgress == null) return;

    final beforeTopics = _completedTopics.length;
    final beforeVideos = _watchedVideos.length;

    _completedTopics = _completedTopics.union(remoteProgress.completedTopics);
    _watchedVideos = _watchedVideos.union(remoteProgress.watchedVideos);

    debugPrint('[KB] Merged progress: topics $beforeTopics -> ${_completedTopics.length}, videos $beforeVideos -> ${_watchedVideos.length}');
  }

  KBChapterData? get _currentChapter {
    if (_kb == null || _kb!.chapters.isEmpty) return null;
    if (_selectedChapterIndex < 0 || _selectedChapterIndex >= _kb!.chapters.length) return null;
    return _kb!.chapters[_selectedChapterIndex];
  }

  KBSectionData? get _currentSection {
    if (_currentChapter == null || _currentChapter!.sections.isEmpty) return null;
    if (_selectedSectionIndex < 0 || _selectedSectionIndex >= _currentChapter!.sections.length) return null;
    return _currentChapter!.sections[_selectedSectionIndex];
  }

  KBTopicData? get _currentTopic {
    if (_currentSection == null || _currentSection!.topics.isEmpty) return null;
    if (_selectedTopicIndex < 0 || _selectedTopicIndex >= _currentSection!.topics.length) return null;
    return _currentSection!.topics[_selectedTopicIndex];
  }

  bool get _hasContent => _kb != null &&
      (_kb!.chapters.isNotEmpty || _kb!.sections.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Check if a topic is unlocked (can be accessed)
  bool _isTopicUnlocked(int flatIndex) {
    if (flatIndex == 0) return true; // First topic always unlocked
    if (flatIndex < 0 || flatIndex >= _allTopics.length) return false;

    // Topic is unlocked if the previous topic is completed
    final prevTopic = _allTopics[flatIndex - 1];
    return _completedTopics.contains(prevTopic.topic.id);
  }

  /// Check if a topic is completed
  bool _isTopicCompleted(String topicId) {
    return _completedTopics.contains(topicId);
  }

  /// Get all video IDs from a topic's content blocks
  List<String> _getVideoIdsFromTopic(KBTopicData topic) {
    final videoIds = <String>[];
    for (final block in topic.contentBlocks) {
      if (block.type == ContentBlockType.vimeo) {
        final videoId = block.content.replaceAll(RegExp(r'[^0-9]'), '');
        videoIds.add('vimeo_$videoId');
      } else if (block.type == ContentBlockType.youtube) {
        String videoId = block.content;
        final watchMatch = RegExp(r'[?&]v=([a-zA-Z0-9_-]+)').firstMatch(videoId);
        if (watchMatch != null) videoId = watchMatch.group(1)!;
        final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)').firstMatch(videoId);
        if (shortMatch != null) videoId = shortMatch.group(1)!;
        final embedMatch = RegExp(r'embed/([a-zA-Z0-9_-]+)').firstMatch(videoId);
        if (embedMatch != null) videoId = embedMatch.group(1)!;
        videoIds.add('youtube_$videoId');
      }
    }
    return videoIds;
  }

  /// Check if all videos in a topic have been watched
  bool _areAllVideosWatched(KBTopicData topic) {
    final videoIds = _getVideoIdsFromTopic(topic);
    if (videoIds.isEmpty) return true; // No videos means all watched
    return videoIds.every((id) => _watchedVideos.contains(id));
  }

  /// Check if topic can be marked as complete (all videos watched)
  bool _canCompleteTopic(KBTopicData topic) {
    return _areAllVideosWatched(topic);
  }

  /// Get the flat index of a topic
  int _getFlatIndexOfTopic(String topicId) {
    for (int i = 0; i < _allTopics.length; i++) {
      if (_allTopics[i].topic.id == topicId) return i;
    }
    return -1;
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Get username from secure storage (key matches AuthService._keyUsername)
      _username = await _storage.read(key: 'a1_tools_username');
      debugPrint('[KB] Loaded username from storage: $_username');

      // Load KB by ID if provided, otherwise by test ID
      KnowledgeBaseData? kb;
      if (widget.kbId != null) {
        kb = await TrainingService.instance.getKnowledgeBaseById(widget.kbId!);
      } else if (widget.testId != null) {
        kb = await TrainingService.instance.getKnowledgeBaseForTest(widget.testId!);
      }
      if (mounted) {
        if (kb != null) {
          // Build flattened topic list
          final topics = <_TopicLocation>[];
          for (int c = 0; c < kb.chapters.length; c++) {
            final chapter = kb.chapters[c];
            for (int s = 0; s < chapter.sections.length; s++) {
              final section = chapter.sections[s];
              for (int t = 0; t < section.topics.length; t++) {
                topics.add(_TopicLocation(
                  chapterIndex: c,
                  sectionIndex: s,
                  topicIndex: t,
                  topic: section.topics[t],
                ));
              }
            }
          }
          // Also add legacy sections
          for (int s = 0; s < kb.sections.length; s++) {
            final section = kb.sections[s];
            for (int t = 0; t < section.topics.length; t++) {
              topics.add(_TopicLocation(
                chapterIndex: -1, // Legacy
                sectionIndex: s,
                topicIndex: t,
                topic: section.topics[t],
              ));
            }
          }

          // Set KB first so local storage keys work
          _kb = kb;
          _allTopics = topics;

          // Load local progress first (instant, offline-capable)
          await _loadLocalProgress();

          // Then try to load from API and merge (may fail if offline or API broken)
          if (_username != null) {
            final progress = await TrainingService.instance.getKBProgress(
              username: _username!,
              kbId: kb.id,
            );
            if (progress != null) {
              // Merge API progress with local (take union of both)
              _mergeProgress(progress);
              // Save merged progress back to local storage
              await _saveLocalProgress();
            } else {
              debugPrint('[KB] API progress load failed, using local only');
            }
          }

          setState(() {
            _loading = false;
          });
        } else {
          setState(() {
            _error = 'No study guide available for this test yet.';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load: $e';
          _loading = false;
        });
      }
    }
  }

  /// Mark a video as watched and update local state
  Future<void> _onVideoWatched(String videoId, String platform) async {
    if (_kb == null || _currentTopic == null) return;

    final fullVideoId = '${platform}_$videoId';
    if (_watchedVideos.contains(fullVideoId)) return; // Already watched

    // Update local state immediately
    setState(() {
      _watchedVideos = Set.from(_watchedVideos)..add(fullVideoId);
    });

    // Save to local storage first (always works)
    await _saveLocalProgress();

    // Then try to save to server (may fail)
    if (_username != null) {
      final success = await TrainingService.instance.markVideoWatched(
        username: _username!,
        kbId: _kb!.id,
        topicId: _currentTopic!.id,
        videoId: fullVideoId,
      );
      debugPrint('[KB] Video watched API save: $success');
    }
  }

  /// Mark current topic as completed and move to next
  Future<void> _markTopicCompleted() async {
    debugPrint('[KB] _markTopicCompleted called');
    debugPrint('[KB] kb: ${_kb?.id}, currentTopic: ${_currentTopic?.id}');

    if (_kb == null || _currentTopic == null) {
      debugPrint('[KB] Early return - missing KB or topic');
      return;
    }

    final topic = _currentTopic!;
    debugPrint('[KB] Topic to complete: ${topic.id}');
    debugPrint('[KB] canComplete: ${_canCompleteTopic(topic)}');

    if (!_canCompleteTopic(topic)) {
      // Show message that videos need to be watched
      debugPrint('[KB] Cannot complete - videos not watched');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please watch all videos before proceeding to the next topic.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Update local state
    debugPrint('[KB] Updating local state - adding ${topic.id} to completed');
    setState(() {
      _completedTopics = Set.from(_completedTopics)..add(topic.id);
    });
    debugPrint('[KB] Completed topics now: $_completedTopics');

    // Save to local storage first (always works)
    debugPrint('[KB] Saving to local storage...');
    await _saveLocalProgress();

    // Then try to save to server (may fail)
    if (_username != null) {
      debugPrint('[KB] Saving to server...');
      final success = await TrainingService.instance.markTopicCompleted(
        username: _username!,
        kbId: _kb!.id,
        topicId: topic.id,
      );
      debugPrint('[KB] Server save result: $success');
    } else {
      debugPrint('[KB] No username - skipping server save');
    }

    // Move to next topic if available
    final currentFlatIndex = _getFlatIndexOfTopic(topic.id);
    debugPrint('[KB] Current flat index: $currentFlatIndex, total topics: ${_allTopics.length}');

    if (currentFlatIndex >= 0 && currentFlatIndex < _allTopics.length - 1) {
      final next = _allTopics[currentFlatIndex + 1];
      debugPrint('[KB] Navigating to next topic: chapter=${next.chapterIndex}, section=${next.sectionIndex}, topic=${next.topicIndex}');
      _navigateToTopic(next.chapterIndex, next.sectionIndex, next.topicIndex, skipLockCheck: true);
    } else {
      // All topics completed
      debugPrint('[KB] All topics completed!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Congratulations! You have completed all topics in this guide.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _navigateToTopic(int chapterIdx, int sectionIdx, int topicIdx, {bool skipLockCheck = false}) {
    debugPrint('[KB] _navigateToTopic: chapter=$chapterIdx, section=$sectionIdx, topic=$topicIdx, skipLock=$skipLockCheck');

    // Find the flat index of the target topic
    final targetIndex = _allTopics.indexWhere((loc) =>
        loc.chapterIndex == chapterIdx &&
        loc.sectionIndex == sectionIdx &&
        loc.topicIndex == topicIdx);

    debugPrint('[KB] Target index found: $targetIndex');

    // Check if topic is unlocked (skip check when navigating programmatically after completion)
    if (!skipLockCheck && !_isTopicUnlocked(targetIndex)) {
      debugPrint('[KB] Topic is locked, showing snackbar');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This topic is locked. Complete previous topics first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    debugPrint('[KB] Setting state: chapter=${chapterIdx >= 0 ? chapterIdx : 0}, section=$sectionIdx, topic=$topicIdx');
    setState(() {
      _selectedChapterIndex = chapterIdx >= 0 ? chapterIdx : 0;
      _selectedSectionIndex = sectionIdx;
      _selectedTopicIndex = topicIdx;
      _showingNav = false;
    });
    debugPrint('[KB] Navigation complete');
  }

  /// Build status icon for topic in navigation list
  Widget _buildTopicStatusIcon({
    required bool isUnlocked,
    required bool isCompleted,
    required bool isSelected,
  }) {
    if (!isUnlocked) {
      return const Icon(Icons.lock, size: 16, color: Colors.grey);
    }
    if (isCompleted) {
      return Icon(Icons.check_circle, size: 16, color: Colors.green[600]);
    }
    return Icon(
      Icons.play_circle_outline,
      size: 16,
      color: isSelected ? _accent : Colors.grey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(_kb?.title ?? 'Study Guide'),
        centerTitle: true,
        leading: isMobile && !_showingNav && _kb != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => setState(() => _showingNav = true),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : !_hasContent
                  ? _buildEmptyState()
                  : isMobile
                      ? _buildMobileLayout(isDark)
                      : _buildDesktopLayout(isDark),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No content available', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    if (_showingNav) {
      return _buildNavigationList(isDark);
    } else {
      return _buildTopicContent(isDark);
    }
  }

  Widget _buildDesktopLayout(bool isDark) {
    return Row(
      children: [
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
            border: Border(right: BorderSide(color: isDark ? Colors.white12 : Colors.grey[300]!)),
          ),
          child: _buildNavigationList(isDark),
        ),
        Expanded(child: _buildTopicContent(isDark)),
      ],
    );
  }

  Widget _buildNavigationList(bool isDark) {
    // Count total topics
    int totalTopics = 0;
    for (final chapter in _kb!.chapters) {
      for (final section in chapter.sections) {
        totalTopics += section.topics.length;
      }
    }
    for (final section in _kb!.sections) {
      totalTopics += section.topics.length;
    }

    final completedCount = _completedTopics.length;
    final progressPercent = totalTopics > 0 ? (completedCount / totalTopics * 100).round() : 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header with progress
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_accent, _accent.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book, color: Colors.white, size: 32),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$progressPercent%',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Study Guide', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '$completedCount / $totalTopics topics completed',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalTopics > 0 ? completedCount / totalTopics : 0,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Chapters
        ..._kb!.chapters.asMap().entries.map((chapterEntry) {
          final chapterIdx = chapterEntry.key;
          final chapter = chapterEntry.value;
          final isChapterExpanded = chapterIdx == _selectedChapterIndex;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isChapterExpanded ? _accent : (isDark ? Colors.white12 : Colors.grey[200]!),
                width: isChapterExpanded ? 2 : 1,
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: isChapterExpanded,
                onExpansionChanged: (expanded) {
                  if (expanded) setState(() => _selectedChapterIndex = chapterIdx);
                },
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(chapter.icon, style: const TextStyle(fontSize: 20)),
                ),
                title: Text(
                  chapter.title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: isChapterExpanded ? _accent : null),
                ),
                subtitle: Text(
                  '${chapter.sections.length} sections',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                ),
                children: [
                  // Sections within chapter
                  ...chapter.sections.asMap().entries.map((sectionEntry) {
                    final sectionIdx = sectionEntry.key;
                    final section = sectionEntry.value;
                    final isSectionExpanded = chapterIdx == _selectedChapterIndex && 
                                              sectionIdx == _selectedSectionIndex;

                    return Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: isSectionExpanded 
                            ? Border.all(color: _accent.withValues(alpha: 0.5)) 
                            : null,
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: isSectionExpanded,
                          onExpansionChanged: (expanded) {
                            if (expanded) {
                              setState(() {
                                _selectedChapterIndex = chapterIdx;
                                _selectedSectionIndex = sectionIdx;
                              });
                            }
                          },
                          leading: const Icon(Icons.folder_outlined, size: 18, color: _accent),
                          title: Text(
                            section.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSectionExpanded ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${section.topics.length} topics',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                          children: section.topics.asMap().entries.map((topicEntry) {
                            final topicIdx = topicEntry.key;
                            final topic = topicEntry.value;
                            final isTopicSelected = chapterIdx == _selectedChapterIndex &&
                                                    sectionIdx == _selectedSectionIndex &&
                                                    topicIdx == _selectedTopicIndex;

                            // Find flat index for this topic
                            final flatIndex = _allTopics.indexWhere((loc) =>
                                loc.chapterIndex == chapterIdx &&
                                loc.sectionIndex == sectionIdx &&
                                loc.topicIndex == topicIdx);
                            final isUnlocked = _isTopicUnlocked(flatIndex);
                            final isCompleted = _isTopicCompleted(topic.id);

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.only(left: 32, right: 16),
                              enabled: isUnlocked,
                              leading: _buildTopicStatusIcon(
                                isUnlocked: isUnlocked,
                                isCompleted: isCompleted,
                                isSelected: isTopicSelected,
                              ),
                              title: Text(
                                topic.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isTopicSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: !isUnlocked
                                      ? Colors.grey
                                      : isTopicSelected
                                          ? _accent
                                          : isCompleted
                                              ? Colors.green[700]
                                              : null,
                                ),
                              ),
                              trailing: isCompleted
                                  ? Icon(Icons.check_circle, size: 16, color: Colors.green[600])
                                  : null,
                              onTap: () => _navigateToTopic(chapterIdx, sectionIdx, topicIdx),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        }),

        // Legacy sections (if any)
        if (_kb!.sections.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Additional Content',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          ..._kb!.sections.asMap().entries.map((sectionEntry) {
            final sectionIdx = sectionEntry.key;
            final section = sectionEntry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: const Icon(Icons.folder_outlined, size: 18, color: _accent),
                  title: Text(section.title),
                  subtitle: Text('${section.topics.length} topics', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  children: section.topics.asMap().entries.map((topicEntry) {
                    final topicIdx = topicEntry.key;
                    final topic = topicEntry.value;

                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.article, size: 16),
                      title: Text(topic.title, style: const TextStyle(fontSize: 13)),
                      onTap: () => _navigateToTopic(-1, sectionIdx, topicIdx),
                    );
                  }).toList(),
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildTopicContent(bool isDark) {
    if (_currentTopic == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Select a topic to read', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    final topic = _currentTopic!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb
          if (_currentChapter != null)
            Text(
              '${_currentChapter!.title} > ${_currentSection?.title ?? ""}',
              style: const TextStyle(color: _accent, fontSize: 12),
            ),
          const SizedBox(height: 8),
          
          // Title
          Text(
            topic.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Content blocks
          if (topic.contentBlocks.isNotEmpty)
            ...topic.contentBlocks.map((block) => _buildContentBlock(block, isDark))
          else if (topic.content.isNotEmpty)
            Text(topic.content, style: const TextStyle(fontSize: 15, height: 1.6))
          else
            Text('No content yet', style: TextStyle(color: Colors.grey[500])),

          const SizedBox(height: 48),

          // Navigation
          _buildTopicNavigation(isDark),
        ],
      ),
    );
  }

  /// Open video in fullscreen in-app player dialog
  void _openVideoPlayer(BuildContext context, String videoId, String platform, String? caption) {
    final fullVideoId = '${platform}_$videoId';
    final isWatched = _watchedVideos.contains(fullVideoId);

    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => _VideoPlayerDialog(
        videoId: videoId,
        platform: platform,
        caption: caption,
        isWatched: isWatched,
        onMarkWatched: () => _onVideoWatched(videoId, platform),
      ),
    );
  }

  Widget _buildContentBlock(ContentBlock block, bool isDark) {
    switch (block.type) {
      case ContentBlockType.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            block.content,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        );

      case ContentBlockType.image:
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  block.content,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                ),
              ),
              if (block.caption != null && block.caption!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  block.caption!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        );

      case ContentBlockType.vimeo:
        final videoId = block.content.replaceAll(RegExp(r'[^0-9]'), ''); // Extract just the ID
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: FractionallySizedBox(
                    widthFactor: 0.85,
                    child: _buildVideoThumbnailCard(
                      videoId: videoId,
                      platform: 'vimeo',
                      caption: block.caption,
                      onTap: () => _openVideoPlayer(context, videoId, 'vimeo', block.caption),
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
              if (block.caption != null && block.caption!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    block.caption!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ],
          ),
        );

      case ContentBlockType.youtube:
        // Extract video ID - handle full URLs or just IDs
        String videoId = block.content;
        // Handle youtube.com/watch?v=ID format
        final watchMatch = RegExp(r'[?&]v=([a-zA-Z0-9_-]+)').firstMatch(videoId);
        if (watchMatch != null) {
          videoId = watchMatch.group(1)!;
        }
        // Handle youtu.be/ID format
        final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)').firstMatch(videoId);
        if (shortMatch != null) {
          videoId = shortMatch.group(1)!;
        }
        // Handle embed URL format
        final embedMatch = RegExp(r'embed/([a-zA-Z0-9_-]+)').firstMatch(videoId);
        if (embedMatch != null) {
          videoId = embedMatch.group(1)!;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: FractionallySizedBox(
                    widthFactor: 0.85,
                    child: _buildVideoThumbnailCard(
                      videoId: videoId,
                      platform: 'youtube',
                      caption: block.caption,
                      onTap: () => _openVideoPlayer(context, videoId, 'youtube', block.caption),
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
              if (block.caption != null && block.caption!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    block.caption!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ],
          ),
        );

      case ContentBlockType.table:
        return _buildTableBlock(block, isDark);
    }
  }

  /// Build a clickable video thumbnail card
  Widget _buildVideoThumbnailCard({
    required String videoId,
    required String platform,
    required String? caption,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    // Get thumbnail URL based on platform
    String thumbnailUrl;
    String platformIcon;
    Color platformColor;

    if (platform == 'youtube') {
      // YouTube provides predictable thumbnail URLs
      thumbnailUrl = ApiConfig.youtubeThumbnail(videoId);
      platformIcon = 'YouTube';
      platformColor = const Color(0xFFFF0000);
    } else {
      // Vimeo - use a placeholder since thumbnails require API call
      // The actual video will open in browser anyway
      thumbnailUrl = '';
      platformIcon = 'Vimeo';
      platformColor = const Color(0xFF1AB7EA);
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Material(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail or placeholder
              if (thumbnailUrl.isNotEmpty)
                Image.network(
                  thumbnailUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildVideoPlaceholder(
                    platform: platform,
                    platformColor: platformColor,
                    isDark: isDark,
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildVideoPlaceholder(
                      platform: platform,
                      platformColor: platformColor,
                      isDark: isDark,
                      showLoading: true,
                    );
                  },
                )
              else
                _buildVideoPlaceholder(
                  platform: platform,
                  platformColor: platformColor,
                  isDark: isDark,
                ),

              // Gradient overlay for better text visibility
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),

              // Play button overlay
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: platformColor.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),

              // Platform badge at top-left
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: platformColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        platform == 'youtube' ? Icons.play_circle_filled : Icons.videocam,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        platformIcon,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // "Tap to play" hint at bottom
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Icon(
                      Icons.open_in_new,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tap to watch in $platformIcon',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
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

  /// Build a placeholder for videos without thumbnails
  Widget _buildVideoPlaceholder({
    required String platform,
    required Color platformColor,
    required bool isDark,
    bool showLoading = false,
  }) {
    return Container(
      color: isDark ? const Color(0xFF252525) : Colors.grey[200],
      child: Center(
        child: showLoading
            ? CircularProgressIndicator(color: platformColor)
            : Icon(
                Icons.video_library,
                size: 64,
                color: platformColor.withValues(alpha: 0.5),
              ),
      ),
    );
  }

  /// Build a table block for display
  Widget _buildTableBlock(ContentBlock block, bool isDark) {
    final tableData = block.tableData ?? {'headers': [], 'rows': []};
    final headers = List<String>.from(tableData['headers'] ?? []);
    final rows = (tableData['rows'] as List?)
        ?.map((r) => List<String>.from(r))
        .toList() ?? [];

    if (headers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    _accent.withValues(alpha: isDark ? 0.2 : 0.1),
                  ),
                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return _accent.withValues(alpha: 0.05);
                    }
                    return null;
                  }),
                  columns: headers.map((h) => DataColumn(
                    label: Text(
                      h,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  )).toList(),
                  rows: rows.map((row) => DataRow(
                    cells: row.map((cell) => DataCell(
                      Text(
                        cell,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    )).toList(),
                  )).toList(),
                ),
              ),
            ),
          ),
          if (block.caption != null && block.caption!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              block.caption!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopicNavigation(bool isDark) {
    // Find current position in flattened list
    int currentFlatIndex = -1;
    for (int i = 0; i < _allTopics.length; i++) {
      final loc = _allTopics[i];
      if (loc.chapterIndex == _selectedChapterIndex &&
          loc.sectionIndex == _selectedSectionIndex &&
          loc.topicIndex == _selectedTopicIndex) {
        currentFlatIndex = i;
        break;
      }
    }

    final hasPrev = currentFlatIndex > 0;
    final hasNext = currentFlatIndex < _allTopics.length - 1;
    final isCurrentTopicCompleted = _currentTopic != null && _isTopicCompleted(_currentTopic!.id);
    final canComplete = _currentTopic != null && _canCompleteTopic(_currentTopic!);
    final videoIds = _currentTopic != null ? _getVideoIdsFromTopic(_currentTopic!) : <String>[];
    final watchedCount = videoIds.where((id) => _watchedVideos.contains(id)).length;
    final isNextUnlocked = hasNext && _isTopicUnlocked(currentFlatIndex + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Video progress indicator (if topic has videos)
        if (videoIds.isNotEmpty && !isCurrentTopicCompleted) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: canComplete ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  canComplete ? Icons.check_circle : Icons.play_circle_outline,
                  color: canComplete ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    canComplete
                        ? 'All videos watched! You can proceed.'
                        : 'Watch all videos to continue ($watchedCount/${videoIds.length} completed)',
                    style: TextStyle(
                      fontSize: 13,
                      color: canComplete ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Navigation buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (hasPrev)
              OutlinedButton.icon(
                onPressed: () {
                  final prev = _allTopics[currentFlatIndex - 1];
                  _navigateToTopic(prev.chapterIndex, prev.sectionIndex, prev.topicIndex);
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Previous'),
              )
            else
              const SizedBox(),

            // Mark Complete / Next button
            if (isCurrentTopicCompleted)
              // Already completed - show next or done
              hasNext
                  ? ElevatedButton.icon(
                      onPressed: isNextUnlocked
                          ? () {
                              final next = _allTopics[currentFlatIndex + 1];
                              _navigateToTopic(next.chapterIndex, next.sectionIndex, next.topicIndex);
                            }
                          : null,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Next Topic'),
                      style: ElevatedButton.styleFrom(backgroundColor: _accent),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.celebration, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('All Done!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
            else
              // Not completed - show Mark Complete button
              ElevatedButton.icon(
                onPressed: canComplete ? _markTopicCompleted : null,
                icon: Icon(
                  canComplete ? Icons.check : Icons.lock,
                  size: 18,
                ),
                label: Text(canComplete ? 'Complete & Continue' : 'Watch Videos First'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canComplete ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Helper class to track topic location in hierarchy
class _TopicLocation {
  final int chapterIndex; // -1 for legacy sections
  final int sectionIndex;
  final int topicIndex;
  final KBTopicData topic;

  _TopicLocation({
    required this.chapterIndex,
    required this.sectionIndex,
    required this.topicIndex,
    required this.topic,
  });
}

/// In-app video player dialog using WebView
/// Supports both Vimeo and YouTube videos
class _VideoPlayerDialog extends StatefulWidget {
  final String videoId;
  final String platform; // 'vimeo' or 'youtube'
  final String? caption;
  final bool isWatched;
  final VoidCallback? onMarkWatched;

  const _VideoPlayerDialog({
    required this.videoId,
    required this.platform,
    this.caption,
    this.isWatched = false,
    this.onMarkWatched,
  });

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  // Windows controller
  windows_webview.WebviewController? _windowsController;
  // iOS/Android controller
  flutter_webview.WebViewController? _mobileController;

  bool _isInitialized = false;
  String? _errorMessage;
  bool _canMarkWatched = false;
  bool _markedAsWatched = false;
  int _watchTimeSeconds = 0;

  bool get _isWindows {
    try {
      return Platform.isWindows;
    } catch (e) {
      debugPrint('[TrainingKnowledgeBaseScreen] Error: $e');
      return false;
    }
  }

  String get _embedUrl {
    if (widget.platform == 'youtube') {
      return ApiConfig.youtubeEmbed(widget.videoId);
    } else {
      return ApiConfig.vimeoEmbed(widget.videoId);
    }
  }

  @override
  void initState() {
    super.initState();
    _markedAsWatched = widget.isWatched;
    _initController();
    _startWatchTimer();
  }

  @override
  void dispose() {
    _windowsController?.dispose();
    super.dispose();
  }

  /// Start timer to enable "Mark as Watched" after 30 seconds
  void _startWatchTimer() {
    if (widget.isWatched) {
      setState(() => _canMarkWatched = true);
      return;
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _watchTimeSeconds = 1);
      _continueWatchTimer();
    });
  }

  void _continueWatchTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _watchTimeSeconds++;
        // Enable mark as watched after 30 seconds of watching
        if (_watchTimeSeconds >= 30) {
          _canMarkWatched = true;
        }
      });
      if (_watchTimeSeconds < 30) {
        _continueWatchTimer();
      }
    });
  }

  void _markAsWatched() {
    if (_markedAsWatched) return;
    setState(() => _markedAsWatched = true);
    widget.onMarkWatched?.call();
  }

  Future<void> _initController() async {
    try {
      if (_isWindows) {
        final controller = windows_webview.WebviewController();
        await controller.initialize();
        await controller.loadUrl(_embedUrl);

        if (mounted) {
          setState(() {
            _windowsController = controller;
            _isInitialized = true;
          });
        }
      } else {
        final controller = flutter_webview.WebViewController()
          ..setJavaScriptMode(flutter_webview.JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..loadRequest(Uri.parse(_embedUrl));

        if (mounted) {
          setState(() {
            _mobileController = controller;
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Init error: $e');
      if (mounted) {
        // Check if it's WebView2 missing error
        final errorStr = e.toString();
        String userMessage;
        if (errorStr.contains('environment_creation_failed') ||
            errorStr.contains('WebView2')) {
          userMessage = 'WebView2 Runtime is not installed on this computer.\n\n'
              'Please install it from Microsoft:\nhttps://go.microsoft.com/fwlink/p/?LinkId=2124703\n\n'
              'Or click "Open in Browser" below to watch the video.';
        } else {
          userMessage = 'Failed to load video player: $e';
        }
        setState(() => _errorMessage = userMessage);
      }
    }
  }

  Widget _buildWebView() {
    if (_isWindows && _windowsController != null) {
      return windows_webview.Webview(_windowsController!);
    } else if (_mobileController != null) {
      return flutter_webview.WebViewWidget(controller: _mobileController!);
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    final platformName = widget.platform == 'youtube' ? 'YouTube' : 'Vimeo';
    final platformColor = widget.platform == 'youtube'
        ? const Color(0xFFFF0000)
        : const Color(0xFF1AB7EA);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _isInitialized
                  ? _buildWebView()
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.white54),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load video',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final url = widget.platform == 'youtube'
                                        ? ApiConfig.youtubeWatch(widget.videoId)
                                        : ApiConfig.vimeoWatch(widget.videoId);
                                    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                  },
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('Open in Browser'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: platformColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: platformColor),
                              const SizedBox(height: 16),
                              Text(
                                'Loading $platformName video...',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
            ),
          ),

          // Close button
          Positioned(
            top: 16,
            right: 16,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),

          // Platform badge at top-left
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: platformColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.platform == 'youtube' ? Icons.play_circle_filled : Icons.videocam,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    platformName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Caption at bottom
          if (widget.caption != null && widget.caption!.isNotEmpty)
            Positioned(
              bottom: 80,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.caption!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          // Mark as Watched button at bottom
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: _markedAsWatched
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Video Watched',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : _canMarkWatched
                    ? Material(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _markAsWatched,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Mark as Watched',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                value: _watchTimeSeconds / 30,
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
                                backgroundColor: Colors.white24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Watch ${30 - _watchTimeSeconds}s more to mark as complete',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
