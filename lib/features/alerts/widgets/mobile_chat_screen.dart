import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pasteboard/pasteboard.dart';

import '../../../app_theme.dart';
import '../../../config/api_config.dart';
import '../models/alert_user.dart';
import '../models/chat_message.dart';
import '../utils/message_timestamp.dart';
import 'forward_message_dialog.dart';
import 'linkified_text.dart';

/// Mobile full-screen chat view
class MobileChatScreen extends StatefulWidget {
  final String currentUsername;
  final String currentRole;
  final AlertUser targetUser;
  final Uint8List? profilePicture;

  const MobileChatScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
    required this.targetUser,
    this.profilePicture,
  });

  @override
  State<MobileChatScreen> createState() => _MobileChatScreenState();
}

class _MobileChatScreenState extends State<MobileChatScreen> {
  static String get _chatBaseUrl => ApiConfig.chatMessages;
  static const Color _accent = AppColors.accent;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _refreshTimer;

  // Pending image from clipboard
  Uint8List? _pendingImage;
  String? _pendingImageName;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _startRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages());
  }

  Future<void> _loadMessages() async {
    try {
      final response = await http.get(Uri.parse(
        '$_chatBaseUrl?action=get_conversation&user1=${widget.currentUsername}&user2=${widget.targetUser.username}',
      ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _messages = (data['messages'] as List)
                .map((m) => ChatMessage.fromJson(m))
                .toList();
            _loading = false;
          });

          // Mark as read
          _markAsRead();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead() async {
    try {
      await http.post(
        Uri.parse(_chatBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'mark_read',
          'from_username': widget.targetUser.username,
          'to_username': widget.currentUsername,
        }),
      );
    } catch (e) {
      debugPrint('[MobileChatScreen] Error: $e');
    }
  }

  Future<void> _handlePaste() async {
    try {
      // Try to get image from clipboard
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        setState(() {
          _pendingImage = imageBytes;
          _pendingImageName = 'clipboard_${DateTime.now().millisecondsSinceEpoch}.png';
        });
        return;
      }
    } catch (e) {
      debugPrint('[MobileChatScreen] Paste error: $e');
    }
  }

  void _clearPendingImage() {
    setState(() {
      _pendingImage = null;
      _pendingImageName = null;
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    final hasImage = _pendingImage != null;

    if (message.isEmpty && !hasImage) return;

    setState(() => _sending = true);
    _messageController.clear();

    // Capture image data before clearing
    final imageData = _pendingImage;
    final imageName = _pendingImageName;
    _clearPendingImage();

    try {
      final body = <String, dynamic>{
        'action': 'send',
        'from_username': widget.currentUsername,
        'to_username': widget.targetUser.username,
        'message': message.isNotEmpty ? message : (hasImage ? '📷 Image' : ''),
      };

      // Add image attachment if present
      if (imageData != null && imageName != null) {
        body['attachment_data'] = base64Encode(imageData);
        body['attachment_name'] = imageName;
        body['attachment_type'] = 'image/png';
      }

      final response = await http.post(
        Uri.parse(_chatBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _loadMessages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _accent.withValues(alpha: 0.2),
              backgroundImage: widget.profilePicture != null
                  ? MemoryImage(widget.profilePicture!)
                  : null,
              child: widget.profilePicture == null
                  ? Text(
                      widget.targetUser.displayName.isNotEmpty
                          ? widget.targetUser.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: _accent, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.targetUser.displayName,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.targetUser.appStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.targetUser.isOnline
                          ? Colors.green
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            'No messages yet.\nStart the conversation!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe =
                                msg.fromUsername == widget.currentUsername;
                            return _buildMessageBubble(msg, isMe, isDark);
                          },
                        ),
            ),

            // Pending image preview
            if (_pendingImage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? Colors.white10 : Colors.grey[100],
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _pendingImage!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Image from clipboard',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Press send or Enter to share',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearPendingImage,
                      tooltip: 'Remove image',
                    ),
                  ],
                ),
              ),

            // Input
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 8,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Paste image button
                  IconButton(
                    icon: Icon(
                      Icons.image_outlined,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    onPressed: _handlePaste,
                    tooltip: 'Paste image from clipboard',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _inputFocusNode,
                      decoration: InputDecoration(
                        hintText: _pendingImage != null
                            ? 'Add a caption (optional)...'
                            : 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: _accent,
                    child: IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              _pendingImage != null ? Icons.send_rounded : Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                      onPressed: _sending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, bool isDark) {
    final hasImage = msg.hasAttachment &&
        (msg.attachmentType?.startsWith('image/') ?? false);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? _accent : (isDark ? Colors.white12 : Colors.grey[300]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image attachment
              if (hasImage && msg.attachmentUrl != null) ...[
                GestureDetector(
                  onTap: () => _showFullImage(msg.attachmentUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      msg.attachmentUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 150,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            color: isMe ? Colors.white : _accent,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 100,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: isMe ? Colors.white70 : Colors.grey,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Image failed to load',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMe ? Colors.white70 : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (msg.message.isNotEmpty && msg.message != '📷 Image')
                  const SizedBox(height: 8),
              ],

              // Text message (skip if it's just the image placeholder)
              if (msg.message.isNotEmpty && msg.message != '📷 Image')
                LinkifiedText(
                  text: msg.message,
                  style: TextStyle(
                    color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black),
                  ),
                  linkStyle: TextStyle(
                    color: isMe ? Colors.lightBlue[100] : Colors.blue,
                    decoration: TextDecoration.underline,
                    decorationColor: isMe ? Colors.lightBlue[100] : Colors.blue,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatMessageTimestamp(msg.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe
                          ? Colors.white70
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.isRead ? Icons.done_all : Icons.done,
                      size: 12,
                      color: msg.isRead ? Colors.blue[200] : Colors.white70,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(imageUrl),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.message));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Message copied'),
                      duration: Duration(seconds: 1)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                _forwardMessage(msg);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _forwardMessage(ChatMessage msg) {
    // Show user selection dialog for forwarding
    showDialog(
      context: context,
      builder: (context) => ForwardMessageDialog(
        message: msg.message,
        currentUsername: widget.currentUsername,
        onForward: (toUsername) async {
          try {
            final response = await http.post(
              Uri.parse(ApiConfig.chatMessages),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'action': 'send',
                'from_username': widget.currentUsername,
                'to_username': toUsername,
                'message': msg.message,
              }),
            );
            if (response.statusCode == 200 || response.statusCode == 201) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Message forwarded to $toUsername'),
                    backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Failed to forward: $e'),
                  backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }
}
