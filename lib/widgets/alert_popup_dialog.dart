import 'package:flutter/material.dart';

/// Dialog widget for displaying alert popups with optional image attachments
class AlertPopupDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? fromUsername;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType;
  final String? currentUsername;
  final String? currentRole;
  final VoidCallback? onReply;
  final void Function(String imageUrl, String? imageName)? onImageTap;

  const AlertPopupDialog({
    required this.title,
    required this.message,
    this.fromUsername,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    this.currentUsername,
    this.currentRole,
    this.onReply,
    this.onImageTap,
    super.key,
  });

  bool get _hasImage =>
      attachmentType == 'image' &&
      attachmentUrl != null &&
      attachmentUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message text
            Text(message),

            // Image attachment
            if (_hasImage) ...[
              const SizedBox(height: 16),
              _buildImageAttachment(context, isDark),
              if (attachmentName != null) ...[
                const SizedBox(height: 4),
                Text(
                  attachmentName!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
        // Show Reply button only if we know who sent the message and user is logged in
        if (fromUsername != null &&
            fromUsername!.isNotEmpty &&
            currentUsername != null &&
            currentRole != null &&
            onReply != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onReply?.call();
            },
            child: const Text('Reply'),
          ),
      ],
    );
  }

  Widget _buildImageAttachment(BuildContext context, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300, maxWidth: 400),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onTap: () => onImageTap?.call(attachmentUrl!, attachmentName),
          child: Image.network(
            attachmentUrl!,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 150,
                width: 200,
                alignment: Alignment.center,
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: const Color(0xFFF49320),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              height: 100,
              width: 200,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.grey[500]),
                  const SizedBox(height: 4),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full screen image viewer dialog
class FullImageDialog extends StatelessWidget {
  final String imageUrl;
  final String? imageName;

  const FullImageDialog({
    required this.imageUrl,
    this.imageName,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          InteractiveViewer(
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
