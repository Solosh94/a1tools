import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pasteboard/pasteboard.dart';

import '../../../app_theme.dart';
import '../../../config/api_config.dart';
import '../models/chat_group.dart';
import '../models/group_message.dart';
import '../utils/message_timestamp.dart';

/// Mobile full-screen group chat view
class MobileGroupChatScreen extends StatefulWidget {
  final String currentUsername;
  final String currentRole;
  final ChatGroup group;

  const MobileGroupChatScreen({
    super.key,
    required this.currentUsername,
    required this.currentRole,
    required this.group,
  });

  @override
  State<MobileGroupChatScreen> createState() => _MobileGroupChatScreenState();
}

class _MobileGroupChatScreenState extends State<MobileGroupChatScreen> {
  static String get _groupsBaseUrl => ApiConfig.chatGroups;
  static const Color _accent = AppColors.accent;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  List<GroupMessage> _messages = [];
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
        '$_groupsBaseUrl?action=get_messages&group_id=${widget.group.id}&username=${widget.currentUsername}',
      ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _messages = (data['messages'] as List)
                .map((m) => GroupMessage.fromJson(m))
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
        Uri.parse(_groupsBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'mark_read',
          'group_id': widget.group.id,
          'username': widget.currentUsername,
        }),
      );
    } catch (e) {
      debugPrint('[MobileGroupChatScreen] Error: $e');
    }
  }

  Future<void> _handlePaste() async {
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        setState(() {
          _pendingImage = imageBytes;
          _pendingImageName = 'clipboard_${DateTime.now().millisecondsSinceEpoch}.png';
        });
        return;
      }
    } catch (e) {
      debugPrint('[MobileGroupChatScreen] Paste error: $e');
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

    final imageData = _pendingImage;
    final imageName = _pendingImageName;
    _clearPendingImage();

    try {
      final body = <String, dynamic>{
        'action': 'send_message',
        'group_id': widget.group.id,
        'username': widget.currentUsername,
        'message': message.isNotEmpty ? message : (hasImage ? '📷 Image' : ''),
      };

      if (imageData != null && imageName != null) {
        body['attachment_data'] = base64Encode(imageData);
        body['attachment_name'] = imageName;
        body['attachment_type'] = 'image/png';
      }

      final response = await http.post(
        Uri.parse(_groupsBaseUrl),
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
              child: const Icon(Icons.group, color: _accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group.name,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.group.memberCount} members',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
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
                            final isSystem = msg.isSystem;

                            if (isSystem) {
                              return _buildSystemMessage(msg, isDark);
                            }
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

  Widget _buildSystemMessage(GroupMessage msg, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            msg.message,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(GroupMessage msg, bool isMe, bool isDark) {
    final hasImage = msg.hasAttachment &&
        (msg.attachmentType?.startsWith('image/') ?? false);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  msg.fromDisplayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),

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

            // Text message
            if (msg.message.isNotEmpty && msg.message != '📷 Image')
              Text(
                msg.message,
                style: TextStyle(
                  color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              formatMessageTimestamp(msg.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe
                    ? Colors.white70
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
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
}
