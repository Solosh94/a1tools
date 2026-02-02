import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import 'suggestion_service.dart';

/// Screen for admins to review and manage user suggestions.
class SuggestionsReviewScreen extends StatefulWidget {
  final String currentUsername;
  final String currentRole;

  const SuggestionsReviewScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
  });

  @override
  State<SuggestionsReviewScreen> createState() => _SuggestionsReviewScreenState();
}

class _SuggestionsReviewScreenState extends State<SuggestionsReviewScreen> {
  static const Color _accent = AppColors.accent;

  List<Suggestion> _suggestions = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoading = true);

    try {
      final suggestions = await SuggestionService.getAllSuggestions(
        status: _filterStatus == 'all' ? null : _filterStatus,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading suggestions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(Suggestion suggestion, String newStatus) async {
    final notesController = TextEditingController(text: suggestion.adminNotes);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark as ${_formatStatus(newStatus)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggestion from ${suggestion.displayName}:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                suggestion.suggestion,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Admin Notes (optional)',
                hintText: 'Add any notes about this decision...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {
              'status': newStatus,
              'notes': notesController.text,
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStatusColor(newStatus),
              foregroundColor: Colors.white,
            ),
            child: Text('Mark as ${_formatStatus(newStatus)}'),
          ),
        ],
      ),
    );

    if (result != null) {
      final success = await SuggestionService.updateSuggestionStatus(
        suggestionId: suggestion.id,
        status: result['status']!,
        adminNotes: result['notes']!.isNotEmpty ? result['notes'] : null,
        reviewedBy: widget.currentUsername,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Suggestion marked as ${_formatStatus(result['status']!)}'),
              backgroundColor: Colors.green,
            ),
          );
          _loadSuggestions();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update suggestion'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteSuggestion(Suggestion suggestion) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Suggestion'),
        content: Text(
          'Are you sure you want to delete this suggestion from ${suggestion.displayName}?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await SuggestionService.deleteSuggestion(suggestion.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Suggestion deleted'),
              backgroundColor: Colors.green,
            ),
          );
          _loadSuggestions();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete suggestion'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'reviewed':
        return 'Reviewed';
      case 'implemented':
        return 'Implemented';
      case 'declined':
        return 'Declined';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'implemented':
        return Colors.green;
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'reviewed':
        return Icons.visibility;
      case 'implemented':
        return Icons.check_circle;
      case 'declined':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          isDark ? 'assets/images/logo-white.png' : 'assets/images/logo.png',
          height: 40,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSuggestions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header and filter
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lightbulb,
                      color: _accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review Suggestions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_suggestions.length} suggestions',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Filter dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filterStatus,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'reviewed', child: Text('Reviewed')),
                          DropdownMenuItem(value: 'implemented', child: Text('Implemented')),
                          DropdownMenuItem(value: 'declined', child: Text('Declined')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _filterStatus = value);
                            _loadSuggestions();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _accent),
                    )
                  : _suggestions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 64,
                                color: isDark ? Colors.white24 : Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _filterStatus == 'all'
                                    ? 'No suggestions yet'
                                    : 'No $_filterStatus suggestions',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return _buildSuggestionCard(suggestion, cardColor, isDark);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(Suggestion suggestion, Color cardColor, bool isDark) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(suggestion.status).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // User avatar
                CircleAvatar(
                  backgroundColor: _accent.withValues(alpha: 0.1),
                  child: Text(
                    suggestion.displayName[0].toUpperCase(),
                    style: const TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        dateFormat.format(suggestion.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(suggestion.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(suggestion.status),
                        size: 14,
                        color: _getStatusColor(suggestion.status),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatStatus(suggestion.status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(suggestion.status),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Suggestion content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              suggestion.suggestion,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.5,
              ),
            ),
          ),

          // Admin notes (if any)
          if (suggestion.adminNotes != null && suggestion.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes,
                      size: 16,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Notes',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            suggestion.adminNotes!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Reviewed info
          if (suggestion.reviewedBy != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Reviewed by ${suggestion.reviewedBy}${suggestion.reviewedAt != null ? ' on ${dateFormat.format(suggestion.reviewedAt!)}' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (suggestion.status != 'reviewed')
                  _buildActionButton(
                    label: 'Reviewed',
                    icon: Icons.visibility,
                    color: Colors.blue,
                    onTap: () => _updateStatus(suggestion, 'reviewed'),
                  ),
                if (suggestion.status != 'implemented')
                  _buildActionButton(
                    label: 'Implemented',
                    icon: Icons.check_circle,
                    color: Colors.green,
                    onTap: () => _updateStatus(suggestion, 'implemented'),
                  ),
                if (suggestion.status != 'declined')
                  _buildActionButton(
                    label: 'Decline',
                    icon: Icons.cancel,
                    color: Colors.red,
                    onTap: () => _updateStatus(suggestion, 'declined'),
                  ),
                _buildActionButton(
                  label: 'Delete',
                  icon: Icons.delete,
                  color: Colors.grey,
                  onTap: () => _deleteSuggestion(suggestion),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
