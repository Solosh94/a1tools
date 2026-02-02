// Inspection Detail Screen
//
// Displays full details of an inspection including photos.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_theme.dart';
import 'inspection_models.dart';
import 'inspection_service.dart';

class InspectionDetailScreen extends StatefulWidget {
  final Inspection inspection;
  final bool isAdmin;
  final VoidCallback? onDeleted;

  const InspectionDetailScreen({
    super.key,
    required this.inspection,
    this.isAdmin = false,
    this.onDeleted,
  });

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  static const Color _accent = AppColors.accent;

  bool _deleting = false;

  Future<void> _deleteInspection() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Inspection'),
        content: const Text(
          'Are you sure you want to delete this inspection? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting = true);

    try {
      final success = await InspectionService.instance.deleteInspection(
        widget.inspection.id,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection deleted'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onDeleted?.call();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete inspection'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _deleting = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _deleting = false);
      }
    }
  }

  void _openPhotoViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PhotoViewerScreen(
          photos: widget.inspection.photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours hr ${minutes > 0 ? '$minutes min' : ''}';
    }
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final inspection = widget.inspection;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Inspection Details'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleting ? null : _deleteInspection,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card with address and status
          _buildCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: _accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inspection.fullAddress,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (inspection.localSubmitTime != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${dateFormat.format(inspection.localSubmitTime!)} at ${timeFormat.format(inspection.localSubmitTime!)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBadge(inspection.chimneyType, Colors.blue, isDark),
                    _buildBadge(
                      inspection.condition,
                      _getConditionColor(inspection.condition),
                      isDark,
                      showDescription: true,
                    ),
                    _buildBadge(
                      inspection.completionStatusDisplay,
                      _getStatusColor(inspection.completionStatus),
                      isDark,
                    ),
                    if (inspection.discountUsed)
                      _buildBadge('Discount Applied', Colors.purple, isDark),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Technician info
          _buildCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Technician', isDark),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.person,
                  'Name',
                  inspection.displayName,
                  isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Job Details
          _buildCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Job Details', isDark),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.category,
                  'Category',
                  inspection.jobCategory,
                  isDark,
                ),
                _buildInfoRow(
                  Icons.work,
                  'Type',
                  inspection.jobType,
                  isDark,
                ),
                if (inspection.startTime != null)
                  _buildInfoRow(
                    Icons.play_arrow,
                    'Start Time',
                    '${dateFormat.format(inspection.startTime!)} ${timeFormat.format(inspection.startTime!)}',
                    isDark,
                  ),
                if (inspection.endTime != null)
                  _buildInfoRow(
                    Icons.stop,
                    'End Time',
                    '${dateFormat.format(inspection.endTime!)} ${timeFormat.format(inspection.endTime!)}',
                    isDark,
                  ),
                if (inspection.jobDuration != null)
                  _buildInfoRow(
                    Icons.timer,
                    'Duration',
                    _formatDuration(inspection.jobDuration!),
                    isDark,
                    valueColor: _accent,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Customer info (if available)
          if (inspection.customerName?.isNotEmpty == true ||
              inspection.customerPhone?.isNotEmpty == true) ...[
            _buildCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Customer Information', isDark),
                  const SizedBox(height: 12),
                  if (inspection.customerName?.isNotEmpty == true)
                    _buildInfoRow(
                      Icons.person,
                      'Name',
                      inspection.customerName!,
                      isDark,
                    ),
                  if (inspection.customerPhone?.isNotEmpty == true)
                    _buildInfoRow(
                      Icons.phone,
                      'Phone',
                      inspection.customerPhone!,
                      isDark,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Description (if available)
          if (inspection.description?.isNotEmpty == true) ...[
            _buildCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Job Description', isDark),
                  const SizedBox(height: 12),
                  Text(
                    inspection.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Issues
          _buildCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Issues Noted', isDark),
                const SizedBox(height: 12),
                Text(
                  inspection.issues,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Recommendations (if available)
          if (inspection.recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Recommendations', isDark),
                  const SizedBox(height: 12),
                  Text(
                    inspection.recommendations,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Photos
          if (inspection.photos.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(
                    'Photos (${inspection.photos.length})',
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: inspection.photos.length,
                    itemBuilder: (context, index) {
                      final photo = inspection.photos[index];
                      return GestureDetector(
                        onTap: () => _openPhotoViewer(index),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.network(
                              photo.url,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null,
                                    color: _accent,
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                color: isDark ? Colors.grey[800] : Colors.grey[200],
                                child: Icon(
                                  Icons.broken_image,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          // Metadata (for admin)
          if (widget.isAdmin) ...[
            const SizedBox(height: 16),
            _buildCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Metadata', isDark),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.person_outline,
                    'Username',
                    inspection.username,
                    isDark,
                  ),
                  _buildInfoRow(
                    Icons.tag,
                    'ID',
                    '#${inspection.id}',
                    isDark,
                  ),
                  _buildInfoRow(
                    Icons.cloud_upload,
                    'Server Time',
                    dateFormat.format(inspection.createdAt),
                    isDark,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCard({required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? (isDark ? Colors.white : Colors.black),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, bool isDark, {bool showDescription = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showDescription && ConditionRatings.all.contains(text))
            Text(
              ConditionRatings.getDescription(text),
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }

  Color _getConditionColor(String condition) {
    switch (condition) {
      case 'Good':
        return Colors.green;
      case 'Fair':
        return Colors.orange;
      case 'Poor':
        return Colors.deepOrange;
      case 'Critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'incomplete':
        return Colors.red;
      case 'follow_up_needed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

/// Full-screen photo viewer with swipe navigation
class _PhotoViewerScreen extends StatefulWidget {
  final List<InspectionPhoto> photos;
  final int initialIndex;

  const _PhotoViewerScreen({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.photos.length}'),
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          // Safety check for empty or invalid URLs
          if (photo.url.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  SizedBox(height: 8),
                  Text('Invalid image URL', style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                photo.url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFFF49320),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white54, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
