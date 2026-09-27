import 'package:get/get.dart';
import 'translations/common_translations.dart';
import 'translations/auth_translations.dart';
import 'translations/transport_translations.dart';
import 'translations/professional_translations.dart';
import 'translations/service_provider_translations.dart';
import 'translations/profile_translations.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          ...CommonTranslations.en,
          ...AuthTranslations.en,
          ...TransportTranslations.en,
          ...ProfessionalTranslations.en,
          ...ServiceProviderTranslations.en,
          ...ProfileTranslations.en,
        },
        'hi_IN': {
          ...CommonTranslations.hi,
          ...AuthTranslations.hi,
          ...TransportTranslations.hi,
          ...ProfessionalTranslations.hi,
          ...ServiceProviderTranslations.hi,
          ...ProfileTranslations.hi,
        },
        'mr_IN': {
          ...CommonTranslations.mr,
          ...AuthTranslations.mr,
          ...TransportTranslations.mr,
          ...ProfessionalTranslations.mr,
          ...ServiceProviderTranslations.mr,
          ...ProfileTranslations.mr,
        },
        'ta_IN': {
          ...CommonTranslations.ta,
          ...AuthTranslations.ta,
          ...TransportTranslations.ta,
          ...ProfessionalTranslations.ta,
          ...ServiceProviderTranslations.ta,
          ...ProfileTranslations.ta,
        },
      };
}
