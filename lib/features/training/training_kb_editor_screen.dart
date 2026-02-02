// Training Knowledge Base Editor Screen
//
// Admin/Developer interface for creating and editing knowledge base content.
// Hierarchy: Knowledge Base > Chapters > Sections > Topics > Blocks
// Supports text, images (URLs), Vimeo video embeds, and tables.

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'training_models.dart';
import 'training_service.dart';

class TrainingKBEditorScreen extends StatefulWidget {
  final String? kbId; // null = create new
  final String currentUserRole;

  const TrainingKBEditorScreen({
    super.key,
    this.kbId,
    required this.currentUserRole,
  });

  @override
  State<TrainingKBEditorScreen> createState() => _TrainingKBEditorScreenState();
}

class _TrainingKBEditorScreenState extends State<TrainingKBEditorScreen> {
  static const Color _accent = AppColors.accent;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // KB data
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _testIdController = TextEditingController();
  String _targetRole = 'dispatcher';

  // Chapters (new hierarchy)
  List<KBChapterData> _chapters = [];
  
  // Track expanded states
  final Set<String> _expandedChapters = {};
  final Set<String> _expandedSections = {};

  bool get _isNew => widget.kbId == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) {
      _loadData();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _testIdController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final kb = await TrainingService.instance.getKnowledgeBase(widget.kbId!);
      if (kb != null && mounted) {
        setState(() {
          _idController.text = kb.id;
          _titleController.text = kb.title;
          _descriptionController.text = kb.description;
          _testIdController.text = kb.testId ?? '';
          _targetRole = kb.targetRole;
          _chapters = List.from(kb.chapters);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load knowledge base';
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

  Future<void> _saveKB() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      bool success;
      if (_isNew) {
        success = await TrainingService.instance.createKnowledgeBase(
          id: _idController.text.trim(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          targetRole: _targetRole,
          testId: _testIdController.text.trim().isEmpty ? null : _testIdController.text.trim(),
        );
      } else {
        success = await TrainingService.instance.updateKnowledgeBase(
          id: widget.kbId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          targetRole: _targetRole,
          testId: _testIdController.text.trim().isEmpty ? null : _testIdController.text.trim(),
        );
      }

      if (mounted) {
        setState(() => _saving = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved successfully'), backgroundColor: Colors.green),
          );
          if (_isNew) Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save'), backgroundColor: Colors.red),
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

  /// Delete knowledge base - Developer only with password confirmation
  Future<void> _deleteKB() async {
    // Check if user is developer
    if (widget.currentUserRole != 'developer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only developers can delete study guides'),
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
            const Text('Delete Study Guide?'),
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
              'This will permanently delete this study guide, including all chapters, '
              'sections, topics, and content blocks.',
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
      final success = await TrainingService.instance.deleteKnowledgeBase(widget.kbId!);
      if (success && mounted) Navigator.pop(context, true);
    }
  }

  // ============================================================================
  // CHAPTER METHODS
  // ============================================================================

  Future<void> _addChapter() async {
    final result = await _showChapterDialog();
    if (result != null && mounted) {
      setState(() => _chapters.add(result));
    }
  }

  Future<void> _editChapter(KBChapterData chapter) async {
    final result = await _showChapterDialog(existing: chapter);
    if (result != null && mounted) {
      await _loadData();
    }
  }

  Future<KBChapterData?> _showChapterDialog({KBChapterData? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final iconController = TextEditingController(text: existing?.icon ?? '📚');
    KBChapterData? result;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Chapter' : 'Edit Chapter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Chapter Title',
                hintText: 'e.g., Getting Started',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: iconController,
              decoration: const InputDecoration(
                labelText: 'Icon (emoji)',
                hintText: '📚',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              
              if (existing == null) {
                final chapter = await TrainingService.instance.createChapter(
                  kbId: widget.kbId!,
                  title: titleController.text.trim(),
                  icon: iconController.text.trim().isEmpty ? '📚' : iconController.text.trim(),
                );
                result = chapter;
              } else {
                await TrainingService.instance.updateChapter(
                  id: existing.id,
                  title: titleController.text.trim(),
                  icon: iconController.text.trim().isEmpty ? '📚' : iconController.text.trim(),
                );
                result = existing; // Signal success
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    return result;
  }

  Future<void> _deleteChapter(KBChapterData chapter) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chapter?'),
        content: Text('Delete "${chapter.title}" and all its sections and topics?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await TrainingService.instance.deleteChapter(chapter.id);
      if (success && mounted) {
        setState(() {
          _chapters.removeWhere((c) => c.id == chapter.id);
          _expandedChapters.remove(chapter.id);
        });
      }
    }
  }

  // ============================================================================
  // SECTION METHODS
  // ============================================================================

  Future<void> _addSection(KBChapterData chapter) async {
    final result = await _showSectionDialog(chapterId: chapter.id);
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Section added!'), backgroundColor: Colors.green),
      );
      await _loadData();
      setState(() => _expandedChapters.add(chapter.id));
    }
  }

  Future<void> _editSection(KBSectionData section) async {
    final result = await _showSectionDialog(existing: section);
    if (result != null && mounted) {
      await _loadData();
    }
  }

  Future<KBSectionData?> _showSectionDialog({String? chapterId, KBSectionData? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    KBSectionData? result;
    bool saving = false;
    String? errorMsg;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Section' : 'Edit Section'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Section Title',
                  hintText: 'e.g., Basic Concepts',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                enabled: !saving,
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 12),
                Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving ? null : () async {
                if (titleController.text.trim().isEmpty) {
                  setDialogState(() => errorMsg = 'Please enter a title');
                  return;
                }
                
                setDialogState(() {
                  saving = true;
                  errorMsg = null;
                });
                
                try {
                  if (existing == null && chapterId != null) {
                    debugPrint('Creating section for chapter: $chapterId');
                    final section = await TrainingService.instance.createSection(
                      chapterId: chapterId,
                      title: titleController.text.trim(),
                    );
                    if (section != null) {
                      result = section;
                      debugPrint('Section created: ${section.id}');
                    } else {
                      setDialogState(() {
                        saving = false;
                        errorMsg = 'Failed to create section. Check console for details.';
                      });
                      return;
                    }
                  } else if (existing != null) {
                    final success = await TrainingService.instance.updateSection(
                      id: existing.id,
                      title: titleController.text.trim(),
                    );
                    if (success) {
                      result = existing;
                    } else {
                      setDialogState(() {
                        saving = false;
                        errorMsg = 'Failed to update section';
                      });
                      return;
                    }
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (e) {
                  debugPrint('Section dialog error: $e');
                  setDialogState(() {
                    saving = false;
                    errorMsg = 'Error: $e';
                  });
                }
              },
              child: saving 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );

    return result;
  }

  Future<void> _deleteSection(KBSectionData section) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section?'),
        content: Text('Delete "${section.title}" and all its topics?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await TrainingService.instance.deleteSection(section.id);
      if (success && mounted) {
        await _loadData();
      }
    }
  }

  // ============================================================================
  // TOPIC METHODS
  // ============================================================================

  Future<void> _addTopic(KBSectionData section) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _TopicEditorScreen(
          sectionId: section.id,
          sectionTitle: section.title,
          topic: null,
        ),
      ),
    );
    if (result == true && mounted) {
      await _loadData();
      setState(() => _expandedSections.add(section.id));
    }
  }

  Future<void> _editTopic(KBSectionData section, KBTopicData topic) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _TopicEditorScreen(
          sectionId: section.id,
          sectionTitle: section.title,
          topic: topic,
        ),
      ),
    );
    if (result == true && mounted) {
      await _loadData();
    }
  }

  Future<void> _deleteTopic(KBSectionData section, KBTopicData topic) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Topic?'),
        content: Text('Delete "${topic.title}" and all its content?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await TrainingService.instance.deleteTopic(topic.id);
      if (success && mounted) {
        await _loadData();
      }
    }
  }

  // ============================================================================
  // REORDER METHODS
  // ============================================================================

  Future<void> _moveChapter(int index, int direction) async {
    final newIndex = index + direction;
    if (newIndex < 0 || newIndex >= _chapters.length) return;

    // Swap locally for immediate feedback
    setState(() {
      final chapter = _chapters.removeAt(index);
      _chapters.insert(newIndex, chapter);
    });

    // Send new order to server
    final chapterIds = _chapters.map((c) => c.id).toList();
    final success = await TrainingService.instance.reorderChapters(widget.kbId!, chapterIds);
    
    if (!success) {
      // Revert on failure
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reorder chapters'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _moveSection(KBChapterData chapter, int index, int direction) async {
    final newIndex = index + direction;
    if (newIndex < 0 || newIndex >= chapter.sections.length) return;

    // Get the section IDs in new order
    final sectionIds = chapter.sections.map((s) => s.id).toList();
    final movedId = sectionIds.removeAt(index);
    sectionIds.insert(newIndex, movedId);

    // Update locally for immediate feedback
    final chapterIndex = _chapters.indexWhere((c) => c.id == chapter.id);
    if (chapterIndex != -1) {
      setState(() {
        final sections = List<KBSectionData>.from(_chapters[chapterIndex].sections);
        final section = sections.removeAt(index);
        sections.insert(newIndex, section);
        _chapters[chapterIndex] = KBChapterData(
          id: chapter.id,
          kbId: chapter.kbId,
          title: chapter.title,
          icon: chapter.icon,
          sortOrder: chapter.sortOrder,
          isActive: chapter.isActive,
          sections: sections,
        );
      });
    }

    // Send new order to server
    final success = await TrainingService.instance.reorderSections(
      chapterId: chapter.id,
      sectionIds: sectionIds,
    );
    
    if (!success) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reorder sections'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _moveTopic(KBSectionData section, int index, int direction) async {
    final newIndex = index + direction;
    if (newIndex < 0 || newIndex >= section.topics.length) return;

    // Get the topic IDs in new order
    final topicIds = section.topics.map((t) => t.id).toList();
    final movedId = topicIds.removeAt(index);
    topicIds.insert(newIndex, movedId);

    // Find and update locally for immediate feedback
    for (int ci = 0; ci < _chapters.length; ci++) {
      final sectionIndex = _chapters[ci].sections.indexWhere((s) => s.id == section.id);
      if (sectionIndex != -1) {
        setState(() {
          final topics = List<KBTopicData>.from(_chapters[ci].sections[sectionIndex].topics);
          final topic = topics.removeAt(index);
          topics.insert(newIndex, topic);
          
          final sections = List<KBSectionData>.from(_chapters[ci].sections);
          sections[sectionIndex] = KBSectionData(
            id: section.id,
            kbId: section.kbId,
            chapterId: section.chapterId,
            title: section.title,
            sortOrder: section.sortOrder,
            isActive: section.isActive,
            topics: topics,
          );
          
          _chapters[ci] = KBChapterData(
            id: _chapters[ci].id,
            kbId: _chapters[ci].kbId,
            title: _chapters[ci].title,
            icon: _chapters[ci].icon,
            sortOrder: _chapters[ci].sortOrder,
            isActive: _chapters[ci].isActive,
            sections: sections,
          );
        });
        break;
      }
    }

    // Send new order to server
    final success = await TrainingService.instance.reorderTopics(section.id, topicIds);
    
    if (!success) {
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reorder topics'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Create Knowledge Base' : 'Edit Knowledge Base'),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Refresh',
            ),
          // Delete button - Developer only
          if (!_isNew && widget.currentUserRole == 'developer')
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteKB,
              tooltip: 'Delete',
            ),
          IconButton(
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            onPressed: _saving ? null : _saveKB,
            tooltip: 'Save',
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
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(isDark),
      floatingActionButton: !_isNew && !_loading
          ? FloatingActionButton.extended(
              onPressed: _addChapter,
              backgroundColor: _accent,
              icon: const Icon(Icons.add),
              label: const Text('Add Chapter'),
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
          // Settings Card
          _buildSettingsCard(isDark),
          const SizedBox(height: 24),

          // Chapters section
          if (!_isNew) ...[
            Row(
              children: [
                const Icon(Icons.library_books, color: _accent),
                const SizedBox(width: 8),
                const Text('Chapters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_chapters.length} chapters', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 12),

            if (_chapters.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.library_books_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No chapters yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the button below to add your first chapter',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._chapters.asMap().entries.map((entry) => _buildChapterCard(entry.value, entry.key, isDark)),
          ],

          const SizedBox(height: 100), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildSettingsCard(bool isDark) {
    return Card(
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
                  Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),

              if (_isNew) ...[
                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'Knowledge Base ID',
                    hintText: 'e.g., dispatcher_kb',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., Dispatcher Training Guide',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of this knowledge base',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _testIdController,
                decoration: const InputDecoration(
                  labelText: 'Linked Test ID (optional)',
                  hintText: 'e.g., dispatcher_test',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _targetRole,
                decoration: const InputDecoration(
                  labelText: 'Target Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'dispatcher', child: Text('Dispatcher')),
                  DropdownMenuItem(value: 'technician', child: Text('Technician')),
                  DropdownMenuItem(value: 'marketing', child: Text('Marketing')),
                ],
                onChanged: (v) => setState(() => _targetRole = v!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChapterCard(KBChapterData chapter, int index, bool isDark) {
    final isExpanded = _expandedChapters.contains(chapter.id);
    final isFirst = index == 0;
    final isLast = index == _chapters.length - 1;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpanded ? _accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chapter Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedChapters.remove(chapter.id);
                } else {
                  _expandedChapters.add(chapter.id);
                }
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(chapter.icon, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${chapter.sections.length} sections',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          
          // Chapter Actions (always visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
            ),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _addSection(chapter),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Section'),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),
                const Spacer(),
                // Move up/down buttons
                IconButton(
                  onPressed: isFirst ? null : () => _moveChapter(index, -1),
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  tooltip: 'Move Up',
                  color: _accent,
                ),
                IconButton(
                  onPressed: isLast ? null : () => _moveChapter(index, 1),
                  icon: const Icon(Icons.arrow_downward, size: 20),
                  tooltip: 'Move Down',
                  color: _accent,
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _editChapter(chapter),
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Edit Chapter',
                  color: Colors.blue,
                ),
                IconButton(
                  onPressed: () => _deleteChapter(chapter),
                  icon: const Icon(Icons.delete, size: 20),
                  tooltip: 'Delete Chapter',
                  color: Colors.red,
                ),
              ],
            ),
          ),

          // Expanded content - Sections
          if (isExpanded && chapter.sections.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: chapter.sections.asMap().entries.map((entry) => 
                  _buildSectionCard(chapter, entry.value, entry.key, isDark)
                ).toList(),
              ),
            ),
          
          if (isExpanded && chapter.sections.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No sections yet. Click "Add Section" above.',
                  style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(KBChapterData chapter, KBSectionData section, int index, bool isDark) {
    final isExpanded = _expandedSections.contains(section.id);
    final isFirst = index == 0;
    final isLast = index == chapter.sections.length - 1;
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: isExpanded ? Border.all(color: _accent.withValues(alpha: 0.5)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedSections.remove(section.id);
                } else {
                  _expandedSections.add(section.id);
                }
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 20, color: _accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${section.topics.length} topics',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          
          // Section Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => _addTopic(section),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Topic', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                const Spacer(),
                // Move up/down buttons
                IconButton(
                  onPressed: isFirst ? null : () => _moveSection(chapter, index, -1),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  tooltip: 'Move Up',
                  color: _accent,
                  iconSize: 18,
                ),
                IconButton(
                  onPressed: isLast ? null : () => _moveSection(chapter, index, 1),
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  tooltip: 'Move Down',
                  color: _accent,
                  iconSize: 18,
                ),
                IconButton(
                  onPressed: () => _editSection(section),
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Edit Section',
                  color: Colors.blue,
                  iconSize: 18,
                ),
                IconButton(
                  onPressed: () => _deleteSection(section),
                  icon: const Icon(Icons.delete, size: 18),
                  tooltip: 'Delete Section',
                  color: Colors.red,
                  iconSize: 18,
                ),
              ],
            ),
          ),

          // Expanded content - Topics
          if (isExpanded && section.topics.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: section.topics.asMap().entries.map((entry) => 
                  _buildTopicTile(section, entry.value, entry.key, isDark)
                ).toList(),
              ),
            ),
          
          if (isExpanded && section.topics.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No topics yet',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopicTile(KBSectionData section, KBTopicData topic, int index, bool isDark) {
    final isFirst = index == 0;
    final isLast = index == section.topics.length - 1;
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.article, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.title, style: const TextStyle(fontSize: 14)),
                  Text(
                    '${topic.contentBlocks.length} blocks',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            // Move up/down buttons
            IconButton(
              onPressed: isFirst ? null : () => _moveTopic(section, index, -1),
              icon: const Icon(Icons.arrow_upward, size: 16),
              tooltip: 'Move Up',
              color: _accent,
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              onPressed: isLast ? null : () => _moveTopic(section, index, 1),
              icon: const Icon(Icons.arrow_downward, size: 16),
              tooltip: 'Move Down',
              color: _accent,
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              onPressed: () => _editTopic(section, topic),
              icon: const Icon(Icons.edit, size: 16),
              tooltip: 'Edit Topic',
              color: Colors.blue,
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              onPressed: () => _deleteTopic(section, topic),
              icon: const Icon(Icons.delete, size: 16),
              tooltip: 'Delete Topic',
              color: Colors.red,
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TOPIC EDITOR (separate screen for editing topics with blocks)
// ============================================================================

class _TopicEditorScreen extends StatefulWidget {
  final String sectionId;
  final String sectionTitle;
  final KBTopicData? topic;

  const _TopicEditorScreen({
    required this.sectionId,
    required this.sectionTitle,
    this.topic,
  });

  @override
  State<_TopicEditorScreen> createState() => _TopicEditorScreenState();
}

class _TopicEditorScreenState extends State<_TopicEditorScreen> {
  static const Color _accent = AppColors.accent;

  final _titleController = TextEditingController();
  List<ContentBlock> _blocks = [];
  bool _saving = false;

  bool get _isNew => widget.topic == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) {
      _titleController.text = widget.topic!.title;
      _blocks = List.from(widget.topic!.contentBlocks);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      bool success;
      if (_isNew) {
        final topic = await TrainingService.instance.createTopic(
          sectionId: widget.sectionId,
          title: _titleController.text.trim(),
          contentBlocks: _blocks,
        );
        success = topic != null;
      } else {
        success = await TrainingService.instance.updateTopic(
          id: widget.topic!.id,
          title: _titleController.text.trim(),
          contentBlocks: _blocks,
        );
      }

      if (mounted) {
        setState(() => _saving = false);
        if (success) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save'), backgroundColor: Colors.red),
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

  Future<void> _delete() async {
    if (_isNew) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Topic?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await TrainingService.instance.deleteTopic(widget.topic!.id);
      if (success && mounted) Navigator.pop(context, true);
    }
  }

  void _addBlock(ContentBlockType type) {
    setState(() {
      switch (type) {
        case ContentBlockType.text:
          _blocks.add(ContentBlock.text(''));
          break;
        case ContentBlockType.image:
          _blocks.add(ContentBlock.image(''));
          break;
        case ContentBlockType.vimeo:
          _blocks.add(ContentBlock.vimeo(''));
          break;
        case ContentBlockType.youtube:
          _blocks.add(ContentBlock.youtube(''));
          break;
        case ContentBlockType.table:
          // Start with a 2x2 table
          _blocks.add(ContentBlock.tableFromData(
            headers: ['Column 1', 'Column 2'],
            rows: [['', '']],
          ));
          break;
      }
    });
  }

  void _removeBlock(int index) {
    setState(() => _blocks.removeAt(index));
  }

  void _moveBlockUp(int index) {
    if (index > 0) {
      setState(() {
        final block = _blocks.removeAt(index);
        _blocks.insert(index - 1, block);
      });
    }
  }

  void _moveBlockDown(int index) {
    if (index < _blocks.length - 1) {
      setState(() {
        final block = _blocks.removeAt(index);
        _blocks.insert(index + 1, block);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add Topic' : 'Edit Topic'),
        actions: [
          if (!_isNew)
            IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
          IconButton(
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 18, color: _accent),
                  const SizedBox(width: 8),
                  Text(
                    'Section: ${widget.sectionTitle}',
                    style: const TextStyle(color: _accent, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Title
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Topic Title',
                hintText: 'e.g., Understanding Customer Calls',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Content Blocks header
            Row(
              children: [
                const Icon(Icons.view_list, size: 20),
                const SizedBox(width: 8),
                const Text('Content Blocks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                PopupMenuButton<ContentBlockType>(
                  onSelected: _addBlock,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ContentBlockType.text,
                      child: Row(children: [Icon(Icons.text_fields, size: 20), SizedBox(width: 12), Text('Text')]),
                    ),
                    const PopupMenuItem(
                      value: ContentBlockType.image,
                      child: Row(children: [Icon(Icons.image, size: 20), SizedBox(width: 12), Text('Image')]),
                    ),
                    const PopupMenuItem(
                      value: ContentBlockType.vimeo,
                      child: Row(children: [Icon(Icons.videocam, size: 20), SizedBox(width: 12), Text('Vimeo Video')]),
                    ),
                    const PopupMenuItem(
                      value: ContentBlockType.youtube,
                      child: Row(children: [Icon(Icons.play_circle_filled, size: 20), SizedBox(width: 12), Text('YouTube Video')]),
                    ),
                    const PopupMenuItem(
                      value: ContentBlockType.table,
                      child: Row(children: [Icon(Icons.table_chart, size: 20), SizedBox(width: 12), Text('Table')]),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('Add Block', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Blocks list
            if (_blocks.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.add_box_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No content blocks', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Click "Add Block" to add text, images, videos, or tables', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...List.generate(_blocks.length, (index) => _buildBlockEditor(index, _blocks[index], isDark)),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockEditor(int index, ContentBlock block, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Block header with type and actions
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    block.type == ContentBlockType.text
                        ? Icons.text_fields
                        : block.type == ContentBlockType.image
                            ? Icons.image
                            : block.type == ContentBlockType.vimeo
                                ? Icons.videocam
                                : block.type == ContentBlockType.youtube
                                    ? Icons.play_circle_filled
                                    : Icons.table_chart,
                    color: _accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  block.type == ContentBlockType.text
                      ? 'Text Block'
                      : block.type == ContentBlockType.image
                          ? 'Image Block'
                          : block.type == ContentBlockType.vimeo
                              ? 'Vimeo Video Block'
                              : block.type == ContentBlockType.youtube
                                  ? 'YouTube Video Block'
                                  : 'Table Block',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                // Move up/down buttons
                IconButton(
                  onPressed: index > 0 ? () => _moveBlockUp(index) : null,
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  tooltip: 'Move Up',
                ),
                IconButton(
                  onPressed: index < _blocks.length - 1 ? () => _moveBlockDown(index) : null,
                  icon: const Icon(Icons.arrow_downward, size: 20),
                  tooltip: 'Move Down',
                ),
                IconButton(
                  onPressed: () => _removeBlock(index),
                  icon: const Icon(Icons.delete, size: 20),
                  color: Colors.red,
                  tooltip: 'Delete Block',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Block content editor
            if (block.type == ContentBlockType.text)
              TextFormField(
                initialValue: block.content,
                decoration: const InputDecoration(
                  hintText: 'Enter text content...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
                onChanged: (value) {
                  _blocks[index] = ContentBlock.text(value);
                },
              )
            else if (block.type == ContentBlockType.image) ...[
              TextFormField(
                initialValue: block.content,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  hintText: 'https://example.com/image.jpg',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _blocks[index] = ContentBlock.image(value, caption: block.caption);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: block.caption ?? '',
                decoration: const InputDecoration(
                  labelText: 'Caption (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _blocks[index] = ContentBlock.image(block.content, caption: value.isEmpty ? null : value);
                },
              ),
              if (block.content.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    block.content,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      color: Colors.grey[300],
                      child: const Center(child: Text('Preview unavailable')),
                    ),
                  ),
                ),
              ],
            ] else if (block.type == ContentBlockType.vimeo) ...[
              TextFormField(
                initialValue: block.content,
                decoration: const InputDecoration(
                  labelText: 'Vimeo Video ID',
                  hintText: '123456789',
                  border: OutlineInputBorder(),
                  helperText: 'Enter just the video ID from the Vimeo URL',
                ),
                onChanged: (value) {
                  _blocks[index] = ContentBlock.vimeo(value, caption: block.caption);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: block.caption ?? '',
                decoration: const InputDecoration(
                  labelText: 'Caption (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _blocks[index] = ContentBlock.vimeo(block.content, caption: value.isEmpty ? null : value);
                },
              ),
            ] else if (block.type == ContentBlockType.youtube) ...[
              TextFormField(
                initialValue: block.content,
                decoration: const InputDecoration(
                  labelText: 'YouTube Video ID or URL',
                  hintText: 'dQw4w9WgXcQ or https://youtube.com/watch?v=...',
                  border: OutlineInputBorder(),
                  helperText: 'Enter the video ID or full YouTube URL',
                ),
                onChanged: (value) {
                  _blocks[index] = ContentBlock.youtube(value, caption: block.caption);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: block.caption ?? '',
                decoration: const InputDecoration(
                  labelText: 'Caption (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  _blocks[index] = ContentBlock.youtube(block.content, caption: value.isEmpty ? null : value);
                },
              ),
            ] else if (block.type == ContentBlockType.table) ...[
              _buildTableEditor(index, block),
            ],
          ],
        ),
      ),
    );
  }

  /// Build the table editor widget
  Widget _buildTableEditor(int blockIndex, ContentBlock block) {
    final tableData = block.tableData ?? {'headers': [], 'rows': []};
    final headers = List<String>.from(tableData['headers'] ?? []);
    final rows = (tableData['rows'] as List?)
        ?.map((r) => List<String>.from(r))
        .toList() ?? [];

    void updateTable(List<String> newHeaders, List<List<String>> newRows) {
      setState(() {
        _blocks[blockIndex] = ContentBlock.tableFromData(
          headers: newHeaders,
          rows: newRows,
          caption: block.caption,
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table controls
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                final newHeaders = [...headers, 'Column ${headers.length + 1}'];
                final newRows = rows.map((r) => [...r, '']).toList();
                updateTable(newHeaders, newRows);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Column'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                final newRow = List<String>.filled(headers.length, '');
                final newRows = [...rows, newRow];
                updateTable(headers, newRows);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Row'),
            ),
            const Spacer(),
            if (headers.length > 1)
              TextButton.icon(
                onPressed: () {
                  final newHeaders = headers.sublist(0, headers.length - 1);
                  final newRows = rows.map((r) => r.sublist(0, r.length - 1)).toList();
                  updateTable(newHeaders, newRows);
                },
                icon: const Icon(Icons.remove, size: 16, color: Colors.red),
                label: const Text('Remove Column', style: TextStyle(color: Colors.red)),
              ),
            if (rows.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  final newRows = rows.sublist(0, rows.length - 1);
                  updateTable(headers, newRows);
                },
                icon: const Icon(Icons.remove, size: 16, color: Colors.red),
                label: const Text('Remove Row', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Table editor
        if (headers.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('Click "Add Column" to start building your table'),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(_accent.withValues(alpha: 0.1)),
                columns: [
                  // Row number column
                  const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                  // Header columns
                  ...headers.asMap().entries.map((entry) {
                    final colIndex = entry.key;
                    return DataColumn(
                      label: SizedBox(
                        width: 120,
                        child: TextFormField(
                          initialValue: entry.value,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          onChanged: (value) {
                            final newHeaders = [...headers];
                            newHeaders[colIndex] = value;
                            updateTable(newHeaders, rows);
                          },
                        ),
                      ),
                    );
                  }),
                ],
                rows: rows.asMap().entries.map((rowEntry) {
                  final rowIndex = rowEntry.key;
                  final row = rowEntry.value;
                  return DataRow(
                    cells: [
                      // Row number
                      DataCell(Text('${rowIndex + 1}', style: TextStyle(color: Colors.grey[600]))),
                      // Data cells
                      ...row.asMap().entries.map((cellEntry) {
                        final colIndex = cellEntry.key;
                        return DataCell(
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              initialValue: cellEntry.value,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                                hintText: 'Enter value',
                              ),
                              onChanged: (value) {
                                final newRows = rows.map((r) => [...r]).toList();
                                newRows[rowIndex][colIndex] = value;
                                updateTable(headers, newRows);
                              },
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

        const SizedBox(height: 12),
        // Caption field
        TextFormField(
          initialValue: block.caption ?? '',
          decoration: const InputDecoration(
            labelText: 'Table Caption (optional)',
            border: OutlineInputBorder(),
            hintText: 'e.g., Table 1: Service call types and descriptions',
          ),
          onChanged: (value) {
            setState(() {
              _blocks[blockIndex] = ContentBlock.tableFromData(
                headers: headers,
                rows: rows,
                caption: value.isEmpty ? null : value,
              );
            });
          },
        ),
      ],
    );
  }
}
