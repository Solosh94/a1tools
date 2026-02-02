// Language Provider
//
// Manages the app's current locale/language setting.
// Persists the user's language preference.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';

  Locale _locale = const Locale('en', 'US');

  Locale get locale => _locale;

  LanguageProvider() {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);

      if (savedLanguage != null) {
        final parts = savedLanguage.split('_');
        if (parts.length == 2) {
          _locale = Locale(parts[0], parts[1]);
        } else {
          _locale = Locale(parts[0]);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved language: $e');
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale == newLocale) return;

    _locale = newLocale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _languageKey,
        newLocale.countryCode != null
            ? '${newLocale.languageCode}_${newLocale.countryCode}'
            : newLocale.languageCode,
      );
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  void setEnglish() => setLocale(const Locale('en', 'US'));
  void setSpanish() => setLocale(const Locale('es', 'ES'));

  bool get isEnglish => _locale.languageCode == 'en';
  bool get isSpanish => _locale.languageCode == 'es';

  String get currentLanguageName {
    switch (_locale.languageCode) {
      case 'es':
        return 'Español';
      case 'en':
      default:
        return 'English';
    }
  }

  String get currentLanguageFlag {
    switch (_locale.languageCode) {
      case 'es':
        return '🇪🇸';
      case 'en':
      default:
        return '🇺🇸';
    }
  }
}

/// Supported languages for the app
class SupportedLanguages {
  static const List<LanguageOption> all = [
    LanguageOption(
      locale: Locale('en', 'US'),
      name: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
    ),
    LanguageOption(
      locale: Locale('es', 'ES'),
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
    ),
  ];

  static LanguageOption? getByLocale(Locale locale) {
    return all.firstWhere(
      (lang) => lang.locale.languageCode == locale.languageCode,
      orElse: () => all.first,
    );
  }
}

class LanguageOption {
  final Locale locale;
  final String name;
  final String nativeName;
  final String flag;

  const LanguageOption({
    required this.locale,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}
