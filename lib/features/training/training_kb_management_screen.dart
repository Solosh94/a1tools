// Training Knowledge Base Management Screen
// 
// Admin/Developer interface for managing all knowledge bases.

import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'training_models.dart';
import 'training_service.dart';
import 'training_kb_editor_screen.dart';

class TrainingKBManagementScreen extends StatefulWidget {
  final String currentUserRole;
  
  const TrainingKBManagementScreen({
    super.key,
    required this.currentUserRole,
  });

  @override
  State<TrainingKBManagementScreen> createState() => _TrainingKBManagementScreenState();
}

class _TrainingKBManagementScreenState extends State<TrainingKBManagementScreen> {
  static const Color _accent = AppColors.accent;

  List<KnowledgeBaseData> _knowledgeBases = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final kbs = await TrainingService.instance.getKnowledgeBases();
      if (mounted) {
        setState(() {
          _knowledgeBases = kbs;
          _loading = false;
        });
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

  void _createKB() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrainingKBEditorScreen(
        currentUserRole: widget.currentUserRole,
      )),
    );
    if (result == true) _loadData();
  }

  void _editKB(KnowledgeBaseData kb) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrainingKBEditorScreen(
        kbId: kb.id,
        currentUserRole: widget.currentUserRole,
      )),
    );
    if (result == true) _loadData();
  }

  /// Delete knowledge base - Developer only with password confirmation
  Future<void> _deleteKB(KnowledgeBaseData kb) async {
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
            const Expanded(child: Text('Delete Study Guide?')),
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
            Text('Delete "${kb.title}" and all its content?'),
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
      final success = await TrainingService.instance.deleteKnowledgeBase(kb.id);
      if (success && mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Guide Editor'),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
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
                      ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(isDark),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createKB,
        backgroundColor: _accent,
        icon: const Icon(Icons.add),
        label: const Text('Create Study Guide'),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_knowledgeBases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No Study Guides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Create your first knowledge base', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

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
                colors: [Colors.blue, Colors.blue.withValues(alpha: 0.8)],
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
                  child: const Icon(Icons.menu_book, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Study Guides', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${_knowledgeBases.length} knowledge bases', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // KB list
          ..._knowledgeBases.map((kb) => _buildKBCard(kb, isDark)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildKBCard(KnowledgeBaseData kb, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _editKB(kb),
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
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      kb.targetRole == 'technician' ? Icons.build : Icons.headset_mic,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kb.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('ID: ${kb.id}', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')])),
                      // Delete option - Developer only
                      if (widget.currentUserRole == 'developer')
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') _editKB(kb);
                      if (value == 'delete') _deleteKB(kb);
                    },
                  ),
                ],
              ),
              if (kb.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(kb.description, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChip(Icons.folder, '${kb.sections.length} sections', Colors.blue),
                  const SizedBox(width: 8),
                  _buildChip(Icons.person, kb.targetRole, _accent),
                  if (kb.testId != null) ...[
                    const SizedBox(width: 8),
                    _buildChip(Icons.link, kb.testId!, Colors.green),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
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
}
