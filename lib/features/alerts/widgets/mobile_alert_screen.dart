import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app_theme.dart';
import '../../../config/api_config.dart';
import '../models/alert_user.dart';

/// Mobile full-screen alert compose view
class MobileAlertScreen extends StatefulWidget {
  final String currentUsername;
  final AlertUser targetUser;
  final Uint8List? profilePicture;

  const MobileAlertScreen({
    super.key,
    required this.currentUsername,
    required this.targetUser,
    this.profilePicture,
  });

  @override
  State<MobileAlertScreen> createState() => _MobileAlertScreenState();
}

class _MobileAlertScreenState extends State<MobileAlertScreen> {
  static String get _alertsBaseUrl => ApiConfig.alerts;
  static const Color _accent = AppColors.accent;

  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendAlert() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _sending = true);

    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(_alertsBaseUrl));
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode({
        'to_username': widget.targetUser.username,
        'from_username': widget.currentUsername,
        'message': message,
      }));

      final response = await request.close();

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Alert sent to ${widget.targetUser.displayName}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to send alert');
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
                  const Text(
                    'Send Alert',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This will send a popup alert to ${widget.targetUser.displayName}\'s screen.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Message input
            Text(
              'Alert Message',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter your alert message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey[100],
              ),
            ),
            const SizedBox(height: 24),
            // Send button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _sendAlert,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(_sending ? 'Sending...' : 'Send Alert'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
