import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  AppLanguage._();

  static final ValueNotifier<Locale> locale =
      ValueNotifier<Locale>(const Locale('en'));

  static bool get isArabic => locale.value.languageCode == 'ar';

  static Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('appLanguage') ??
        prefs.getString('consent_profile_language') ??
        'en';
    locale.value =
        Locale(language.toLowerCase().startsWith('ar') ? 'ar' : 'en');
  }

  static Future<void> setLanguage(String language) async {
    final code = language.toLowerCase().startsWith('ar') ? 'ar' : 'en';
    locale.value = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appLanguage', code);
    await prefs.setString('consent_profile_language', code);
  }
}

void loadAppLanguage() {
  unawaited(AppLanguage.loadSaved());
}
