import 'package:flutter/material.dart';

/// Overlay widget displayed during push updates
class PushUpdateOverlay extends StatelessWidget {
  final double progress;
  final String status;

  const PushUpdateOverlay({
    required this.progress,
    required this.status,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.system_update,
                  size: 64,
                  color: Color(0xFFF49320),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Installing Update',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  status,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 300,
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFF49320),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please wait, the app will restart automatically.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
