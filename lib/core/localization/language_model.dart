import 'package:flutter/material.dart';

/// Metadata representing a supported language in the WheelBoard app.
class LanguageModel {
  final String languageCode;
  final String countryCode;
  final String name;
  final String nativeName;
  final String script;

  const LanguageModel({
    required this.languageCode,
    required this.countryCode,
    required this.name,
    required this.nativeName,
    required this.script,
  });

  Locale get locale => Locale(languageCode, countryCode);

  String get key => '${languageCode}_$countryCode';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanguageModel &&
          runtimeType == other.runtimeType &&
          languageCode == other.languageCode &&
          countryCode == other.countryCode;

  @override
  int get hashCode => languageCode.hashCode ^ countryCode.hashCode;
}
