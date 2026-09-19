import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// A fallback delegate that provides Material and Cupertino localizations 
/// for languages not natively supported by Flutter (e.g., Hausa, Igbo, Yoruba, Zulu, etc.)
/// by falling back to English.
class FallbackLocalizationDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackLocalizationDelegate();

  @override
  bool isSupported(Locale locale) {
    // List all your custom languages that aren't natively supported by MaterialLocalizations
    return ['ha', 'ig', 'yo', 'zu', 'ak', 'fa', 'sw'].contains(locale.languageCode);
  }

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // Force the use of English Material localizations for these languages
    return GlobalMaterialLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(FallbackLocalizationDelegate old) => false;
}

class FallbackCupertinoLocalizationDelegate extends LocalizationsDelegate<dynamic> {
  const FallbackCupertinoLocalizationDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ha', 'ig', 'yo', 'zu', 'ak', 'fa', 'sw'].contains(locale.languageCode);
  }

  @override
  Future<dynamic> load(Locale locale) async {
    return GlobalCupertinoLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(FallbackCupertinoLocalizationDelegate old) => false;
}
