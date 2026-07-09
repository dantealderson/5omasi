import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'appLocale';
  String _locale = 'ar';

  String get locale => _locale;
  bool get isArabic => _locale == 'ar';
  bool get isEnglish => _locale == 'en';

  Locale get flutterLocale => Locale(_locale);

  LocaleProvider() {
    _loadLocaleFromPrefs();
  }

  Future<void> _loadLocaleFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString(_localeKey) ?? 'ar';
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale);
  }

  /// Toggle between Arabic and English
  Future<void> toggleLocale() async {
    await setLocale(_locale == 'ar' ? 'en' : 'ar');
  }
}
