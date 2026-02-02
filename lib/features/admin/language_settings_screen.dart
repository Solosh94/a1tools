// Language Settings Screen
//
// Allows users to change the app's language.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import '../../core/providers/language_provider.dart';

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  static const Color _accent = AppColors.accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Language / Idioma'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current language info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Text(
                  languageProvider.currentLanguageFlag,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Language',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      Text(
                        languageProvider.currentLanguageName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Select Language / Seleccionar Idioma',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Language options
          ...SupportedLanguages.all.map((language) {
            final isSelected =
                languageProvider.locale.languageCode == language.locale.languageCode;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    languageProvider.setLocale(language.locale);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          language.locale.languageCode == 'es'
                              ? 'Idioma cambiado a ${language.nativeName}'
                              : 'Language changed to ${language.name}',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _accent
                            : (isDark ? Colors.white12 : Colors.black12),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          language.flag,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                language.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              Text(
                                language.nativeName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: _accent)
                        else
                          Icon(
                            Icons.circle_outlined,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // Info note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    languageProvider.isSpanish
                        ? 'El cambio de idioma se aplicará en toda la aplicación.'
                        : 'Language change will apply throughout the app.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Language selector widget (for use in settings or profile)
class LanguageSelector extends StatelessWidget {
  final bool showLabel;

  const LanguageSelector({
    super.key,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return PopupMenuButton<Locale>(
      onSelected: (locale) {
        languageProvider.setLocale(locale);
      },
      itemBuilder: (ctx) => SupportedLanguages.all.map((language) {
        final isSelected =
            languageProvider.locale.languageCode == language.locale.languageCode;

        return PopupMenuItem<Locale>(
          value: language.locale,
          child: Row(
            children: [
              Text(language.flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Text(language.nativeName),
              if (isSelected) ...[
                const Spacer(),
                const Icon(Icons.check, size: 18, color: Color(0xFFF49320)),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white24
                : Colors.black12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              languageProvider.currentLanguageFlag,
              style: const TextStyle(fontSize: 18),
            ),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Text(languageProvider.currentLanguageName),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}
