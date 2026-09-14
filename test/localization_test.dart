import 'package:flutter_test/flutter_test.dart';
import 'package:wheelboard/core/localization/app_translations.dart';
import 'package:wheelboard/core/localization/localization_service.dart';

void main() {
  group('LocalizationService Configuration', () {
    test('defines 4 supported languages (English, Hindi, Marathi, Tamil)', () {
      final languages = LocalizationService.supportedLanguages;
      expect(languages.length, 4);

      final codes = languages.map((l) => l.languageCode).toList();
      expect(codes, containsAll(['en', 'hi', 'mr', 'ta']));

      final nativeNames = languages.map((l) => l.nativeName).toList();
      expect(nativeNames, containsAll(['English', 'हिन्दी', 'मराठी', 'தமிழ்']));
    });

    test('default and fallback locale is en_US', () {
      expect(LocalizationService.defaultLocale.languageCode, 'en');
      expect(LocalizationService.defaultLocale.countryCode, 'US');
      expect(LocalizationService.fallbackLocale.languageCode, 'en');
    });
  });

  group('AppTranslations Dictionaries', () {
    final keys = AppTranslations().keys;

    test('contains translation maps for all 4 locales', () {
      expect(keys.containsKey('en_US'), isTrue);
      expect(keys.containsKey('hi_IN'), isTrue);
      expect(keys.containsKey('mr_IN'), isTrue);
      expect(keys.containsKey('ta_IN'), isTrue);
    });

    test('each locale has substantial translation keys (> 80 keys each)', () {
      expect(keys['en_US']!.length, greaterThan(80));
      expect(keys['hi_IN']!.length, greaterThan(80));
      expect(keys['mr_IN']!.length, greaterThan(80));
      expect(keys['ta_IN']!.length, greaterThan(80));
    });

    test('essential common keys exist in all 4 languages', () {
      final essentialKeys = [
        'Save',
        'Cancel',
        'Home',
        'Fleet',
        'Trips',
        'Feeds',
        'Jobs',
        'Profile',
        'Earnings',
        'Bookings',
        'Leads',
        'Services',
        'Active',
        'Completed',
        'Language',
        'English',
        'Hindi',
        'Marathi',
        'Tamil',
      ];

      for (final locale in ['en_US', 'hi_IN', 'mr_IN', 'ta_IN']) {
        final dict = keys[locale]!;
        for (final k in essentialKeys) {
          expect(dict.containsKey(k), isTrue,
              reason: 'Missing key "$k" in locale $locale');
          expect(dict[k]!.isNotEmpty, isTrue,
              reason: 'Empty translation for "$k" in locale $locale');
        }
      }
    });

    test('auth and onboarding keys exist across all 4 languages', () {
      final authKeys = [
        'Get Started',
        'Skip',
        'Log In',
        'Select Your Role',
        'Choose how you want to use Wheelboard',
        'Transport Company',
        'Professional Driver',
        'Service Provider',
        'Welcome Back',
        'Email & Password',
        'Phone OTP',
        'Don\'t have an account?',
        'Register here',
      ];

      for (final locale in ['en_US', 'hi_IN', 'mr_IN', 'ta_IN']) {
        final dict = keys[locale]!;
        for (final k in authKeys) {
          expect(dict.containsKey(k), isTrue,
              reason: 'Missing auth key "$k" in locale $locale');
          expect(dict[k]!.isNotEmpty, isTrue);
        }
      }
    });

    test('professional and transport specific keys exist', () {
      final specificKeys = [
        'Jobs for you',
        'My Calendar',
        'Popular Feeds',
        'View all',
      ];

      for (final locale in ['en_US', 'hi_IN', 'mr_IN', 'ta_IN']) {
        final dict = keys[locale]!;
        for (final k in specificKeys) {
          expect(dict.containsKey(k), isTrue,
              reason: 'Missing specific key "$k" in locale $locale');
          expect(dict[k]!.isNotEmpty, isTrue);
        }
      }
    });
  });
}
