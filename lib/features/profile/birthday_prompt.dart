import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../auth/auth_service.dart';

/// Helper to show birthday prompt if user hasn't set it
class BirthdayPrompt {
  static const Color _accent = AppColors.accent;

  /// Check and show birthday prompt if needed
  /// Call this after login or on app start
  static Future<void> checkAndShow(BuildContext context) async {
    // Wait a bit for the app to settle
    await Future.delayed(const Duration(seconds: 2));
    
    if (!context.mounted) return;
    
    final shouldPrompt = await AuthService.shouldPromptForBirthday();
    if (!shouldPrompt) return;
    
    if (!context.mounted) return;
    
    _showPromptDialog(context);
  }

  static void _showPromptDialog(BuildContext context) {
    DateTime? selectedDate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Text('🎂', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('When\'s Your Birthday?'),
                  ),
                ],
              ),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Help us celebrate you! Add your birthday so your team can know when it\'s your special day.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Date picker button
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime(2000, 1, 1),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                          helpText: 'Select your birthday',
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.fromSeed(
                                  seedColor: _accent,
                                  brightness: isDark ? Brightness.dark : Brightness.light,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedDate != null ? _accent : Colors.grey,
                            width: selectedDate != null ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: selectedDate != null 
                              ? _accent.withValues(alpha: 0.1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: selectedDate != null ? _accent : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              selectedDate != null
                                  ? _formatDate(selectedDate!)
                                  : 'Select your birthday',
                              style: TextStyle(
                                fontSize: 16,
                                color: selectedDate != null
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'A 🎂 will appear next to your name on your birthday!',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await AuthService.dismissBirthdayPrompt();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Maybe Later'),
                ),
                ElevatedButton(
                  onPressed: selectedDate == null
                      ? null
                      : () async {
                          final birthday = _formatDateForApi(selectedDate!);
                          final success = await AuthService.updateBirthday(birthday);
                          
                          if (context.mounted) {
                            Navigator.pop(context);
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Birthday saved! 🎂'
                                      : 'Failed to save birthday. Please try again in Settings.',
                                ),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Birthday'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String _formatDateForApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
