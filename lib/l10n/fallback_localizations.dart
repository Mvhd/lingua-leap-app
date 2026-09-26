import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// A set of fallback delegates that provide Material, Cupertino, and Widgets localizations 
/// for all supported languages in the app.
/// 
/// For languages natively supported by Flutter, it uses their native localizations.
/// For languages NOT natively supported (e.g., Hausa, Igbo, Yoruba, Zulu, Akan), 
/// it falls back to English to prevent crashes and warnings.
class FallbackLocalizationDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackLocalizationDelegate();

  static const List<String> _unsupportedByFlutter = ['ak', 'ha', 'ig', 'la', 'ug', 'yo', 'zu'];
  
  static const List<String> _appSupportedLocales = [
    'ak', 'ar', 'da', 'de', 'en', 'es', 'fa', 'fr', 'ha', 'hi', 'hu', 'ig', 'it', 'ja', 'ko', 'la', 'nl', 'pa', 'pl', 'pt', 'ru', 'sv', 'sw', 'ug', 'uk', 'ur', 'yo', 'zh', 'zu'
  ];

  @override
  bool isSupported(Locale locale) {
    return _appSupportedLocales.contains(locale.languageCode);
  }

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    final String targetCode = _unsupportedByFlutter.contains(locale.languageCode) ? 'en' : locale.languageCode;
    return GlobalMaterialLocalizations.delegate.load(Locale(targetCode));
  }

  @override
  bool shouldReload(FallbackLocalizationDelegate old) => false;
}

class FallbackCupertinoLocalizationDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationDelegate();

  @override
  bool isSupported(Locale locale) {
    return FallbackLocalizationDelegate._appSupportedLocales.contains(locale.languageCode);
  }

  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    final String targetCode = FallbackLocalizationDelegate._unsupportedByFlutter.contains(locale.languageCode) ? 'en' : locale.languageCode;
    return GlobalCupertinoLocalizations.delegate.load(Locale(targetCode));
  }

  @override
  bool shouldReload(FallbackCupertinoLocalizationDelegate old) => false;
}

class FallbackWidgetsLocalizationDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const FallbackWidgetsLocalizationDelegate();

  @override
  bool isSupported(Locale locale) {
    return FallbackLocalizationDelegate._appSupportedLocales.contains(locale.languageCode);
  }

  @override
  Future<WidgetsLocalizations> load(Locale locale) async {
    final String targetCode = FallbackLocalizationDelegate._unsupportedByFlutter.contains(locale.languageCode) ? 'en' : locale.languageCode;
    return GlobalWidgetsLocalizations.delegate.load(Locale(targetCode));
  }

  @override
  bool shouldReload(FallbackWidgetsLocalizationDelegate old) => false;
}
