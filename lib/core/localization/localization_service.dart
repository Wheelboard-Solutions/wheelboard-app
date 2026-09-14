import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_model.dart';

class LocalizationService extends GetxService {
  static const String _prefLanguageCodeKey = 'wb_language_code';
  static const String _prefCountryCodeKey = 'wb_country_code';

  static const defaultLocale = Locale('en', 'US');
  static const fallbackLocale = Locale('en', 'US');

  static const List<LanguageModel> supportedLanguages = [
    LanguageModel(
      languageCode: 'en',
      countryCode: 'US',
      name: 'English',
      nativeName: 'English',
      script: 'Latin',
    ),
    LanguageModel(
      languageCode: 'hi',
      countryCode: 'IN',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      script: 'Devanagari',
    ),
    LanguageModel(
      languageCode: 'mr',
      countryCode: 'IN',
      name: 'Marathi',
      nativeName: 'मराठी',
      script: 'Devanagari',
    ),
    LanguageModel(
      languageCode: 'ta',
      countryCode: 'IN',
      name: 'Tamil',
      nativeName: 'தமிழ்',
      script: 'Tamil',
    ),
  ];

  static List<Locale> get supportedLocales =>
      supportedLanguages.map((l) => l.locale).toList();

  static LocalizationService get to => Get.find<LocalizationService>();

  late final Rx<Locale> _currentLocale;

  Locale get currentLocale => _currentLocale.value;

  LanguageModel get currentLanguage => supportedLanguages.firstWhere(
        (l) => l.languageCode == currentLocale.languageCode,
        orElse: () => supportedLanguages.first,
      );

  String get currentLanguageName => currentLanguage.nativeName;

  static Future<LocalizationService> init() async {
    final service = LocalizationService();
    final prefs = await SharedPreferences.getInstance();

    final savedLang = prefs.getString(_prefLanguageCodeKey);
    final savedCountry = prefs.getString(_prefCountryCodeKey);

    Locale initialLocale;
    if (savedLang != null && savedCountry != null) {
      initialLocale = Locale(savedLang, savedCountry);
    } else {
      // Check system locale or fallback to English
      final deviceLocale = Get.deviceLocale;
      if (deviceLocale != null &&
          supportedLanguages.any((l) => l.languageCode == deviceLocale.languageCode)) {
        final match = supportedLanguages.firstWhere(
            (l) => l.languageCode == deviceLocale.languageCode);
        initialLocale = match.locale;
      } else {
        initialLocale = defaultLocale;
      }
    }

    service._currentLocale = initialLocale.obs;
    return service;
  }

  Future<void> changeLanguage(LanguageModel language) async {
    if (_currentLocale.value == language.locale) return;

    _currentLocale.value = language.locale;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLanguageCodeKey, language.languageCode);
    await prefs.setString(_prefCountryCodeKey, language.countryCode);

    await Get.updateLocale(language.locale);
  }

  Future<void> changeLocale(Locale locale) async {
    final language = supportedLanguages.firstWhere(
      (l) => l.languageCode == locale.languageCode,
      orElse: () => supportedLanguages.first,
    );
    await changeLanguage(language);
  }
}
